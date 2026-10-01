import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarNowMarker extends StatefulWidget {
  const CalendarNowMarker({super.key});

  @override
  State<CalendarNowMarker> createState() => _CalendarNowMarkerState();
}

class _CalendarNowMarkerState extends State<CalendarNowMarker> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final timeStr = DateFormat('HH:mm').format(_now);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 17,
            color: primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.5),
                    primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
