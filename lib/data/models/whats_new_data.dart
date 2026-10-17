import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WhatsNewItem {
  final IconData icon;
  final String title;

  const WhatsNewItem({
    required this.icon,
    required this.title,
  });
}

class WhatsNewData {
  static const String version = '7.70';
  static const String discordUrl = 'https://discord.gg/FaPcNGURdN';
  static const String githubUrl = 'https://github.com/anyyting-es/aniting';

  static const List<WhatsNewItem> news = [
    WhatsNewItem(
      icon: Icons.bolt_rounded,
      title: 'Debrid Service',
    ),
    WhatsNewItem(
      icon: LucideIcons.sparkles,
      title: 'UI Improvements',
    ),
    WhatsNewItem(
      icon: LucideIcons.downloadCloud,
      title: 'Download Improvements',
    ),
    WhatsNewItem(
      icon: LucideIcons.cloudDownload,
      title: 'Online Stream Downloads',
    ),
    WhatsNewItem(
      icon: LucideIcons.folderCheck,
      title: 'Local Library Detection',
    ),
  ];
}
