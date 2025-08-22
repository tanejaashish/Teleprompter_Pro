import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:fft/fft.dart';

class RealtimeVoiceAnalyzer {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final StreamController<VoiceAnalysisResult> _analysisController = 
      StreamController<VoiceAnalysisResult>.broadcast();
  
  // ML Models
  late Interpreter _pitchModel;
  late Interpreter _emotionModel;
  late Interpreter _qualityModel;
  
  // Analysis buffers
  final List<double> _pitchBuffer = [];
  final List<double> _volumeBuffer = [];
  final List<double> _toneBuffer = [];
  
  // Configuration
  final AnalysisConfig config;
  Timer? _analysisTimer;
  bool _isAnalyzing = false;
  
  Stream<VoiceAnalysisResult> get analysisStream => _analysisController.stream;
  
  RealtimeVoiceAnalyzer({AnalysisConfig? config}) 
      : config = config ?? AnalysisConfig.professional();
  
  Future<void> initialize() async {
    await _recorder.openRecorder();
    await _loadModels();
    
    // Set up audio stream processing
    await _recorder.setSubscriptionDuration(
      Duration(milliseconds: config.analysisInterval),
    );
  }
  
  Future<void> startRealtimeAnalysis() async {
    _isAnalyzing = true;
    
    // Start recording with stream
    final stream = await _recorder.startRecorder(
      toStream: _processAudioStream,
      codec: Codec.pcm16,
      sampleRate: 44100,
      numChannels: 1,
    );
    
    // Start periodic analysis
    _analysisTimer = Timer.periodic(
      Duration(milliseconds: config.feedbackInterval), 
      (_) => _performAnalysis(),
    );
  }
  
  StreamSink<Food> get _processAudioStream {
    return StreamSink<Food>(
      onData: (Food food) async {
        if (food is FoodData) {
          final audioData = food.data!;
          await _analyzeAudioChunk(audioData);
        }
      },
    );
  }
  
  Future<void> _analyzeAudioChunk(Uint8List audioData) async {
    // Convert to float samples
    final samples = _convertToSamples(audioData);
    
    // Extract features
    final features = AudioFeatures(
      pitch: await _extractPitch(samples),
      volume: _calculateVolume(samples),
      tone: await _analyzeTone(samples),
      clarity: _calculateClarity(samples),
      pace: _calculatePace(samples),
      energy: _calculateEnergy(samples),
    );
    
    // Run ML inference
    final emotionalState = await _detectEmotion(features);
    final voiceQuality = await _assessVoiceQuality(features);
    final speakingStyle = await _analyzeSpeakingStyle(features);
    
    // Generate feedback
    final feedback = _generateFeedback(features, emotionalState, voiceQuality);
    
    // Emit analysis result
    _analysisController.add(VoiceAnalysisResult(
      timestamp: DateTime.now(),
      pitch: features.pitch,
      volume: features.volume,
      tone: features.tone,
      clarity: features.clarity,
      pace: features.pace,
      emotion: emotionalState,
      quality: voiceQuality,
      style: speakingStyle,
      feedback: feedback,
      suggestions: _generateSuggestions(features),
      score: _calculateOverallScore(features, voiceQuality),
    ));
  }
  
  Future<double> _extractPitch(Float32List samples) async {
    // Autocorrelation-based pitch detection
    final autocorr = _autocorrelate(samples);
    final pitch = _findPitchFromAutocorrelation(autocorr);
    
    // Smooth with buffer
    _pitchBuffer.add(pitch);
    if (_pitchBuffer.length > 10) _pitchBuffer.removeAt(0);
    
    return _pitchBuffer.reduce((a, b) => a + b) / _pitchBuffer.length;
  }
  
  Future<EmotionalState> _detectEmotion(AudioFeatures features) async {
    // Prepare input tensor
    final input = [
      features.pitch,
      features.volume,
      features.tone,
      features.pace,
      features.energy,
    ];
    
    // Run emotion detection model
    final output = List.filled(7, 0.0); // 7 emotions
    _emotionModel.run(input, output);
    
    // Map to emotion categories
    final emotions = {
      'neutral': output[0],
      'happy': output[1],
      'sad': output[2],
      'angry': output[3],
      'fearful': output[4],
      'surprised': output[5],
      'disgusted': output[6],
    };
    
    final primaryEmotion = emotions.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    return EmotionalState(
      primary: primaryEmotion,
      confidence: emotions[primaryEmotion]!,
      allEmotions: emotions,
      valence: _calculateValence(emotions),
      arousal: _calculateArousal(emotions),
    );
  }
  
  VoiceFeedback _generateFeedback(
    AudioFeatures features,
    EmotionalState emotion,
    VoiceQuality quality,
  ) {
    final feedback = VoiceFeedback();
    
    // Pitch feedback
    if (features.pitch < config.idealPitchRange.start) {
      feedback.pitch = "Your pitch is a bit low. Try speaking slightly higher.";
    } else if (features.pitch > config.idealPitchRange.end) {
      feedback.pitch = "Your pitch is high. Try relaxing your voice.";
    } else {
      feedback.pitch = "Good pitch range!";
    }
    
    // Volume feedback
    if (features.volume < config.minVolume) {
      feedback.volume = "Speak a bit louder for better clarity.";
    } else if (features.volume > config.maxVolume) {
      feedback.volume = "You're speaking too loudly. Reduce volume slightly.";
    } else {
      feedback.volume = "Perfect volume level.";
    }
    
    // Pace feedback
    if (features.pace < 120) {
      feedback.pace = "You're speaking slowly. Consider speeding up slightly.";
    } else if (features.pace > 180) {
      feedback.pace = "You're speaking quickly. Try to slow down.";
    } else {
      feedback.pace = "Good speaking pace.";
    }
    
    // Emotional feedback
    feedback.emotion = _getEmotionalFeedback(emotion);
    
    // Quality feedback
    feedback.overall = _getQualityFeedback(quality);
    
    return feedback;
  }
  
  List<String> _generateSuggestions(AudioFeatures features) {
    final suggestions = <String>[];
    
    // Breathing suggestions
    if (features.energy < 0.3) {
      suggestions.add("Take deeper breaths between sentences");
    }
    
    // Articulation suggestions
    if (features.clarity < 0.7) {
      suggestions.add("Focus on articulating consonants clearly");
    }
    
    // Variation suggestions
    if (_isPitchMonotone()) {
      suggestions.add("Add more pitch variation for engagement");
    }
    
    // Pause suggestions
    if (features.pace > 160 && !_hasNaturalPauses()) {
      suggestions.add("Include more natural pauses");
    }
    
    return suggestions;
  }
}

class VoiceAnalysisResult {
  final DateTime timestamp;
  final double pitch;
  final double volume;
  final double tone;
  final double clarity;
  final double pace;
  final EmotionalState emotion;
  final VoiceQuality quality;
  final SpeakingStyle style;
  final VoiceFeedback feedback;
  final List<String> suggestions;
  final double score;
  
  VoiceAnalysisResult({
    required this.timestamp,
    required this.pitch,
    required this.volume,
    required this.tone,
    required this.clarity,
    required this.pace,
    required this.emotion,
    required this.quality,
    required this.style,
    required this.feedback,
    required this.suggestions,
    required this.score,
  });
}