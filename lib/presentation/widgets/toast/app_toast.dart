import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notification types for global toasts.
enum ToastType {
  info,
  success,
  warning,
  error,
}

/// Representation of a toast notification.
class ToastMessage {
  final String id;
  final String message;
  final String? title;
  final ToastType type;
  final IconData? icon;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final DateTime createdAt;

  ToastMessage({
    String? id,
    required this.message,
    this.title,
    this.type = ToastType.info,
    this.icon,
    this.duration = const Duration(milliseconds: 3500),
    this.actionLabel,
    this.onAction,
    DateTime? createdAt,
  })  : id = id ?? UniqueKey().toString(),
        createdAt = createdAt ?? DateTime.now();

  ToastMessage copyWith({
    String? id,
    String? message,
    String? title,
    ToastType? type,
    IconData? icon,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    DateTime? createdAt,
  }) {
    return ToastMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      title: title ?? this.title,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      duration: duration ?? this.duration,
      actionLabel: actionLabel ?? this.actionLabel,
      onAction: onAction ?? this.onAction,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Riverpod notifier managing the active toast notifications queue.
class ToastQueueNotifier extends Notifier<List<ToastMessage>> {
  static const int maxVisibleToasts = 3;

  @override
  List<ToastMessage> build() => const [];

  void show(ToastMessage message) {
    final updated = List<ToastMessage>.from(state);
    if (updated.length >= maxVisibleToasts) {
      updated.removeAt(0);
    }
    updated.add(message);
    state = updated;
  }

  void dismiss(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clear() {
    state = const [];
  }
}

final toastQueueProvider =
    NotifierProvider<ToastQueueNotifier, List<ToastMessage>>(ToastQueueNotifier.new);

/// Global convenience API for triggering liquid glass toasts across the application.
class AppToast {
  static ToastQueueNotifier? _notifier;

  /// Internal initializer invoked by [AppToastHost].
  static void registerNotifier(ToastQueueNotifier notifier) {
    _notifier = notifier;
  }

  /// Displays a global liquid glass toast. Can be called with or without [BuildContext].
  static void show({
    BuildContext? context,
    required String message,
    String? title,
    ToastType type = ToastType.info,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final toast = ToastMessage(
      message: message,
      title: title,
      type: type,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    if (_notifier != null) {
      _notifier!.show(toast);
      return;
    }

    if (context != null && context.mounted) {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(toastQueueProvider.notifier).show(toast);
    }
  }

  /// Convenience method for success toast (e.g. download deleted, saved, completed).
  static void success(
    String message, {
    BuildContext? context,
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: ToastType.success,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience method for error toast.
  static void error(
    String message, {
    BuildContext? context,
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 4500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: ToastType.error,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience method for warning toast.
  static void warning(
    String message, {
    BuildContext? context,
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 4000),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: ToastType.warning,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience method for info toast.
  static void info(
    String message, {
    BuildContext? context,
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context: context,
      message: message,
      title: title,
      type: ToastType.info,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Dismisses a toast by its id.
  static void dismiss(String id, {BuildContext? context}) {
    if (_notifier != null) {
      _notifier!.dismiss(id);
      return;
    }
    if (context != null && context.mounted) {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(toastQueueProvider.notifier).dismiss(id);
    }
  }

  /// Clears all active toasts.
  static void clear({BuildContext? context}) {
    if (_notifier != null) {
      _notifier!.clear();
      return;
    }
    if (context != null && context.mounted) {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(toastQueueProvider.notifier).clear();
    }
  }
}

/// Drop-in functional compatibility for legacy showGlassToast calls.
void showGlassToast(
  BuildContext context, {
  required String message,
  IconData? icon,
  bool isError = false,
  bool isSuccess = false,
}) {
  final type = isError
      ? ToastType.error
      : isSuccess
          ? ToastType.success
          : ToastType.info;

  AppToast.show(
    context: context,
    message: message,
    type: type,
    icon: icon,
  );
}
