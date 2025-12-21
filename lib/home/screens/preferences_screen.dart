import 'package:flutter/material.dart';
import 'package:skedule/main.dart';
import 'dart:developer';

class PreferencesSheet extends StatelessWidget {
  const PreferencesSheet({super.key});

  // --- HÀM LOGOUT ĐÃ ĐƯỢC VIẾT LẠI, ĐƠN GIẢN VÀ ĐÚNG ĐẮN ---
  Future<void> _signOut(BuildContext context) async {
    try {
      // 1. Đóng bottom sheet (tùy chọn, nhưng nên có để UI mượt hơn)
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 2. Chỉ cần gọi signOut. AuthGate sẽ tự động phát hiện sự kiện
      // và chuyển người dùng về màn hình LoginScreen.
      await supabase.auth.signOut();

    } catch (e) {
      debugPrint('Lỗi lấy profile: $e');
      setState(() => _isLoading = false);
    }
  }

  // Hàm đăng xuất thật
  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      // AuthGate sẽ tự động đưa người dùng về trang Login
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? 'N/A';
    final userName = user?.userMetadata?['name'] ?? user?.email?.split('@').first ?? 'Người dùng';
    final userInitials = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Thông tin cá nhân (Real Data)
          _buildProfileHeader(),
          const SizedBox(height: 30),

          // 2. Nhóm cài đặt: Tài khoản
          _buildSectionTitle('Tài khoản'),
          _buildSettingTile(
            icon: Icons.workspace_premium,
            title: 'Nâng cấp Premium',
            subtitle: 'Mở khóa tính năng AI nâng cao',
            color: Colors.amber[800]!,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen())),
          ),
          _buildSettingTile(
            icon: Icons.person_outline,
            title: 'Chỉnh sửa hồ sơ',
            onTap: () {},
          ),

          const SizedBox(height: 24),

          // 3. Nhóm cài đặt: Ứng dụng
          _buildSectionTitle('Ứng dụng'),
          _buildSettingTile(
            icon: Icons.notifications_none_rounded,
            title: 'Thông báo',
            trailing: Switch(value: true, onChanged: (v) {}, activeColor: const Color(0xFF455A75)),
          ),
          _buildSettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'Chế độ tối',
            trailing: Switch(value: false, onChanged: (v) {}, activeColor: const Color(0xFF455A75)),
          ),
          _buildSettingTile(
            icon: Icons.language_rounded,
            title: 'Ngôn ngữ',
            subtitle: 'Tiếng Việt',
            onTap: () {},
          ),

          const SizedBox(height: 40),

          // 4. Nút Đăng xuất
          ElevatedButton.icon(
            onPressed: _handleSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('ĐĂNG XUẤT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.redAccent,
              elevation: 0,
              side: const BorderSide(color: Colors.redAccent, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Text('Phiên bản 1.5.0', style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
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
      color: const Color(0xFF4A6C8B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Text(initials, style: const TextStyle(color: Color(0xFF4A6C8B), fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(email, style: TextStyle(color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white), onPressed: () {}),
              ],
            ),
            const Divider(color: Colors.white30, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('127', 'Tasks Done'),
                _buildStat('12', 'Day Streak'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Free Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9094A6)),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color color = const Color(0xFF455A75),
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }
}