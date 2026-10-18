#include "external_authorization.h"
#include <flutter/standard_method_codec.h>
#include <sddl.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <algorithm>
#include <thread>
#include <vector>
#include "utils.h"

namespace {
std::wstring Executable() {
  std::vector<wchar_t> path(32768);
  const auto size = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  return std::wstring(path.data(), size);
}
std::wstring InstallationId() {
  auto path = Executable();
  std::transform(path.begin(), path.end(), path.begin(), towlower);
  uint64_t hash = 14695981039346656037ull;
  for (auto c : path) { hash ^= static_cast<uint64_t>(c); hash *= 1099511628211ull; }
  wchar_t value[17];
  swprintf_s(value, L"%016llx", static_cast<unsigned long long>(hash));
  return value;
}
std::wstring Command() { return L"\"" + Executable() + L"\" \"%1\""; }
std::wstring Scheme() {
#ifdef _DEBUG
  return L"hazuki-auth-debug-" + InstallationId();
#else
  wchar_t command[32768]; DWORD size = sizeof(command);
  if (RegGetValueW(HKEY_CURRENT_USER, L"Software\\Classes\\hazuki-auth\\shell\\open\\command", nullptr,
      RRF_RT_REG_SZ, nullptr, command, &size) == ERROR_SUCCESS && _wcsicmp(Command().c_str(), command) == 0) return L"hazuki-auth";
  return L"hazuki-auth-portable-" + InstallationId();
#endif
}
std::wstring PipeName(const std::wstring& id) { return L"\\\\.\\pipe\\HazukiAuth-" + InstallationId() + L"-" + id; }
bool IsId(const std::wstring& id) {
  return id.size() == 32 && std::all_of(id.begin(), id.end(), [](wchar_t c) { return (c >= L'0' && c <= L'9') || (c >= L'a' && c <= L'f'); });
}
bool Matches(const std::wstring& url, const std::wstring& id) {
  const auto base = Scheme() + L"://authorize/" + id;
  return url.size() <= 32768 && url.compare(0, base.size(), base) == 0 &&
    (url.size() == base.size() || url[base.size()] == L'?' || url[base.size()] == L'#');
}
bool RegisterProtocol() {
  const auto key = L"Software\\Classes\\" + Scheme();
  HKEY handle;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, key.c_str(), 0, nullptr, 0, KEY_SET_VALUE, nullptr, &handle, nullptr) != ERROR_SUCCESS) return false;
  const wchar_t label[] = L"URL:Hazuki authorization";
  const auto first = RegSetValueExW(handle, nullptr, 0, REG_SZ, reinterpret_cast<const BYTE*>(label), sizeof(label));
  const auto second = RegSetValueExW(handle, L"URL Protocol", 0, REG_SZ, reinterpret_cast<const BYTE*>(L""), sizeof(wchar_t));
  RegCloseKey(handle);
  if (first != ERROR_SUCCESS || second != ERROR_SUCCESS) return false;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, (key + L"\\shell\\open\\command").c_str(), 0, nullptr, 0, KEY_SET_VALUE, nullptr, &handle, nullptr) != ERROR_SUCCESS) return false;
  const auto command = Command();
  const auto status = RegSetValueExW(handle, nullptr, 0, REG_SZ, reinterpret_cast<const BYTE*>(command.c_str()), static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(handle);
  return status == ERROR_SUCCESS;
}
PSECURITY_DESCRIPTOR UserOnlyDescriptor() {
  HANDLE token;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return nullptr;
  DWORD length = 0; GetTokenInformation(token, TokenUser, nullptr, 0, &length);
  std::vector<BYTE> data(length);
  const bool ok = GetTokenInformation(token, TokenUser, data.data(), length, &length) != FALSE;
  CloseHandle(token);
  if (!ok) return nullptr;
  LPWSTR sid = nullptr;
  if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(data.data())->User.Sid, &sid)) return nullptr;
  const auto sddl = std::wstring(L"D:P(A;;GA;;;") + sid + L")";
  LocalFree(sid);
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr);
  return descriptor;
}
std::string StringArg(const flutter::EncodableMap& map, const char* name) {
  const auto it = map.find(flutter::EncodableValue(name));
  if (it == map.end()) return {};
  const auto value = std::get_if<std::string>(&it->second);
  return value ? *value : std::string();
}
std::wstring Wide(const std::string& text) {
  if (text.empty()) return {};
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
  if (count == 0) return {};
  std::wstring value(count, 0);
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), value.data(), count);
  return value;
}
bool Await(HANDLE pipe, HANDLE stop, OVERLAPPED& overlapped) {
  HANDLE waits[] = {stop, overlapped.hEvent};
  if (WaitForMultipleObjects(2, waits, FALSE, INFINITE) != WAIT_OBJECT_0 + 1) {
    CancelIoEx(pipe, &overlapped);
    WaitForSingleObject(overlapped.hEvent, INFINITE);
    return false;
  }
  DWORD transferred;
  return GetOverlappedResult(pipe, &overlapped, &transferred, FALSE) != FALSE;
}
}  // namespace

bool ForwardExternalAuthorizationCallback() {
  int count = 0;
  auto argv = CommandLineToArgvW(GetCommandLineW(), &count);
  if (!argv) return false;
  std::wstring url;
  for (int i = 1; i < count; ++i) {
    if (std::wstring(argv[i]).rfind(L"hazuki-auth", 0) == 0) { url = argv[i]; break; }
  }
  LocalFree(argv);
  if (url.empty()) return false;
  const auto base = Scheme() + L"://authorize/";
  if (url.compare(0, base.size(), base) != 0 || url.size() < base.size() + 32) return true;
  const auto id = url.substr(base.size(), 32);
  if (!IsId(id) || !Matches(url, id)) return true;
  const auto pipeName = PipeName(id);
  HANDLE pipe = CreateFileW(pipeName.c_str(), GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, 0, nullptr);
  if (pipe == INVALID_HANDLE_VALUE) return true;
  DWORD written;
  WriteFile(pipe, url.data(), static_cast<DWORD>(url.size() * sizeof(wchar_t)), &written, nullptr);
  CloseHandle(pipe);
  return true;
}

struct ExternalAuthorization::Pending {
  HANDLE pipe = INVALID_HANDLE_VALUE;
  HANDLE stop = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  std::thread thread;
  ~Pending() {
    SetEvent(stop);
    if (thread.joinable()) thread.join();
    if (pipe != INVALID_HANDLE_VALUE) CloseHandle(pipe);
    CloseHandle(stop);
  }
};

ExternalAuthorization::ExternalAuthorization(flutter::BinaryMessenger* messenger, HWND window) : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(messenger, "hazuki/external_authorization", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto* args = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
    if (!args) { result->Error("login_invalid_external_options"); return; }
    const auto id = StringArg(*args, "id");
    const auto wideId = Wide(id);
    if (!IsId(wideId)) { result->Error("login_invalid_external_session"); return; }
    if (call.method_name() == "close") { pending_.erase(id); result->Success(); return; }
    if (call.method_name() == "prepare") {
      if (pending_.count(id) || !RegisterProtocol()) { result->Error("login_external_unavailable"); return; }
      auto pending = std::make_unique<Pending>();
      auto descriptor = UserOnlyDescriptor();
      if (!descriptor) { result->Error("login_external_unavailable"); return; }
      SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), descriptor, FALSE};
      pending->pipe = CreateNamedPipeW(PipeName(wideId).c_str(), PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
        PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS, 1, 65536, 65536, 0, &security);
      LocalFree(descriptor);
      if (pending->pipe == INVALID_HANDLE_VALUE) { result->Error("login_external_unavailable"); return; }
      auto* state = pending.get();
      state->thread = std::thread([state, wideId, window = window_] {
        OVERLAPPED operation{}; operation.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        const bool connected = ConnectNamedPipe(state->pipe, &operation) != FALSE;
        const auto error = connected ? ERROR_SUCCESS : GetLastError();
        if (connected || error == ERROR_PIPE_CONNECTED || (error == ERROR_IO_PENDING && Await(state->pipe, state->stop, operation))) {
          ResetEvent(operation.hEvent);
          std::vector<wchar_t> data(32769); DWORD bytes = 0;
          const bool read = ReadFile(state->pipe, data.data(), 65536, &bytes, &operation) != FALSE;
          if (read || (GetLastError() == ERROR_IO_PENDING && Await(state->pipe, state->stop, operation))) {
            if (!read) GetOverlappedResult(state->pipe, &operation, &bytes, FALSE);
            const std::wstring url(data.data(), bytes / sizeof(wchar_t));
            if (bytes % sizeof(wchar_t) == 0 && Matches(url, wideId)) {
              auto payload = std::make_unique<std::wstring>(url);
              if (PostMessageW(window, kCallbackMessage, 0, reinterpret_cast<LPARAM>(payload.get()))) payload.release();
            }
          }
        }
        CloseHandle(operation.hEvent);
      });
      pending_[id] = std::move(pending);
      result->Success(flutter::EncodableValue(Utf8FromUtf16((Scheme() + L"://authorize/" + wideId).c_str())));
    } else if (call.method_name() == "launch") {
      const auto url = StringArg(*args, "url");
      const auto colon = url.find(':');
      const auto scheme = url.substr(0, colon);
      const std::vector<std::string> denied{"file", "javascript", "data", "vbscript", "shell", "powershell", "cmd", "intent", "about", "blob", "ms-msdt", "search-ms", "ms-settings"};
      const auto allowedIt = args->find(flutter::EncodableValue("allowedSchemes"));
      const auto* allowed = allowedIt == args->end() ? nullptr : std::get_if<flutter::EncodableList>(&allowedIt->second);
      if (!pending_.count(id) || url.size() > 32768 || colon == std::string::npos || url.find_first_of(" \t\r\n\\") != std::string::npos ||
          !allowed || std::find(allowed->begin(), allowed->end(), flutter::EncodableValue(scheme)) == allowed->end() || std::find(denied.begin(), denied.end(), scheme) != denied.end()) {
        result->Error("login_invalid_external_url"); return;
      }
      const auto wideUrl = Wide(url);
      DWORD executableLength = 0;
      if (FAILED(AssocQueryStringW(ASSOCF_IS_PROTOCOL, ASSOCSTR_EXECUTABLE,
          Wide(scheme).c_str(), L"open", nullptr, &executableLength)) || executableLength == 0) {
        result->Success(flutter::EncodableValue(false)); return;
      }
      SHELLEXECUTEINFOW info{}; info.cbSize = sizeof(info); info.fMask = SEE_MASK_FLAG_NO_UI | SEE_MASK_NOASYNC;
      info.hwnd = window_; info.lpVerb = L"open"; info.lpFile = wideUrl.c_str(); info.nShow = SW_SHOWNORMAL;
      result->Success(flutter::EncodableValue(ShellExecuteExW(&info) != FALSE));
    } else { result->NotImplemented(); }
  });
}

ExternalAuthorization::~ExternalAuthorization() { channel_->SetMethodCallHandler(nullptr); pending_.clear(); }
void ExternalAuthorization::OnCallback(LPARAM payload) {
  std::unique_ptr<std::wstring> url(reinterpret_cast<std::wstring*>(payload));
  if (!url) return;
  for (const auto& pending : pending_) {
    if (Matches(*url, Wide(pending.first))) {
      channel_->InvokeMethod("callback", std::make_unique<flutter::EncodableValue>(Utf8FromUtf16(url->c_str())));
      return;
    }
  }
}
