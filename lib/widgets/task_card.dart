// lib/widgets/task_card.dart
import 'package:flutter/material.dart';

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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
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
                child: Icon(icon, color: Colors.grey[700], size: 20),
              ),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Đảm bảo column không chiếm quá nhiều chỗ
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                  // GIẢI PHÁP: Wrap Row thời gian/địa điểm để tránh tràn ngang đẩy thẻ xuống
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildInfoRow(Icons.access_time, time),
                      _buildInfoRow(Icons.location_on, location),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
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