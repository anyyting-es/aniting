import 'package:flutter/material.dart';

/// An IndexedStack that smoothly animates page switches (fade + subtle upward glide)
/// while preserving the full state, scroll position, and controllers of all pages.
class ShellAnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const ShellAnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 240),
  });

  @override
  State<ShellAnimatedIndexedStack> createState() => _ShellAnimatedIndexedStackState();
}

class _ShellAnimatedIndexedStackState extends State<ShellAnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.99,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(ShellAnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      setState(() {
        _currentIndex = widget.index;
      });
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
    final effectiveIndex = widget.children.isEmpty
        ? 0
        : _currentIndex.clamp(0, widget.children.length - 1);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: IndexedStack(
          index: effectiveIndex,
          children: [
            for (int i = 0; i < widget.children.length; i++)
              TickerMode(
                enabled: effectiveIndex == i,
                child: widget.children[i],
              ),
          ],
        ),
      ),
    );
  }
}
