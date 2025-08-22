// packages/ui_kit/lib/organisms/control_panel.dart

class ControlPanel extends StatefulWidget {
  final ScrollEngine scrollEngine;
  final TeleprompterSettings settings;
  final Script script;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onFullscreenToggle;
  final bool isFullscreen;

  const ControlPanel({
    Key? key,
    required this.scrollEngine,
    required this.settings,
    required this.script,
    this.onSettingsPressed,
    this.onFullscreenToggle,
    this.isFullscreen = false,
  }) : super(key: key);

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  bool _isPlaying = false;
  double _currentSpeed = 2.0;

  @override
  void initState() {
    super.initState();
    _listenToEngine();
  }

  void _listenToEngine() {
    widget.scrollEngine.speedStream.listen((speed) {
      if (mounted) {
        setState(() {
          _currentSpeed = speed;
          _isPlaying = speed > 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset button
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                  onPressed: () => widget.scrollEngine.reset(),
                  tooltip: 'Reset (Home)',
                ),
                const SizedBox(width: 16),
                
                // Play/Pause button
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor,
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
                
                // Jump forward button
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: () => _jumpForward(),
                  tooltip: 'Jump Forward',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Speed control
            Row(
              children: [
                const Icon(Icons.slow_motion_video, color: Colors.white70, size: 20),
                Expanded(
                  child: Slider(
                    value: _currentSpeed,
                    min: 0.5,
                    max: 5.0,
                    divisions: 45,
                    label: '${_currentSpeed.toStringAsFixed(1)}x',
                    onChanged: (value) {
                      setState(() => _currentSpeed = value);
                      widget.scrollEngine.adjustSpeed(value / _currentSpeed);
                    },
                  ),
                ),
                const Icon(Icons.speed, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_currentSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Bottom controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Script info
                Text(
                  '${widget.script.wordCount} words • ${_formatDuration(widget.script.estimatedReadTime)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                
                // Action buttons
                Row(
                  children: [
                    // Mirror mode toggle
                    IconButton(
                      icon: Icon(
                        Icons.flip,
                        color: widget.settings.mirrorMode ? Colors.blue : Colors.white70,
                      ),
                      onPressed: _toggleMirrorMode,
                      tooltip: 'Mirror Mode',
                    ),
                    
                    // Settings button
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: widget.onSettingsPressed,
                      tooltip: 'Settings',
                    ),
                    
                    // Fullscreen toggle
                    IconButton(
                      icon: Icon(
                        widget.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white70,
                      ),
                      onPressed: widget.onFullscreenToggle,
                      tooltip: 'Fullscreen (F11)',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.scrollEngine.pauseScrolling();
    } else {
      widget.scrollEngine.startScrolling(
        ScrollSpeed.values.firstWhere(
          (s) => s.value == _currentSpeed,
          orElse: () => ScrollSpeed.medium,
        ),
      );
    }
  }

  void _jumpForward() {
    final currentPos = widget.scrollEngine.currentPosition;
    final maxExtent = widget.scrollEngine.maxScrollExtent;
    final jumpDistance = maxExtent * 0.1; // Jump 10% forward
    widget.scrollEngine.jumpToPosition(
      (currentPos + jumpDistance).clamp(0, maxExtent),
    );
  }

  void _toggleMirrorMode() {
    // This would need to update the settings
    // For now, just showing the UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mirror mode toggled')),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Supporting classes for the UI components
class TeleprompterSettings {
  final TextStyle textStyle;
  final EdgeInsets padding;
  final TextAlign textAlign;
  final Color backgroundColor;
  final bool mirrorMode;
  final bool showGuide;
  final double guidePosition;
  final Color guideColor;
  final bool showTimer;
  final bool showControls;

  const TeleprompterSettings({
    this.textStyle = const TextStyle(fontSize: 24, color: Colors.white, height: 1.5),
    this.padding = const EdgeInsets.all(20),
    this.textAlign = TextAlign.center,
    this.backgroundColor = Colors.black,
    this.mirrorMode = false,
    this.showGuide = true,
    this.guidePosition = 0.3,
    this.guideColor = Colors.red,
    this.showTimer = false,
    this.showControls = true,
  });
}