// packages/ui_kit/lib/organisms/teleprompter_display.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class TeleprompterDisplay extends StatefulWidget {
  final Script script;
  final ScrollController scrollController;
  final TeleprompterSettings settings;
  final ScrollEngine scrollEngine;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onFullscreenToggle;

  const TeleprompterDisplay({
    Key? key,
    required this.script,
    required this.scrollController,
    required this.settings,
    required this.scrollEngine,
    this.onSettingsPressed,
    this.onFullscreenToggle,
  }) : super(key: key);

  @override
  State<TeleprompterDisplay> createState() => _TeleprompterDisplayState();
}

class _TeleprompterDisplayState extends State<TeleprompterDisplay> {
  bool _showControls = true;
  bool _isFullscreen = false;
  double _currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _setupKeyboardShortcuts();
    _listenToScrollPosition();
  }

  void _setupKeyboardShortcuts() {
    // Keyboard shortcuts will be handled by RawKeyboardListener
  }

  void _listenToScrollPosition() {
    widget.scrollEngine.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentProgress = position.progress;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _showControls = true),
        onExit: (_) {
          if (widget.scrollEngine.isScrolling) {
            setState(() => _showControls = false);
          }
        },
        child: Container(
          color: widget.settings.backgroundColor,
          child: Stack(
            children: [
              // Main text display
              _buildTextDisplay(),
              
              // Reading guide
              if (widget.settings.showGuide) _buildReadingGuide(),
              
              // Progress indicator
              _buildProgressIndicator(),
              
              // Control overlay
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _showControls ? _buildControlOverlay() : const SizedBox(),
              ),
              
              // Countdown timer (if enabled)
              if (widget.settings.showTimer) _buildCountdownTimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextDisplay() {
    Widget textWidget = SingleChildScrollView(
      controller: widget.scrollController,
      physics: const NeverScrollableScrollPhysics(), // Controlled by engine
      child: Padding(
        padding: widget.settings.padding,
        child: SelectableText(
          widget.script.content,
          style: widget.settings.textStyle,
          textAlign: widget.settings.textAlign,
        ),
      ),
    );

    // Apply mirror mode if enabled
    if (widget.settings.mirrorMode) {
      textWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: textWidget,
      );
    }

    return textWidget;
  }

  Widget _buildReadingGuide() {
    return Positioned(
      top: MediaQuery.of(context).size.height * widget.settings.guidePosition,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        color: widget.settings.guideColor.withOpacity(0.7),
        child: Center(
          child: Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: widget.settings.guideColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: widget.settings.guideColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(
        value: _currentProgress,
        backgroundColor: Colors.grey.withOpacity(0.2),
        valueColor: AlwaysStoppedAnimation<Color>(
          Theme.of(context).primaryColor.withOpacity(0.7),
        ),
        minHeight: 3,
      ),
    );
  }

  Widget _buildControlOverlay() {
    return ControlPanel(
      scrollEngine: widget.scrollEngine,
      settings: widget.settings,
      script: widget.script,
      onSettingsPressed: widget.onSettingsPressed,
      onFullscreenToggle: () {
        setState(() => _isFullscreen = !_isFullscreen);
        widget.onFullscreenToggle?.call();
      },
      isFullscreen: _isFullscreen,
    );
  }

  Widget _buildCountdownTimer() {
    return Positioned(
      top: 20,
      right: 20,
      child: StreamBuilder<ScrollPosition>(
        stream: widget.scrollEngine.positionStream,
        builder: (context, snapshot) {
          final remainingTime = _calculateRemainingTime(snapshot.data?.progress ?? 0);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatTime(remainingTime),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Duration _calculateRemainingTime(double progress) {
    final totalTime = widget.script.estimatedReadTime;
    final elapsed = totalTime * progress;
    return totalTime - elapsed;
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.scrollEngine.adjustSpeed(1.1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.scrollEngine.adjustSpeed(0.9);
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      widget.scrollEngine.reset();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        setState(() => _isFullscreen = false);
        widget.onFullscreenToggle?.call();
      }
    }
  }

  void _togglePlayPause() {
    if (widget.scrollEngine.isScrolling) {
      widget.scrollEngine.pauseScrolling();
    } else {
      widget.scrollEngine.resumeScrolling();
    }
  }
}