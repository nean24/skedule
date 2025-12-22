import 'package:flutter/material.dart';
import 'package:draggable_fab/draggable_fab.dart';
import 'package:skedule/home/screens/calendar_screen.dart'; // <<< ĐÃ THÊM DÒNG NÀY
import 'package:skedule/home/screens/ai_agent_screen.dart';
import 'package:skedule/home/screens/dashboard_page.dart';
import 'package:skedule/home/screens/preferences_screen.dart';
import 'package:skedule/home/screens/note_screen.dart'; // Import NoteScreen
import 'package:skedule/features/payment/payment_screen.dart'; // Import PaymentScreen

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

  // === THAY ĐỔI Ở ĐÂY ===
  // Thay thế widget giữ chỗ bằng CalendarScreen thật
  static final List<Widget> _mainPages = <Widget>[
    const DashboardPage(),
    const CalendarScreen(),
    const NoteScreen(), // Thay thế placeholder bằng NoteScreen
  ];
  // =====================

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
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _mainPages,
      ),
      floatingActionButton: DraggableFab(
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF4A6C8B),
          onPressed: () {
            // TODO: Mở màn hình tạo task mới
          },
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          // === SỬA LỖI Ở ĐÂY ===
          // Chỉ cần một "mainAxisAlignment:"
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', index: 0),
            _buildNavItem(icon: Icons.calendar_month_rounded, label: 'Calendar', index: 1),
            const SizedBox(width: 48), // Khoảng trống cho FAB chính
            _buildNavItem(icon: Icons.note_alt_rounded, label: 'Notes', index: 2),
            _buildNavItem(icon: Icons.settings_rounded, label: 'Preferences', index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
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
