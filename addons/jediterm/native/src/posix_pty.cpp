#include "posix_pty.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/variant/char_string.hpp>

#include <string>
#include <cstring>

#if !defined(_WIN32)
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <util.h>
#else
#include <pty.h>
#endif

#include <poll.h>
#endif

using namespace godot;

PosixPTY::PosixPTY() {
	_stop_requested.store(false);
	_pending_exit_code.store(-1);
	_process_exited_flag.store(false);
}

PosixPTY::~PosixPTY() {
	close();
}

void PosixPTY::_bind_methods() {
	ClassDB::bind_method(D_METHOD("open", "cols", "rows", "command"), &PosixPTY::open);
	ClassDB::bind_method(D_METHOD("write", "data"), &PosixPTY::write);
	ClassDB::bind_method(D_METHOD("resize", "cols", "rows"), &PosixPTY::resize);
	ClassDB::bind_method(D_METHOD("close"), &PosixPTY::close);
	ClassDB::bind_method(D_METHOD("poll_data"), &PosixPTY::poll_data);

	ADD_SIGNAL(MethodInfo("data_received", PropertyInfo(Variant::PACKED_BYTE_ARRAY, "data")));
	ADD_SIGNAL(MethodInfo("process_exited", PropertyInfo(Variant::INT, "exit_code")));
}

PackedByteArray PosixPTY::poll_data() {
	PackedByteArray result;

	{
		std::lock_guard<std::mutex> lock(_buffer_mutex);
		if (!_pending_buffer.empty()) {
			result.resize((int)_pending_buffer.size());
			memcpy(result.ptrw(), _pending_buffer.data(), _pending_buffer.size());
			_pending_buffer.clear();
		}
	}

	if (result.size() > 0) {
		emit_signal("data_received", result);
	}

	if (_process_exited_flag.load()) {
		_process_exited_flag.store(false);
		emit_signal("process_exited", _pending_exit_code.load());
	}

	return result;
}

int PosixPTY::open(int cols, int rows, const String &command) {
#if defined(_WIN32)
	return ERR_UNAVAILABLE;
#else
	if (_is_opened) {
		return ERR_ALREADY_IN_USE;
	}
	if (cols <= 0 || rows <= 0) {
		return ERR_INVALID_PARAMETER;
	}

	struct winsize ws {};
	ws.ws_col = (unsigned short)cols;
	ws.ws_row = (unsigned short)rows;
	ws.ws_xpixel = 0;
	ws.ws_ypixel = 0;

	int master_fd = -1;
	int pid = ::forkpty(&master_fd, nullptr, nullptr, &ws);
	if (pid < 0) {
		return ERR_CANT_FORK;
	}

	if (pid == 0) {
		// Child: start a shell command via /bin/sh -lc "<command>".
		::setenv("TERM", "xterm-256color", 0);

		std::string cmd;
		if (command.is_empty()) {
			const char *shell = ::getenv("SHELL");
			if (shell == nullptr || shell[0] == '\0') {
				shell = "/bin/sh";
			}
			cmd = std::string(shell) + " -l";
		} else {
			CharString cs = command.utf8();
			cmd = std::string(cs.get_data());
		}

		::execl("/bin/sh", "sh", "-lc", cmd.c_str(), (char *)nullptr);
		::_exit(127);
	}

	// Parent
	_master_fd = master_fd;
	_child_pid.store(pid);
	_is_opened = true;

	// Non-blocking IO for smoother polling.
	int flags = ::fcntl(_master_fd, F_GETFL, 0);
	if (flags >= 0) {
		::fcntl(_master_fd, F_SETFL, flags | O_NONBLOCK);
	}

	{
		std::lock_guard<std::mutex> lock(_buffer_mutex);
		_pending_buffer.clear();
	}

	_start_reader_thread();
	return OK;
#endif
}

int PosixPTY::write(const PackedByteArray &data) {
#if defined(_WIN32)
	return -1;
#else
	if (!_is_opened || _master_fd < 0) {
		return -1;
	}
	if (data.is_empty()) {
		return 0;
	}

	ssize_t n = ::write(_master_fd, data.ptr(), (size_t)data.size());
	if (n < 0) {
		return -1;
	}
	return (int)n;
#endif
}

int PosixPTY::resize(int cols, int rows) {
#if defined(_WIN32)
	return ERR_UNAVAILABLE;
#else
	if (!_is_opened || _master_fd < 0) {
		return ERR_UNCONFIGURED;
	}
	if (cols <= 0 || rows <= 0) {
		return ERR_INVALID_PARAMETER;
	}

	struct winsize ws {};
	ws.ws_col = (unsigned short)cols;
	ws.ws_row = (unsigned short)rows;
	ws.ws_xpixel = 0;
	ws.ws_ypixel = 0;
	int rc = ::ioctl(_master_fd, TIOCSWINSZ, &ws);
	return (rc == 0) ? OK : ERR_CANT_CREATE;
#endif
}

void PosixPTY::close() {
#if defined(_WIN32)
	_is_opened = false;
#else
	if (!_is_opened) {
		return;
	}

	_stop_reader_thread();

	if (_master_fd >= 0) {
		::close(_master_fd);
		_master_fd = -1;
	}

	// Best-effort: ensure child is gone.
	int pid = _child_pid.exchange(-1);
	if (pid > 0) {
		int status = 0;
		pid_t w = ::waitpid(pid, &status, WNOHANG);
		if (w == 0) {
			::kill(pid, SIGHUP);
			// Give it a moment.
			for (int i = 0; i < 20; i++) {
				w = ::waitpid(pid, &status, WNOHANG);
				if (w != 0) {
					break;
				}
				::usleep(1000 * 10);
			}
			if (w == 0) {
				::kill(pid, SIGTERM);
			}
		}
	}

	_is_opened = false;
#endif
}

void PosixPTY::_start_reader_thread() {
#if defined(_WIN32)
	return;
#else
	_stop_requested.store(false);
	_process_exited_flag.store(false);
	_reader_thread = new std::thread([this]() {
		if (_master_fd < 0) {
			return;
		}

		std::vector<uint8_t> buf;
		buf.resize(32768);

		while (!_stop_requested.load()) {
			// Check child exit.
			int pid = _child_pid.load();
			if (pid > 0) {
				int status = 0;
				pid_t w = ::waitpid(pid, &status, WNOHANG);
				if (w == pid) {
					int code = -1;
					if (WIFEXITED(status)) {
						code = WEXITSTATUS(status);
					} else if (WIFSIGNALED(status)) {
						code = 128 + WTERMSIG(status);
					}
					_pending_exit_code.store(code);
					_process_exited_flag.store(true);
					_child_pid.store(-1);
					break;
				}
			}

			struct pollfd pfd {};
			pfd.fd = _master_fd;
			pfd.events = POLLIN;
			int prc = ::poll(&pfd, 1, 20);
			if (prc < 0) {
				if (errno == EINTR) {
					continue;
				}
				break;
			}
			if (prc == 0) {
				continue;
			}
			if (pfd.revents & (POLLERR | POLLHUP | POLLNVAL)) {
				break;
			}
			if (!(pfd.revents & POLLIN)) {
				continue;
			}

			ssize_t n = ::read(_master_fd, buf.data(), buf.size());
			if (n < 0) {
				if (errno == EAGAIN || errno == EINTR) {
					continue;
				}
				break;
			}
			if (n == 0) {
				break;
			}

			{
				std::lock_guard<std::mutex> lock(_buffer_mutex);
				_pending_buffer.insert(_pending_buffer.end(), buf.data(), buf.data() + n);
			}
		}

		// If we reached here without a recorded exit, record best-effort.
		if (!_process_exited_flag.load()) {
			int status = 0;
			int code = -1;
			int pid = _child_pid.load();
			if (pid > 0) {
				pid_t w = ::waitpid(pid, &status, WNOHANG);
				if (w == pid) {
					if (WIFEXITED(status)) {
						code = WEXITSTATUS(status);
					} else if (WIFSIGNALED(status)) {
						code = 128 + WTERMSIG(status);
					}
				}
			}
			_pending_exit_code.store(code);
			_process_exited_flag.store(true);
		}
	});
#endif
}

void PosixPTY::_stop_reader_thread() {
#if defined(_WIN32)
	return;
#else
	if (_reader_thread == nullptr) {
		return;
	}
	_stop_requested.store(true);
	_reader_thread->join();
	delete _reader_thread;
	_reader_thread = nullptr;
#endif
}
