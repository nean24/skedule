import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skedule/features/settings/settings_provider.dart';
import '../../features/note/models/note.dart';
import '../../features/note/screens/note_detail_screen.dart';
import '../../features/note/widgets/note_card.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  final _supabase = Supabase.instance.client;
  List<Note> _notes = [];
  bool _isLoading = true;

  // Biến quản lý kênh lắng nghe Realtime
  RealtimeChannel? _notesSubscription;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
    _subscribeToNotes(); // <--- Kích hoạt lắng nghe ngay khi mở app
  }

  @override
  void dispose() {
    // Hủy đăng ký khi thoát màn hình để tránh rò rỉ bộ nhớ
    if (_notesSubscription != null) {
      _supabase.removeChannel(_notesSubscription!);
    }
    super.dispose();
  }

  // --- HÀM LẮNG NGHE REALTIME ---
  void _subscribeToNotes() {
    _notesSubscription = _supabase
        .channel('public:notes') // Tên kênh (bất kỳ)
        .onPostgresChanges(
            event: PostgresChangeEvent.all, // Nghe: INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'notes',
            callback: (payload) {
              // Khi có bất kỳ thay đổi nào trên bảng notes, tải lại danh sách
              print("♻️ Database changed! Reloading notes...");
              _fetchNotes();
            })
        .subscribe();
  }

  Future<void> _fetchNotes() async {
    try {
      // --- QUERY MỚI: JOIN VỚI CÁC BẢNG KHÁC ---
      final response = await _supabase
          .from('notes')
          .select('*, events(title), tasks(title), schedules(events(title))')
          .order('updated_at', ascending: false);

      final data = response as List<dynamic>;

      if (mounted) {
        setState(() {
          _notes = data.map((json) => Note.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[400];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(settings.strings.translate('note'),
            style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NoteDetailScreen(),
                ),
              );
              // Reload thủ công sau khi quay về (dự phòng nếu Realtime chậm)
              _fetchNotes();
            },
          ),
        ],
      ),
      // Thêm RefreshIndicator để user có thể kéo xuống reload thủ công
      body: RefreshIndicator(
        onRefresh: _fetchNotes,
        color: Theme.of(context).primaryColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notes.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      // Để RefreshIndicator hoạt động cần scrollable
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_alt_outlined,
                              size: 64, color: iconColor),
                          const SizedBox(height: 16),
                          Text(
                            settings.strings.translate('no_notes_yet'),
                            style: TextStyle(color: subTextColor, fontSize: 16),
                          ),
                          // Trick để chiếm chiều cao màn hình, giúp kéo refresh được
                          SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(), // Quan trọng cho RefreshIndicator
                    padding: const EdgeInsets.all(16),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return NoteCard(
                        note: note,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  NoteDetailScreen(note: note),
                            ),
                          );
                          // Không cần gọi _fetchNotes() ở đây vì Realtime sẽ tự bắt update
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
