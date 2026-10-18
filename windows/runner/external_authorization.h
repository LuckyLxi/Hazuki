#ifndef RUNNER_EXTERNAL_AUTHORIZATION_H_
#define RUNNER_EXTERNAL_AUTHORIZATION_H_
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <windows.h>
#include <map>
#include <memory>
#include <string>

// Called before console attachment and Dart creation. Unowned callbacks exit.
bool ForwardExternalAuthorizationCallback();

class ExternalAuthorization {
 public:
  static constexpr UINT kCallbackMessage = WM_APP + 80;
  ExternalAuthorization(flutter::BinaryMessenger* messenger, HWND window);
  ~ExternalAuthorization();
  void OnCallback(LPARAM payload);
 private:
  struct Pending;
  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::map<std::string, std::unique_ptr<Pending>> pending_;
};
#endif
