import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // Default settings
  String _language = 'English';
  bool _isDarkMode = false;
  bool _is24HourFormat = true;
  String _dateFormat = 'dd/MM/yyyy';

  // Getters
  String get language => _language;
  bool get isDarkMode => _isDarkMode;
  bool get is24HourFormat => _is24HourFormat;
  String get dateFormat => _dateFormat;

  String get localeCode => _language == 'Tiếng Việt' ? 'vi' : 'en';

  // Load settings from Supabase
  Future<void> loadSettings() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('profiles')
          .select('settings_json')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['settings_json'] != null) {
        final settings = response['settings_json'] as Map<String, dynamic>;
        _language = settings['language'] ?? 'English';
        _isDarkMode = settings['is_dark_mode'] ?? false;
        _is24HourFormat = settings['is_24_hour_format'] ?? true;
        _dateFormat = settings['date_format'] ?? 'dd/MM/yyyy';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // Update a single setting
  Future<void> updateSetting(String key, dynamic value) async {
    // Update local state
    if (key == 'language') _language = value;
    if (key == 'is_dark_mode') _isDarkMode = value;
    if (key == 'is_24_hour_format') _is24HourFormat = value;
    if (key == 'date_format') _dateFormat = value;
    
    notifyListeners();

    // Sync with Supabase
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final newSettings = {
        'language': _language,
        'is_dark_mode': _isDarkMode,
        'is_24_hour_format': _is24HourFormat,
        'date_format': _dateFormat,
      };

      await _supabase.from('profiles').update({
        'settings_json': newSettings,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('Error updating setting $key: $e');
    }
  }
}
