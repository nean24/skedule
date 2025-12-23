import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/features/settings/settings_provider.dart';
import '../models/note.dart';

// --- BẢNG MÀU ĐỒNG BỘ ---
class AppColors {
  static const Color scaffoldBg = Color(0xFFDDE3ED);
  static const Color cardBg = Colors.white;
  static const Color primaryBlue = Color(0xFF455A75);
  static const Color textDark = Color(0xFF2D3142);
  static const Color textLight = Color(0xFF9094A6);
  static const Color noteAccent =
      Color(0xFF6C63FF); // Màu tím nhạt đặc trưng cho Note

  // Dark Mode
  static const Color scaffoldBgDark = Color(0xFF121212);
  static const Color cardBgDark = Color(0xFF1E1E1E);
  static const Color textDarkDark = Color(0xFFE0E0E0);
  static const Color textLightDark = Color(0xFFA0A0A0);
}

class NoteDetailScreen extends StatefulWidget {
  final Note? note;

  const NoteDetailScreen({super.key, this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final _contentController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isDirty = false; // Đánh dấu có thay đổi chưa lưu
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _contentController.text = widget.note!.content;
      _lastUpdated = widget.note!.updatedAt ?? widget.note!.createdAt;
    }

    // Lắng nghe thay đổi text để hiện nút lưu
    _contentController.addListener(() {
      if (!_isDirty) {
        setState(() => _isDirty = true);
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // --- LOGIC: LƯU GHI CHÚ ---
  Future<void> _saveNote() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final now = DateTime.now().toIso8601String();
      final noteData = {
        'content': content,
        'updated_at': now,
      };

      if (widget.note == null) {
        // Tạo mới
        noteData['user_id'] = user.id;
        noteData['created_at'] = now; // Thêm ngày tạo
        await _supabase.from('notes').insert(noteData);
      } else {
        // Cập nhật
        await _supabase
            .from('notes')
            .update(noteData)
            .eq('id', widget.note!.id);
      }

      setState(() {
        _isLoading = false;
        _isDirty = false;
        _lastUpdated = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settings.strings.translate('note_saved') ??
                'Đã lưu ghi chú! ✅'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Trả về true để reload list
      }
    } catch (e) {
      debugPrint("Lỗi lưu note: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${settings.strings.translate('error_saving_note')}: $e')),
        );
      }
    }
  }

  // --- LOGIC: XÓA GHI CHÚ ---
  Future<void> _deleteNote() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (widget.note == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.strings.translate('delete_note_confirm_title') ??
            'Xóa ghi chú?'),
        content: Text(
            settings.strings.translate('delete_note_confirm_content') ??
                'Hành động này không thể hoàn tác.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(settings.strings.translate('cancel') ?? 'Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              settings.strings.translate('delete') ?? 'Xóa',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.from('notes').delete().eq('id', widget.note!.id);
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${settings.strings.translate('error_deleting_note')}$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    // Màu sắc theo theme
    final bgColor = isDark ? AppColors.scaffoldBgDark : AppColors.scaffoldBg;
    final cardColor = isDark ? AppColors.cardBgDark : AppColors.cardBg;
    final textColor = isDark ? AppColors.textDarkDark : AppColors.textDark;
    final subTextColor = isDark ? AppColors.textLightDark : AppColors.textLight;
    final accentColor = AppColors.noteAccent;

    // Format ngày giờ cập nhật
    final dateStr = DateFormat('HH:mm - dd/MM/yyyy', settings.localeCode)
        .format(_lastUpdated);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.note == null
              ? (settings.strings.translate('new_note') ?? 'Ghi chú mới')
              : (settings.strings.translate('edit_note') ?? 'Chỉnh sửa'),
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          // Nút Xóa (Chỉ hiện nếu đang sửa note cũ)
          if (widget.note != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: _isLoading ? null : _deleteNote,
              ),
            ),

          // Nút Lưu (Chỉ hiện khi có thay đổi hoặc note mới)
          if (_isDirty || widget.note == null)
            Container(
              margin:
                  const EdgeInsets.only(right: 12, left: 4, top: 8, bottom: 8),
              decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]),
              child: IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, color: Colors.white, size: 22),
                onPressed: _isLoading ? null : _saveNote,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER: Thông tin cập nhật ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.access_time_filled, size: 16, color: subTextColor),
                const SizedBox(width: 8),
                Text(
                  '${settings.strings.translate('updated') ?? 'Cập nhật'}: $dateStr',
                  style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                // Badge loại Note
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'NOTE',
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // --- BODY: Vùng soạn thảo ---
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: 20), // Cách lề để tạo hiệu ứng nổi
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null, // Cho phép xuống dòng vô tận
                expands: true, // Chiếm hết không gian còn lại
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  height: 1.6, // Tăng khoảng cách dòng để dễ đọc
                ),
                decoration: InputDecoration(
                  hintText: settings.strings.translate('note_hint') ??
                      'Viết gì đó vào đây...',
                  hintStyle: TextStyle(
                      fontSize: 16, color: subTextColor.withOpacity(0.5)),
                  border: InputBorder.none, // Bỏ viền gạch chân
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
