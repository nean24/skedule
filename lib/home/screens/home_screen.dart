import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String _userName = 'Bạn'; // Tên mặc định

  final SubscriptionService _subscriptionService = SubscriptionService();
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkUserData();
  }

  // Lấy cả tên và trạng thái Premium
  Future<void> _checkUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      // 1. Lấy Premium
      final isPremium = await _subscriptionService.isPremium();

      // 2. Lấy Tên
      final profileRes = await _supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();

      String rawName = profileRes?['name'] ?? 'Bạn';

      if (mounted) {
        setState(() {
          _isPremium = isPremium;
          _userName = _processName(rawName);
        });
      }
    }
  }

  // Hàm xử lý tên: Nếu dài > 12 ký tự thì chỉ lấy tên (từ cuối cùng)
  String _processName(String fullName) {
    if (fullName.trim().isEmpty) return 'Bạn';
    if (fullName.length > 12) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        return parts.last; // Lấy từ cuối cùng (Tên)
      }
    }
    return fullName; // Tên ngắn thì giữ nguyên
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
    ).then((_) => _checkUserData()); // Check lại khi quay về (เผื่อ mua xong)
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
      // --- APP BAR ĐÃ SỬA ---
      appBar: AppBar(
        // Hiển thị lời chào thay vì tên App
        title: Text(
          'Xin chào, $_userName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Chỉ hiện nút Premium nếu chưa mua
          if (!_isPremium)
            IconButton(
              icon: const Icon(Icons.workspace_premium, color: Colors.orange),
              onPressed: _navigateToPayment,
              tooltip: 'Nâng cấp Premium',
            ),
        ],
      ),
      // ----------------------

      body: IndexedStack(
        index: _selectedIndex,
        children: _mainPages,
      ),

      // --- NÚT AI ---
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AiAgentScreen()),
            );
          },
          shape: const CircleBorder(),
          child: const AiChatBubble(),
        ),
      ),
      // ---------------

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
        color: isSelected ? const Color(0xFF455A75) : Colors.grey.shade400,
        size: 28,
      ),
      onPressed: () => _onNavItemTapped(index),
      tooltip: label,
    );
  }
}
