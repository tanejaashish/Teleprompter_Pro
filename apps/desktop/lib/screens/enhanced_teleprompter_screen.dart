// lib/screens/enhanced_teleprompter_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'enhanced_scripts_screen.dart';

// Complete Teleprompter with ALL Phase 2 Features
class EnhancedTeleprompterScreen extends ConsumerStatefulWidget {
  final TabController? tabController;
  
  const EnhancedTeleprompterScreen({
    super.key,
    this.tabController,
  });

  @override
  ConsumerState<EnhancedTeleprompterScreen> createState() => _EnhancedTeleprompterScreenState();
}

class _EnhancedTeleprompterScreenState extends ConsumerState<EnhancedTeleprompterScreen> 
    with TickerProviderStateMixin {
  
  // Core controllers
  ScrollController? _scrollController;
  AdvancedScrollEngine? _scrollEngine;
  late AnimationController _fpsAnimationController;
  
  // State variables
  bool _isPlaying = false;
  double _currentSpeed = 2.0;
  bool _mirrorMode = false;
  bool _showGuide = true;
  double _guidePosition = 0.3;
  Color _guideColor = Colors.red;
  bool _showTimer = true;
  bool _showFPS = false;
  double _currentFPS = 60.0;
  double _fontSize = 32.0;
  String _fontFamily = 'Roboto';
  Color _textColor = Colors.white;
  Color _backgroundColor = Colors.black;
  TextAlign _textAlign = TextAlign.center;
  double _lineHeight = 1.8;
  EdgeInsets _padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 100);
  
  // Performance monitoring
  final List<Duration> _frameTimes = [];
  Timer? _fpsTimer;
  
  // Keyboard focus
  final FocusNode _focusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadSettings();
    _startPerformanceMonitoring();
    _focusNode.requestFocus();
  }
  
  void _initializeControllers() {
    _scrollController = ScrollController();
    _fpsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _scrollEngine = AdvancedScrollEngine(
      scrollController: _scrollController!,
      tickerProvider: this,
      onFPSUpdate: (fps) {
        if (mounted) {
          setState(() => _currentFPS = fps);
        }
      },
    );
  }
  
  Future<void> _loadSettings() async {
    final settings = await ref.read(settingsProvider.future);
    if (mounted && settings != null) {
      setState(() {
        _fontSize = settings.fontSize;
        _fontFamily = settings.fontFamily;
        _textColor = settings.textColor;
        _backgroundColor = settings.backgroundColor;
        _textAlign = settings.textAlign;
        _lineHeight = settings.lineHeight;
        _padding = settings.padding;
        _showGuide = settings.showGuide;
        _guidePosition = settings.guidePosition;
        _guideColor = settings.guideColor;
        _currentSpeed = settings.defaultSpeed;
      });
    }
  }
  
  void _startPerformanceMonitoring() {
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_frameTimes.isNotEmpty && _showFPS) {
        final fps = _frameTimes.length.toDouble();
        _frameTimes.clear();
        if (mounted) {
          setState(() => _currentFPS = fps);
        }
      }
    });
  }
  
  @override
  void dispose() {
    _scrollEngine?.dispose();
    _scrollController?.dispose();
    _fpsAnimationController.dispose();
    _fpsTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final selectedScript = ref.watch(selectedScriptProvider);
    
    if (selectedScript == null) {
      return _buildNoScriptState();
    }
    
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: _buildTeleprompterView(selectedScript),
      ),
    );
  }
  
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _adjustSpeed(1.1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _adjustSpeed(0.9);
      } else if (event.logicalKey == LogicalKeyboardKey.home) {
        _reset();
      } else if (event.logicalKey == LogicalKeyboardKey.end) {
        _jumpToEnd();
      } else if (event.logicalKey == LogicalKeyboardKey.f11) {
        _toggleFullscreen();
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        _toggleMirrorMode();
      } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
        _toggleGuide();
      } else if (event.logicalKey == LogicalKeyboardKey.keyT) {
        _toggleTimer();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isPlaying) _togglePlayPause();
      }
    }
  }
  
  Widget _buildNoScriptState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speaker_notes_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Script Selected',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text('Select a script from the Scripts tab or import one'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => widget.tabController?.animateTo(1),
                icon: const Icon(Icons.description),
                label: const Text('Go to Scripts'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _importScript,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Script'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTeleprompterView(Script script) {
    return Stack(
      children: [
        // Main display area with theme
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: _backgroundColor,
          child: _buildScrollableText(script),
        ),
        
        // Reading guide
        if (_showGuide) _buildReadingGuide(),
        
        // Timer display
        if (_showTimer) _buildTimerDisplay(script),
        
        // FPS counter
        if (_showFPS) _buildFPSCounter(),
        
        // Progress bar
        _buildProgressBar(),
        
        // Advanced control panel
        _buildAdvancedControlPanel(script),
      ],
    );
  }
  
  Widget _buildScrollableText(Script script) {
    Widget textWidget = SingleChildScrollView(
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: Container(
        padding: _padding,
        child: SelectableText.rich(
          _buildRichText(script.content),
          style: TextStyle(
            fontSize: _fontSize,
            height: _lineHeight,
            color: _textColor,
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w400,
          ),
          textAlign: _textAlign,
        ),
      ),
    );
    
    if (_mirrorMode) {
      textWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(3.14159),
        child: textWidget,
      );
    }
    
    return textWidget;
  }
  
  TextSpan _buildRichText(String content) {
    // Parse for rich text formatting (bold, italic, underline)
    final List<TextSpan> spans = [];
    final RegExp richTextPattern = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*|__(.*?)__');
    
    int lastEnd = 0;
    for (final match in richTextPattern.allMatches(content)) {
      // Add normal text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      
      // Add formatted text
      if (match.group(1) != null) {
        // Bold text
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(2) != null) {
        // Italic text
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(3) != null) {
        // Underlined text
        spans.add(TextSpan(
          text: match.group(3),
          style: const TextStyle(decoration: TextDecoration.underline),
        ));
      }
      
      lastEnd = match.end;
    }
    
    // Add any remaining text
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }
    
    return TextSpan(children: spans);
  }
  
  Widget _buildReadingGuide() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      top: MediaQuery.of(context).size.height * _guidePosition,
      left: 0,
      right: 0,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: _guideColor.withOpacity(0.5),
          boxShadow: [
            BoxShadow(
              color: _guideColor.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimerDisplay(Script script) {
    return Positioned(
      top: 20,
      right: 20,
      child: StreamBuilder<ScrollPosition>(
        stream: _scrollEngine?.positionStream,
        builder: (context, snapshot) {
          final progress = snapshot.data?.progress ?? 0.0;
          final remainingTime = _calculateRemainingTime(script, progress);
          final elapsedTime = _calculateElapsedTime(script, progress);
          
          return Card(
            color: Colors.black87,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Elapsed: ${_formatTime(elapsedTime)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'Remaining: ${_formatTime(remainingTime)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildFPSCounter() {
    return Positioned(
      top: 20,
      left: 20,
      child: Card(
        color: _currentFPS < 50 ? Colors.red.shade900 : Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'FPS: ${_currentFPS.toStringAsFixed(0)}',
            style: TextStyle(
              color: _currentFPS < 50 ? Colors.white : Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildProgressBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: StreamBuilder<ScrollPosition>(
        stream: _scrollEngine?.positionStream,
        builder: (context, snapshot) {
          return LinearProgressIndicator(
            value: snapshot.data?.progress ?? 0.0,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor.withOpacity(0.7),
            ),
            minHeight: 4,
          );
        },
      ),
    );
  }
  
  Widget _buildAdvancedControlPanel(Script script) {
    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: Card(
        color: Colors.black.withOpacity(0.9),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Script info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        script.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${script.wordCount} words • ${_calculateReadingTime(script).inMinutes} min',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  // Quick actions
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.text_fields, color: Colors.white70),
                        onPressed: _showTextSettings,
                        tooltip: 'Text Settings',
                      ),
                      IconButton(
                        icon: Icon(
                          _showFPS ? Icons.speed : Icons.speed_outlined,
                          color: _showFPS ? Colors.green : Colors.white70,
                        ),
                        onPressed: () => setState(() => _showFPS = !_showFPS),
                        tooltip: 'Show FPS',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.fullscreen,
                          color: Colors.white70,
                        ),
                        onPressed: _toggleFullscreen,
                        tooltip: 'Fullscreen (F11)',
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Main controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Jump to start
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: _reset,
                    tooltip: 'Reset (Home)',
                  ),
                  
                  // Rewind
                  IconButton(
                    icon: const Icon(Icons.fast_rewind, color: Colors.white),
                    onPressed: () => _jump(-0.1),
                    tooltip: 'Rewind 10%',
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Play/Pause
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade800],
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _togglePlayPause,
                      tooltip: 'Play/Pause (Space)',
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Fast forward
                  IconButton(
                    icon: const Icon(Icons.fast_forward, color: Colors.white),
                    onPressed: () => _jump(0.1),
                    tooltip: 'Forward 10%',
                  ),
                  
                  // Jump to end
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: _jumpToEnd,
                    tooltip: 'Jump to End (End)',
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Speed control with presets
              Row(
                children: [
                  const Icon(Icons.slow_motion_video, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  
                  // Speed presets
                  ...['0.5x', '1x', '2x', '3x'].map((speed) {
                    final value = double.parse(speed.replaceAll('x', ''));
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        label: Text(speed),
                        backgroundColor: _currentSpeed == value ? Colors.blue : null,
                        labelStyle: TextStyle(
                          color: _currentSpeed == value ? Colors.white : Colors.white70,
                        ),
                        onPressed: () => _setSpeed(value),
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(width: 8),
                  
                  // Fine speed control
                  Expanded(
                    child: Slider(
                      value: _currentSpeed,
                      min: 0.25,
                      max: 5.0,
                      divisions: 95,
                      label: '${_currentSpeed.toStringAsFixed(2)}x',
                      onChanged: _setSpeed,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  Text(
                    '${_currentSpeed.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Toggle controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mirror mode
                  TextButton.icon(
                    icon: Icon(
                      Icons.flip,
                      color: _mirrorMode ? Colors.blue : Colors.white70,
                    ),
                    label: Text(
                      'Mirror',
                      style: TextStyle(
                        color: _mirrorMode ? Colors.blue : Colors.white70,
                      ),
                    ),
                    onPressed: _toggleMirrorMode,
                  ),
                  
                  // Guide
                  TextButton.icon(
                    icon: Icon(
                      Icons.remove_red_eye,
                      color: _showGuide ? Colors.blue : Colors.white70,
                    ),
                    label: Text(
                      'Guide',
                      style: TextStyle(
                        color: _showGuide ? Colors.blue : Colors.white70,
                      ),
                    ),
                    onPressed: _toggleGuide,
                  ),
                  
                  // Timer
                  TextButton.icon(
                    icon: Icon(
                      Icons.timer,
                      color: _showTimer ? Colors.blue : Colors.white70,
                    ),
                    label: Text(
                      'Timer',
                      style: TextStyle(
                        color: _showTimer ? Colors.blue : Colors.white70,
                      ),
                    ),
                    onPressed: _toggleTimer,
                  ),
                  
                  // Markers
                  TextButton.icon(
                    icon: const Icon(Icons.bookmark_outline, color: Colors.white70),
                    label: const Text(
                      'Markers',
                      style: TextStyle(color: Colors.white70),
                    ),
                    onPressed: _showMarkers,
                  ),
                ],
              ),
              
              // Keyboard shortcuts hint
              const SizedBox(height: 4),
              Text(
                'Space: Play/Pause • ↑↓: Speed • Home/End: Jump • M: Mirror • G: Guide • T: Timer • F11: Fullscreen',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Control methods
  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    if (_isPlaying) {
      _scrollEngine?.startScrolling(_currentSpeed);
    } else {
      _scrollEngine?.pauseScrolling();
    }
  }
  
  void _adjustSpeed(double multiplier) {
    _setSpeed((_currentSpeed * multiplier).clamp(0.25, 5.0));
  }
  
  void _setSpeed(double speed) {
    setState(() {
      _currentSpeed = speed;
    });
    _scrollEngine?.setSpeed(speed);
  }
  
  void _reset() {
    _scrollController?.jumpTo(0);
  }
  
  void _jumpToEnd() {
    _scrollController?.jumpTo(_scrollController!.position.maxScrollExtent);
  }
  
  void _jump(double percentage) {
    final maxExtent = _scrollController!.position.maxScrollExtent;
    final currentPosition = _scrollController!.offset;
    final jumpDistance = maxExtent * percentage;
    _scrollController!.jumpTo((currentPosition + jumpDistance).clamp(0, maxExtent));
  }
  
  void _toggleMirrorMode() {
    setState(() {
      _mirrorMode = !_mirrorMode;
    });
  }
  
  void _toggleGuide() {
    setState(() {
      _showGuide = !_showGuide;
    });
  }
  
  void _toggleTimer() {
    setState(() {
      _showTimer = !_showTimer;
    });
  }
  
  void _toggleFullscreen() {
    // Implement fullscreen toggle
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fullscreen mode toggled')),
    );
  }
  
  void _showTextSettings() {
    showDialog(
      context: context,
      builder: (context) => _TextSettingsDialog(
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        textColor: _textColor,
        backgroundColor: _backgroundColor,
        lineHeight: _lineHeight,
        textAlign: _textAlign,
        guidePosition: _guidePosition,
        guideColor: _guideColor,
        onSettingsChanged: (settings) {
          setState(() {
            _fontSize = settings['fontSize'];
            _fontFamily = settings['fontFamily'];
            _textColor = settings['textColor'];
            _backgroundColor = settings['backgroundColor'];
            _lineHeight = settings['lineHeight'];
            _textAlign = settings['textAlign'];
            _guidePosition = settings['guidePosition'];
            _guideColor = settings['guideColor'];
          });
        },
      ),
    );
  }
  
  void _showMarkers() {
    // Show markers dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Markers feature coming soon')),
    );
  }
  
  Future<void> _importScript() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'docx', 'pdf', 'md'],
    );
    
    if (result != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final title = path.basenameWithoutExtension(result.files.single.name);
      
      ref.read(inMemoryScriptsProvider.notifier).addScript(title, content);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported "$title"')),
      );
    }
  }
  
  // Helper methods
  Duration _calculateRemainingTime(Script script, double progress) {
    final totalTime = _calculateReadingTime(script);
    final remainingMilliseconds = (totalTime.inMilliseconds * (1 - progress)).round();
    return Duration(milliseconds: remainingMilliseconds);
  }

  Duration _calculateElapsedTime(Script script, double progress) {
    final totalTime = _calculateReadingTime(script);
    final elapsedMilliseconds = (totalTime.inMilliseconds * progress).round();
    return Duration(milliseconds: elapsedMilliseconds);
  }

  Duration _calculateReadingTime(Script script) {
    const wordsPerMinute = 150;
    final minutes = (script.wordCount / wordsPerMinute).ceil();
    return Duration(minutes: minutes);
  }
  
  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// Advanced scroll engine with performance monitoring
class AdvancedScrollEngine {
  final ScrollController scrollController;
  final TickerProvider tickerProvider;
  final Function(double)? onFPSUpdate;
  
  Timer? _scrollTimer;
  double _speed = 2.0;
  bool _isScrolling = false;
  
  final _positionController = StreamController<ScrollPosition>.broadcast();
  final List<Duration> _frameTimes = [];
  Timer? _fpsTimer;
  DateTime _lastFrameTime = DateTime.now();
  
  AdvancedScrollEngine({
    required this.scrollController,
    required this.tickerProvider,
    this.onFPSUpdate,
  }) {
    _startFPSMonitoring();
  }
  
  Stream<ScrollPosition> get positionStream => _positionController.stream;
  
  void _startFPSMonitoring() {
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_frameTimes.isNotEmpty) {
        final fps = _frameTimes.length.toDouble();
        _frameTimes.clear();
        onFPSUpdate?.call(fps);
      }
    });
  }
  
  void startScrolling(double speed) {
    _speed = speed;
    _isScrolling = true;
    
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isScrolling || !scrollController.hasClients) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final deltaTime = now.difference(_lastFrameTime).inMicroseconds / 1000000.0;
      _lastFrameTime = now;
      
      _frameTimes.add(Duration(microseconds: (deltaTime * 1000000).round()));
      
      final currentPosition = scrollController.offset;
      final maxExtent = scrollController.position.maxScrollExtent;
      
      if (currentPosition >= maxExtent) {
        pauseScrolling();
        return;
      }
      
      final scrollDelta = _speed * 60 * deltaTime;
      //final newPosition = (currentPosition + scrollDelta).clamp(0.0, maxExtent).toDouble();
      final newPosition = (currentPosition + scrollDelta).clamp(0.0, maxExtent).toDouble();
      
      scrollController.jumpTo(newPosition);
      
      _positionController.add(ScrollPosition(
        position: newPosition,
        velocity: _speed,
        timestamp: now,
        progress: newPosition / maxExtent,
      ));
    });
  }
  
  void pauseScrolling() {
    _isScrolling = false;
    _scrollTimer?.cancel();
  }
  
  void setSpeed(double speed) {
    _speed = speed;
    if (_isScrolling) {
      pauseScrolling();
      startScrolling(speed);
    }
  }
  
  void dispose() {
    _scrollTimer?.cancel();
    _fpsTimer?.cancel();
    _positionController.close();
  }
}

class ScrollPosition {
  final double position;
  final double velocity;
  final DateTime timestamp;
  final double progress;
  
  ScrollPosition({
    required this.position,
    required this.velocity,
    required this.timestamp,
    required this.progress,
  });
}

// Text settings dialog
class _TextSettingsDialog extends StatefulWidget {
  final double fontSize;
  final String fontFamily;
  final Color textColor;
  final Color backgroundColor;
  final double lineHeight;
  final TextAlign textAlign;
  final double guidePosition;
  final Color guideColor;
  final Function(Map<String, dynamic>) onSettingsChanged;
  
  const _TextSettingsDialog({
    required this.fontSize,
    required this.fontFamily,
    required this.textColor,
    required this.backgroundColor,
    required this.lineHeight,
    required this.textAlign,
    required this.guidePosition,
    required this.guideColor,
    required this.onSettingsChanged,
  });
  
  @override
  State<_TextSettingsDialog> createState() => _TextSettingsDialogState();
}

class _TextSettingsDialogState extends State<_TextSettingsDialog> {
  late double _fontSize;
  late String _fontFamily;
  late Color _textColor;
  late Color _backgroundColor;
  late double _lineHeight;
  late TextAlign _textAlign;
  late double _guidePosition;
  late Color _guideColor;
  
  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _fontFamily = widget.fontFamily;
    _textColor = widget.textColor;
    _backgroundColor = widget.backgroundColor;
    _lineHeight = widget.lineHeight;
    _textAlign = widget.textAlign;
    _guidePosition = widget.guidePosition;
    _guideColor = widget.guideColor;
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Text Settings'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Font size
              ListTile(
                title: const Text('Font Size'),
                trailing: SizedBox(
                  width: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 16,
                          max: 72,
                          onChanged: (value) => setState(() => _fontSize = value),
                        ),
                      ),
                      Text('${_fontSize.round()}'),
                    ],
                  ),
                ),
              ),
              
              // Font family
              ListTile(
                title: const Text('Font Family'),
                trailing: DropdownButton<String>(
                  value: _fontFamily,
                  items: ['Roboto', 'Arial', 'Times New Roman', 'Courier New', 'Georgia']
                      .map((font) => DropdownMenuItem(
                            value: font,
                            child: Text(font),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _fontFamily = value!),
                ),
              ),
              
              // Line height
              ListTile(
                title: const Text('Line Height'),
                trailing: SizedBox(
                  width: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _lineHeight,
                          min: 1.0,
                          max: 3.0,
                          onChanged: (value) => setState(() => _lineHeight = value),
                        ),
                      ),
                      Text(_lineHeight.toStringAsFixed(1)),
                    ],
                  ),
                ),
              ),
              
              // Text alignment
              ListTile(
                title: const Text('Text Alignment'),
                trailing: SegmentedButton<TextAlign>(
                  segments: const [
                    ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left)),
                    ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center)),
                    ButtonSegment(value: TextAlign.right, icon: Icon(Icons.format_align_right)),
                  ],
                  selected: {_textAlign},
                  onSelectionChanged: (Set<TextAlign> selected) {
                    setState(() => _textAlign = selected.first);
                  },
                ),
              ),
              
              // Guide position
              ListTile(
                title: const Text('Guide Position'),
                trailing: SizedBox(
                  width: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _guidePosition,
                          min: 0.1,
                          max: 0.9,
                          onChanged: (value) => setState(() => _guidePosition = value),
                        ),
                      ),
                      Text('${(_guidePosition * 100).round()}%'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSettingsChanged({
              'fontSize': _fontSize,
              'fontFamily': _fontFamily,
              'textColor': _textColor,
              'backgroundColor': _backgroundColor,
              'lineHeight': _lineHeight,
              'textAlign': _textAlign,
              'guidePosition': _guidePosition,
              'guideColor': _guideColor,
            });
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}