import 'package:flutter/material.dart';

class AiChatBubble extends StatelessWidget {
  const AiChatBubble({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu chủ đạo chuẩn của App (Primary Blue)
    const primaryColor = Color(0xFF455A75);

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // --- SỬA LẠI: Dùng màu đơn sắc thay vì Gradient ---
        color: primaryColor,
        // ------------------------------------------------
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome, // Icon ngôi sao lấp lánh
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
