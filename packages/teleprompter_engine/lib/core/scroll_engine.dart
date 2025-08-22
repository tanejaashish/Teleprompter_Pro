// packages/teleprompter_engine/lib/core/scroll_engine.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum ScrollSpeed {
  verySlow(0.5),
  slow(1.0),
  medium(2.0),
  fast(3.0),
  veryFast(4.0);

  final double value;
  const ScrollSpeed(this.value);
}

class ScrollPosition {
  final double position;
  final double velocity;
  final DateTime timestamp;
  final double progress; // 0.0 to 1.0

  ScrollPosition({
    required this.position,
    required this.velocity,
    required this.timestamp,
    required this.progress,
  });
}

abstract class ScrollEngine {
  Stream<ScrollPosition> get positionStream;
  Stream<double> get speedStream;
  double get maxScrollExtent;
  double get currentPosition;
  bool get isScrolling;
  
  void startScrolling(ScrollSpeed speed);
  void pauseScrolling();
  void resumeScrolling();
  void adjustSpeed(double multiplier);
  void jumpToPosition(double position);
  void reset();
  void dispose();
}

class SmoothScrollEngine implements ScrollEngine {
  final ScrollController scrollController;
  final TickerProvider tickerProvider;
  
  late AnimationController _animationController;
  Timer? _scrollTimer;
  
  final _positionController = StreamController<ScrollPosition>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  
  double _currentSpeed = ScrollSpeed.medium.value;
  double _targetPosition = 0;
  bool _isScrolling = false;
  DateTime _lastFrameTime = DateTime.now();
  int _frameCount = 0;
  double _fps = 60.0;
  
  // Performance monitoring
  final List<Duration> _frameTimes = [];
  Timer? _fpsTimer;

  SmoothScrollEngine({
    required this.scrollController,
    required this.tickerProvider,
  }) {
    _initializeAnimationController();
    _startFPSMonitoring();
  }

  void _initializeAnimationController() {
    _animationController = AnimationController(
      vsync: tickerProvider,
      duration: const Duration(seconds: 1),
    );
  }

  void _startFPSMonitoring() {
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_frameTimes.isNotEmpty) {
        _fps = _frameTimes.length.toDouble();
        _frameTimes.clear();
        
        // Emit performance metrics
        debugPrint('Teleprompter FPS: $_fps');
      }
    });
  }

  @override
  Stream<ScrollPosition> get positionStream => _positionController.stream;

  @override
  Stream<double> get speedStream => _speedController.stream;

  @override
  double get maxScrollExtent => scrollController.position.maxScrollExtent;

  @override
  double get currentPosition => scrollController.offset;

  @override
  bool get isScrolling => _isScrolling;

  @override
  void startScrolling(ScrollSpeed speed) {
    if (_isScrolling) return;
    
    _currentSpeed = speed.value;
    _isScrolling = true;
    _speedController.add(_currentSpeed);
    
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), _performScroll); // 60 FPS target
  }

  void _performScroll(Timer timer) {
    if (!_isScrolling || !scrollController.hasClients) {
      timer.cancel();
      return;
    }

    final now = DateTime.now();
    final deltaTime = now.difference(_lastFrameTime).inMicroseconds / 1000000.0;
    _lastFrameTime = now;
    
    // Track frame time for FPS calculation
    _frameTimes.add(Duration(microseconds: (deltaTime * 1000000).round()));
    
    // Calculate smooth scroll delta
    final scrollDelta = _currentSpeed * 60 * deltaTime; // pixels per frame
    
    final newPosition = (scrollController.offset + scrollDelta)
        .clamp(0.0, scrollController.position.maxScrollExtent);
    
    // Use jumpTo for immediate positioning (smoother than animateTo for continuous scrolling)
    scrollController.jumpTo(newPosition);
    
    // Emit position update
    _positionController.add(ScrollPosition(
      position: newPosition,
      velocity: _currentSpeed,
      timestamp: now,
      progress: newPosition / scrollController.position.maxScrollExtent,
    ));
    
    // Stop at end
    if (newPosition >= scrollController.position.maxScrollExtent) {
      pauseScrolling();
    }
  }

  @override
  void pauseScrolling() {
    _isScrolling = false;
    _scrollTimer?.cancel();
    _speedController.add(0);
  }

  @override
  void resumeScrolling() {
    if (!_isScrolling && _currentSpeed > 0) {
      startScrolling(ScrollSpeed.values.firstWhere(
        (s) => s.value == _currentSpeed,
        orElse: () => ScrollSpeed.medium,
      ));
    }
  }

  @override
  void adjustSpeed(double multiplier) {
    _currentSpeed = (_currentSpeed * multiplier).clamp(0.1, 10.0);
    _speedController.add(_currentSpeed);
  }

  @override
  void jumpToPosition(double position) {
    final clampedPosition = position.clamp(0.0, scrollController.position.maxScrollExtent);
    scrollController.jumpTo(clampedPosition);
    
    _positionController.add(ScrollPosition(
      position: clampedPosition,
      velocity: _currentSpeed,
      timestamp: DateTime.now(),
      progress: clampedPosition / scrollController.position.maxScrollExtent,
    ));
  }

  @override
  void reset() {
    pauseScrolling();
    jumpToPosition(0);
    _currentSpeed = ScrollSpeed.medium.value;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _fpsTimer?.cancel();
    _positionController.close();
    _speedController.close();
    _animationController.dispose();
  }
}

// Advanced scroll algorithms for Phase 5
enum ScrollAlgorithm {
  linear,
  ease,
  bezier,
  adaptive, // Adjusts based on content density
}

class AdvancedScrollEngine extends SmoothScrollEngine {
  ScrollAlgorithm _algorithm = ScrollAlgorithm.linear;
  
  // Predictive rendering for 120Hz+ displays
  final int lookaheadFrames;
  final List<double> _predictedPositions = [];
  
  AdvancedScrollEngine({
    required super.scrollController,
    required super.tickerProvider,
    this.lookaheadFrames = 3,
  });
  
  void setScrollAlgorithm(ScrollAlgorithm algorithm) {
    _algorithm = algorithm;
  }
  
  void enablePredictiveRendering() {
    // Calculate future positions for smoother high-refresh rendering
    _predictedPositions.clear();
    
    for (int i = 1; i <= lookaheadFrames; i++) {
      final futureTime = i * (1000 / 120); // Assume 120Hz
      final predictedDelta = _currentSpeed * futureTime / 1000;
      _predictedPositions.add(currentPosition + predictedDelta);
    }
  }
  
  @override
  void adjustSpeed(double multiplier) {
    if (_algorithm == ScrollAlgorithm.bezier) {
      // Smooth bezier curve transition
      _animateSpeedChange(_currentSpeed, _currentSpeed * multiplier);
    } else {
      super.adjustSpeed(multiplier);
    }
  }
  
  void _animateSpeedChange(double from, double to) {
    final animation = Tween<double>(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    
    animation.addListener(() {
      _currentSpeed = animation.value;
      _speedController.add(_currentSpeed);
    });
    
    _animationController.forward(from: 0);
  }
}