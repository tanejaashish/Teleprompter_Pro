// lib/screens/enhanced_scripts_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:uuid/uuid.dart';

// Complete Script Model with all Phase 2 features
class Script {
  final String id;
  final String title;
  final String content;
  final String? richContent; // JSON for rich text
  final DateTime createdAt;
  final DateTime updatedAt;
  final ScriptSettings settings;
  final List<ScriptMarker> markers;
  final String? category;
  final List<String> tags;
  final Map<String, dynamic>? metadata;

  Script({
    required this.id,
    required this.title,
    required this.content,
    this.richContent,
    required this.createdAt,
    required this.updatedAt,
    required this.settings,
    this.markers = const [],
    this.category,
    this.tags = const [],
    this.metadata,
  });

  int get wordCount => content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  int get characterCount => content.length;
  
  Duration get estimatedReadTime {
    const averageWPM = 150;
    final minutes = wordCount / averageWPM;
    return Duration(minutes: minutes.ceil());
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'richContent': richContent,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'settings': settings.toJson(),
    'markers': markers.map((m) => m.toJson()).toList(),
    'category': category,
    'tags': tags,
    'metadata': metadata,
  };

  factory Script.fromJson(Map<String, dynamic> json) => Script(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    richContent: json['richContent'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    settings: ScriptSettings.fromJson(json['settings']),
    markers: (json['markers'] as List?)?.map((m) => ScriptMarker.fromJson(m)).toList() ?? [],
    category: json['category'],
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    metadata: json['metadata'],
  );
}

class ScriptSettings {
  final double fontSize;
  final String fontFamily;
  final Color textColor;
  final Color backgroundColor;
  final TextAlign textAlign;
  final double lineHeight;
  final EdgeInsets padding;
  final bool showGuide;
  final double guidePosition;
  final Color guideColor;
  final double defaultSpeed;

  ScriptSettings({
    this.fontSize = 32.0,
    this.fontFamily = 'Roboto',
    this.textColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.textAlign = TextAlign.center,
    this.lineHeight = 1.8,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
    this.showGuide = true,
    this.guidePosition = 0.3,
    this.guideColor = Colors.red,
    this.defaultSpeed = 2.0,
  });

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'textColor': textColor.value,
    'backgroundColor': backgroundColor.value,
    'textAlign': textAlign.index,
    'lineHeight': lineHeight,
    'padding': {
      'left': padding.left,
      'top': padding.top,
      'right': padding.right,
      'bottom': padding.bottom,
    },
    'showGuide': showGuide,
    'guidePosition': guidePosition,
    'guideColor': guideColor.value,
    'defaultSpeed': defaultSpeed,
  };

  factory ScriptSettings.fromJson(Map<String, dynamic> json) => ScriptSettings(
    fontSize: json['fontSize']?.toDouble() ?? 32.0,
    fontFamily: json['fontFamily'] ?? 'Roboto',
    textColor: Color(json['textColor'] ?? Colors.white.value),
    backgroundColor: Color(json['backgroundColor'] ?? Colors.black.value),
    textAlign: TextAlign.values[json['textAlign'] ?? 1],
    lineHeight: json['lineHeight']?.toDouble() ?? 1.8,
    padding: EdgeInsets.fromLTRB(
      json['padding']?['left']?.toDouble() ?? 40,
      json['padding']?['top']?.toDouble() ?? 100,
      json['padding']?['right']?.toDouble() ?? 40,
      json['padding']?['bottom']?.toDouble() ?? 100,
    ),
    showGuide: json['showGuide'] ?? true,
    guidePosition: json['guidePosition']?.toDouble() ?? 0.3,
    guideColor: Color(json['guideColor'] ?? Colors.red.value),
    defaultSpeed: json['defaultSpeed']?.toDouble() ?? 2.0,
  );
}

class ScriptMarker {
  final String id;
  final int position;
  final String label;
  final MarkerType type;
  final Color? color;

  ScriptMarker({
    required this.id,
    required this.position,
    required this.label,
    this.type = MarkerType.general,
    this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': position,
    'label': label,
    'type': type.name,
    'color': color?.value,
  };

  factory ScriptMarker.fromJson(Map<String, dynamic> json) => ScriptMarker(
    id: json['id'],
    position: json['position'],
    label: json['label'],
    type: MarkerType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => MarkerType.general,
    ),
    color: json['color'] != null ? Color(json['color']) : null,
  );
}

enum MarkerType { general, pause, emphasis, cue, section }

// SQLite Database Service
class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._();
  
  DatabaseService._();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDirectory.path, 'teleprompt_pro.db');
    
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scripts (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        rich_content TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        settings TEXT NOT NULL,
        markers TEXT,
        category TEXT,
        tags TEXT,
        metadata TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // Add default templates
    await _insertDefaultTemplates(db);
  }
  
  Future<void> _insertDefaultTemplates(Database db) async {
    final templates = [
      {
        'id': const Uuid().v4(),
        'name': 'News Broadcast',
        'content': '**Breaking News**\n\n[Headline here]\n\nGood evening, I\'m [Your Name], and here are tonight\'s top stories.\n\n[Story 1]\n\n[Story 2]\n\n[Story 3]\n\nWe\'ll have more on these stories after the break.',
        'category': 'News',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'id': const Uuid().v4(),
        'name': 'YouTube Intro',
        'content': 'Hey everyone! Welcome back to [Channel Name]!\n\nToday we\'re going to talk about [Topic].\n\nBut before we get started, make sure to hit that subscribe button and ring the notification bell so you never miss an upload!\n\n[Main Content]\n\nThanks for watching! See you in the next video!',
        'category': 'YouTube',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'id': const Uuid().v4(),
        'name': 'Presentation',
        'content': '**[Presentation Title]**\n\nGood [morning/afternoon], everyone.\n\nToday I\'ll be presenting [Topic].\n\n**Agenda:**\n1. [Point 1]\n2. [Point 2]\n3. [Point 3]\n\nLet\'s begin with [Point 1]...',
        'category': 'Business',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    ];
    
    for (final template in templates) {
      await db.insert('templates', template);
    }
  }
}

// Script Repository with SQLite
class ScriptRepository {
  final DatabaseService _db = DatabaseService.instance;
  final _scriptsController = StreamController<List<Script>>.broadcast();
  
  Stream<List<Script>> watchScripts() {
    _loadScripts();
    return _scriptsController.stream;
  }
  
  Future<void> _loadScripts() async {
    final scripts = await getAllScripts();
    _scriptsController.add(scripts);
  }
  
  Future<List<Script>> getAllScripts() async {
    final db = await _db.database;
    final maps = await db.query('scripts', orderBy: 'updated_at DESC');
    return maps.map((map) => _scriptFromMap(map)).toList();
  }
  
  Future<Script> createScript(Script script) async {
    final db = await _db.database;
    await db.insert('scripts', _scriptToMap(script));
    _loadScripts();
    return script;
  }
  
  Future<Script> updateScript(Script script) async {
    final db = await _db.database;
    await db.update(
      'scripts',
      _scriptToMap(script),
      where: 'id = ?',
      whereArgs: [script.id],
    );
    _loadScripts();
    return script;
  }
  
  Future<void> deleteScript(String id) async {
    final db = await _db.database;
    await db.delete('scripts', where: 'id = ?', whereArgs: [id]);
    _loadScripts();
  }
  
  Future<List<Map<String, dynamic>>> getTemplates() async {
    final db = await _db.database;
    return await db.query('templates', orderBy: 'name');
  }
  
  Map<String, dynamic> _scriptToMap(Script script) => {
    'id': script.id,
    'title': script.title,
    'content': script.content,
    'rich_content': script.richContent,
    'created_at': script.createdAt.millisecondsSinceEpoch,
    'updated_at': script.updatedAt.millisecondsSinceEpoch,
    'settings': jsonEncode(script.settings.toJson()),
    'markers': jsonEncode(script.markers.map((m) => m.toJson()).toList()),
    'category': script.category,
    'tags': jsonEncode(script.tags),
    'metadata': script.metadata != null ? jsonEncode(script.metadata) : null,
  };
  
  Script _scriptFromMap(Map<String, dynamic> map) => Script(
    id: map['id'],
    title: map['title'],
    content: map['content'],
    richContent: map['rich_content'],
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    settings: ScriptSettings.fromJson(jsonDecode(map['settings'])),
    markers: map['markers'] != null 
      ? (jsonDecode(map['markers']) as List).map((m) => ScriptMarker.fromJson(m)).toList()
      : [],
    category: map['category'],
    tags: map['tags'] != null ? (jsonDecode(map['tags']) as List).cast<String>() : [],
    metadata: map['metadata'] != null ? jsonDecode(map['metadata']) : null,
  );
  
  void dispose() {
    _scriptsController.close();
  }
}

// Providers
final scriptRepositoryProvider = Provider((ref) => ScriptRepository());

final scriptsProvider = StreamProvider<List<Script>>((ref) {
  final repository = ref.watch(scriptRepositoryProvider);
  return repository.watchScripts();
});

final selectedScriptProvider = StateProvider<Script?>((ref) => null);

final settingsProvider = FutureProvider<ScriptSettings?>((ref) async {
  // Load from database or return defaults
  return ScriptSettings();
});

// Add in-memory scripts provider
class ScriptsNotifier extends StateNotifier<List<Script>> {
  ScriptsNotifier() : super([]);

  void addScript(String title, String content) {
    final script = Script(
      id: const Uuid().v4(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      settings: ScriptSettings(),
    );
    state = [...state, script];
  }
}

final inMemoryScriptsProvider = StateNotifierProvider<ScriptsNotifier, List<Script>>(
  (ref) => ScriptsNotifier(),
);

// Enhanced Scripts Screen UI
class EnhancedScriptsScreen extends ConsumerStatefulWidget {
  final TabController? tabController;
  
  const EnhancedScriptsScreen({
    super.key,
    this.tabController,
  });

  @override
  ConsumerState<EnhancedScriptsScreen> createState() => _EnhancedScriptsScreenState();
}

class _EnhancedScriptsScreenState extends ConsumerState<EnhancedScriptsScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  
  @override
  Widget build(BuildContext context) {
    final scriptsAsync = ref.watch(scriptsProvider);
    
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          const Divider(height: 1),
          Expanded(
            child: scriptsAsync.when(
              data: (scripts) => _buildScriptsList(scripts),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Scripts Library',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Chip(
            label: Text('${ref.watch(scriptsProvider).value?.length ?? 0} scripts'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _showTemplates,
            icon: const Icon(Icons.content_paste),
            label: const Text('Templates'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _importScript,
            icon: const Icon(Icons.upload_file),
            label: const Text('Import'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showScriptEditor(null),
            icon: const Icon(Icons.add),
            label: const Text('New Script'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search scripts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedCategory,
            hint: const Text('All Categories'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ...['News', 'YouTube', 'Business', 'Personal', 'Other']
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
            ],
            onChanged: (value) => setState(() => _selectedCategory = value),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScriptsList(List<Script> scripts) {
    // Filter scripts
    var filteredScripts = scripts;
    if (_searchQuery.isNotEmpty) {
      filteredScripts = filteredScripts.where((s) =>
        s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        s.content.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    if (_selectedCategory != null) {
      filteredScripts = filteredScripts.where((s) => s.category == _selectedCategory).toList();
    }
    
    if (filteredScripts.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredScripts.length,
      itemBuilder: (context, index) {
        final script = filteredScripts[index];
        return _buildScriptCard(script);
      },
    );
  }
  
  Widget _buildScriptCard(Script script) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectScript(script),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      script.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (script.category != null)
                    Chip(
                      label: Text(script.category!),
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                script.content.length > 150
                    ? '${script.content.substring(0, 150)}...'
                    : script.content,
                style: TextStyle(color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.text_fields, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${script.wordCount} words',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${script.estimatedReadTime.inMinutes} min',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.update, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(script.updatedAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () => _selectScript(script),
                    tooltip: 'Use in Teleprompter',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showScriptEditor(script),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () => _exportScript(script),
                    tooltip: 'Export',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(script),
                    tooltip: 'Delete',
                  ),
                ],
              ),
              if (script.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: script.tags.map((tag) => Chip(
                    label: Text(tag),
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No scripts found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text('Create a new script or import one to get started'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _showScriptEditor(null),
                icon: const Icon(Icons.add),
                label: const Text('Create Script'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _importScript,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _selectScript(Script script) {
    ref.read(selectedScriptProvider.notifier).state = script;
    widget.tabController?.animateTo(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded "${script.title}" in teleprompter'),
        action: SnackBarAction(
          label: 'Go',
          onPressed: () => widget.tabController?.animateTo(0),
        ),
      ),
    );
  }
  
  void _showScriptEditor(Script? script) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScriptEditorDialog(
        script: script,
        onSave: (updatedScript) async {
          final repository = ref.read(scriptRepositoryProvider);
          if (script == null) {
            await repository.createScript(updatedScript);
          } else {
            await repository.updateScript(updatedScript);
          }
        },
      ),
    );
  }
  
  void _showTemplates() async {
    final repository = ref.read(scriptRepositoryProvider);
    final templates = await repository.getTemplates();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Script Templates'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                title: Text(template['name']),
                subtitle: Text(template['category'] ?? 'General'),
                trailing: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _createFromTemplate(template);
                  },
                  child: const Text('Use'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _createFromTemplate(Map<String, dynamic> template) {
    final script = Script(
      id: const Uuid().v4(),
      title: 'New ${template['name']}',
      content: template['content'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      settings: ScriptSettings(),
      category: template['category'],
    );
    _showScriptEditor(script);
  }
  
  Future<void> _importScript() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx', 'pdf', 'md'],
    );
    
    if (result != null) {
      final file = File(result.files.single.path!);
      String content = '';
      
      if (result.files.single.extension == 'txt' || 
          result.files.single.extension == 'md') {
        content = await file.readAsString();
      } else {
        // For docx and pdf, show a message (would need additional packages)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DOCX and PDF import coming soon')),
        );
        return;
      }
      
      final script = Script(
        id: const Uuid().v4(),
        title: path.basenameWithoutExtension(result.files.single.name),
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        settings: ScriptSettings(),
      );
      
      await ref.read(scriptRepositoryProvider).createScript(script);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported "${script.title}"')),
      );
    }
  }
  
  Future<void> _exportScript(Script script) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Script',
      fileName: '${script.title}.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    
    if (result != null) {
      final file = File(result);
      await file.writeAsString(script.content);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported "${script.title}"')),
      );
    }
  }
  
  void _confirmDelete(Script script) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Script?'),
        content: Text('Are you sure you want to delete "${script.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(scriptRepositoryProvider).deleteScript(script.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${script.title}"')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Rich Text Script Editor Dialog
class ScriptEditorDialog extends StatefulWidget {
  final Script? script;
  final Function(Script) onSave;
  
  const ScriptEditorDialog({
    super.key,
    this.script,
    required this.onSave,
  });
  
  @override
  State<ScriptEditorDialog> createState() => _ScriptEditorDialogState();
}

class _ScriptEditorDialogState extends State<ScriptEditorDialog> {
  late TextEditingController _titleController;
  late quill.QuillController _quillController;
  late String _category;
  final List<String> _tags = [];
  
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.script?.title ?? '');
    _category = widget.script?.category ?? 'General';
    
    if (widget.script != null && widget.script!.richContent != null) {
      _quillController = quill.QuillController(
        document: quill.Document.fromJson(jsonDecode(widget.script!.richContent!)),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _quillController = quill.QuillController.basic();
      if (widget.script != null) {
        _quillController.document.insert(0, widget.script!.content);
      }
    }
    
    if (widget.script != null) {
      _tags.addAll(widget.script!.tags);
    }
  }
  
@override
Widget build(BuildContext context) {
  return Dialog(
    child: Container(
      width: 900,
      height: 700,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                widget.script == null ? 'New Script' : 'Edit Script',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ['General', 'News', 'YouTube', 'Business', 'Personal', 'Other']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Wrap QuillToolbar with Builder for proper context
          Builder(
            builder: (BuildContext context) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: quill.QuillSimpleToolbar(
                  controller: _quillController,
                  config: const quill.QuillSimpleToolbarConfig(
                    showFontFamily: false,  // Disable font family to avoid issues
                    showFontSize: true,
                    showBoldButton: true,
                    showItalicButton: true,
                    showUnderLineButton: true,
                    showStrikeThrough: true,
                    showColorButton: false,  // Disable color buttons temporarily
                    showBackgroundColorButton: false,
                    showClearFormat: true,
                    showAlignmentButtons: true,
                    showListNumbers: true,
                    showListBullets: true,
                    showLink: false,  // Disable link button
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Wrap QuillEditor with Builder for proper context
          Expanded(
            child: Builder(
              builder: (BuildContext context) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: quill.QuillEditor.basic(
                    controller: _quillController,
                    config: const quill.QuillEditorConfig(
                      padding: EdgeInsets.all(16),
                      //readOnly: false,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Word Count: ${_getWordCount()}'),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
  
  int _getWordCount() {
    final text = _quillController.document.toPlainText();
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
  
  void _save() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    
    final script = Script(
      id: widget.script?.id ?? const Uuid().v4(),
      title: _titleController.text,
      content: _quillController.document.toPlainText(),
      richContent: jsonEncode(_quillController.document.toDelta().toJson()),
      createdAt: widget.script?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      settings: widget.script?.settings ?? ScriptSettings(),
      markers: widget.script?.markers ?? [],
      category: _category,
      tags: _tags,
    );
    
    widget.onSave(script);
    Navigator.of(context).pop();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }
}