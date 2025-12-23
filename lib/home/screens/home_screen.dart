import 'package:flutter/material.dart';
// Nhớ import file widget này
import 'package:skedule/widgets/ai_chat_bubble.dart';
import 'package:skedule/home/screens/calendar_screen.dart';
import 'package:skedule/home/screens/ai_agent_screen.dart';
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

      // --- SỬA NÚT AI GỌN GÀNG ---
      // Ta dùng một Container để giữ kích thước lớn hơn FAB mặc định một chút (70 vs 56)
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          // Để màu trong suốt vì AiChatBubble đã có màu nền rồi
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AiAgentScreen()),
            );
          },
          shape: const CircleBorder(),
          // Gọi widget bong bóng chat đã sửa màu ở Bước 1
          child: const AiChatBubble(),
        ),
      ),
      // ----------------------------

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
            const SizedBox(width: 48), // Khoảng trống cho nút AI
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
        // Dùng màu AppColors.primaryBlue để đồng bộ (giá trị 0xFF455A75)
        color: isSelected ? const Color(0xFF455A75) : Colors.grey.shade400,
        size: 28,
      ),
      onPressed: () => _onNavItemTapped(index),
      tooltip: label,
    );
  }
}
