class AnalysisDashboard extends StatefulWidget {
  @override
  _AnalysisDashboardState createState() => _AnalysisDashboardState();
}

class _AnalysisDashboardState extends State<AnalysisDashboard> {
  final RealtimeVoiceAnalyzer _voiceAnalyzer = RealtimeVoiceAnalyzer();
  final VideoSentimentAnalyzer _videoAnalyzer = VideoSentimentAnalyzer();
  final RealtimeTranscriber _transcriber = RealtimeTranscriber();
  
  VoiceAnalysisResult? _latestVoiceAnalysis;
  VideoSentimentResult? _latestVideoAnalysis;
  String _currentTranscript = '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Main teleprompter view
          Expanded(
            flex: 2,
            child: TeleprompterView(
              onRecordingStart: _startAnalysis,
              onRecordingStop: _stopAnalysis,
            ),
          ),
          
          // Analysis panel
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  // Voice metrics
                  _buildVoiceMetrics(),
                  
                  // Emotion indicators
                  _buildEmotionIndicators(),
                  
                  // Real-time feedback
                  _buildFeedbackPanel(),
                  
                  // Suggestions
                  _buildSuggestionsPanel(),
                  
                  // Transcript
                  _buildTranscriptPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVoiceMetrics() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voice Metrics', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            
            // Pitch gauge
            _buildMetricGauge(
              label: 'Pitch',
              value: _latestVoiceAnalysis?.pitch ?? 150,
              min: 80,
              max: 300,
              unit: 'Hz',
              idealRange: Range(120, 200),
            ),
            
            // Volume meter
            _buildMetricMeter(
              label: 'Volume',
              value: _latestVoiceAnalysis?.volume ?? -20,
              min: -60,
              max: 0,
              unit: 'dB',
            ),
            
            // Pace indicator
            _buildMetricIndicator(
              label: 'Pace',
              value: _latestVoiceAnalysis?.pace ?? 150,
              unit: 'WPM',
              status: _getPaceStatus(_latestVoiceAnalysis?.pace ?? 150),
            ),
            
            // Clarity score
            _buildMetricScore(
              label: 'Clarity',
              value: _latestVoiceAnalysis?.clarity ?? 0.8,
              showPercentage: true,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmotionIndicators() {
    final emotions = _latestVoiceAnalysis?.emotion.allEmotions ?? {};
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emotional State', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16),
            
            // Emotion radar chart
            SizedBox(
              height: 200,
              child: RadarChart(
                data: emotions.entries.map((e) => 
                  RadarData(e.key, e.value)
                ).toList(),
              ),
            ),
            
            // Dominant emotion
            if (_latestVoiceAnalysis != null)
              Chip(
                label: Text(_latestVoiceAnalysis!.emotion.primary),
                avatar: Icon(_getEmotionIcon(_latestVoiceAnalysis!.emotion.primary)),
              ),
          ],
        ),
      ),
    );
  }
}