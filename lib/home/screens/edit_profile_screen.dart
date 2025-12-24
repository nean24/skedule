import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/features/settings/settings_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final name = user.userMetadata?['name'] ?? '';
      _nameController.text = name;
    }
  }

  Future<void> _updateProfile() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final name = _nameController.text.trim();
      final updates = {
        'name': name,
      };

      // 1. Update auth user metadata (for immediate UI updates via currentUser)
      await _supabase.auth.updateUser(
        UserAttributes(
          data: updates,
        ),
      );

      // 2. Update profiles table (for database consistency)
      try {
        await _supabase.from('profiles').update({
          'name': name,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      } catch (dbError) {
        // If updating profiles fails, we might want to log it,
        // but since auth update succeeded, we can consider it a partial success
        // or just ignore if the profile row doesn't exist yet (though it should).
        debugPrint('Error updating profiles table: $dbError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.strings.translate('profile_updated'))),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${settings.strings.translate('error_updating_profile')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;
    final cardColor = colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.strings.translate('edit_profile'), style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: settings.strings.translate('display_name'),
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                filled: true,
                fillColor: cardColor,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(settings.strings.translate('save_changes')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
