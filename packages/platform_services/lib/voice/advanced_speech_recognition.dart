import 'dart:async';
import 'dart:collection';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class AdvancedSpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  final _transcriptionController = StreamController<TranscriptionResult>.broadcast();
  final _confidenceController = StreamController<double>.broadcast();
  
  // Language models for better accuracy
  final Map<String, LanguageModel> _languageModels = {};
  final Queue<String> _transcriptionBuffer = Queue();
  
  // Noise cancellation
  NoiseSuppressionEngine? _noiseSuppressor;
  
  // Multi-language support
  List<LocaleName> _availableLocales = [];
  String _currentLocale = 'en_US';
  
  // Advanced configuration
  SpeechConfig _config = SpeechConfig();
  
  Stream<TranscriptionResult> get transcriptionStream => _transcriptionController.stream;
  Stream<double> get confidenceStream => _confidenceController.stream;
  
  Future<bool> initialize({SpeechConfig? config}) async {
    if (config != null) _config = config;
    
    // Request permissions
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw MicrophonePermissionException('Microphone permission denied');
    }
    
    // Initialize speech recognition
    final initialized = await _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
      debugLogging: _config.debugMode,
      finalTimeout: Duration(seconds: _config.finalTimeout),
    );
    
    if (initialized) {
      // Load available languages
      _availableLocales = await _speech.locales();
      
      // Initialize noise suppression if enabled
      if (_config.enableNoiseSuppression) {
        _noiseSuppressor = NoiseSuppressionEngine();
        await _noiseSuppressor!.initialize();
      }
      
      // Load language models
      await _loadLanguageModels();
    }
    
    return initialized;
  }
  
  Future<void> startContinuousListening({
    required Function(TranscriptionResult) onResult,
    String? locale,
    ScriptContext? context,
  }) async {
    if (!_speech.isAvailable) await initialize();
    
    _currentLocale = locale ?? _currentLocale;
    
    // Configure recognition based on context
    if (context != null) {
      await _configureForContext(context);
    }
    
    // Start continuous listening with auto-restart
    await _startListeningWithAutoRestart(onResult);
  }
  
  Future<void> _startListeningWithAutoRestart(
    Function(TranscriptionResult) onResult,
  ) async {
    await _speech.listen(
      onResult: (result) => _processResult(result, onResult),
      listenFor: Duration(seconds: _config.listenDuration),
      pauseFor: Duration(seconds: _config.pauseDuration),
      partialResults: true,
      onDevice: _config.onDeviceRecognition,
      listenMode: ListenMode.dictation,
      localeId: _currentLocale,
    );
    
    // Auto-restart when listening stops
    _speech.statusListener = (status) {
      if (status == 'notListening' && _config.autoRestart) {
        Future.delayed(Duration(milliseconds: 100), () {
          _startListeningWithAutoRestart(onResult);
        });
      }
    };
  }
  
  void _processResult(
    SpeechRecognitionResult result,
    Function(TranscriptionResult) onResult,
  ) {
    // Apply noise suppression
    final cleanedText = _noiseSuppressor?.process(result.recognizedWords) 
                       ?? result.recognizedWords;
    
    // Buffer management for smoother output
    _transcriptionBuffer.add(cleanedText);
    if (_transcriptionBuffer.length > _config.bufferSize) {
      _transcriptionBuffer.removeFirst();
    }
    
    // Calculate confidence with language model
    final confidence = _calculateEnhancedConfidence(
      result.confidence,
      cleanedText,
    );
    
    _confidenceController.add(confidence);
    
    // Create enhanced result
    final enhancedResult = TranscriptionResult(
      text: cleanedText,
      confidence: confidence,
      isFinal: result.finalResult,
      alternatives: result.alternates?.map((a) => a.recognizedWords).toList() ?? [],
      timestamp: DateTime.now(),
      locale: _currentLocale,
    );
    
    _transcriptionController.add(enhancedResult);
    onResult(enhancedResult);
  }
  
  double _calculateEnhancedConfidence(double baseConfidence, String text) {
    // Use language model to improve confidence calculation
    final model = _languageModels[_currentLocale];
    if (model == null) return baseConfidence;
    
    final grammarScore = model.calculateGrammarScore(text);
    final contextScore = model.calculateContextScore(text, _transcriptionBuffer.toList());
    
    // Weighted average
    return (baseConfidence * 0.5 + grammarScore * 0.3 + contextScore * 0.2)
           .clamp(0.0, 1.0);
  }
  
  Future<void> _loadLanguageModels() async {
    // Load pre-trained language models for supported languages
    for (final locale in _availableLocales) {
      try {
        final modelPath = 'assets/models/language/${locale.localeId}.tflite';
        _languageModels[locale.localeId] = await LanguageModel.load(modelPath);
      } catch (e) {
        print('Failed to load model for ${locale.localeId}: $e');
      }
    }
  }
  
  Future<void> _configureForContext(ScriptContext context) async {
    // Adjust recognition parameters based on script context
    if (context.technicalContent) {
      // Load technical vocabulary
      await _speech.addVocabulary(context.technicalTerms);
    }
    
    if (context.scriptLanguage != null) {
      _currentLocale = context.scriptLanguage!;
    }
    
    // Adjust sensitivity based on environment
    if (context.noisyEnvironment) {
      _config.sensitivity = 0.3; // Less sensitive in noisy environments
    }
  }
  
  void dispose() {
    _transcriptionController.close();
    _confidenceController.close();
    _noiseSuppressor?.dispose();
    _speech.stop();
  }
}

class SpeechConfig {
  bool debugMode = false;
  bool enableNoiseSuppression = true;
  bool autoRestart = true;
  bool onDeviceRecognition = true;
  int listenDuration = 30;
  int pauseDuration = 3;
  int finalTimeout = 5;
  int bufferSize = 10;
  double sensitivity = 0.5;
}

class TranscriptionResult {
  final String text;
  final double confidence;
  final bool isFinal;
  final List<String> alternatives;
  final DateTime timestamp;
  final String locale;
  
  TranscriptionResult({
    required this.text,
    required this.confidence,
    required this.isFinal,
    required this.alternatives,
    required this.timestamp,
    required this.locale,
  });
}