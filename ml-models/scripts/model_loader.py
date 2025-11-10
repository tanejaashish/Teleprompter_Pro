"""
ML Model Loader for TelePrompt Pro
Loads and manages machine learning models for AI features
"""

import os
import json
import logging
from typing import Dict, Any, Optional
import tensorflow as tf
import numpy as np

logger = logging.getLogger(__name__)


class ModelLoader:
    """Centralized model loader for all ML models"""

    def __init__(self, models_dir: str = "ml-models/models"):
        self.models_dir = models_dir
        self.loaded_models: Dict[str, Any] = {}
        self.configs: Dict[str, Dict] = {}

    def load_model(self, model_name: str, device: str = "cuda") -> Any:
        """
        Load a model by name

        Args:
            model_name: Name of the model (e.g., 'eye-correction', 'background-removal')
            device: Device to load model on ('cuda' or 'cpu')

        Returns:
            Loaded model instance
        """
        if model_name in self.loaded_models:
            logger.info(f"Model {model_name} already loaded, returning cached instance")
            return self.loaded_models[model_name]

        model_path = os.path.join(self.models_dir, model_name)
        config_path = os.path.join(model_path, "model_config.json")

        # Load configuration
        try:
            with open(config_path, "r") as f:
                config = json.load(f)
                self.configs[model_name] = config
        except FileNotFoundError:
            logger.error(f"Configuration file not found: {config_path}")
            raise FileNotFoundError(f"Model configuration not found for {model_name}")

        # Load model based on framework
        framework = config.get("framework", "tensorflow")

        if framework == "tensorflow":
            model = self._load_tensorflow_model(model_path, config, device)
        elif framework == "pytorch":
            model = self._load_pytorch_model(model_path, config, device)
        elif framework == "onnx":
            model = self._load_onnx_model(model_path, config)
        else:
            raise ValueError(f"Unsupported framework: {framework}")

        self.loaded_models[model_name] = model
        logger.info(f"Model {model_name} loaded successfully on {device}")

        return model

    def _load_tensorflow_model(
        self, model_path: str, config: Dict, device: str
    ) -> tf.keras.Model:
        """Load TensorFlow/Keras model"""
        model_file = config["model_files"].get("full_model", "model.h5")
        full_path = os.path.join(model_path, model_file)

        # Configure device
        if device == "cuda":
            physical_devices = tf.config.list_physical_devices("GPU")
            if physical_devices:
                tf.config.experimental.set_memory_growth(physical_devices[0], True)
        else:
            os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

        try:
            # Check if model file exists
            if not os.path.exists(full_path):
                logger.warning(
                    f"Model file not found: {full_path}. "
                    f"This is a placeholder. Please train or download the model."
                )
                return self._create_placeholder_model(config)

            model = tf.keras.models.load_model(full_path)
            return model
        except Exception as e:
            logger.error(f"Error loading TensorFlow model: {e}")
            return self._create_placeholder_model(config)

    def _load_pytorch_model(
        self, model_path: str, config: Dict, device: str
    ) -> Any:
        """Load PyTorch model"""
        try:
            import torch

            model_file = config["model_files"].get("weights", "model.pth")
            full_path = os.path.join(model_path, model_file)

            if not os.path.exists(full_path):
                logger.warning(
                    f"Model file not found: {full_path}. "
                    f"This is a placeholder."
                )
                return None

            model = torch.load(full_path, map_location=device)
            model.eval()
            return model
        except ImportError:
            logger.error("PyTorch not installed")
            raise ImportError("PyTorch is required for this model")

    def _load_onnx_model(self, model_path: str, config: Dict) -> Any:
        """Load ONNX model"""
        try:
            import onnxruntime as ort

            model_file = config["model_files"].get("onnx", "model.onnx")
            full_path = os.path.join(model_path, model_file)

            if not os.path.exists(full_path):
                logger.warning(
                    f"Model file not found: {full_path}. "
                    f"This is a placeholder."
                )
                return None

            session = ort.InferenceSession(full_path)
            return session
        except ImportError:
            logger.error("ONNX Runtime not installed")
            raise ImportError("ONNX Runtime is required for this model")

    def _create_placeholder_model(self, config: Dict) -> tf.keras.Model:
        """Create a placeholder model for development/testing"""
        logger.info("Creating placeholder model")

        input_shape = config.get("input_shape", [1, 224, 224, 3])[1:]
        output_shape = config.get("output_shape", [1, 224, 224, 3])[1:]

        # Simple passthrough model
        inputs = tf.keras.Input(shape=input_shape)
        outputs = tf.keras.layers.Conv2D(
            output_shape[-1], (3, 3), padding="same", activation="sigmoid"
        )(inputs)

        model = tf.keras.Model(inputs=inputs, outputs=outputs)
        return model

    def preprocess_input(
        self, model_name: str, input_data: np.ndarray
    ) -> np.ndarray:
        """
        Preprocess input data according to model configuration

        Args:
            model_name: Name of the model
            input_data: Raw input data (image array)

        Returns:
            Preprocessed input ready for inference
        """
        config = self.configs.get(model_name)
        if not config:
            raise ValueError(f"Model {model_name} not loaded")

        preprocessing = config.get("preprocessing", {})

        # Resize
        if "resize" in preprocessing:
            target_size = preprocessing["resize"]
            # Use OpenCV or PIL to resize
            # input_data = cv2.resize(input_data, tuple(target_size))

        # Normalize
        if preprocessing.get("normalize", False):
            mean = np.array(preprocessing.get("mean", [0.5, 0.5, 0.5]))
            std = np.array(preprocessing.get("std", [0.5, 0.5, 0.5]))
            input_data = (input_data - mean) / std

        # Add batch dimension if needed
        if len(input_data.shape) == 3:
            input_data = np.expand_dims(input_data, axis=0)

        return input_data

    def postprocess_output(
        self, model_name: str, output_data: np.ndarray
    ) -> np.ndarray:
        """
        Postprocess model output according to configuration

        Args:
            model_name: Name of the model
            output_data: Raw model output

        Returns:
            Processed output
        """
        config = self.configs.get(model_name)
        if not config:
            raise ValueError(f"Model {model_name} not loaded")

        postprocessing = config.get("postprocessing", {})

        # Remove batch dimension if present
        if len(output_data.shape) == 4 and output_data.shape[0] == 1:
            output_data = output_data[0]

        # Apply threshold for segmentation models
        if "segmentation_threshold" in config.get("hyperparameters", {}):
            threshold = config["hyperparameters"]["segmentation_threshold"]
            output_data = (output_data > threshold).astype(np.float32)

        return output_data

    def predict(
        self,
        model_name: str,
        input_data: np.ndarray,
        preprocess: bool = True,
        postprocess: bool = True,
    ) -> np.ndarray:
        """
        Run inference on input data

        Args:
            model_name: Name of the model
            input_data: Input data (image array)
            preprocess: Whether to apply preprocessing
            postprocess: Whether to apply postprocessing

        Returns:
            Model predictions
        """
        model = self.loaded_models.get(model_name)
        if not model:
            raise ValueError(f"Model {model_name} not loaded")

        # Preprocess
        if preprocess:
            input_data = self.preprocess_input(model_name, input_data)

        # Inference
        output = model.predict(input_data)

        # Postprocess
        if postprocess:
            output = self.postprocess_output(model_name, output)

        return output

    def unload_model(self, model_name: str) -> None:
        """Unload a model from memory"""
        if model_name in self.loaded_models:
            del self.loaded_models[model_name]
            logger.info(f"Model {model_name} unloaded from memory")

    def get_model_info(self, model_name: str) -> Dict:
        """Get model configuration and metadata"""
        return self.configs.get(model_name, {})


# Singleton instance
_model_loader = None


def get_model_loader() -> ModelLoader:
    """Get the global model loader instance"""
    global _model_loader
    if _model_loader is None:
        _model_loader = ModelLoader()
    return _model_loader


# Example usage
if __name__ == "__main__":
    # Configure logging
    logging.basicConfig(level=logging.INFO)

    # Load models
    loader = get_model_loader()

    try:
        # Load eye correction model
        eye_model = loader.load_model("eye-correction")
        print("Eye correction model loaded")

        # Load background removal model
        bg_model = loader.load_model("background-removal")
        print("Background removal model loaded")

        # Get model info
        info = loader.get_model_info("eye-correction")
        print(f"Model info: {json.dumps(info, indent=2)}")

        # Example prediction (with dummy data)
        dummy_input = np.random.rand(224, 224, 3).astype(np.float32)
        output = loader.predict("eye-correction", dummy_input)
        print(f"Prediction output shape: {output.shape}")

    except Exception as e:
        print(f"Error: {e}")
