import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';

// --- BẢNG MÀU ĐỒNG BỘ ---
class AppColors {
  static const Color scaffoldBg = Color(0xFFDDE3ED);
  static const Color cardBg = Colors.white;
  static const Color primaryBlue = Color(0xFF455A75);
  static const Color textDark = Color(0xFF2D3142);
  static const Color textLight = Color(0xFF9094A6);
  static const Color accent = Color(0xFF3B82F6); // Màu xanh dương điểm nhấn

  // Dark Mode
  static const Color scaffoldBgDark = Color(0xFF121212);
  static const Color cardBgDark = Color(0xFF1E1E1E);
  static const Color textDarkDark = Color(0xFFE0E0E0);
  static const Color textLightDark = Color(0xFFA0A0A0);
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    final bgColor = isDark ? AppColors.scaffoldBgDark : AppColors.scaffoldBg;
    final cardColor = isDark ? AppColors.cardBgDark : AppColors.cardBg;
    final textColor = isDark ? AppColors.textDarkDark : AppColors.textDark;
    final subTextColor = isDark ? AppColors.textLightDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Hướng dẫn & Hỗ trợ',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          // --- HEADER GIỚI THIỆU ---
          Text(
            'Câu hỏi thường gặp',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Tìm hiểu cách sử dụng Skedule hiệu quả nhất.',
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 20),

          // --- DANH SÁCH CÂU HỎI (FAQ) ---
          _buildFaqItem(
            context,
            'Sự khác nhau giữa Task và Event?',
            '• Task (Công việc): Có thể đánh dấu hoàn thành, tính vào chuỗi Streak.\n• Event (Sự kiện): Chỉ là lịch trình diễn ra trong khung giờ nhất định, không có trạng thái hoàn thành.',
            Icons.help_outline,
            cardColor,
            textColor,
            subTextColor,
          ),
          _buildFaqItem(
            context,
            'Làm sao để tăng chuỗi Streak?',
            'Bạn cần hoàn thành ít nhất một Task (Công việc) mỗi ngày. Nếu bạn quên một ngày, chuỗi sẽ được tính lại, trừ khi bạn có hoàn thành vào ngày hôm trước (chế độ bảo vệ chuỗi).',
            Icons.local_fire_department_outlined,
            cardColor,
            textColor,
            subTextColor,
          ),
          _buildFaqItem(
            context,
            'Trợ lý AI có thể làm gì?',
            'AI có thể giúp bạn lên lịch trình, giải đáp thắc mắc, tóm tắt ghi chú. Tính năng này yêu cầu tài khoản Premium.',
            Icons.smart_toy_outlined,
            cardColor,
            textColor,
            subTextColor,
          ),
          _buildFaqItem(
            context,
            'Làm sao để nâng cấp Premium?',
            'Vào trang Tài khoản hoặc bấm vào biểu tượng Vương miện ở màn hình AI để xem các gói đăng ký.',
            Icons.workspace_premium_outlined,
            cardColor,
            textColor,
            subTextColor,
          ),

          const SizedBox(height: 30),

          // --- LIÊN HỆ HỖ TRỢ ---
          Text(
            'Cần hỗ trợ thêm?',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 16),
          _buildContactCard(cardColor, textColor, subTextColor),
        ],
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer,
      IconData icon, Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          title: Text(
            question,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
          ),
          iconColor: AppColors.primaryBlue,
          collapsedIconColor: subTextColor,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.8),
                    height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
      Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.mail_outline, color: Colors.green, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gửi email cho chúng tôi',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                'support@skedule.com',
                style: TextStyle(color: subTextColor, fontSize: 14),
              ),
            ],
          )
        ],
      ),
    );
  }
}
