// Script Model
class Script {
  final String id;
  final String title;
  final String content;
  final String? richContent;
  final int wordCount;
  final int estimatedDuration;
  final String? category;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Script({
    required this.id,
    required this.title,
    required this.content,
    this.richContent,
    required this.wordCount,
    required this.estimatedDuration,
    this.category,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Script.fromJson(Map<String, dynamic> json) {
    return Script(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      richContent: json['richContent'] as String?,
      wordCount: json['wordCount'] as int? ?? 0,
      estimatedDuration: json['estimatedDuration'] as int? ?? 0,
      category: json['category'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'richContent': richContent,
      'wordCount': wordCount,
      'estimatedDuration': estimatedDuration,
      'category': category,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
