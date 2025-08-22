import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AdvancedVoiceScrollController {
  final ScrollController scrollController;
  final TextAnalysisEngine textAnalyzer;
  final ScrollOptimizer optimizer;
  
  // Script state
  String _scriptText = '';
  List<Word> _scriptWords = [];
  int _currentWordIndex = 0;
  
  // Timing and rhythm
  double _averageReadingSpeed = 150.0; // words per minute
  DateTime? _lastWordTime;
  final Queue<double> _speedHistory = Queue();
  
  // Advanced features
  bool _adaptiveScrolling = true;
  bool _predictiveScrolling = true;
  double _lookaheadFactor = 0.35;
  
  // Smoothing
  Timer? _smoothScrollTimer;
  double _currentPosition = 0.0;
  double _targetPosition = 0.0;
  
  AdvancedVoiceScrollController({
    required this.scrollController,
    TextAnalysisEngine? textAnalyzer,
    ScrollOptimizer? optimizer,
  }) : textAnalyzer = textAnalyzer ?? TextAnalysisEngine(),
        optimizer = optimizer ?? ScrollOptimizer();
  
  void setScript(String text) {
    _scriptText = text;
    _scriptWords = _parseWords(text);
    _currentWordIndex = 0;
    _calculateReadingMetrics();
  }
  
  List<Word> _parseWords(String text) {
    final words = <Word>[];
    final pattern = RegExp(r'\S+');
    final matches = pattern.allMatches(text);
    
    for (final match in matches) {
      words.add(Word(
        text: match.group(0)!,
        startOffset: match.start,
        endOffset: match.end,
        isPunctuation: _isPunctuation(match.group(0)!),
      ));
    }
    
    return words;
  }
  
  void processTranscription(String spokenText, {double confidence = 1.0}) {
    if (_scriptWords.isEmpty) return;
    
    // Advanced matching with multiple algorithms
    final match = _findBestMatch(spokenText, confidence);
    
    if (match != null && match.confidence > 0.65) {
      _updatePosition(match);
      
      if (_adaptiveScrolling) {
        _adaptToReadingSpeed(match);
      }
      
      if (_predictiveScrolling) {
        _predictNextPosition(match);
      }
    }
  }
  
  MatchResult? _findBestMatch(String spokenText, double speechConfidence) {
    // Try multiple matching strategies
    final strategies = [
      () => _exactMatch(spokenText),
      () => _fuzzyMatch(spokenText),
      () => _phoneticMatch(spokenText),
      () => _contextualMatch(spokenText),
    ];
    
    MatchResult? bestMatch;
    double bestScore = 0.0;
    
    for (final strategy in strategies) {
      final match = strategy();
      if (match != null) {
        final adjustedScore = match.confidence * speechConfidence;
        if (adjustedScore > bestScore) {
          bestScore = adjustedScore;
          bestMatch = match;
        }
      }
    }
    
    return bestMatch;
  }
  
  MatchResult? _exactMatch(String spokenText) {
    final spokenWords = spokenText.toLowerCase().split(' ');
    final searchWindow = min(100, _scriptWords.length - _currentWordIndex);
    
    for (int i = _currentWordIndex; i < _currentWordIndex + searchWindow; i++) {
      if (i + spokenWords.length > _scriptWords.length) break;
      
      bool matches = true;
      for (int j = 0; j < spokenWords.length; j++) {
        if (_scriptWords[i + j].text.toLowerCase() != spokenWords[j]) {
          matches = false;
          break;
        }
      }
      
      if (matches) {
        return MatchResult(
          startIndex: i,
          endIndex: i + spokenWords.length,
          confidence: 1.0,
          matchType: MatchType.exact,
        );
      }
    }
    
    return null;
  }
  
  MatchResult? _fuzzyMatch(String spokenText) {
    final spokenWords = spokenText.toLowerCase().split(' ');
    final searchWindow = min(150, _scriptWords.length - _currentWordIndex);
    
    double bestScore = 0.0;
    int bestIndex = _currentWordIndex;
    
    for (int i = _currentWordIndex; i < _currentWordIndex + searchWindow; i++) {
      if (i + spokenWords.length > _scriptWords.length) break;
      
      double score = 0.0;
      for (int j = 0; j < spokenWords.length; j++) {
        score += _calculateSimilarity(
          _scriptWords[i + j].text.toLowerCase(),
          spokenWords[j],
        );
      }
      score /= spokenWords.length;
      
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    
    if (bestScore > 0.7) {
      return MatchResult(
        startIndex: bestIndex,
        endIndex: bestIndex + spokenWords.length,
        confidence: bestScore,
        matchType: MatchType.fuzzy,
      );
    }
    
    return null;
  }
  
  void _updatePosition(MatchResult match) {
    _currentWordIndex = match.endIndex;
    
    // Calculate pixel position
    final word = _scriptWords[min(match.endIndex, _scriptWords.length - 1)];
    final characterPosition = word.endOffset;
    
    // Estimate vertical position based on character offset
    final textPainter = TextPainter(
      text: TextSpan(text: _scriptText.substring(0, characterPosition)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: scrollController.position.viewportDimension);
    
    _targetPosition = textPainter.height - 
                     (scrollController.position.viewportDimension * _lookaheadFactor);
    
    _smoothScrollTo(_targetPosition);
  }
  
  void _smoothScrollTo(double position) {
    _smoothScrollTimer?.cancel();
    
    final distance = (position - _currentPosition).abs();
    final duration = _calculateScrollDuration(distance);
    
    _smoothScrollTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      final progress = timer.tick / (duration.inMilliseconds / 16);
      
      if (progress >= 1.0) {
        _currentPosition = position;
        scrollController.jumpTo(position);
        timer.cancel();
      } else {
        // Easing function for smooth animation
        final eased = _easeInOutCubic(progress);
        final newPosition = _currentPosition + (position - _currentPosition) * eased;
        scrollController.jumpTo(newPosition);
      }
    });
  }
  
  Duration _calculateScrollDuration(double distance) {
    // Dynamic duration based on distance and reading speed
    final baseDuration = 500; // milliseconds
    final speedFactor = _averageReadingSpeed / 150.0;
    final distanceFactor = min(distance / 100.0, 2.0);
    
    return Duration(
      milliseconds: (baseDuration * distanceFactor / speedFactor).round(),
    );
  }
  
  double _easeInOutCubic(double t) {
    return t < 0.5 
      ? 4 * t * t * t 
      : 1 - pow(2 - 2 * t, 3) / 2;
  }
  
  void _adaptToReadingSpeed(MatchResult match) {
    final now = DateTime.now();
    if (_lastWordTime != null) {
      final timeDiff = now.difference(_lastWordTime!).inMilliseconds / 1000.0;
      final wordsDiff = match.endIndex - match.startIndex;
      final currentSpeed = (wordsDiff / timeDiff) * 60.0; // WPM
      
      _speedHistory.add(currentSpeed);
      if (_speedHistory.length > 10) {
        _speedHistory.removeFirst();
      }
      
      // Calculate average speed
      if (_speedHistory.isNotEmpty) {
        _averageReadingSpeed = _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;
      }
      
      // Adjust lookahead based on speed
      _lookaheadFactor = 0.3 + (_averageReadingSpeed / 500.0).clamp(0.0, 0.3);
    }
    _lastWordTime = now;
  }
  
  void _predictNextPosition(MatchResult match) {
    // Predict where the reader will be in the next second
    final wordsPerSecond = _averageReadingSpeed / 60.0;
    final predictedWords = wordsPerSecond * 1.0; // 1 second ahead
    final predictedIndex = min(
      (match.endIndex + predictedWords).round(),
      _scriptWords.length - 1,
    );
    
    // Pre-render the predicted area
    optimizer.preRenderArea(
      startIndex: match.endIndex,
      endIndex: predictedIndex,
    );
  }
  
  void dispose() {
    _smoothScrollTimer?.cancel();
  }
}