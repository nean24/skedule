// lib/home/screens/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:skedule/widgets/stat_card.dart'; // Import widget
import 'package:skedule/widgets/task_card.dart'; // Import widget

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Màu nền chính của app
      backgroundColor: const Color(0xFFF4F6FD),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          children: [
            // 1. Header
            _buildHeader(),
            const SizedBox(height: 24),

            // 2. Lưới thống kê
            _buildStatsGrid(),
            const SizedBox(height: 24),

            // 3. Phần "Coming Up"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSectionHeader(title: 'Coming Up'),
            ),
            const SizedBox(height: 16),

            // 4. Danh sách Coming Up
            _buildComingUpList(),

            // 5. Phần Missed Tasks
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSectionHeader(title: 'Missed Tasks', count: 3),
            ),
            const SizedBox(height: 16),

            // === PHẦN MỚI ĐƯỢC THÊM VÀO ===
            _buildMissedTasksList(),
            // ===============================

            const SizedBox(height: 24), // Thêm khoảng cách trước summary card

            // 6. Phần This Week's Summary
            _buildSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              SizedBox(height: 4),
              Text(
                'Sunday, October 12, 2025', // Dữ liệu giả
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  )
                ]
            ),
            child: const Column(
              children: [
                Text(
                  '80%',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6E85B7)),
                ),
                Text('Productivity Score', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3, // Đã điều chỉnh để không bị overflow
        children: const [
          StatCard(label: 'Completed', value: '0', icon: Icons.check_circle, iconColor: Color(0xFF6E85B7)),
          StatCard(label: 'Happening Now', value: '0', icon: Icons.waves, iconColor: Colors.purple),
          StatCard(label: 'Missed', value: '3', icon: Icons.cancel, iconColor: Colors.redAccent),
          StatCard(label: 'Day Streak', value: '5', icon: Icons.trending_up, iconColor: Colors.green),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, int? count}) {
    return Row(
      children: [
        Icon(
            title == 'Coming Up' ? Icons.access_time_filled : Icons.error_outline,
            color: title == 'Missed Tasks' ? Colors.redAccent : Colors.grey[800]
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
        ),
        const Spacer(),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
      ],
    );
  }

  Widget _buildComingUpList() {
    // Dữ liệu giả - sau này sẽ lấy từ Supabase
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          TaskCard(
            title: 'Submit assignment',
            subtitle: '• School',
            time: 'N/A',
            location: 'N/A',
            tag1Text: 'task',
            tag1Color: Colors.orange,
            tag2Text: 'high',
            tag2Color: Colors.red,
            icon: Icons.check_box_outline_blank,
            borderColor: Colors.orange,
            isTask: true,
          ),
          TaskCard(
            title: 'Mathematics 101',
            subtitle: '• Education',
            time: '2:00 PM - 3:30 PM',
            location: 'Room 204',
            tag1Text: 'class',
            tag1Color: Colors.purple,
            tag2Text: '', // Bỏ trống nếu không có tag 2
            tag2Color: Colors.transparent,
            icon: Icons.school, // Icon mũ tốt nghiệp
            borderColor: Colors.purple,
          ),
          TaskCard(
            title: 'Evening Shift',
            subtitle: '• Work',
            time: '5:00 PM - 10:00 PM',
            location: 'Store',
            tag1Text: 'work shift',
            tag1Color: Colors.blue,
            tag2Text: '',
            tag2Color: Colors.transparent,
            icon: Icons.work,
            borderColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  // === HÀM MỚI ĐỂ HIỂN THỊ CÁC TASK ĐÃ LỠ ===
  Widget _buildMissedTasksList() {
    // Dữ liệu giả cho các task đã lỡ
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          TaskCard(
            title: 'Complete budget report',
            subtitle: 'Yesterday • Work',
            time: 'N/A',
            location: 'N/A',
            tag1Text: 'high',
            tag1Color: Colors.red,
            tag2Text: '',
            tag2Color: Colors.transparent,
            icon: Icons.check_box_outline_blank,
            borderColor: Colors.red, // Viền đỏ cho task đã lỡ
            isTask: true,
          ),
          TaskCard(
            title: 'Call dentist for appointment',
            subtitle: 'Yesterday • Personal',
            time: 'N/A',
            location: 'N/A',
            tag1Text: 'medium',
            tag1Color: Colors.orange,
            tag2Text: '',
            tag2Color: Colors.transparent,
            icon: Icons.check_box_outline_blank,
            borderColor: Colors.red, // Viền đỏ cho task đã lỡ
            isTask: true,
          ),
          TaskCard(
            title: 'Update portfolio website',
            subtitle: 'Oct 10 • Work',
            time: 'N/A',
            location: 'N/A',
            tag1Text: 'medium',
            tag1Color: Colors.orange,
            tag2Text: '',
            tag2Color: Colors.transparent,
            icon: Icons.check_box_outline_blank,
            borderColor: Colors.red, // Viền đỏ cho task đã lỡ
            isTask: true,
          ),
        ],
      ),
    );
  }


  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        elevation: 0,
        color: const Color(0xFFE0E5F1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This Week's Summary",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem('12', 'Completed'),
                  _summaryItem('5', 'Active Days'),
                  _summaryItem('10', 'Upcoming'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }
}