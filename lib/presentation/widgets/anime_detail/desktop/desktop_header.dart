import 'package:flutter/material.dart';

class DesktopHeader extends StatefulWidget {
  final String seasonYearStr;
  final String title;
  final List<String> genres;
  final String description;

  const DesktopHeader({
    super.key,
    required this.seasonYearStr,
    required this.title,
    required this.genres,
    required this.description,
  });

  @override
  State<DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends State<DesktopHeader> {
  bool _isSynopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Season Year
        if (widget.seasonYearStr.isNotEmpty) ...[
          Text(
            widget.seasonYearStr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Big Anime Title
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            height: 1.15,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),

        // Cyan Genre Pills (matching screenshot)
        if (widget.genres.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.genres.map((g) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C7FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  g,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Synopsis Paragraph (expandable)
        if (widget.description.isNotEmpty) ...[
          GestureDetector(
            onTap: () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
            child: Text(
              widget.description,
              maxLines: _isSynopsisExpanded ? 99 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
