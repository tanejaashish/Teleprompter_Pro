import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class FeedbackStorageService {
  Database? _database;
  final CloudBackupService _cloudBackup = CloudBackupService();
  
  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      join(dbPath, 'feedback_storage.db'),
      version: 1,
      onCreate: (db, version) async {
        // Analysis feedback table
        await db.execute('''
          CREATE TABLE analysis_feedback (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            voice_analysis TEXT,
            video_analysis TEXT,
            transcript TEXT,
            emotions TEXT,
            suggestions TEXT,
            overall_score REAL,
            user_notes TEXT,
            tags TEXT,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        
        // Session recordings table
        await db.execute('''
          CREATE TABLE recording_sessions (
            id TEXT PRIMARY KEY,
            title TEXT,
            script_id TEXT,
            video_path TEXT,
            audio_path TEXT,
            duration INTEGER,
            analysis_summary TEXT,
            feedback_summary TEXT,
            improvements TEXT,
            created_at INTEGER
          )
        ''');
        
        // Performance metrics table
        await db.execute('''
          CREATE TABLE performance_metrics (
            id TEXT PRIMARY KEY,
            session_id TEXT,
            metric_type TEXT,
            value REAL,
            timestamp INTEGER,
            context TEXT
          )
        ''');
      },
    );
  }
  
  Future<String> saveFeedback({
    required String sessionId,
    required VoiceAnalysisResult voiceAnalysis,
    required VideoSentimentResult videoAnalysis,
    required String transcript,
    String? userNotes,
    List<String>? tags,
  }) async {
    final id = Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    await _database!.insert('analysis_feedback', {
      'id': id,
      'session_id': sessionId,
      'timestamp': timestamp,
      'voice_analysis': jsonEncode(voiceAnalysis.toJson()),
      'video_analysis': jsonEncode(videoAnalysis.toJson()),
      'transcript': transcript,
      'emotions': jsonEncode(voiceAnalysis.emotion.toJson()),
      'suggestions': jsonEncode(voiceAnalysis.suggestions),
      'overall_score': voiceAnalysis.score,
      'user_notes': userNotes,
      'tags': tags?.join(','),
      'created_at': timestamp,
      'updated_at': timestamp,
    });
    
    // Backup to cloud if enabled
    if (_cloudBackup.isEnabled) {
      await _cloudBackup.uploadFeedback(id, {
        'sessionId': sessionId,
        'voiceAnalysis': voiceAnalysis.toJson(),
        'videoAnalysis': videoAnalysis.toJson(),
        'transcript': transcript,
      });
    }
    
    return id;
  }
  
  Future<List<FeedbackSession>> getFeedbackHistory({
    String? sessionId,
    DateRange? dateRange,
    List<String>? tags,
    int limit = 50,
  }) async {
    String query = 'SELECT * FROM analysis_feedback WHERE 1=1';
    List<dynamic> args = [];
    
    if (sessionId != null) {
      query += ' AND session_id = ?';
      args.add(sessionId);
    }
    
    if (dateRange != null) {
      query += ' AND timestamp BETWEEN ? AND ?';
      args.add(dateRange.start.millisecondsSinceEpoch);
      args.add(dateRange.end.millisecondsSinceEpoch);
    }
    
    if (tags != null && tags.isNotEmpty) {
      query += ' AND (';
      for (int i = 0; i < tags.length; i++) {
        if (i > 0) query += ' OR ';
        query += 'tags LIKE ?';
        args.add('%${tags[i]}%');
      }
      query += ')';
    }
    
    query += ' ORDER BY timestamp DESC LIMIT ?';
    args.add(limit);
    
    final results = await _database!.rawQuery(query, args);
    
    return results.map((row) => FeedbackSession.fromMap(row)).toList();
  }
  
  Future<AnalyticsSummary> generateAnalyticsSummary({
    required DateRange period,
    required String userId,
  }) async {
    final sessions = await getFeedbackHistory(dateRange: period);
    
    if (sessions.isEmpty) {
      return AnalyticsSummary.empty();
    }
    
    // Calculate averages and trends
    double avgPitch = 0;
    double avgPace = 0;
    double avgClarity = 0;
    double avgScore = 0;
    Map<String, int> emotionCounts = {};
    List<String> commonSuggestions = [];
    
    for (final session in sessions) {
      final voiceData = session.voiceAnalysis;
      avgPitch += voiceData.pitch;
      avgPace += voiceData.pace;
      avgClarity += voiceData.clarity;
      avgScore += voiceData.score;
      
      // Count emotions
      final emotion = voiceData.emotion.primary;
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
      
      // Collect suggestions
      commonSuggestions.addAll(voiceData.suggestions);
    }
    
    final count = sessions.length.toDouble();
    
    return AnalyticsSummary(
      period: period,
      totalSessions: sessions.length,
      averagePitch: avgPitch / count,
      averagePace: avgPace / count,
      averageClarity: avgClarity / count,
      averageScore: avgScore / count,
      emotionDistribution: emotionCounts,
      topSuggestions: _getTopSuggestions(commonSuggestions),
      improvementTrend: _calculateTrend(sessions),
    );
  }
  
  Future<void> exportFeedback({
    required String format,
    required String outputPath,
    DateRange? dateRange,
  }) async {
    final sessions = await getFeedbackHistory(dateRange: dateRange);
    
    switch (format.toLowerCase()) {
      case 'pdf':
        await _exportToPDF(sessions, outputPath);
        break;
      case 'csv':
        await _exportToCSV(sessions, outputPath);
        break;
      case 'json':
        await _exportToJSON(sessions, outputPath);
        break;
      default:
        throw UnsupportedError('Format $format not supported');
    }
  }
}