import 'package:flutter/material.dart';
import 'package:draggable_fab/draggable_fab.dart';
import 'package:skedule/home/screens/calendar_screen.dart';
import 'package:skedule/home/screens/ai_agent_screen.dart'; // <<< GIỮ NGUYÊN IMPORT NÀY
import 'package:skedule/home/screens/dashboard_page.dart';
import 'package:skedule/home/screens/preferences_screen.dart';
import 'package:skedule/home/screens/note_screen.dart';
import 'package:skedule/features/payment/payment_screen.dart';
import 'package:skedule/features/payment/subscription_service.dart';

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

  static final List<Widget> _mainPages = <Widget>[
    const DashboardPage(),
    const CalendarScreen(),
    const NoteScreen(),
  ];

  void _showPreferencesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return const PreferencesSheet();
      },
    );
  }

  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentScreen()),
    );
  }

  void _onNavItemTapped(int index) {
    if (index == 3) {
      _showPreferencesSheet();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium),
            onPressed: _navigateToPayment,
            tooltip: 'Upgrade to Premium',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _mainPages,
      ),

      // --- SỬA NÚT AI Ở ĐÂY ---
      floatingActionButton: DraggableFab(
        child: Container(
          height: 70.0, // Làm nút to hơn một chút cho nổi bật
          width: 70.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Thêm gradient để nút AI trông hiện đại hơn
            gradient: const LinearGradient(
              colors: [
                Color(0xFF4A6C8B), // Màu chính
                Color(0xFF2C4E6D), // Màu đậm hơn chút
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A6C8B).withOpacity(0.4),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            // Để transparent để thấy màu gradient của Container
            backgroundColor: Colors.transparent,
            elevation: 0,
            onPressed: () {
              // Chuyển hướng sang màn hình AI Agent
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AiAgentScreen()),
              );
            },
            shape: const CircleBorder(),
            // Dùng ảnh từ assets
            child: Padding(
              padding: const EdgeInsets.all(12.0), // Căn chỉnh ảnh cho vừa vặn
              child: Image.asset(
                'assets/ai_robot.png', // Đảm bảo bạn đã khai báo trong pubspec.yaml
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
      // ------------------------

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(
                icon: Icons.dashboard_rounded, label: 'Dashboard', index: 0),
            _buildNavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Calendar',
                index: 1),
            const SizedBox(width: 48), // Khoảng trống cho FAB chính
            _buildNavItem(
                icon: Icons.note_alt_rounded, label: 'Notes', index: 2),
            _buildNavItem(
                icon: Icons.settings_rounded, label: 'Preferences', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      {required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index && index != 3;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? const Color(0xFF4A6C8B) : Colors.grey.shade400,
        size: 28,
      ),
      onPressed: () => _onNavItemTapped(index),
      tooltip: label,
    );
  }
}
