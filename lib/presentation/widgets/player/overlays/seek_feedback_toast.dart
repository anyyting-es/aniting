import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Minimalist, side-anchored seek indicator without background container.
/// Displays on the left for rewind (<< 10) and right for fast-forward (10 >>)
/// with a smooth, subtle fade and slide animation.
class SeekFeedbackToast extends ConsumerStatefulWidget {
  final String text;

  const SeekFeedbackToast({super.key, required this.text});

  @override
  ConsumerState<SeekFeedbackToast> createState() => _SeekFeedbackToastState();
}

class _SeekFeedbackToastState extends ConsumerState<SeekFeedbackToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    final isForward = widget.text.startsWith('+');
    _slideAnimation = Tween<Offset>(
      begin: Offset(isForward ? -0.15 : 0.15, 0.0),
      end: Offset(isForward ? 0.08 : -0.08, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant SeekFeedbackToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconPack = ref.watch(iconPackProvider);
    final isForward = widget.text.startsWith('+');
    final numberText = widget.text
        .replaceAll('+', '')
        .replaceAll('-', '')
        .replaceAll('s', '')
        .trim();

    return Align(
      alignment: isForward ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isForward ? 0 : 56,
          right: isForward ? 56 : 0,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: isForward
                  ? [
                      Text(
                        numberText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 12,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        AppIcons.fastForward(iconPack),
                        color: Colors.white,
                        size: 28,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 12,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ]
                  : [
                      Icon(
                        AppIcons.fastRewind(iconPack),
                        color: Colors.white,
                        size: 28,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 12,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        numberText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 12,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}
