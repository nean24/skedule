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
  RealtimeChannel? _notesSubscription;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
    _subscribeToNotes();
  }

  @override
  void dispose() {
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          settings.strings.translate('note'),
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onBackground),
        ),
        iconTheme: IconThemeData(color: colorScheme.onBackground),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            color: colorScheme.primary,
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            color: colorScheme.primary,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NoteDetailScreen(),
                ),
              );
              _fetchNotes();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotes,
        color: colorScheme.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notes.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_alt_outlined,
                              size: 64, color: colorScheme.primary.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            settings.strings.translate('no_notes_yet'),
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.6), fontSize: 16),
                          ),
                          SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                              builder: (context) => NoteDetailScreen(note: note),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
