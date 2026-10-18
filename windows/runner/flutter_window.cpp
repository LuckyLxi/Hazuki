#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "reader_image_actions.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  external_authorization_ = std::make_unique<ExternalAuthorization>(flutter_controller_->engine()->messenger(), GetHandle());
  media_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "hazuki.comics/media",
          &flutter::StandardMethodCodec::GetInstance());
  media_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "copyImage") {
          result->NotImplemented();
          return;
        }
        const auto* arguments =
            call.arguments()
                ? std::get_if<flutter::EncodableMap>(call.arguments())
                : nullptr;
        if (!arguments) {
          result->Error("invalid_image", "Missing image data");
          return;
        }
        const auto bytes_it = arguments->find(flutter::EncodableValue("bytes"));
        const auto width_it = arguments->find(flutter::EncodableValue("width"));
        const auto height_it =
            arguments->find(flutter::EncodableValue("height"));
        const auto* bytes =
            bytes_it == arguments->end()
                ? nullptr
                : std::get_if<std::vector<uint8_t>>(&bytes_it->second);
        const auto* width = width_it == arguments->end()
                                ? nullptr
                                : std::get_if<int32_t>(&width_it->second);
        const auto* height = height_it == arguments->end()
                                 ? nullptr
                                 : std::get_if<int32_t>(&height_it->second);
        if (!bytes || !width || !height) {
          result->Error("invalid_image", "Missing image pixels or dimensions");
        } else if (!CopyReaderImageToClipboard(GetHandle(), *bytes, *width,
                                               *height)) {
          result->Error("image_action_failed",
                        "Unable to copy image to the clipboard");
        } else {
          result->Success();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  external_authorization_.reset();
  if (media_channel_) {
    media_channel_->SetMethodCallHandler(nullptr);
    media_channel_.reset();
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == ExternalAuthorization::kCallbackMessage) {
    if (external_authorization_) external_authorization_->OnCallback(lparam);
    else delete reinterpret_cast<std::wstring*>(lparam);
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
