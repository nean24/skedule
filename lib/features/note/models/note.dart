class Note {
  final String id;
  final String? eventId;
  final String? taskId;
  final String? scheduleId;
  final String content;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? linkedTitle; // <--- TRƯỜNG MỚI

  Note({
    required this.id,
    this.eventId,
    this.taskId,
    this.scheduleId,
    required this.content,
    this.color,
    required this.createdAt,
    required this.updatedAt,
    this.linkedTitle, // <--- Add to constructor
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    // --- LOGIC LẤY TIÊU ĐỀ LIÊN KẾT ---
    String? fetchedTitle;

    // 1. Kiểm tra nếu có Event liên kết
    if (json['events'] != null && json['events']['title'] != null) {
      fetchedTitle = "📅 Event: ${json['events']['title']}";
    }
    // 2. Kiểm tra nếu có Task liên kết
    else if (json['tasks'] != null && json['tasks']['title'] != null) {
      fetchedTitle = "✅ Task: ${json['tasks']['title']}";
    }
    // 3. Kiểm tra nếu có Schedule liên kết (Schedule thường không có title, lấy từ event cha)
    else if (json['schedules'] != null && json['schedules']['events'] != null) {
      fetchedTitle = "🕒 Schedule: ${json['schedules']['events']['title']}";
    }
    // -----------------------------------

    return Note(
      id: json['id'].toString(),
      eventId: json['event_id']?.toString(),
      taskId: json['task_id']?.toString(),
      scheduleId: json['schedule_id']?.toString(),
      content: json['content'] ?? '',
      color: json['color'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      linkedTitle: fetchedTitle, // <--- Gán giá trị
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'task_id': taskId,
      'schedule_id': scheduleId,
      'content': content,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}