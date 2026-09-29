import 'package:flutter/material.dart';

class DesktopMangaHeader extends StatefulWidget {
  final String? subtitleStr;
  final String title;
  final List<String> genres;
  final String description;

  const DesktopMangaHeader({
    super.key,
    this.subtitleStr,
    required this.title,
    required this.genres,
    required this.description,
  });

  @override
  State<DesktopMangaHeader> createState() => _DesktopMangaHeaderState();
}

class _DesktopMangaHeaderState extends State<DesktopMangaHeader> {
  bool _isSynopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtitle (Year • Format)
        if (widget.subtitleStr != null && widget.subtitleStr!.isNotEmpty) ...[
          Text(
            widget.subtitleStr!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Main Title
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

        // Cyan / Accent Genre Pills
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

        // Synopsis (Expandable)
        if (widget.description.isNotEmpty) ...[
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
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
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
