import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/main.dart'; // Để dùng biến 'supabase'
import 'package:skedule/features/payment/payment_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final User? user = supabase.auth.currentUser;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  // Lấy dữ liệu profile thật từ bảng 'profiles'
  Future<void> _fetchUserProfile() async {
    if (user == null) return;
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user!.id)
          .single();
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FD),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFFDDE3ED),
            backgroundImage: _profileData?['avatar_url'] != null
                ? NetworkImage(_profileData!['avatar_url'])
                : null,
            child: _profileData?['avatar_url'] == null
                ? const Icon(Icons.person, size: 40, color: Color(0xFF455A75))
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profileData?['full_name'] ?? 'Người dùng Skedule',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'Chưa cập nhật email',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
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