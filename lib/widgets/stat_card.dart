// lib/widgets/stat_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: backgroundColor,
      child: Padding(
        // GIẢI PHÁP: Giảm padding dọc từ 16 xuống 12 để tăng không gian nội dung
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: iconColor, size: 26), // Giảm nhẹ size icon
            const SizedBox(height: 4),
            // GIẢI PHÁP: Sử dụng Flexible để Text có thể co lại nếu thiếu chỗ
            Flexible(
              child: FittedBox( // Đảm bảo số không bị cắt mất
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Tránh tràn chữ nếu label quá dài
              style: TextStyle(color: labelColor, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}