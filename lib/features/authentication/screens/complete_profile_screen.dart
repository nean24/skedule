  // lib/features/authentication/screens/complete_profile_screen.dart

  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import 'package:skedule/main.dart';
  import 'package:skedule/home/screens/home_screen.dart';

  class CompleteProfileScreen extends StatefulWidget {
    const CompleteProfileScreen({super.key});

    @override
    State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
  }

  class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _birthDateController = TextEditingController();

    DateTime? _selectedBirthDate;
    String? _selectedGender;
    XFile? _selectedAvatar;
    bool _isLoading = false;

    @override
    void dispose() {
      _nameController.dispose();
      _birthDateController.dispose();
      super.dispose();
    }

    Future<void> _pickAvatar() async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedAvatar = image;
        });
      }
    }

    Future<void> _selectBirthDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedBirthDate ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
      if (picked != null && picked != _selectedBirthDate) {
        setState(() {
          _selectedBirthDate = picked;
          _birthDateController.text = "${picked.day}/${picked.month}/${picked.year}";
        });
      }
    }

    Future<void> _saveProfile() async {
      if (!_formKey.currentState!.validate()) return;
      setState(() { _isLoading = true; });

      try {
        final userId = supabase.auth.currentUser!.id;
        String? avatarUrl;

        // 1. Upload ảnh đại diện nếu có
        if (_selectedAvatar != null) {
          final imageFile = File(_selectedAvatar!.path);
          final imageExtension = _selectedAvatar!.path.split('.').last.toLowerCase();
          final imagePath = 'avatars/$userId/profile_avatar.$imageExtension';

          await supabase.storage.from('avatars').upload(
            imagePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
          avatarUrl = supabase.storage.from('avatars').getPublicUrl(imagePath);
        }

        // 2. Cập nhật thông tin vào bảng profiles
        await supabase.from('profiles').update({
          'name': _nameController.text.trim(),
          'birth_date': _selectedBirthDate?.toIso8601String(),
          'gender': _selectedGender,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        }).eq('id', userId);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false
          );
        }

      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi lưu hồ sơ: ${error.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) { setState(() { _isLoading = false; }); }
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hoàn Thiện Hồ Sơ')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _selectedAvatar != null ? FileImage(File(_selectedAvatar!.path)) : null,
                      child: _selectedAvatar == null ? const Icon(Icons.camera_alt, size: 40) : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Vui lòng nhập tên' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _birthDateController,
                    decoration: const InputDecoration(labelText: 'Ngày sinh', hintText: 'Nhấn để chọn'),
                    readOnly: true,
                    onTap: () => _selectBirthDate(context),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(labelText: 'Giới tính'),
                    items: ['Nam', 'Nữ', 'Khác'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() { _selectedGender = newValue; });
                    },
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(onPressed: _saveProfile, child: const Text('Hoàn tất')),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }