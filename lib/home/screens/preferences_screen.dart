// lib/home/screens/preferences_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'package:skedule/features/payment/subscription_service.dart';

class PreferencesSheet extends StatefulWidget {
  const PreferencesSheet({super.key});

  @override
  State<PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<PreferencesSheet> {
  final _supabase = Supabase.instance.client;
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isPremium = false;
  bool _isLoading = true;
  String _planDetails = '';

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionStatus();
  }

  Future<void> _fetchSubscriptionStatus() async {
    final subDetails = await _subscriptionService.getSubscriptionDetails();
    
    bool isPremium = false;
    String planText = 'Free Plan';

    if (subDetails != null) {
      final plan = subDetails['plan'] as String?;
      final status = subDetails['status'] as String?;
      final endDateStr = subDetails['end_date'] as String?;

      if (plan == 'premium' && status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        if (endDate.isAfter(DateTime.now())) {
          isPremium = true;
          final daysLeft = endDate.difference(DateTime.now()).inDays;
          final monthsLeft = (daysLeft / 30).ceil();
          planText = 'Premium ($monthsLeft months left)';
        }
      }
    }

    if (mounted) {
      setState(() {
        _isPremium = isPremium;
        _planDetails = planText;
        _isLoading = false;
      });
    }
  }

  // --- HÀM LOGOUT ĐÃ ĐƯỢC VIẾT LẠI, ĐƠN GIẢN VÀ ĐÚNG ĐẮN ---
  Future<void> _signOut(BuildContext context) async {
    try {
      // 1. Đóng bottom sheet (tùy chọn, nhưng nên có để UI mượt hơn)
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 2. Chỉ cần gọi signOut. AuthGate sẽ tự động phát hiện sự kiện
      // và chuyển người dùng về màn hình LoginScreen.
      await _supabase.auth.signOut();

    } catch (e) {
      log('Error during sign out: ${e.toString()}', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi không xác định khi đăng xuất: ${e.toString()}.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- GIAO DIỆN CHÍNH ---
  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final userEmail = user?.email ?? 'N/A';
    final userName = user?.userMetadata?['name'] ?? user?.email?.split('@').first ?? 'Người dùng';
    final userInitials = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildTabs(),
          const SizedBox(height: 24),
          const Text('Account Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          _buildAccountInfoCard(userInitials, userName, userEmail),
          const SizedBox(height: 16),
          _buildInfoTile(icon: Icons.email_outlined, text: userEmail),
          _buildInfoTile(icon: Icons.calendar_today_outlined, text: 'Member Since January 2024'),
          const Divider(height: 32),
          _buildActionTile(
            context: context,
            icon: Icons.person_outline,
            text: 'Edit Profile',
            onTap: () { /* TODO: Mở màn hình chỉnh sửa profile */ },
          ),
          _buildActionTile(
            context: context,
            icon: Icons.logout,
            text: 'Sign Out',
            color: Colors.red,
            onTap: () => _signOut(context),
          ),
          const SizedBox(height: 24),
          const Center(child: Text('Skedule v1.0.0', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  // --- CÁC WIDGET PHỤ (ĐÃ ĐƯA VÀO BÊN TRONG CLASS) ---
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.settings_outlined),
        const SizedBox(width: 8),
        const Text('Preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton('Account', isSelected: true),
          _buildTabButton('Settings'),
          _buildTabButton('Theme'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, {bool isSelected = false}) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.white : Colors.transparent,
          foregroundColor: isSelected ? const Color(0xFF4A6C8B) : Colors.grey.shade700,
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildAccountInfoCard(String initials, String name, String email) {
    return Card(
      elevation: 4,
      color: const Color(0xFF4A6C8B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(initials, style: const TextStyle(color: Color(0xFF4A6C8B), fontWeight: FontWeight.bold, fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(email, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white), 
                  onPressed: () {
                    // TODO: Implement edit profile
                  }
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 32, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('127', 'Tasks Done'),
                _buildStat('12', 'Day Streak'),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isPremium ? Colors.amber.shade700 : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: _isPremium ? null : Border.all(color: Colors.white30),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isPremium) ...[
                                const Icon(Icons.star, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  _planDetails.isNotEmpty ? _planDetails : (_isPremium ? 'Premium' : 'Free Plan'),
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildInfoTile({required IconData icon, required String text}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey.shade700),
        title: Text(text),
      ),
    );
  }

  Widget _buildActionTile({required BuildContext context, required IconData icon, required String text, Color? color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Theme.of(context).iconTheme.color),
      title: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
} // <--- Dấu ngoặc quan trọng kết thúc class PreferencesSheet