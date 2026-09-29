import 'package:flutter/material.dart';

class DesktopTabButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const DesktopTabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<DesktopTabButton> createState() => _DesktopTabButtonState();
}

class _DesktopTabButtonState extends State<DesktopTabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: widget.isSelected
                      ? Colors.white
                      : (_isHovered ? Colors.white : Colors.white60),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 2,
                width: widget.isSelected ? 26 : 0,
                color: widget.isSelected
                    ? Colors.white
                    : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
