// lib/home/screens/preferences_screen.dart

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
  String _selectedTab = 'account_tab'; 

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
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${settings.strings.translate('error_sign_out')}: ${e.toString()}.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- GIAO DIỆN CHÍNH ---
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final user = _supabase.auth.currentUser;
    final userEmail = user?.email ?? 'N/A';
    final userName = user?.userMetadata?['name'] ?? user?.email?.split('@').first ?? 'Người dùng';
    final userInitials = userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U';

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
      color: colorScheme.background,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, settings, colorScheme, textTheme),
          const SizedBox(height: 16),
          _buildTabs(settings, colorScheme, textTheme),
          const SizedBox(height: 24),
          
          if (_selectedTab == 'account_tab') ...[
            Text(settings.strings.translate('account_info'), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            const SizedBox(height: 16),
            _buildAccountInfoCard(userInitials, userName, userEmail, settings, colorScheme, textTheme),
            const SizedBox(height: 16),
            _buildInfoTile(icon: Icons.calendar_today_outlined, text: '${settings.strings.translate('member_since')} $memberSince', colorScheme: colorScheme, textTheme: textTheme),
            const Divider(height: 32),
            _buildActionTile(
              context: context,
              icon: Icons.person_outline,
              text: settings.strings.translate('edit_profile'),
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            _buildActionTile(
              context: context,
              icon: Icons.logout,
              text: settings.strings.translate('sign_out'),
              color: Colors.red,
              onTap: () => _signOut(context),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ] else if (_selectedTab == 'settings_tab') ...[
            Text(settings.strings.translate('general_settings'), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Icons.language,
              title: settings.strings.translate('language'),
              colorScheme: colorScheme,
              textTheme: textTheme,
              trailing: DropdownButton<String>(
                value: settings.language,
                dropdownColor: colorScheme.surface,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
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
              colorScheme: colorScheme,
              textTheme: textTheme,
              trailing: Switch(
                value: settings.isDarkMode,
                onChanged: (value) {
                  settings.updateSetting('is_dark_mode', value);
                },
                activeColor: colorScheme.primary,
              ),
            ),
            _buildSettingItem(
              icon: Icons.access_time,
              title: settings.strings.translate('24_hour_time'),
              colorScheme: colorScheme,
              textTheme: textTheme,
              trailing: Switch(
                value: settings.is24HourFormat,
                onChanged: (value) {
                  settings.updateSetting('is_24_hour_format', value);
                },
                activeColor: colorScheme.primary,
              ),
            ),
            _buildSettingItem(
              icon: Icons.date_range,
              title: settings.strings.translate('date_format'),
              colorScheme: colorScheme,
              textTheme: textTheme,
              trailing: DropdownButton<String>(
                value: settings.dateFormat,
                dropdownColor: colorScheme.surface,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                underline: const SizedBox(),
                items: ['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'].map((String value) {
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
          Center(child: Text(settings.strings.translate('version'), style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SettingsProvider settings, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.settings_outlined, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(settings.strings.translate('preferences'), style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTabs(SettingsProvider settings, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton(
            settings.strings.translate('account_info'),
            tabKey: 'account_tab',
            isSelected: _selectedTab == 'account_tab',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          _buildTabButton(
            settings.strings.translate('general_settings'),
            tabKey: 'settings_tab',
            isSelected: _selectedTab == 'settings_tab',
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, {required String tabKey, bool isSelected = false, required ColorScheme colorScheme, required TextTheme textTheme}) {
    final selectedColor = colorScheme.primary;
    final unselectedTextColor = colorScheme.onSurface.withOpacity(0.7);
    final selectedTextColor = colorScheme.onPrimary;

    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedTab = tabKey;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? selectedColor : Colors.transparent,
          foregroundColor: isSelected ? selectedTextColor : unselectedTextColor,
          elevation: isSelected ? 2 : 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAccountInfoCard(String initials, String name, String email, SettingsProvider settings, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.onPrimary,
                  child: Text(initials, style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                      Text(email, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8))),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: colorScheme.onPrimary),
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                    );
                    if (result == true && mounted) {
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
            Divider(color: colorScheme.onPrimary.withOpacity(0.3), height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('127', settings.strings.translate('tasks_done'), colorScheme, textTheme),
                _buildStat('12', settings.strings.translate('day_streak'), colorScheme, textTheme),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPremium ? Colors.amber : colorScheme.onPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: _isPremium ? null : Border.all(color: colorScheme.onPrimary.withOpacity(0.5)),
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
                              const Icon(Icons.star, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _isPremium ? (_planName ?? settings.strings.translate('premium')) : settings.strings.translate('free_plan'),
                              style: textTheme.bodyMedium?.copyWith(
                                color: _isPremium ? Colors.white : colorScheme.onPrimary.withOpacity(0.9),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        Text(value, style: textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildInfoTile({required IconData icon, required String text, required ColorScheme colorScheme, required TextTheme textTheme}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(text, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
      ),
    );
  }

  Widget _buildActionTile({required BuildContext context, required IconData icon, required String text, Color? color, required VoidCallback onTap, required ColorScheme colorScheme, required TextTheme textTheme}) {
    final textColor = color ?? colorScheme.onSurface;
    final iconColor = color ?? colorScheme.primary;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(text, style: textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Widget _buildSettingItem({required IconData icon, required String title, required Widget trailing, required ColorScheme colorScheme, required TextTheme textTheme}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: colorScheme.onSurface))),
            trailing,
          ],
        ),
      ),
    );
  }
}