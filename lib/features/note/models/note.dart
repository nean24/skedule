class Note {
  final String id;
  final String? eventId;
  final String? taskId;
  final String? scheduleId;
  final String content;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    this.eventId,
    this.taskId,
    this.scheduleId,
    required this.content,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'].toString(), // Ensure id is String
      eventId: json['event_id']?.toString(), // Ensure eventId is String
      taskId: json['task_id']?.toString(), // Ensure taskId is String
      scheduleId: json['schedule_id']?.toString(), // Ensure scheduleId is String
      content: json['content'] ?? '', // Handle null content
      color: json['color'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
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
