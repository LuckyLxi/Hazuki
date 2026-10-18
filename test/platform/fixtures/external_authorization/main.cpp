// Generic test provider: accepts a generated callback, returns synthetic data.
// No real provider SDK, credentials, network requests or URL diagnostics.
#include <windows.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <string>
#include <vector>
#include <fstream>
int Finish(int code) { std::ofstream("build/mock-external-auth/provider-result.txt") << code; return code; }
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  int count = 0;
  auto args = CommandLineToArgvW(GetCommandLineW(), &count);
  std::wstring url = count == 2 ? args[1] : L"";
  LocalFree(args);
  if (count != 2) return Finish(10);
  if (url.rfind(L"hazuki-auth-mock-", 0) != 0) return Finish(11);
  const auto start = url.find(L"?callback=");
  if (start == std::wstring::npos) return Finish(12);
  std::wstring encoded = url.substr(start + 10);
  std::vector<wchar_t> decoded(encoded.size() + 1);
  DWORD size = static_cast<DWORD>(decoded.size());
  if (UrlUnescapeW(encoded.data(), decoded.data(), &size, 0) != S_OK) return Finish(2);
  const std::wstring callback(decoded.data());
  if (callback.rfind(L"hazuki-auth", 0) != 0 || callback.find(L"://authorize/") == std::wstring::npos) return Finish(3);
  const auto result = callback + L"?code=synthetic&state=mock-state";
  SHELLEXECUTEINFOW info{}; info.cbSize = sizeof(info); info.fMask = SEE_MASK_FLAG_NO_UI | SEE_MASK_NOASYNC;
  info.lpVerb = L"open"; info.lpFile = result.c_str(); info.nShow = SW_HIDE;
  return Finish(ShellExecuteExW(&info) ? 0 : 4);
}
