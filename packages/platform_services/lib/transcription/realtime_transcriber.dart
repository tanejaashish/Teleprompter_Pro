class RealtimeTranscriber {
  final StreamController<TranscriptionUpdate> _transcriptionController = 
      StreamController<TranscriptionUpdate>.broadcast();
  
  WebSocket? _websocket;
  String _currentTranscript = '';
  final List<TranscriptSegment> _segments = [];
  
  Stream<TranscriptionUpdate> get transcriptionStream => _transcriptionController.stream;
  
  Future<void> startTranscription({
    required Stream<Uint8List> audioStream,
    required String language,
    TranscriptionConfig? config,
  }) async {
    final cfg = config ?? TranscriptionConfig.realtime();
    
    // Connect to transcription service
    _websocket = await WebSocket.connect(
      'wss://transcribe.teleprompt.pro/realtime',
    );
    
    // Send configuration
    _websocket!.add(jsonEncode({
      'action': 'configure',
      'language': language,
      'model': cfg.model,
      'enablePunctuation': cfg.enablePunctuation,
      'enableSpeakerDiarization': cfg.enableSpeakerDiarization,
      'vocabularyFilter': cfg.customVocabulary,
    }));
    
    // Listen for transcription results
    _websocket!.listen((data) {
      final result = jsonDecode(data);
      _processTranscriptionResult(result);
    });
    
    // Stream audio to service
    audioStream.listen((chunk) {
      if (_websocket?.readyState == WebSocket.open) {
        _websocket!.add(chunk);
      }
    });
  }
  
  void _processTranscriptionResult(Map<String, dynamic> result) {
    final type = result['type'];
    
    switch (type) {
      case 'partial':
        _handlePartialResult(result);
        break;
      case 'final':
        _handleFinalResult(result);
        break;
      case 'speaker_change':
        _handleSpeakerChange(result);
        break;
      case 'punctuation':
        _handlePunctuation(result);
        break;
    }
  }
  
  void _handleFinalResult(Map<String, dynamic> result) {
    final segment = TranscriptSegment(
      text: result['text'],
      startTime: Duration(milliseconds: result['startTime']),
      endTime: Duration(milliseconds: result['endTime']),
      confidence: result['confidence'],
      speaker: result['speaker'],
      words: (result['words'] as List).map((w) => Word.fromJson(w)).toList(),
    );
    
    _segments.add(segment);
    _currentTranscript = _segments.map((s) => s.text).join(' ');
    
    _transcriptionController.add(TranscriptionUpdate(
      type: UpdateType.final,
      segment: segment,
      fullTranscript: _currentTranscript,
      timestamp: DateTime.now(),
    ));
  }
}