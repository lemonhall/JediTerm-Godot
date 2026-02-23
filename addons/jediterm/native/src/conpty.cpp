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

	// Pipe layout (matches EchoCon):
	// - Pass `in_read` and `out_write` to CreatePseudoConsole.
	// - Keep `in_write` for input, and `out_read` for output.
	if (!CreatePipe(&in_read, &in_write, &sa, 0)) {
		return ERR_CANT_OPEN;
	}
	if (!CreatePipe(&out_read, &out_write, &sa, 0)) {
		CloseHandle(in_read);
		CloseHandle(in_write);
		return ERR_CANT_OPEN;
	}

	// Our side should not be inherited by the child process.
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

	// Keep `in_read` / `out_write` alive until close().
	// ConPTY's backing conhost may duplicate these handles asynchronously; closing too early can
	// cause the child process to observe EOF / broken pipes immediately.

	// Prepare attribute list for STARTUPINFOEX.
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

	// Attach the created pseudo console to the child process via STARTUPINFOEX.
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

	// CreateProcessW requires a mutable command line buffer.
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

	{
		std::lock_guard<std::mutex> lock(_buffer_mutex);
		_pending_buffer.clear();
	}

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

	// Best-effort: ensure the child process is gone after close().
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

	// Cancel any pending synchronous ReadFile in the reader thread.
	// NOTE: Closing the handle from another thread does not reliably unblock a blocking ReadFile.
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
