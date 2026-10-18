#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "mpv/display_mode_manager.h"
#include "mpv/mpv_plugin.h"

static bool QueryWindowPlacement(HWND hwnd, WINDOWPLACEMENT* wp) {
  wp->length = sizeof(*wp);
  if (!GetWindowPlacement(hwnd, wp)) return false;

  using IsWindowArrangedFn = BOOL(WINAPI*)(HWND);
  static const IsWindowArrangedFn is_window_arranged =
      reinterpret_cast<IsWindowArrangedFn>(GetProcAddress(GetModuleHandleW(L"user32.dll"), "IsWindowArranged"));
  if (!is_window_arranged || IsIconic(hwnd) || IsZoomed(hwnd) || !is_window_arranged(hwnd)) return true;

  RECT rect{};
  if (!GetWindowRect(hwnd, &rect)) return true;
  MONITORINFO mi{};
  mi.cbSize = sizeof(mi);
  if (!GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &mi)) return true;
  OffsetRect(&rect, mi.rcMonitor.left - mi.rcWork.left, mi.rcMonitor.top - mi.rcWork.top);
  wp->rcNormalPosition = rect;
  return true;
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  MpvPlayerPluginRegisterWithRegistrar(
      flutter_controller_->engine()->GetRegistrarForPlugin("MpvPlayerPlugin"));
  MpvAudioPlayerPluginRegisterWithRegistrar(
      flutter_controller_->engine()->GetRegistrarForPlugin("MpvAudioPlayerPlugin"));

  RegisterWindowChannel();

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_DISPLAYCHANGE:
      mpv::DisplayModeManager::RecoverIfNeeded();
      break;
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterWindowChannel() {
  auto messenger = flutter_controller_->engine()->messenger();
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "plezy/window", &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler([this](
                                            const flutter::MethodCall<flutter::EncodableValue>& call,
                                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string& name = call.method_name();
    if (name == "setFullScreen") {
      bool value = false;
      if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
        auto it = args->find(flutter::EncodableValue("isFullScreen"));
        if (it != args->end()) {
          if (const bool* b = std::get_if<bool>(&it->second)) value = *b;
        }
      }
      SetNativeFullScreen(value);
      result->Success();
    } else if (name == "isFullScreen") {
      result->Success(flutter::EncodableValue(is_fullscreen_));
    } else {
      result->NotImplemented();
    }
  });
}

void FlutterWindow::NotifyFullScreenChanged() {
  if (!window_channel_) return;
  window_channel_->InvokeMethod("onFullScreenChanged", std::make_unique<flutter::EncodableValue>(is_fullscreen_));
}

void FlutterWindow::SetNativeFullScreen(bool fullscreen) {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  if (fullscreen == is_fullscreen_) return;

  if (fullscreen) {
    RECT wr{};
    ::GetWindowRect(hwnd, &wr);
    POINT center{(wr.left + wr.right) / 2, (wr.top + wr.bottom) / 2};
    MONITORINFO mi{};
    mi.cbSize = sizeof(mi);
    if (!::GetMonitorInfoW(::MonitorFromPoint(center, MONITOR_DEFAULTTONEAREST), &mi)) {
      return;
    }

    QueryWindowPlacement(hwnd, &placement_before_fullscreen_);
    style_before_fullscreen_ = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    ex_style_before_fullscreen_ = ::GetWindowLongPtr(hwnd, GWL_EXSTYLE);

    ::SetWindowLongPtr(hwnd, GWL_STYLE, style_before_fullscreen_ & ~WS_OVERLAPPEDWINDOW);
    ::SetWindowLongPtr(
        hwnd, GWL_EXSTYLE,
        ex_style_before_fullscreen_ & ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE));

    const RECT& r = mi.rcMonitor;
    ::SetWindowPos(
        hwnd, HWND_TOP, r.left, r.top, r.right - r.left, r.bottom - r.top,
        SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOACTIVATE);

    is_fullscreen_ = true;
  } else {
    if (style_before_fullscreen_ != 0) {
      ::SetWindowLongPtr(hwnd, GWL_STYLE, style_before_fullscreen_);
      ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, ex_style_before_fullscreen_);
    }

    if (placement_before_fullscreen_.length == sizeof(WINDOWPLACEMENT)) {
      WINDOWPLACEMENT wp = placement_before_fullscreen_;
      if (wp.showCmd == SW_SHOWMINIMIZED) wp.showCmd = SW_SHOWNORMAL;
      ::SetWindowPlacement(hwnd, &wp);
    }

    ::SetWindowPos(
        hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);

    is_fullscreen_ = false;
    placement_before_fullscreen_ = {};
    style_before_fullscreen_ = 0;
    ex_style_before_fullscreen_ = 0;
  }

  NotifyFullScreenChanged();
}
