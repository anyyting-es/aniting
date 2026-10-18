import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/presentation/widgets/toast/app_toast.dart';
import 'package:seanime_app/presentation/widgets/toast/app_toast_item.dart';

/// Global overlay host mounted at the root of the app that renders
/// active liquid glass notifications in the top corner.
class AppToastHost extends ConsumerStatefulWidget {
  const AppToastHost({super.key});

  @override
  ConsumerState<AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends ConsumerState<AppToastHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppToast.registerNotifier(ref.read(toastQueueProvider.notifier));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppToast.registerNotifier(ref.read(toastQueueProvider.notifier));

    final toasts = ref.watch(toastQueueProvider);
    if (toasts.isEmpty) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 720;
    final topPadding = mediaQuery.padding.top;

    return Positioned(
      top: isDesktop ? 24 : (topPadding + 10),
      right: isDesktop ? 24 : 16,
      left: isDesktop ? null : 16,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 420 : double.infinity,
          minWidth: isDesktop ? 280 : 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
          children: [
            for (final toast in toasts)
              Padding(
                key: ValueKey(toast.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: AppToastItem(toast: toast),
              ),
          ],
        ),
      ),
    );
  }
}
