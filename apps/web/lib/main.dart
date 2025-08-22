import 'package:flutter/material.dart';
import 'dart:async';  // ADD THIS LINE
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    ProviderScope(
      child: TelePromptProWeb(),
    ),
  );
}

class TelePromptProWeb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TelePrompt Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: WebMainScreen(),
    );
  }
}

class WebMainScreen extends StatefulWidget {
  @override
  State<WebMainScreen> createState() => _WebMainScreenState();
}

class _WebMainScreenState extends State<WebMainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TelePrompt Pro - Web'),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              // Show login/profile
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.speaker_notes),
                label: Text('Teleprompter'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description),
                label: Text('Scripts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cloud),
                label: Text('Cloud Sync'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildSelectedScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return WebTeleprompterScreen();
      case 1:
        return WebScriptsScreen();
      case 2:
        return WebCloudScreen();
      case 3:
        return WebSettingsScreen();
      default:
        return WebTeleprompterScreen();
    }
  }
}

class WebTeleprompterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.speaker_notes, size: 64),
          SizedBox(height: 16),
          Text('Web Teleprompter', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 8),
          Text('Optimized for browser use'),
        ],
      ),
    );
  }
}

class WebScriptsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Scripts Management'));
  }
}

class WebCloudScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Cloud Sync'));
  }
}

class WebRecordingScreen extends StatefulWidget {
  @override
  State<WebRecordingScreen> createState() => _WebRecordingScreenState();
}

class _WebRecordingScreenState extends State<WebRecordingScreen> {
  bool _isRecording = false;
  String _transcription = 'Ready to record...';
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 800),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Camera preview area
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.grey,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.videocam, size: 64, color: Colors.white30),
                  ),
                  
                  // Transcription overlay
                  if (_isRecording)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Live Transcription',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(_transcription,
                              style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // Control buttons
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _isRecording = !_isRecording;
                if (_isRecording) {
                  _startTranscription();
                }
              }),
              icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
              label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.orange : Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _startTranscription() {
    Timer.periodic(Duration(seconds: 2), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      setState(() {
        final phrases = [
          'Recording in progress...',
          'Capturing your presentation...',
          'Audio being transcribed...',
        ];
        _transcription = phrases[DateTime.now().second % phrases.length];
      });
    });
  }
}

class WebSettingsScreen extends StatefulWidget {
  @override
  State<WebSettingsScreen> createState() => _WebSettingsScreenState();
}

class _WebSettingsScreenState extends State<WebSettingsScreen> {
  String _selectedCamera = 'Default Camera';
  String _selectedMicrophone = 'Default Microphone';
  String _videoQuality = '1080p';
  String _frameRate = '30 FPS';
  String _exportFormat = 'PDF';
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: ListView(
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 24),
          
          // Recording Settings Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recording Settings', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  
                  // Camera Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Camera'),
                      DropdownButton<String>(
                        value: _selectedCamera,
                        items: ['Default Camera', 'External Webcam', 'Virtual Camera']
                            .map((cam) => DropdownMenuItem(
                                  value: cam,
                                  child: Text(cam),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedCamera = value!),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Microphone Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Microphone'),
                      DropdownButton<String>(
                        value: _selectedMicrophone,
                        items: ['Default Microphone', 'USB Microphone', 'Headset']
                            .map((mic) => DropdownMenuItem(
                                  value: mic,
                                  child: Text(mic),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedMicrophone = value!),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Quality Settings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Video Quality'),
                      DropdownButton<String>(
                        value: _videoQuality,
                        items: ['720p', '1080p', '4K']
                            .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                            .toList(),
                        onChanged: (value) => setState(() => _videoQuality = value!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Export Settings Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Default Format'),
                      DropdownButton<String>(
                        value: _exportFormat,
                        items: ['PDF', 'CSV', 'JSON', 'HTML']
                            .map((format) => DropdownMenuItem(
                                  value: format,
                                  child: Text(format),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _exportFormat = value!),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12),
                  
                  ElevatedButton.icon(
                    onPressed: () => _showExportDialog(),
                    icon: Icon(Icons.folder_open),
                    label: Text('Select Export Location'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export Location'),
        content: Text('Browser will prompt for download location when exporting'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}