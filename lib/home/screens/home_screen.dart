import 'package:flutter/material.dart';
import 'package:skedule/home/screens/calendar_screen.dart';
import 'package:skedule/home/screens/ai_agent_screen.dart';
import 'package:skedule/home/screens/dashboard_page.dart';
import 'package:skedule/home/screens/preferences_screen.dart';
<<<<<<< HEAD
import 'package:skedule/home/screens/note_screen.dart'; // Import NoteScreen
import 'package:skedule/features/payment/payment_screen.dart';

import '../../features/payment/subscription_service.dart'; // Import PaymentScreen
=======
import 'package:skedule/home/screens/note_screen.dart';
import 'package:skedule/features/payment/payment_screen.dart';
>>>>>>> d1a388f (upd: sua giao dien calendar va tinh chinh AI)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isPremium = false;
  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    final isPremium = await _subscriptionService.isPremium();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
      });
    }
  }

  // Danh sách các trang chính - Sử dụng đúng các class thật từ dự án của bạn
  late final List<Widget> _mainPages;

  @override
  void initState() {
    super.initState();
    _mainPages = <Widget>[
      const DashboardPage(),
      const CalendarScreen(),
      const AiAgentScreen(), // Không dùng const vì class này có logic khởi tạo phức tạp
      const NoteScreen(),
      const PreferencesScreen(), // Đã chuyển sang View riêng thay vì BottomSheet
    ];
  }

  // Hàm xử lý chuyển đổi giữa các tab
  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Hàm điều hướng sang màn hình thanh toán
  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentScreen()),
    );
  }

  // Lấy tiêu đề tương ứng với từng Tab để hiển thị trên AppBar
  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return 'Skedule';
      case 1: return 'Lịch trình';
      case 2: return 'AI Assistant';
      case 3: return 'Ghi chú';
      case 4: return 'Cài đặt';
      default: return 'Skedule';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ẩn AppBar của HomeScreen khi vào tab AI vì AiAgentScreen đã có AppBar riêng
    bool isAiTab = _selectedIndex == 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isAiTab
          ? null
          : AppBar(
        backgroundColor: const Color(0xFFE2E6EE),
        elevation: 0,
        centerTitle: false,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Color(0xFF2D3142),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
<<<<<<< HEAD
          if (!_isPremium)
            IconButton(
              icon: const Icon(Icons.workspace_premium),
              onPressed: _navigateToPayment,
              tooltip: 'Upgrade to Premium',
            ),
          if (_isPremium)
             Padding(
               padding: const EdgeInsets.only(right: 16.0),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.amber,
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: const Text(
                   'VIP',
                   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                 ),
               ),
             ),
=======
          IconButton(
            icon: const Icon(Icons.workspace_premium, color: Color(0xFF4A6C8B)),
            onPressed: _navigateToPayment,
            tooltip: 'Nâng cấp Premium',
          ),
>>>>>>> d1a388f (upd: sua giao dien calendar va tinh chinh AI)
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _mainPages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.grid_view_rounded, 'Tổng quan'),
                _buildNavItem(1, Icons.calendar_today_rounded, 'Lịch'),
                _buildNavItem(2, Icons.auto_awesome_rounded, 'AI Agent'),
                _buildNavItem(3, Icons.description_outlined, 'Ghi chú'),
                _buildNavItem(4, Icons.settings_outlined, 'Cài đặt'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget xây dựng các mục điều hướng ở Bottom Bar
  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // Hiệu ứng nền chọn đồng bộ với trang Lịch
          color: isSelected ? const Color(0xFFF1F3F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF465B75) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF465B75) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}