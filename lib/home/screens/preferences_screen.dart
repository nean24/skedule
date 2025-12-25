import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'package:skedule/features/payment/subscription_service.dart';
import 'package:intl/intl.dart';
import 'package:skedule/home/screens/edit_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:skedule/features/settings/settings_provider.dart';

class PreferencesSheet extends StatefulWidget {
  const PreferencesSheet({super.key});

  @override
  State<PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<PreferencesSheet> {
  final _supabase = Supabase.instance.client;
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isPremium = false;
  String? _planName;
  bool _isLoading = true;
  String _selectedTab =
      'Account'; // Giữ nguyên key cũ để logic màu hoạt động đúng

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionStatus();
  }

  Future<void> _fetchSubscriptionStatus() async {
    final isPremium = await _subscriptionService.isPremium();
    final planName = await _subscriptionService.getActivePlanName();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
        _planName = planName;
        _isLoading = false;
      });
    }
  }

  // --- LOGIC ĐĂNG XUẤT (ĐÃ FIX) ---
  Future<void> _signOut(BuildContext context) async {
    try {
      if (context.mounted) Navigator.of(context).pop(); // Đóng sheet trước
      await _supabase.auth.signOut();
    } catch (e) {
      log('Error during sign out: ${e.toString()}', error: e);
      if (context.mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${settings.strings.translate('error_sign_out')}: ${e.toString()}.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- GIAO DIỆN CHÍNH (MÀU CŨ) ---
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    // --- KHÔI PHỤC MÀU CŨ ---
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconColor = isDark ? Colors.white : Colors.black;
    // ------------------------

    final user = _supabase.auth.currentUser;
    final userEmail = user?.email ?? 'N/A';
    final userName = user?.userMetadata?['name'] ??
        user?.email?.split('@').first ??
        'Người dùng';
    final userInitials =
        userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U';

    String memberSince = 'N/A';
    if (user?.createdAt != null) {
      try {
        final date = DateTime.parse(user!.createdAt);
        memberSince = DateFormat('MMMM yyyy', settings.localeCode).format(date);
      } catch (e) {
        log('Error parsing date: $e');
      }
    }

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, settings, textColor, iconColor),
          const SizedBox(height: 16),
          _buildTabs(isDark),
          const SizedBox(height: 24),
          if (_selectedTab == 'Account') ...[
            Text(settings.strings.translate('account_info'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor)),
            const SizedBox(height: 16),

            // Card Account (Đã xóa tasks_done & day_streak, giữ màu xanh đặc trưng)
            _buildAccountInfoCard(userInitials, userName, userEmail, settings),

            const SizedBox(height: 16),
            _buildInfoTile(
                icon: Icons.calendar_today_outlined,
                text:
                    '${settings.strings.translate('member_since')} $memberSince',
                isDark: isDark),
            const Divider(height: 32),
            _buildActionTile(
              context: context,
              icon: Icons.person_outline,
              text: settings.strings.translate('edit_profile'),
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const EditProfileScreen()),
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              isDark: isDark,
            ),
            _buildActionTile(
              context: context,
              icon: Icons.logout,
              text: settings.strings.translate('sign_out'),
              color: Colors.red,
              onTap: () => _signOut(context),
              isDark: isDark,
            ),
          ] else if (_selectedTab == 'Settings') ...[
            Text(settings.strings.translate('general_settings'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor)),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Icons.language,
              title: settings.strings.translate('language'),
              isDark: isDark,
              textColor: textColor,
              trailing: DropdownButton<String>(
                value: settings.language,
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                style: TextStyle(color: textColor),
                underline: const SizedBox(),
                items: ['English', 'Tiếng Việt'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    settings.updateSetting('language', newValue);
                  }
                },
              ),
            ),
            _buildSettingItem(
              icon: Icons.dark_mode_outlined,
              title: settings.strings.translate('dark_mode'),
              isDark: isDark,
              textColor: textColor,
              trailing: Switch(
                value: settings.isDarkMode,
                onChanged: (value) {
                  settings.updateSetting('is_dark_mode', value);
                },
                activeColor: const Color(0xFF4A6C8B),
              ),
            ),
            _buildSettingItem(
              icon: Icons.access_time,
              title: settings.strings.translate('24_hour_time'),
              isDark: isDark,
              textColor: textColor,
              trailing: Switch(
                value: settings.is24HourFormat,
                onChanged: (value) {
                  settings.updateSetting('is_24_hour_format', value);
                },
                activeColor: const Color(0xFF4A6C8B),
              ),
            ),
            _buildSettingItem(
              icon: Icons.date_range,
              title: settings.strings.translate('date_format'),
              isDark: isDark,
              textColor: textColor,
              trailing: DropdownButton<String>(
                value: settings.dateFormat,
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                style: TextStyle(color: textColor),
                underline: const SizedBox(),
                items: ['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    settings.updateSetting('date_format', newValue);
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 32),
          Center(
              child: Text(settings.strings.translate('version'),
                  style: TextStyle(color: subTextColor))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- CÁC WIDGET PHỤ (GIỮ STYLE CŨ) ---

  Widget _buildHeader(BuildContext context, SettingsProvider settings,
      Color textColor, Color iconColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.settings_outlined, color: iconColor),
        const SizedBox(width: 8),
        Text(settings.strings.translate('preferences'),
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close, color: iconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTabs(bool isDark) {
    final backgroundColor =
        isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton('Account',
              isSelected: _selectedTab == 'Account', isDark: isDark),
          _buildTabButton('Settings',
              isSelected: _selectedTab == 'Settings', isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text,
      {bool isSelected = false, required bool isDark}) {
    // Logic màu Tab cũ
    final selectedColor = isDark ? const Color(0xFF4A6C8B) : Colors.white;
    final unselectedTextColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final selectedTextColor = isDark ? Colors.white : const Color(0xFF4A6C8B);

    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedTab = text;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? selectedColor : Colors.transparent,
          foregroundColor: isSelected ? selectedTextColor : unselectedTextColor,
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildAccountInfoCard(
      String initials, String name, String email, SettingsProvider settings) {
    // Card màu xanh đặc trưng (0xFF4A6C8B)
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
                  child: Text(initials,
                      style: const TextStyle(
                          color: Color(0xFF4A6C8B),
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(email,
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const EditProfileScreen()),
                    );
                    if (result == true && mounted) {
                      setState(() {});
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // CHỈ HIỂN THỊ TRẠNG THÁI PREMIUM (Đã bỏ Tasks/Streak)
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    _isPremium ? Colors.amber : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: _isPremium
                    ? null
                    : Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isPremium) ...[
                          const Icon(Icons.star, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _isPremium
                              ? (_planName ??
                                  settings.strings.translate('premium'))
                              : settings.strings.translate('free_plan'),
                          style: TextStyle(
                            color: _isPremium
                                ? Colors.white
                                : Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
      {required IconData icon, required String text, required bool isDark}) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.grey[400] : Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(text, style: TextStyle(color: textColor)),
      ),
    );
  }

  Widget _buildActionTile(
      {required BuildContext context,
      required IconData icon,
      required String text,
      Color? color,
      required VoidCallback onTap,
      required bool isDark}) {
    final textColor = color ?? (isDark ? Colors.white : Colors.black);
    final iconColor =
        color ?? (isDark ? Colors.white : Theme.of(context).iconTheme.color);

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Widget _buildSettingItem(
      {required IconData icon,
      required String title,
      required Widget trailing,
      required bool isDark,
      required Color textColor}) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconColor = isDark ? Colors.grey[400] : Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor))),
            trailing,
          ],
        ),
      ),
    );
  }
}
