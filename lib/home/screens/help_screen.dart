import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';
import 'package:skedule/theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Hướng dẫn & Hỗ trợ',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onBackground),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: colorScheme.surface, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colorScheme.onSurface),
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
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onBackground),
          ),
          const SizedBox(height: 8),
          Text(
            'Tìm hiểu cách sử dụng Skedule hiệu quả nhất.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),

          // --- DANH SÁCH CÂU HỎI (FAQ) ---
          _buildFaqItem(
            context,
            'Sự khác nhau giữa Task và Event?',
            '• Task (Công việc): Có thể đánh dấu hoàn thành, tính vào chuỗi Streak.\n• Event (Sự kiện): Chỉ là lịch trình diễn ra trong khung giờ nhất định, không có trạng thái hoàn thành.',
            Icons.help_outline,
            colorScheme,
            textTheme,
          ),
          _buildFaqItem(
            context,
            'Làm sao để tăng chuỗi Streak?',
            'Bạn cần hoàn thành ít nhất một Task (Công việc) mỗi ngày. Nếu bạn quên một ngày, chuỗi sẽ được tính lại, trừ khi bạn có hoàn thành vào ngày hôm trước (chế độ bảo vệ chuỗi).',
            Icons.local_fire_department_outlined,
            colorScheme,
            textTheme,
          ),
          _buildFaqItem(
            context,
            'Trợ lý AI có thể làm gì?',
            'AI có thể giúp bạn lên lịch trình, giải đáp thắc mắc, tóm tắt ghi chú. Tính năng này yêu cầu tài khoản Premium.',
            Icons.smart_toy_outlined,
            colorScheme,
            textTheme,
          ),
          _buildFaqItem(
            context,
            'Làm sao để nâng cấp Premium?',
            'Vào trang Tài khoản hoặc bấm vào biểu tượng Vương miện ở màn hình AI để xem các gói đăng ký.',
            Icons.workspace_premium_outlined,
            colorScheme,
            textTheme,
          ),

          const SizedBox(height: 30),

          // --- LIÊN HỆ HỖ TRỢ ---
          Text(
            'Cần hỗ trợ thêm?',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onBackground),
          ),
          const SizedBox(height: 16),
          _buildContactCard(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer,
      IconData icon, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          title: Text(
            question,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          iconColor: colorScheme.primary,
          collapsedIconColor: colorScheme.onSurface.withOpacity(0.5),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.8), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'support@skedule.com',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
