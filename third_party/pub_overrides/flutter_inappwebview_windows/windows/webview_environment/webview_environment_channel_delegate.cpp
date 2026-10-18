#include "../utils/flutter.h"
#include "../utils/log.h"
#include "../utils/strconv.h"
#include "../utils/string.h"
#include "webview_environment.h"
#include "webview_environment_channel_delegate.h"

#include "webview_environment_manager.h"
#include <wil/wrl.h>

namespace flutter_inappwebview_plugin
{
  WebViewEnvironmentChannelDelegate::WebViewEnvironmentChannelDelegate(WebViewEnvironment* webViewEnv, flutter::BinaryMessenger* messenger)
    : webViewEnvironment(webViewEnv), ChannelDelegate(messenger, WebViewEnvironment::METHOD_CHANNEL_NAME_PREFIX + webViewEnv->id)
  {}

  void WebViewEnvironmentChannelDelegate::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (!webViewEnvironment) {
      result->Success();
      return;
    }

    // auto& arguments = std::get<flutter::EncodableMap>(*method_call.arguments());
    auto& methodName = method_call.method_name();

    if (string_equals(methodName, "dispose")) {
      if (webViewEnvironment->plugin && webViewEnvironment->plugin->webViewEnvironmentManager) {
        std::map<std::string, std::unique_ptr<WebViewEnvironment>>& webViewEnvironments = webViewEnvironment->plugin->webViewEnvironmentManager->webViewEnvironments;
        const auto id = webViewEnvironment->id;
        if (map_contains(webViewEnvironments, id)) {
          // A released environment can still have a departing browser process.
          // Keep the reply pending until that process releases its data folder.
          auto reply = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
          wil::com_ptr<ICoreWebView2Environment5> environment;
          auto token = std::make_shared<EventRegistrationToken>();
          bool waiting = false;
          if (SUCCEEDED(webViewEnvironment->getEnvironment()->QueryInterface(IID_PPV_ARGS(&environment)))) {
            waiting = SUCCEEDED(environment->add_BrowserProcessExited(
              Microsoft::WRL::Callback<ICoreWebView2BrowserProcessExitedEventHandler>(
                [environment, token, reply](ICoreWebView2Environment*, ICoreWebView2BrowserProcessExitedEventArgs*) -> HRESULT {
                  // Removing the handler may release the callback itself.
                  auto keepEnvironment = environment;
                  auto keepReply = reply;
                  const auto registration = *token;
                  keepEnvironment->remove_BrowserProcessExited(registration);
                  keepReply->Success();
                  return S_OK;
                }).Get(), token.get()));
          }
          webViewEnvironments.erase(id);
          if (!waiting) reply->Success();
          return;
        }
      }
      result->Success();
    }
    else {
      result->NotImplemented();
    }
  }

  WebViewEnvironmentChannelDelegate::~WebViewEnvironmentChannelDelegate()
  {
    debugLog("dealloc WebViewEnvironmentChannelDelegate");
    webViewEnvironment = nullptr;
  }
}
