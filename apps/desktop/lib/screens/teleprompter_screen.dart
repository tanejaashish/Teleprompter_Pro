// lib/screens/teleprompter_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'scripts_screen.dart'; // Import to get Script class and providers

class TeleprompterScreen extends ConsumerStatefulWidget {
  final TabController? tabController;
  
  const TeleprompterScreen({
    super.key,
    this.tabController,
  });

  @override
  ConsumerState<TeleprompterScreen> createState() => _TeleprompterScreenState();
}

class _TeleprompterScreenState extends ConsumerState<TeleprompterScreen> 
    with TickerProviderStateMixin {
  ScrollController? _scrollController;
  SimpleScrollEngine? _scrollEngine;
  bool _isPlaying = false;
  double _currentSpeed = 2.0;
  bool _mirrorMode = false;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollEngine = SimpleScrollEngine(
      scrollController: _scrollController!,
      tickerProvider: this,
    );
  }

  @override
  void dispose() {
    _scrollEngine?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedScript = ref.watch(selectedScriptProvider);
    
    if (selectedScript == null) {
      return _buildNoScriptState();
    }
    
    return _buildTeleprompterView(selectedScript);
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
          const Text('Select a script from the Scripts tab to begin'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              // Navigate to scripts tab
              widget.tabController?.animateTo(1);
            },
            child: const Text('Go to Scripts'),
          ),
        ],
      ),
    );
  }

  Widget _buildTeleprompterView(Script script) {
    return Stack(
      children: [
        // Main display area
        Container(
          color: Colors.black,
          child: Transform(
            alignment: Alignment.center,
            transform: _mirrorMode ? Matrix4.rotationY(3.14159) : Matrix4.identity(),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const NeverScrollableScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
                child: SelectableText(
                  script.content,
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.8,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        
        // Reading guide
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            color: Colors.red.withOpacity(0.5),
          ),
        ),
        
        // Control panel
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Card(
            color: Colors.black87,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Script info
                  Text(
                    script.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${script.wordCount} words',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  
                  // Play controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white),
                        onPressed: () {
                          _scrollController?.jumpTo(0);
                        },
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          Icons.flip,
                          color: _mirrorMode ? Colors.blue : Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _mirrorMode = !_mirrorMode;
                          });
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Speed control
                  Row(
                    children: [
                      const Icon(Icons.slow_motion_video, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          value: _currentSpeed,
                          min: 0.5,
                          max: 5.0,
                          divisions: 45,
                          label: '${_currentSpeed.toStringAsFixed(1)}x',
                          onChanged: (value) {
                            setState(() {
                              _currentSpeed = value;
                            });
                            _scrollEngine?.setSpeed(value);
                          },
                        ),
                      ),
                      const Icon(Icons.speed, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentSpeed.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

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
}

// Simple scroll engine for immediate use
class SimpleScrollEngine {
  final ScrollController scrollController;
  final TickerProvider tickerProvider;
  
  Timer? _scrollTimer;
  double _speed = 2.0;
  bool _isScrolling = false;

  SimpleScrollEngine({
    required this.scrollController,
    required this.tickerProvider,
  });

  void startScrolling(double speed) {
    _speed = speed;
    _isScrolling = true;
    
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_isScrolling || !scrollController.hasClients) {
        timer.cancel();
        return;
      }
      
      final currentPosition = scrollController.offset;
      final maxExtent = scrollController.position.maxScrollExtent;
      
      if (currentPosition >= maxExtent) {
        pauseScrolling();
        return;
      }
      
      scrollController.jumpTo(
        (currentPosition + _speed).clamp(0, maxExtent),
      );
    });
  }

  void pauseScrolling() {
    _isScrolling = false;
    _scrollTimer?.cancel();
  }

  void setSpeed(double speed) {
    _speed = speed;
  }

  void dispose() {
    _scrollTimer?.cancel();
  }
}