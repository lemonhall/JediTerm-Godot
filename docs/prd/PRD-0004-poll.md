## Codex 指令

### 任务：ConPTY 延迟优化 — 去掉 call_deferred，改用 poll 模式

### 背景

当前 `conpty.cpp` 的读取线程每收到一个 chunk 就 `call_deferred("emit_signal", "data_received", data)`，这导致数据要等到下一帧 idle 阶段才被 GDScript 处理，体感延迟明显。实测终端渲染本身只需 0.58ms，瓶颈完全在数据通路延迟。

### 改动方案

C++ 侧：读取线程不再 emit 信号，改为往一个 Mutex 保护的内部 buffer 里追加数据。暴露一个 `poll_data()` 方法给 GDScript，每帧调用一次，一次性取走所有积压数据。

GDScript 侧：`_process()` 里每帧调用 `poll_data()`，拿到数据后喂给 VT 解析器。

### 文件 1：`addons/jediterm/native/src/conpty.cpp`

把整个文件替换为以下内容：

```cpp
#include "conpty.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <array>
#include <atomic>
#include <cstring>
#include <mutex>
#include <thread>
#include <vector>

#if defined(_WIN32) && !defined(_CONPTY_DISABLED)
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <consoleapi.h>
#include <processthreadsapi.h>
#include <wincon.h>
#include <winerror.h>

#ifndef PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE
#define PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE 0x00020016
#endif
#endif

using namespace godot;

ConPTY::ConPTY() {
#if defined(_WIN32) && !defined(_CONPTY_DISABLED)
	_stop_requested.store(false);
	_pending_exit_code.store(-1);
	_process_exited_flag.store(false);
#endif
}

ConPTY::~ConPTY() {
	close();
}

void ConPTY::_bind_methods() {
	ClassDB::bind_method(D_METHOD("open", "cols", "rows", "command"), &ConPTY::open);
	ClassDB::bind_method(D_METHOD("write", "data"), &ConPTY::write);
	ClassDB::bind_method(D_METHOD("resize", "cols", "rows"), &ConPTY::resize);
	ClassDB::bind_method(D_METHOD("close"), &ConPTY::close);
	ClassDB::bind_method(D_METHOD("poll_data"), &ConPTY::poll_data);

	ADD_SIGNAL(MethodInfo("data_received", PropertyInfo(Variant::PACKED_BYTE_ARRAY, "data")));
	ADD_SIGNAL(MethodInfo("process_exited", PropertyInfo(Variant::INT, "exit_code")));
}

PackedByteArray ConPTY::poll_data() {
#if !defined(_WIN32) || defined(_CONPTY_DISABLED)
	return PackedByteArray();
#else
	PackedByteArray result;

	{
		std::lock_guard<std::mutex> lock(_buffer_mutex);
		if (!_pending_buffer.empty()) {
			result.resize((int)_pending_buffer.size());
			memcpy(result.ptrw(), _pending_buffer.data(), _pending_buffer.size());
			_pending_buffer.clear();
		}
	}

	// Emit signal for backward compatibility (GDScript code that connects to data_received still works)
	if (result.size() > 0) {
		emit_signal("data_received", result);
	}

	// Check if process exited
	if (_process_exited_flag.load()) {
		_process_exited_flag.store(false);
		emit_signal("process_exited", _pending_exit_code.load());
	}

	return result;
#endif
}

int ConPTY::open(int cols, int rows, const String &command) {
#if !defined(_WIN32) || defined(_CONPTY_DISABLED)
	return ERR_UNAVAILABLE;
#else
	if (_is_opened) {
		return ERR_ALREADY_IN_USE;
	}
	if (cols <= 0 || rows <= 0) {
		return ERR_INVALID_PARAMETER;
	}

	HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
	if (!kernel32) {
		return ERR_UNAVAILABLE;
	}

	using CreatePseudoConsoleFn = HRESULT(WINAPI *)(COORD, HANDLE, HANDLE, DWORD, HPCON *);
	using ClosePseudoConsoleFn = void(WINAPI *)(HPCON);
	using ResizePseudoConsoleFn = HRESULT(WINAPI *)(HPCON, COORD);

	auto pCreatePseudoConsole = reinterpret_cast<CreatePseudoConsoleFn>(GetProcAddress(kernel32, "CreatePseudoConsole"));
	auto pClosePseudoConsole = reinterpret_cast<ClosePseudoConsoleFn>(GetProcAddress(kernel32, "ClosePseudoConsole"));
	auto pResizePseudoConsole = reinterpret_cast<ResizePseudoConsoleFn>(GetProcAddress(kernel32, "ResizePseudoConsole"));
	if (!pCreatePseudoConsole || !pClosePseudoConsole || !pResizePseudoConsole) {
		return ERR_UNAVAILABLE;
	}

	SECURITY_ATTRIBUTES sa{};
	sa.nLength = sizeof(sa);
	sa.bInheritHandle = TRUE;

	HANDLE in_read = INVALID_HANDLE_VALUE;
	HANDLE in_write = INVALID_HANDLE_VALUE;
	HANDLE out_read = INVALID_HANDLE_VALUE;
	HANDLE out_write = INVALID_HANDLE_VALUE;

	if (!CreatePipe(&in_read, &in_write, &sa, 0)) {
		return ERR_CANT_OPEN;
	}
	if (!CreatePipe(&out_read, &out_write, &sa, 0)) {
		CloseHandle(in_read);
		CloseHandle(in_write);
		return ERR_CANT_OPEN;
	}

	SetHandleInformation(in_write, HANDLE_FLAG_INHERIT, 0);
	SetHandleInformation(out_read, HANDLE_FLAG_INHERIT, 0);

	COORD size{};
	size.X = (SHORT)cols;
	size.Y = (SHORT)rows;

	HPCON hpc = nullptr;
	HRESULT hr = pCreatePseudoConsole(size, in_read, out_write, 0, &hpc);

	if (FAILED(hr) || hpc == nullptr) {
		CloseHandle(in_read);
		CloseHandle(out_write);
		CloseHandle(in_write);
		CloseHandle(out_read);
		return ERR_CANT_OPEN;
	}

	SIZE_T attr_size = 0;
	InitializeProcThreadAttributeList(nullptr, 1, 0, &attr_size);
	auto attr_list = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(malloc(attr_size));
	if (!attr_list) {
		pClosePseudoConsole(hpc);
		CloseHandle(in_write);
		CloseHandle(out_read);
		return ERR_OUT_OF_MEMORY;
	}

	if (!InitializeProcThreadAttributeList(attr_list, 1, 0, &attr_size)) {
		::free(attr_list);
		pClosePseudoConsole(hpc);
		CloseHandle(in_write);
		CloseHandle(out_read);
		return ERR_CANT_OPEN;
	}

	if (!UpdateProcThreadAttribute(attr_list, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, hpc, sizeof(HPCON), nullptr, nullptr)) {
		DeleteProcThreadAttributeList(attr_list);
		::free(attr_list);
		pClosePseudoConsole(hpc);
		CloseHandle(in_write);
		CloseHandle(out_read);
		return ERR_CANT_OPEN;
	}

	STARTUPINFOEXW si{};
	ZeroMemory(&si, sizeof(si));
	si.StartupInfo.cb = sizeof(STARTUPINFOEXW);
	si.lpAttributeList = attr_list;

	String cmd = command;
	if (cmd.is_empty()) {
		cmd = "powershell.exe";
	}

	Char16String u16 = cmd.utf16();
	std::vector<wchar_t> cmdline;
	cmdline.reserve((size_t)u16.length() + 1);
	for (int i = 0; i < (int)u16.length(); i++) {
		cmdline.push_back((wchar_t)u16[i]);
	}
	cmdline.push_back(L'\0');

	PROCESS_INFORMATION pi{};
	BOOL ok = CreateProcessW(
			nullptr,
			cmdline.data(),
			nullptr,
			nullptr,
			FALSE,
			EXTENDED_STARTUPINFO_PRESENT,
			nullptr,
			nullptr,
			&si.StartupInfo,
			&pi);

	DeleteProcThreadAttributeList(attr_list);
	::free(attr_list);

	if (!ok) {
		pClosePseudoConsole(hpc);
		CloseHandle(in_write);
		CloseHandle(out_read);
		return ERR_CANT_FORK;
	}

	_hpc = hpc;
	_h_in_read = in_read;
	_h_out_write = out_write;
	_h_in_write = in_write;
	_h_out_read = out_read;
	_h_process = pi.hProcess;
	_h_thread = pi.hThread;
	_is_opened = true;

	_start_reader_thread();
	return OK;
#endif
}

int ConPTY::write(const PackedByteArray &data) {
#if !defined(_WIN32) || defined(_CONPTY_DISABLED)
	return -1;
#else
	if (!_is_opened || _h_in_write == nullptr) {
		return -1;
	}
	if (data.is_empty()) {
		return 0;
	}

	HANDLE h = (HANDLE)_h_in_write;
	DWORD written = 0;
	BOOL ok = WriteFile(h, data.ptr(), (DWORD)data.size(), &written, nullptr);
	if (!ok) {
		return -1;
	}
	return (int)written;
#endif
}

int ConPTY::resize(int cols, int rows) {
#if !defined(_WIN32) || defined(_CONPTY_DISABLED)
	return ERR_UNAVAILABLE;
#else
	if (!_is_opened || _hpc == nullptr) {
		return ERR_UNCONFIGURED;
	}
	if (cols <= 0 || rows <= 0) {
		return ERR_INVALID_PARAMETER;
	}

	HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
	if (!kernel32) {
		return ERR_UNAVAILABLE;
	}
	using ResizePseudoConsoleFn = HRESULT(WINAPI *)(HPCON, COORD);
	auto pResizePseudoConsole = reinterpret_cast<ResizePseudoConsoleFn>(GetProcAddress(kernel32, "ResizePseudoConsole"));
	if (!pResizePseudoConsole) {
		return ERR_UNAVAILABLE;
	}

	COORD size{};
	size.X = (SHORT)cols;
	size.Y = (SHORT)rows;
	HRESULT hr = pResizePseudoConsole((HPCON)_hpc, size);
	return FAILED(hr) ? ERR_CANT_CREATE : OK;
#endif
}

void ConPTY::close() {
#if !defined(_WIN32) || defined(_CONPTY_DISABLED)
	_is_opened = false;
#else
	if (!_is_opened) {
		return;
	}

	_stop_reader_thread();

	HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
	using ClosePseudoConsoleFn = void(WINAPI *)(HPCON);
	auto pClosePseudoConsole = kernel32 ? reinterpret_cast<ClosePseudoConsoleFn>(GetProcAddress(kernel32, "ClosePseudoConsole")) : nullptr;

	if (_h_process != nullptr) {
		DWORD code = STILL_ACTIVE;
		if (GetExitCodeProcess((HANDLE)_h_process, &code) && code == STILL_ACTIVE) {
			TerminateProcess((HANDLE)_h_process, 0);
			WaitForSingleObject((HANDLE)_h_process, 2000);
		}
	}

	if (_h_in_write != nullptr) {
		CloseHandle((HANDLE)_h_in_write);
		_h_in_write = nullptr;
	}
	if (_h_out_read != nullptr) {
		CloseHandle((HANDLE)_h_out_read);
		_h_out_read = nullptr;
	}
	if (_h_in_read != nullptr) {
		CloseHandle((HANDLE)_h_in_read);
		_h_in_read = nullptr;
	}
	if (_h_out_write != nullptr) {
		CloseHandle((HANDLE)_h_out_write);
		_h_out_write = nullptr;
	}

	if (_h_thread != nullptr) {
		CloseHandle((HANDLE)_h_thread);
		_h_thread = nullptr;
	}
	if (_h_process != nullptr) {
		CloseHandle((HANDLE)_h_process);
		_h_process = nullptr;
	}

	if (_hpc != nullptr && pClosePseudoConsole) {
		pClosePseudoConsole((HPCON)_hpc);
	}
	_hpc = nullptr;
	_is_opened = false;
#endif
}

#if defined(_WIN32) && !defined(_CONPTY_DISABLED)
void ConPTY::_start_reader_thread() {
	_stop_requested.store(false);
	_process_exited_flag.store(false);
	_reader_thread = new std::thread([this]() {
		HANDLE h = (HANDLE)_h_out_read;
		if (h == nullptr || h == INVALID_HANDLE_VALUE) {
			return;
		}

		// Larger buffer = fewer syscalls, fewer mutex locks
		std::array<uint8_t, 32768> buf{};
		while (!_stop_requested.load()) {
			DWORD read = 0;
			BOOL ok = ReadFile(h, buf.data(), (DWORD)buf.size(), &read, nullptr);
			if (!ok) {
				DWORD err = GetLastError();
				if (err == ERROR_OPERATION_ABORTED && _stop_requested.load()) {
					break;
				}
				if (err == ERROR_BROKEN_PIPE || err == ERROR_INVALID_HANDLE) {
					break;
				}
				break;
			}
			if (read == 0) {
				break;
			}

			{
				std::lock_guard<std::mutex> lock(_buffer_mutex);
				_pending_buffer.insert(_pending_buffer.end(), buf.data(), buf.data() + read);
			}
		}

		// Best-effort exit code.
		int exit_code = -1;
		if (_h_process != nullptr) {
			DWORD code = STILL_ACTIVE;
			if (GetExitCodeProcess((HANDLE)_h_process, &code) && code != STILL_ACTIVE) {
				exit_code = (int)code;
			}
		}
		_pending_exit_code.store(exit_code);
		_process_exited_flag.store(true);
	});
}

void ConPTY::_stop_reader_thread() {
	if (_reader_thread == nullptr) {
		return;
	}
	_stop_requested.store(true);

	CancelSynchronousIo((HANDLE)_reader_thread->native_handle());

	_reader_thread->join();
	delete _reader_thread;
	_reader_thread = nullptr;

	if (_h_out_read != nullptr) {
		CloseHandle((HANDLE)_h_out_read);
		_h_out_read = nullptr;
	}
}
#endif
```

### 文件 2：`addons/jediterm/native/src/conpty.h`

需要在头文件中添加新的成员变量和方法声明。在现有的 private 成员区域中添加：

```cpp
// 在已有的 #include 之后添加
#include <mutex>
#include <vector>
#include <atomic>
```

在类声明中添加：

```cpp
public:
	PackedByteArray poll_data();

private:
	// Poll-mode buffer (replaces call_deferred signal emission)
	std::mutex _buffer_mutex;
	std::vector<uint8_t> _pending_buffer;
	std::atomic<int> _pending_exit_code{-1};
	std::atomic<bool> _process_exited_flag{false};
```

并删除原有的这两个方法声明（如果存在）：

```cpp
// 删除这两行
void _emit_data_received_deferred(const PackedByteArray &data);
void _emit_process_exited_deferred(int exit_code);
```

### 文件 3：`addons/jediterm/scenes/render_v3_conpty_demo.gd`（外层 demo 脚本）

修改 `_process` 和 `_on_pty_data_received`：

```gdscript
func _process(_delta: float) -> void:
	# Poll PTY data every frame — no more call_deferred delay
	if _pty != null and _pty.has_method("poll_data"):
		var data: PackedByteArray = _pty.poll_data()
		# poll_data() already emits data_received signal for backward compat,
		# so _on_pty_data_received will be called via signal.
		# But if we want minimal latency, process directly here:
		if data.size() > 0 and _terminal != null and _terminal.has_method("processBytes"):
			_terminal.processBytes(data)

	var fps := int(Engine.get_frames_per_second())
	var has_pty := (_pty != null)
	info.text = "Render v3 ConPTY demo | FPS:%d | PTY:%s | Font:%s@%d" % [
		fps,
		("YES" if has_pty else "NO"),
		_font_label,
		int(_font_px),
	]
```

同时把 `_on_pty_data_received` 改成空操作，避免 poll_data 里 emit 的信号导致重复处理：

```gdscript
func _on_pty_data_received(_data: PackedByteArray) -> void:
	# Data is now processed directly in _process() via poll_data().
	# This callback is kept for backward compatibility but does nothing.
	pass
```

### 改完后

编译：
```powershell
pwsh -NoProfile -File scripts/build_conpty_gdextension.ps1
```

测试：
```powershell
& $env:GODOT_WIN_EXE --headless --path . --script res://tests/debug_conpty_raw.gd 2>&1
```

### 改动总结

- C++ 读取线程：`call_deferred` → mutex 保护的 `vector<uint8_t>` buffer，ReadFile buffer 从 4096 → 32768
- 新增 `poll_data()` 方法：GDScript 每帧主动取数据，同帧处理，同帧渲染
- 数据从到达到显示：从 2-3 帧延迟降到最多 1 帧（16ms）