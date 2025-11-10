// Recording Model
class Recording {
  final String id;
  final String title;
  final int duration;
  final String? cloudUrl;
  final String? thumbnailUrl;
  final String quality;
  final String format;
  final String status;
  final DateTime createdAt;

  Recording({
    required this.id,
    required this.title,
    required this.duration,
    this.cloudUrl,
    this.thumbnailUrl,
    this.quality = '1080p',
    this.format = 'mp4',
    this.status = 'completed',
    required this.createdAt,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] as String,
      title: json['title'] as String,
      duration: json['duration'] as int? ?? 0,
      cloudUrl: json['cloudUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      quality: json['quality'] as String? ?? '1080p',
      format: json['format'] as String? ?? 'mp4',
      status: json['status'] as String? ?? 'completed',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'cloudUrl': cloudUrl,
      'thumbnailUrl': thumbnailUrl,
      'quality': quality,
      'format': format,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
