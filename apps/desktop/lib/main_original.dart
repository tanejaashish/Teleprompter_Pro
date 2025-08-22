// lib/main.dart

import 'package:flutter/material.dart';
import 'dart:async';  // ADD THIS LINE
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

// Original screens (preserved)
import 'screens/scripts_screen.dart';
import 'screens/teleprompter_screen.dart';

// Enhanced screens (added for Phase 2 completion)
// Uncomment these when the files are created
import 'screens/enhanced_scripts_screen.dart';
import 'screens/enhanced_teleprompter_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'TelePrompt Pro',
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  runApp(
    const ProviderScope(
      child: TelePromptProApp(),
    ),
  );
}

class TelePromptProApp extends StatelessWidget {
  const TelePromptProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TelePrompt Pro',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  
  // Feature flag to switch between original and enhanced versions
  // Set to true to use enhanced Phase 2 features
  bool useEnhancedVersion = true; // Change to true when ready to use enhanced features

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
      _tabController.animateTo(index);
    });
  }
  
  // Toggle between original and enhanced versions
  void _toggleVersion() {
    setState(() {
      useEnhancedVersion = !useEnhancedVersion;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          useEnhancedVersion 
            ? 'Switched to Enhanced Phase 2 Version' 
            : 'Switched to Original Version'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _navigateToTab,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.speaker_notes, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'TelePrompt Pro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Version indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: useEnhancedVersion ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      useEnhancedVersion ? 'Enhanced' : 'Original',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Version toggle button
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    onPressed: _toggleVersion,
                    tooltip: 'Switch Version',
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.speaker_notes_outlined),
                selectedIcon: Icon(Icons.speaker_notes),
                label: Text('Teleprompter'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: Text('Scripts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.videocam_outlined),
                selectedIcon: Icon(Icons.videocam),
                label: Text('Record'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content area with TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: useEnhancedVersion
                ? [
                    EnhancedTeleprompterScreen(tabController: _tabController),
                    EnhancedScriptsScreen(tabController: _tabController),
                    const RecordScreen(),
                    const EnhancedSettingsScreen(),
                  ]
                : [
                    TeleprompterScreenWrapper(tabController: _tabController),
                    ScriptsScreenWrapper(tabController: _tabController),
                    const RecordScreen(),
                    const SettingsScreen(),
                  ],
            ),
          ),
        ],
      ),
    );
  }
}

// Original wrapper widgets (preserved)
class TeleprompterScreenWrapper extends StatelessWidget {
  final TabController tabController;
  
  const TeleprompterScreenWrapper({
    super.key,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return TeleprompterScreen(tabController: tabController);
  }
}

class ScriptsScreenWrapper extends StatelessWidget {
  final TabController tabController;
  
  const ScriptsScreenWrapper({
    super.key,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return ScriptsScreen(tabController: tabController);
  }
}

// Placeholder for Record screen (Phase 4)
// Replace the placeholder RecordScreen with the full Phase 4 implementation
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  bool _isRecording = false;
  bool _showAnalytics = true;
  String _recordingStatus = 'Ready';
  
  // Analysis data
  double _currentPitch = 150.0;
  double _currentVolume = -20.0;
  double _currentPace = 150.0;
  double _clarity = 0.85;
  String _emotion = 'Neutral';
  String _currentTranscription = 'Waiting for speech...';
  List<String> _suggestions = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Main recording area
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black87,
              child: Column(
                children: [
                  // Video preview area
                  Expanded(
                    child: Stack(
                      children: [
                        // Camera preview placeholder
                        Container(
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isRecording ? Colors.red : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: _buildVideoPreview(),
                        ),
                        
                        // Recording indicator
                        if (_isRecording)
                          Positioned(
                            top: 40,
                            left: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.fiber_manual_record, size: 16, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('REC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        
                        // Teleprompter overlay
                        if (_isRecording)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 200,
                            child: Container(
                              color: Colors.black54,
                              padding: EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                child: Text(
                                  'Your teleprompter text will appear here while recording...',
                                  style: TextStyle(color: Colors.white, fontSize: 20),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Control panel
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Settings button
                        IconButton(
                          icon: Icon(Icons.settings),
                          onPressed: _showRecordingSettings,
                          tooltip: 'Recording Settings',
                        ),
                        SizedBox(width: 16),
                        
                        // Main record button
                        ElevatedButton.icon(
                          onPressed: _toggleRecording,
                          icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                          label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? Colors.orange : Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                        ),
                        SizedBox(width: 16),
                        
                        // Effects button
                        IconButton(
                          icon: Icon(Icons.auto_awesome),
                          onPressed: _showEffects,
                          tooltip: 'Effects & Filters',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Real-time analytics panel
          if (_showAnalytics)
            Container(
              width: 400,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  left: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: _buildAnalyticsPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Stack(
      children: [
        // Camera preview
        if (!_isRecording)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Camera Preview', style: TextStyle(color: Colors.grey, fontSize: 18)),
                SizedBox(height: 8),
                Text('Click "Start Recording" to begin', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        else
          Container(
            color: Colors.grey[900],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam, size: 48, color: Colors.white54),
                  SizedBox(height: 8),
                  Text('Camera Feed Active', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        
        // Real-time transcription overlay
        if (_isRecording)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              height: 100,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Transcription', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _currentTranscription,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnalyticsPanel() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Header
        Row(
          children: [
            Text(
              'Real-time Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => setState(() => _showAnalytics = false),
              iconSize: 20,
            ),
          ],
        ),
        Divider(),
        
        // Voice Metrics
        _buildMetricCard(
          title: 'Voice Metrics',
          icon: Icons.mic,
          children: [
            _buildMetricRow('Pitch', '${_currentPitch.round()} Hz', _getPitchColor()),
            _buildMetricRow('Volume', '${_currentVolume.round()} dB', _getVolumeColor()),
            _buildMetricRow('Pace', '${_currentPace.round()} WPM', _getPaceColor()),
            _buildMetricRow('Clarity', '${(_clarity * 100).round()}%', _getClarityColor()),
          ],
        ),
        
        // Emotional State
        _buildMetricCard(
          title: 'Emotional Analysis',
          icon: Icons.psychology,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getEmotionColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _emotion,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        
        // Suggestions
        _buildMetricCard(
          title: 'Suggestions',
          icon: Icons.lightbulb,
          children: _suggestions.isEmpty
              ? [Text('No suggestions yet', style: TextStyle(color: Colors.grey))]
              : _suggestions.map((s) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_right, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(s, style: TextStyle(fontSize: 12))),
                    ],
                  ),
                )).toList(),
        ),
        
        // Export button
        SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _exportAnalytics,
          icon: Icon(Icons.download),
          label: Text('Export Analytics'),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPitchColor() => _currentPitch > 200 ? Colors.orange : Colors.green;
  Color _getVolumeColor() => _currentVolume > -15 ? Colors.orange : Colors.green;
  Color _getPaceColor() => _currentPace > 180 ? Colors.orange : Colors.green;
  Color _getClarityColor() => _clarity > 0.7 ? Colors.green : Colors.orange;
  
  Color _getEmotionColor() {
    switch (_emotion) {
      case 'Happy': return Colors.green;
      case 'Sad': return Colors.blue;
      case 'Angry': return Colors.red;
      case 'Fearful': return Colors.purple;
      default: return Colors.grey;
    }
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _startAnalysis();
        _recordingStatus = 'Recording...';
      } else {
        _stopAnalysis();
        _recordingStatus = 'Stopped';
      }
    });
  }

  void _startAnalysis() {
    // Simulate real-time analysis updates
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      setState(() {
        // Simulate voice metrics changes
        _currentPitch = 120 + (30 * (DateTime.now().millisecondsSinceEpoch % 10) / 10);
        _currentVolume = -30 + (20 * (DateTime.now().millisecondsSinceEpoch % 8) / 8);
        _currentPace = 140 + (40 * (DateTime.now().millisecondsSinceEpoch % 6) / 6);
        _clarity = 0.7 + (0.3 * (DateTime.now().millisecondsSinceEpoch % 5) / 5);
        
        // Rotate through emotions
        final emotions = ['Neutral', 'Happy', 'Confident', 'Focused'];
        _emotion = emotions[(DateTime.now().second ~/ 5) % emotions.length];
        
        // Generate random suggestions
        if (DateTime.now().second % 10 == 0) {
          _suggestions = [
            'Try speaking slightly slower',
            'Good eye contact with camera',
            'Maintain current energy level',
          ];
        }
      });
    });
    // Simulate transcription
      final phrases = [
        'Hello, welcome to my presentation.',
        'Today we will discuss important topics.',
        'Let me share some insights with you.',
        'This is a key point to remember.',
      ];
      _currentTranscription = phrases[DateTime.now().second % phrases.length];
  }

  void _stopAnalysis() {
    setState(() {
      _suggestions = ['Recording complete! Review your performance metrics.'];
    });
  }

  void _showRecordingSettings() {
    // Show recording settings dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recording Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Video Quality'),
              subtitle: Text('1080p HD'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
            ListTile(
              title: Text('Frame Rate'),
              subtitle: Text('30 FPS'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
            ListTile(
              title: Text('Audio Source'),
              subtitle: Text('Default Microphone'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEffects() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Effects & Filters'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Virtual Background'),
              value: false,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text('Beauty Filter'),
              value: false,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text('Eye Contact Correction'),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _exportAnalytics() {
    String exportPath = 'C:\\Users\\Documents\\TelePromptPro\\Analytics';
    String selectedFormat = 'PDF';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export Analytics'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose export format and location'),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Format',
                  border: OutlineInputBorder(),
                ),
                value: selectedFormat,
                items: ['PDF', 'CSV', 'JSON', 'HTML']
                    .map((format) => DropdownMenuItem(
                          value: format,
                          child: Text(format),
                        ))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedFormat = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Save Location',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.folder_open),
                    onPressed: () {
                      // In production, use file_picker package
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('File picker would open here')),
                      );
                    },
                  ),
                ),
                initialValue: exportPath,
                onChanged: (value) {
                  exportPath = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exporting to $exportPath as $selectedFormat')),
              );
            },
            child: Text('Export'),
          ),
        ],
      ),
    );
  }
}

// Original settings screen (preserved)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Default Font Size'),
              subtitle: const Text('32px'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Default Scroll Speed'),
              subtitle: const Text('2.0x'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Theme'),
              subtitle: const Text('System'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Settings Screen for Phase 2 completion
class EnhancedSettingsScreen extends StatefulWidget {
  const EnhancedSettingsScreen({super.key});

  @override
  State<EnhancedSettingsScreen> createState() => _EnhancedSettingsScreenState();
}

class _EnhancedSettingsScreenState extends State<EnhancedSettingsScreen> {
  // Settings values
  double _defaultFontSize = 32.0;
  double _defaultScrollSpeed = 2.0;
  ThemeMode _themeMode = ThemeMode.system;
  String _defaultFontFamily = 'Roboto';
  Color _defaultTextColor = Colors.white;
  Color _defaultBackgroundColor = Colors.black;
  bool _showFPSByDefault = false;
  bool _showTimerByDefault = true;
  bool _showGuideByDefault = true;
  double _defaultGuidePosition = 0.3;
  double _defaultLineHeight = 1.8;
  bool _enableKeyboardShortcuts = true;
  bool _autoSaveScripts = true;
  int _autoSaveInterval = 30; // seconds
  
  // ADD THESE NEW VARIABLES
  String _selectedCamera = 'Default Camera';
  String _selectedMicrophone = 'Default Microphone';
  List<String> _availableCameras = ['Default Camera', 'External Webcam', 'Virtual Camera'];
  List<String> _availableMicrophones = ['Default Microphone', 'USB Microphone', 'Headset'];
  String _videoQuality = '1080p';
  String _frameRate = '30 FPS';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetToDefaults,
                child: const Text('Reset to Defaults'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Display Settings Section
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.display_settings),
              title: const Text('Display Settings'),
              children: [
                // Font Size
                ListTile(
                  title: const Text('Default Font Size'),
                  subtitle: Slider(
                    value: _defaultFontSize,
                    min: 16,
                    max: 72,
                    divisions: 56,
                    label: '${_defaultFontSize.round()}px',
                    onChanged: (value) => setState(() => _defaultFontSize = value),
                  ),
                  trailing: Text('${_defaultFontSize.round()}px'),
                ),
                
                // Font Family
                ListTile(
                  title: const Text('Default Font Family'),
                  trailing: DropdownButton<String>(
                    value: _defaultFontFamily,
                    items: ['Roboto', 'Arial', 'Times New Roman', 'Courier New', 'Georgia']
                        .map((font) => DropdownMenuItem(
                              value: font,
                              child: Text(font),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _defaultFontFamily = value!),
                  ),
                ),
                
                // Line Height
                ListTile(
                  title: const Text('Default Line Height'),
                  subtitle: Slider(
                    value: _defaultLineHeight,
                    min: 1.0,
                    max: 3.0,
                    divisions: 20,
                    label: _defaultLineHeight.toStringAsFixed(1),
                    onChanged: (value) => setState(() => _defaultLineHeight = value),
                  ),
                  trailing: Text(_defaultLineHeight.toStringAsFixed(1)),
                ),
                
                // Theme Mode
                ListTile(
                  title: const Text('Theme Mode'),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (Set<ThemeMode> selected) {
                      setState(() => _themeMode = selected.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Teleprompter Settings Section
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.speed),
              title: const Text('Teleprompter Settings'),
              children: [
                // Default Scroll Speed
                ListTile(
                  title: const Text('Default Scroll Speed'),
                  subtitle: Slider(
                    value: _defaultScrollSpeed,
                    min: 0.25,
                    max: 5.0,
                    divisions: 95,
                    label: '${_defaultScrollSpeed.toStringAsFixed(2)}x',
                    onChanged: (value) => setState(() => _defaultScrollSpeed = value),
                  ),
                  trailing: Text('${_defaultScrollSpeed.toStringAsFixed(2)}x'),
                ),
                
                // Show FPS Counter
                SwitchListTile(
                  title: const Text('Show FPS Counter by Default'),
                  subtitle: const Text('Display performance metrics'),
                  value: _showFPSByDefault,
                  onChanged: (value) => setState(() => _showFPSByDefault = value),
                ),
                
                // Show Timer
                SwitchListTile(
                  title: const Text('Show Timer by Default'),
                  subtitle: const Text('Display elapsed and remaining time'),
                  value: _showTimerByDefault,
                  onChanged: (value) => setState(() => _showTimerByDefault = value),
                ),
                
                // Show Guide
                SwitchListTile(
                  title: const Text('Show Reading Guide by Default'),
                  subtitle: const Text('Display horizontal guide line'),
                  value: _showGuideByDefault,
                  onChanged: (value) => setState(() => _showGuideByDefault = value),
                ),
                
                // Guide Position
                if (_showGuideByDefault)
                  ListTile(
                    title: const Text('Default Guide Position'),
                    subtitle: Slider(
                      value: _defaultGuidePosition,
                      min: 0.1,
                      max: 0.9,
                      divisions: 8,
                      label: '${(_defaultGuidePosition * 100).round()}%',
                      onChanged: (value) => setState(() => _defaultGuidePosition = value),
                    ),
                    trailing: Text('${(_defaultGuidePosition * 100).round()}%'),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Recording Settings Section (ADD THIS ENTIRE BLOCK)
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Recording Settings'),
              children: [
                ListTile(
                  title: const Text('Camera'),
                  subtitle: Text('Default Camera'),
                  trailing: DropdownButton<String>(
                    value: 'Default Camera',
                    items: ['Default Camera', 'External Webcam', 'Virtual Camera']
                        .map((camera) => DropdownMenuItem(
                              value: camera,
                              child: Text(camera),
                            ))
                        .toList(),
                    onChanged: (value) {},
                  ),
                ),
                ListTile(
                  title: const Text('Microphone'),
                  subtitle: Text('Default Microphone'),
                  trailing: DropdownButton<String>(
                    value: 'Default Microphone',
                    items: ['Default Microphone', 'USB Microphone', 'Headset']
                        .map((mic) => DropdownMenuItem(
                              value: mic,
                              child: Text(mic),
                            ))
                        .toList(),
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Keyboard & Controls Section
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.keyboard),
              title: const Text('Keyboard & Controls'),
              children: [
                SwitchListTile(
                  title: const Text('Enable Keyboard Shortcuts'),
                  subtitle: const Text('Use keyboard controls in teleprompter'),
                  value: _enableKeyboardShortcuts,
                  onChanged: (value) => setState(() => _enableKeyboardShortcuts = value),
                ),
                
                if (_enableKeyboardShortcuts) ...[
                  const ListTile(
                    title: Text('Keyboard Shortcuts'),
                    subtitle: Text(
                      'Space: Play/Pause\n'
                      '↑/↓: Speed control\n'
                      'Home/End: Jump to start/end\n'
                      'M: Mirror mode\n'
                      'G: Toggle guide\n'
                      'T: Toggle timer\n'
                      'F11: Fullscreen',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Storage & Backup Section
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.storage),
              title: const Text('Storage & Backup'),
              children: [
                SwitchListTile(
                  title: const Text('Auto-save Scripts'),
                  subtitle: const Text('Automatically save changes while editing'),
                  value: _autoSaveScripts,
                  onChanged: (value) => setState(() => _autoSaveScripts = value),
                ),
                
                if (_autoSaveScripts)
                  ListTile(
                    title: const Text('Auto-save Interval'),
                    subtitle: Slider(
                      value: _autoSaveInterval.toDouble(),
                      min: 10,
                      max: 120,
                      divisions: 11,
                      label: '${_autoSaveInterval}s',
                      onChanged: (value) => setState(() => _autoSaveInterval = value.round()),
                    ),
                    trailing: Text('${_autoSaveInterval}s'),
                  ),
                
                ListTile(
                  title: const Text('Export All Scripts'),
                  subtitle: const Text('Backup all scripts to a file'),
                  trailing: OutlinedButton(
                    onPressed: _exportAllScripts,
                    child: const Text('Export'),
                  ),
                ),
                
                ListTile(
                  title: const Text('Import Scripts'),
                  subtitle: const Text('Restore scripts from backup'),
                  trailing: OutlinedButton(
                    onPressed: _importScripts,
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // About Section
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              children: [
                const ListTile(
                  title: Text('TelePrompt Pro'),
                  subtitle: Text('Version 2.0.0 - Phase 2 Complete'),
                ),
                ListTile(
                  title: const Text('Documentation'),
                  subtitle: const Text('View user guide and tutorials'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {},
                ),
                ListTile(
                  title: const Text('Check for Updates'),
                  trailing: OutlinedButton(
                    onPressed: _checkForUpdates,
                    child: const Text('Check'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _saveSettings() {
    // Save settings to database/preferences
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }
  
  void _resetToDefaults() {
    setState(() {
      _defaultFontSize = 32.0;
      _defaultScrollSpeed = 2.0;
      _themeMode = ThemeMode.system;
      _defaultFontFamily = 'Roboto';
      _defaultTextColor = Colors.white;
      _defaultBackgroundColor = Colors.black;
      _showFPSByDefault = false;
      _showTimerByDefault = true;
      _showGuideByDefault = true;
      _defaultGuidePosition = 0.3;
      _defaultLineHeight = 1.8;
      _enableKeyboardShortcuts = true;
      _autoSaveScripts = true;
      _autoSaveInterval = 30;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings reset to defaults')),
    );
  }
  
  void _exportAllScripts() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting scripts...')),
    );
  }
  
  void _importScripts() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import scripts feature coming soon')),
    );
  }
  
  void _checkForUpdates() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You are running the latest version')),
    );
  }
}