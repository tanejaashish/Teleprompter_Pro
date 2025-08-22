// packages/core/lib/infrastructure/repositories/script_repository_impl.dart

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class ScriptRepositoryImpl implements ScriptRepository {
  Database? _database;
  final _scriptsController = StreamController<List<Script>>.broadcast();
  final _uuid = const Uuid();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    // Initialize sqflite for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'teleprompt_pro.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scripts (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        settings TEXT NOT NULL,
        markers TEXT,
        metadata TEXT
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_scripts_title ON scripts(title);
    ''');
    
    await db.execute('''
      CREATE INDEX idx_scripts_updated ON scripts(updated_at);
    ''');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations
  }
  
  @override
  Future<List<Script>> getAllScripts() async {
    final db = await database;
    final maps = await db.query(
      'scripts',
      orderBy: 'updated_at DESC',
    );
    
    return maps.map((map) => _scriptFromMap(map)).toList();
  }
  
  @override
  Future<Script?> getScript(String id) async {
    final db = await database;
    final maps = await db.query(
      'scripts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return _scriptFromMap(maps.first);
  }
  
  @override
  Future<Script> createScript(ScriptData data) async {
    final db = await database;
    final now = DateTime.now();
    final script = Script(
      id: _uuid.v4(),
      title: data.title,
      content: data.content,
      createdAt: now,
      updatedAt: now,
      settings: data.settings ?? ScriptSettings(),
      markers: data.markers ?? [],
      metadata: data.metadata,
    );
    
    await db.insert('scripts', _scriptToMap(script));
    _notifyScriptsChanged();
    
    return script;
  }
  
  @override
  Future<Script> updateScript(String id, ScriptData data) async {
    final db = await database;
    final existing = await getScript(id);
    if (existing == null) throw Exception('Script not found');
    
    final updated = existing.copyWith(
      title: data.title,
      content: data.content,
      updatedAt: DateTime.now(),
      settings: data.settings ?? existing.settings,
      markers: data.markers ?? existing.markers,
      metadata: data.metadata ?? existing.metadata,
    );
    
    await db.update(
      'scripts',
      _scriptToMap(updated),
      where: 'id = ?',
      whereArgs: [id],
    );
    
    _notifyScriptsChanged();
    return updated;
  }
  
  @override
  Future<void> deleteScript(String id) async {
    final db = await database;
    await db.delete(
      'scripts',
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyScriptsChanged();
  }
  
  @override
  Stream<List<Script>> watchScripts() {
    _loadAndNotifyScripts(); // Initial load
    return _scriptsController.stream;
  }
  
  @override
  Future<List<Script>> searchScripts(String query) async {
    final db = await database;
    final maps = await db.query(
      'scripts',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
    
    return maps.map((map) => _scriptFromMap(map)).toList();
  }
  
  @override
  Future<void> importScript(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found');
    
    final content = await file.readAsString();
    final fileName = basename(filePath).replaceAll(RegExp(r'\.[^.]+$'), '');
    
    await createScript(ScriptData(
      title: fileName,
      content: content,
    ));
  }
  
  @override
  Future<void> exportScript(String id, String filePath) async {
    final script = await getScript(id);
    if (script == null) throw Exception('Script not found');
    
    final file = File(filePath);
    await file.writeAsString(script.content);
  }
  
  Map<String, dynamic> _scriptToMap(Script script) {
    return {
      'id': script.id,
      'title': script.title,
      'content': script.content,
      'created_at': script.createdAt.millisecondsSinceEpoch,
      'updated_at': script.updatedAt.millisecondsSinceEpoch,
      'settings': jsonEncode(script.settings.toJson()),
      'markers': script.markers.isNotEmpty 
          ? jsonEncode(script.markers.map((m) => m.toJson()).toList())
          : null,
      'metadata': script.metadata != null 
          ? jsonEncode(script.metadata)
          : null,
    };
  }
  
  Script _scriptFromMap(Map<String, dynamic> map) {
    return Script(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      settings: ScriptSettings.fromJson(jsonDecode(map['settings'])),
      markers: map['markers'] != null
          ? (jsonDecode(map['markers']) as List)
              .map((m) => ScriptMarker.fromJson(m))
              .toList()
          : [],
      metadata: map['metadata'] != null 
          ? jsonDecode(map['metadata'])
          : null,
    );
  }
  
  void _notifyScriptsChanged() async {
    await _loadAndNotifyScripts();
  }
  
  Future<void> _loadAndNotifyScripts() async {
    final scripts = await getAllScripts();
    _scriptsController.add(scripts);
  }
  
  void dispose() {
    _scriptsController.close();
    _database?.close();
  }
}