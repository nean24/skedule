// lib/widgets/task_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final String location;
  final String tag1Text;
  final Color tag1Color;
  final String tag2Text;
  final Color tag2Color;
  final IconData icon;
  final Color borderColor;
  final bool isTask;

  const TaskCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.location,
    required this.tag1Text,
    required this.tag1Color,
    required this.tag2Text,
    required this.tag2Color,
    required this.icon,
    required this.borderColor,
    this.isTask = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[700];
    final borderColorSide = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColorSide),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: borderColor, width: 5),
          ),
        ),
        child: Row(
          children: [
            if (isTask)
              Checkbox(value: false, onChanged: (val) {}, visualDensity: VisualDensity.compact)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(icon, color: iconColor, size: 20),
              ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Đảm bảo column không chiếm quá nhiều chỗ
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                  // GIẢI PHÁP: Wrap Row thời gian/địa điểm để tránh tràn ngang đẩy thẻ xuống
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildInfoRow(Icons.access_time, time, subtitleColor ?? Colors.grey),
                      _buildInfoRow(Icons.location_on, location, subtitleColor ?? Colors.grey),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (tag1Text.isNotEmpty) _buildTag(tag1Text, tag1Color),
                if (tag2Text.isNotEmpty) const SizedBox(height: 4),
                if (tag2Text.isNotEmpty) _buildTag(tag2Text, tag2Color),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}