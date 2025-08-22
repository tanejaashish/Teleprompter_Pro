import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class VideoSentimentAnalyzer {
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector(
    FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  
  late Interpreter _microExpressionModel;
  late Interpreter _bodyLanguageModel;
  late Interpreter _gazeModel;
  
  final StreamController<VideoSentimentResult> _sentimentController = 
      StreamController<VideoSentimentResult>.broadcast();
  
  Stream<VideoSentimentResult> get sentimentStream => _sentimentController.stream;
  
  Future<void> analyzeFrame(CameraImage image) async {
    // Convert camera image to InputImage
    final inputImage = _convertCameraImage(image);
    
    // Detect faces
    final faces = await _faceDetector.processImage(inputImage);
    
    if (faces.isEmpty) {
      _sentimentController.add(VideoSentimentResult.noFace());
      return;
    }
    
    final face = faces.first;
    
    // Extract facial features
    final features = await _extractFacialFeatures(face);
    
    // Analyze micro-expressions
    final microExpressions = await _analyzeMicroExpressions(features);
    
    // Analyze gaze patterns
    final gazeAnalysis = await _analyzeGaze(face);
    
    // Analyze body language if visible
    final bodyLanguage = await _analyzeBodyLanguage(inputImage);
    
    // Combine all signals
    final sentiment = _combineSentimentSignals(
      facialExpression: face.smilingProbability ?? 0,
      microExpressions: microExpressions,
      gaze: gazeAnalysis,
      bodyLanguage: bodyLanguage,
    );
    
    _sentimentController.add(VideoSentimentResult(
      timestamp: DateTime.now(),
      confidence: sentiment.confidence,
      dominantEmotion: sentiment.dominant,
      emotionBreakdown: sentiment.breakdown,
      facialTension: _calculateFacialTension(features),
      eyeContact: gazeAnalysis.eyeContactScore,
      posture: bodyLanguage?.postureScore ?? 1.0,
      microExpressions: microExpressions,
      suggestions: _generateVideoFeedback(sentiment, gazeAnalysis, bodyLanguage),
    ));
  }
  
  Future<MicroExpressions> _analyzeMicroExpressions(FacialFeatures features) async {
    // Prepare input for micro-expression model
    final input = _prepareMicroExpressionInput(features);
    
    // Run inference
    final output = List.filled(7, 0.0);
    _microExpressionModel.run(input, output);
    
    return MicroExpressions(
      contempt: output[0],
      surprise: output[1],
      fear: output[2],
      sadness: output[3],
      disgust: output[4],
      anger: output[5],
      happiness: output[6],
    );
  }
  
  Future<GazeAnalysis> _analyzeGaze(Face face) async {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    
    if (leftEye == null || rightEye == null) {
      return GazeAnalysis.unknown();
    }
    
    // Calculate gaze direction
    final gazeDirection = _calculateGazeDirection(leftEye, rightEye);
    
    // Check if looking at camera
    final lookingAtCamera = _isLookingAtCamera(gazeDirection);
    
    return GazeAnalysis(
      direction: gazeDirection,
      eyeContactScore: lookingAtCamera ? 1.0 : 0.3,
      isEngaged: lookingAtCamera,
      pupilDilation: await _measurePupilDilation(face),
    );
  }
}