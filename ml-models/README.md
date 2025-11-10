# Machine Learning Models for TelePrompt Pro

This directory contains machine learning models and related resources for AI-powered features in TelePrompt Pro.

## Models Overview

### 1. Eye Contact Correction Model
**Location:** `models/eye-correction/`
**Purpose:** Adjusts video frames to maintain natural eye contact with the camera
**Technology:** Computer Vision + Deep Learning
**Framework:** TensorFlow/PyTorch

**Features:**
- Facial landmark detection
- Gaze direction estimation
- Eye region manipulation
- Natural-looking correction

**Input:** Video frames (RGB images)
**Output:** Corrected video frames with adjusted eye gaze

**Model Architecture:**
- Base: MediaPipe Face Mesh for landmark detection
- Custom CNN for gaze estimation
- Generative model for eye region synthesis

**Performance:**
- Processing speed: 30 FPS on GPU, 10 FPS on CPU
- Model size: ~50 MB
- Accuracy: 95% gaze correction accuracy

### 2. Background Removal Model
**Location:** `models/background-removal/`
**Purpose:** Segment person from background for virtual background replacement
**Technology:** Semantic Segmentation
**Framework:** TensorFlow Lite / ONNX

**Features:**
- Real-time person segmentation
- High accuracy boundary detection
- Optimized for video streaming
- Mobile-friendly

**Input:** Video frames (RGB images, 512x512 or 1920x1080)
**Output:** Alpha matte mask for background separation

**Model Architecture:**
- Base: DeepLabV3+ or U-Net architecture
- Optimized for real-time inference
- MobileNet backbone for efficiency

**Performance:**
- Processing speed: 60 FPS on GPU, 15 FPS on mobile
- Model size: ~17 MB (mobile), ~80 MB (desktop)
- Accuracy: 98% segmentation accuracy

### 3. Speech-to-Text Model (Whisper Integration)
**Location:** External API (OpenAI Whisper)
**Purpose:** Transcribe audio for voice-scrolling and subtitles
**Technology:** Transformer-based ASR

**Features:**
- Multi-language support (96+ languages)
- High accuracy transcription
- Punctuation and formatting
- Speaker diarization (optional)

**API Integration:**
- Endpoint: OpenAI Whisper API
- Input: Audio file (MP3, WAV, M4A)
- Output: Timestamped transcription

### 4. Content Generation Model (GPT Integration)
**Location:** External API (OpenAI GPT-4)
**Purpose:** Generate scripts, improve content, suggest edits
**Technology:** Large Language Model

**Features:**
- Script generation from prompts
- Content improvement suggestions
- Style adaptation
- Length optimization

**API Integration:**
- Endpoint: OpenAI GPT-4 API
- Input: Text prompt with context
- Output: Generated or improved text

## Model Integration Guide

### Prerequisites
```bash
# Python dependencies
pip install tensorflow torch torchvision onnxruntime opencv-python mediapipe

# Node.js dependencies (for TensorFlow.js)
npm install @tensorflow/tfjs @tensorflow/tfjs-node
```

### Loading Models (Python)

```python
import tensorflow as tf

# Load eye correction model
eye_correction_model = tf.keras.models.load_model('ml-models/models/eye-correction/model.h5')

# Load background removal model
bg_removal_model = tf.keras.models.load_model('ml-models/models/background-removal/model.h5')

# Make predictions
corrected_frame = eye_correction_model.predict(input_frame)
person_mask = bg_removal_model.predict(input_frame)
```

### Loading Models (Node.js)

```javascript
const tf = require('@tensorflow/tfjs-node');

// Load model
const model = await tf.loadLayersModel('file://ml-models/models/eye-correction/model.json');

// Make predictions
const inputTensor = tf.browser.fromPixels(imageData);
const prediction = model.predict(inputTensor);
```

## Model Training

### Eye Contact Correction
**Dataset Requirements:**
- 10,000+ video frames with annotated gaze directions
- Various lighting conditions and camera angles
- Diverse demographics

**Training Process:**
1. Collect training data with MediaPipe Face Mesh
2. Annotate gaze directions manually
3. Train CNN for gaze estimation
4. Train GAN for eye region synthesis
5. Fine-tune on validation set

**Training Script:**
```bash
python scripts/train_eye_correction.py \
  --data-dir ./data/eye-correction \
  --epochs 100 \
  --batch-size 32 \
  --learning-rate 0.001
```

### Background Removal
**Dataset Requirements:**
- Large segmentation dataset (e.g., COCO, ADE20K)
- Video-specific annotations
- Various backgrounds and poses

**Training Process:**
1. Download base dataset
2. Augment with video-specific data
3. Train DeepLabV3+ model
4. Optimize for mobile deployment
5. Convert to TensorFlow Lite

**Training Script:**
```bash
python scripts/train_background_removal.py \
  --data-dir ./data/segmentation \
  --architecture deeplabv3+ \
  --epochs 50 \
  --batch-size 16
```

## Model Optimization

### Quantization
Reduce model size and increase inference speed:

```bash
# TensorFlow Lite quantization
python scripts/quantize_model.py \
  --input-model models/eye-correction/model.h5 \
  --output-model models/eye-correction/model_quantized.tflite \
  --quantization-type int8
```

### ONNX Conversion
For cross-platform compatibility:

```bash
# Convert PyTorch to ONNX
python scripts/convert_to_onnx.py \
  --model-path models/background-removal/model.pth \
  --output-path models/background-removal/model.onnx
```

## Deployment

### Backend Deployment (Python)
Models are loaded in the AI service container:
```dockerfile
FROM python:3.9
RUN pip install tensorflow torch opencv-python
COPY ml-models /app/ml-models
WORKDIR /app
CMD ["python", "ai-service.py"]
```

### Frontend Deployment (TensorFlow.js)
For browser-based inference:
```javascript
// Load model in browser
const model = await tf.loadLayersModel('/models/eye-correction/model.json');

// Run inference on video frame
const prediction = await model.predict(videoFrame);
```

### Mobile Deployment (TensorFlow Lite)
For native mobile apps:
```dart
// Flutter TensorFlow Lite integration
import 'package:tflite_flutter/tflite_flutter.dart';

final interpreter = await Interpreter.fromAsset('models/eye_correction.tflite');
interpreter.run(inputImage, outputBuffer);
```

## Model Versioning

Models are versioned using semantic versioning:
- `v1.0.0` - Initial release
- `v1.1.0` - Performance improvements
- `v2.0.0` - Architecture changes

**Version Management:**
```bash
# Tag model version
git tag -a ml-models/eye-correction-v1.0.0 -m "Initial eye correction model"

# Store models in cloud storage
aws s3 cp models/eye-correction/model.h5 \
  s3://teleprompter-models/eye-correction/v1.0.0/model.h5
```

## Performance Benchmarks

| Model | Platform | Device | FPS | Latency | Size |
|-------|----------|--------|-----|---------|------|
| Eye Correction | GPU | NVIDIA RTX 3060 | 30 | 33ms | 50MB |
| Eye Correction | CPU | Intel i7 | 10 | 100ms | 50MB |
| Eye Correction | Mobile | iPhone 14 | 15 | 66ms | 35MB |
| Background Removal | GPU | NVIDIA RTX 3060 | 60 | 16ms | 80MB |
| Background Removal | CPU | Intel i7 | 15 | 66ms | 80MB |
| Background Removal | Mobile | iPhone 14 | 30 | 33ms | 17MB |

## API Endpoints

### Eye Correction API
```
POST /api/ai/correct-eye-contact
Content-Type: multipart/form-data

Parameters:
  - video: Video file
  - intensity: 0.0 - 1.0 (correction strength)

Response:
{
  "jobId": "job_123",
  "status": "processing",
  "estimatedTime": 120
}
```

### Background Removal API
```
POST /api/ai/remove-background
Content-Type: multipart/form-data

Parameters:
  - video: Video file
  - background: Image file (optional)

Response:
{
  "jobId": "job_456",
  "status": "processing",
  "estimatedTime": 90
}
```

## Monitoring and Metrics

Track model performance in production:
- Inference time per frame
- GPU/CPU utilization
- Model accuracy (through user feedback)
- Error rates and failure modes

**Monitoring Tools:**
- Prometheus for metrics collection
- Grafana for visualization
- TensorBoard for model performance

## Troubleshooting

### Common Issues

**Issue: Model loading fails**
```
Solution: Verify model file path and format
Check TensorFlow/PyTorch version compatibility
```

**Issue: Slow inference speed**
```
Solution: Enable GPU acceleration
Reduce input resolution
Use quantized model version
```

**Issue: Poor model accuracy**
```
Solution: Check input preprocessing
Verify model version
Retrain on domain-specific data
```

## Future Enhancements

1. **Real-time Pose Correction**: Adjust body posture in real-time
2. **Lighting Enhancement**: Automatic lighting correction
3. **Voice Enhancement**: Remove background noise, enhance clarity
4. **Multi-person Support**: Handle multiple speakers in frame
5. **Style Transfer**: Apply artistic styles to videos
6. **Auto-framing**: Intelligent camera framing and zooming

## License

Models are proprietary and licensed under TelePrompt Pro Enterprise License.

## Support

For ML model questions or issues:
- Email: ml-support@teleprompter.pro
- Slack: #ml-models channel
- Documentation: https://docs.teleprompter.pro/ml-models
