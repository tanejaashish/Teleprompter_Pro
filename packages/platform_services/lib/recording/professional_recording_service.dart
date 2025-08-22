import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

class ProfessionalRecordingService {
  CameraController? _cameraController;
  AudioRecorder? _audioRecorder;
  List<CameraDescription> _cameras = [];
  
  // Recording state
  RecordingSession? _currentSession;
  final _sessionController = StreamController<RecordingSession>.broadcast();
  
  // Advanced settings
  RecordingProfile _profile = RecordingProfile.standard();
  VideoEffectsEngine? _effectsEngine;
  
  Stream<RecordingSession> get sessionStream => _sessionController.stream;
  
  Future<void> initialize({RecordingProfile? profile}) async {
    if (profile != null) _profile = profile;
    
    // Get available cameras
    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw NoCameraException();
    
    // Initialize effects engine if needed
    if (_profile.enableEffects) {
      _effectsEngine = VideoEffectsEngine();
      await _effectsEngine!.initialize();
    }
    
    // Initialize audio recorder
    _audioRecorder = AudioRecorder();
    await _audioRecorder!.initialize(
      sampleRate: _profile.audioSampleRate,
      bitRate: _profile.audioBitRate,
    );
  }
  
  Future<void> selectCamera(CameraLensDirection direction) async {
    final camera = _cameras.firstWhere(
      (cam) => cam.lensDirection == direction,
      orElse: () => _cameras.first,
    );
    
    await _initializeCamera(camera);
  }
  
  Future<void> _initializeCamera(CameraDescription camera) async {
    _cameraController?.dispose();
    
    _cameraController = CameraController(
      camera,
      _profile.videoResolution,
      enableAudio: _profile.recordAudio,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    
    await _cameraController!.initialize();
    
    // Configure advanced settings
    if (_profile.enableHDR) {
      await _cameraController!.setExposureMode(ExposureMode.auto);
    }
    
    if (_profile.stabilization) {
      await _cameraController!.enableVideoStabilization();
    }
    
    await _cameraController!.prepareForVideoRecording();
  }
  
  Future<RecordingSession> startRecording({
    String? outputPath,
    Script? script,
    Map<String, dynamic>? metadata,
  }) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw CameraNotInitializedException();
    }
    
    // Create session
    _currentSession = RecordingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      script: script,
      metadata: metadata ?? {},
      profile: _profile,
    );
    
    // Determine output path
    final tempDir = await getTemporaryDirectory();
    final sessionPath = '${tempDir.path}/session_${_currentSession!.id}';
    await Directory(sessionPath).create(recursive: true);
    
    _currentSession!.videoPath = '$sessionPath/video_raw.mp4';
    _currentSession!.audioPath = '$sessionPath/audio.wav';
    
    // Start video recording
    await _cameraController!.startVideoRecording();
    
    // Start separate audio recording for better quality
    if (_profile.recordAudio && _profile.separateAudioTrack) {
      await _audioRecorder!.startRecording(_currentSession!.audioPath!);
    }
    
    // Start monitoring
    _startRecordingMonitor();
    
    _sessionController.add(_currentSession!);
    return _currentSession!;
  }
  
  void _startRecordingMonitor() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentSession == null) {
        timer.cancel();
        return;
      }
      
      _currentSession!.duration = DateTime.now().difference(_currentSession!.startTime);
      _currentSession!.fileSize = _estimateFileSize();
      
      // Check limits
      if (_profile.maxDuration != null && 
          _currentSession!.duration > _profile.maxDuration!) {
        stopRecording();
        timer.cancel();
      }
      
      _sessionController.add(_currentSession!);
    });
  }
  
  Future<ProcessedRecording> stopRecording({
    bool processVideo = true,
    VideoExportSettings? exportSettings,
  }) async {
    if (_currentSession == null) throw NoActiveRecordingException();
    
    // Stop camera recording
    final videoFile = await _cameraController!.stopVideoRecording();
    _currentSession!.videoPath = videoFile.path;
    
    // Stop audio recording
    if (_audioRecorder!.isRecording) {
      await _audioRecorder!.stopRecording();
    }
    
    // Process video if requested
    String finalPath = videoFile.path;
    if (processVideo) {
      finalPath = await _processRecording(
        _currentSession!,
        exportSettings ?? VideoExportSettings.default_(),
      );
    }
    
    final result = ProcessedRecording(
      session: _currentSession!,
      finalPath: finalPath,
      thumbnailPath: await _generateThumbnail(finalPath),
      metadata: await _extractMetadata(finalPath),
    );
    
    _currentSession = null;
    return result;
  }
  
  Future<String> _processRecording(
    RecordingSession session,
    VideoExportSettings settings,
  ) async {
    final outputPath = session.videoPath!.replaceAll('_raw.mp4', '_processed.mp4');
    
    // Build FFmpeg command
    final command = FFmpegCommandBuilder()
      ..addInput(session.videoPath!)
      ..setVideoCodec(settings.videoCodec)
      ..setVideoBitrate(settings.videoBitrate)
      ..setVideoResolution(settings.resolution)
      ..setFrameRate(settings.frameRate);
    
    // Add audio if available
    if (session.audioPath != null) {
      command
        ..addInput(session.audioPath!)
        ..setAudioCodec(settings.audioCodec)
        ..setAudioBitrate(settings.audioBitrate)
        ..enableAudioNormalization();
    }
    
    // Apply effects
    if (_profile.enableEffects && _effectsEngine != null) {
      final filters = <String>[];
      
      if (session.profile.virtualBackground != null) {
        filters.add(_effectsEngine!.getBackgroundFilter(
          session.profile.virtualBackground!,
        ));
      }
      
      if (session.profile.colorCorrection) {
        filters.add('eq=brightness=0.06:contrast=1.1:saturation=1.2');
      }
      
      if (session.profile.denoiseVideo) {
        filters.add('hqdn3d=4:3:6:4');
      }
      
      if (filters.isNotEmpty) {
        command.setVideoFilters(filters.join(','));
      }
    }
    
    // Add metadata
    command.setMetadata({
      'title': session.script?.title ?? 'Recording',
      'creation_time': session.startTime.toIso8601String(),
      'duration': session.duration.inSeconds.toString(),
      ...session.metadata,
    });
    
    command.setOutput(outputPath);
    
    // Execute FFmpeg
    await FFmpegKit.executeWithArguments(command.build());
    
    return outputPath;
  }
  
  Future<String> _generateThumbnail(String videoPath) async {
    final thumbnailPath = videoPath.replaceAll('.mp4', '_thumb.jpg');
    
    await FFmpegKit.execute(
      '-i $videoPath -ss 00:00:01 -vframes 1 -vf scale=320:-1 $thumbnailPath'
    );
    
    return thumbnailPath;
  }
  
  Future<VideoMetadata> _extractMetadata(String videoPath) async {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info = session.getMediaInformation();
    
    return VideoMetadata(
      duration: Duration(milliseconds: info?.getDuration()?.toInt() ?? 0),
      bitrate: info?.getBitrate() ?? 0,
      size: File(videoPath).lengthSync(),
      resolution: _extractResolution(info),
      codec: info?.getStreams()?.first.getCodecName() ?? 'unknown',
    );
  }
  
  // Live streaming support
  Future<LiveStream> startLiveStream({
    required String rtmpUrl,
    required String streamKey,
    LiveStreamSettings? settings,
  }) async {
    final streamSettings = settings ?? LiveStreamSettings.default_();
    
    // Initialize streaming encoder
    final encoder = StreamingEncoder();
    await encoder.initialize(
      inputSource: _cameraController!.buildPreview(),
      outputUrl: '$rtmpUrl/$streamKey',
      settings: streamSettings,
    );
    
    // Start streaming
    await encoder.startStreaming();
    
    return LiveStream(
      url: rtmpUrl,
      key: streamKey,
      startTime: DateTime.now(),
      encoder: encoder,
    );
  }
}

class RecordingProfile {
  final ResolutionPreset videoResolution;
  final int videoFrameRate;
  final int videoBitrate;
  final int audioSampleRate;
  final int audioBitRate;
  final bool recordAudio;
  final bool separateAudioTrack;
  final bool enableEffects;
  final bool enableHDR;
  final bool stabilization;
  final bool colorCorrection;
  final bool denoiseVideo;
  final Duration? maxDuration;
  final String? virtualBackground;
  
  RecordingProfile({
    this.videoResolution = ResolutionPreset.high,
    this.videoFrameRate = 30,
    this.videoBitrate = 5000000,
    this.audioSampleRate = 48000,
    this.audioBitRate = 192000,
    this.recordAudio = true,
    this.separateAudioTrack = false,
    this.enableEffects = false,
    this.enableHDR = false,
    this.stabilization = true,
    this.colorCorrection = false,
    this.denoiseVideo = false,
    this.maxDuration,
    this.virtualBackground,
  });
  
  factory RecordingProfile.standard() => RecordingProfile();
  
  factory RecordingProfile.professional() => RecordingProfile(
    videoResolution: ResolutionPreset.max,
    videoFrameRate: 60,
    videoBitrate: 10000000,
    separateAudioTrack: true,
    enableEffects: true,
    enableHDR: true,
    colorCorrection: true,
    denoiseVideo: true,
  );
}