import json
import threading
from pathlib import Path

import numpy as np
from ai_edge_litert.interpreter import Interpreter
from flask import Flask, jsonify, request
from PIL import Image, ImageOps, UnidentifiedImageError

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 10 * 1024 * 1024

BASE_DIR = Path(__file__).resolve().parent

# Load prediction labels.
with open(BASE_DIR / "class_names.json", encoding="utf-8") as file:
    labels = json.load(file)

# Load your TFLite model.
interpreter = Interpreter(
    model_path=str(BASE_DIR / "ekrushi_model.tflite")
)
interpreter.allocate_tensors()

input_info = interpreter.get_input_details()[0]
output_info = interpreter.get_output_details()[0]

_, height, width, channels = input_info["shape"]

if channels != 3 or input_info["dtype"] != np.float32:
    raise ValueError("Expected a float32 RGB image model.")

if output_info["shape"][-1] != len(labels):
    raise ValueError("Model output count does not match class_names.json.")

model_lock = threading.Lock()

# Temporary assumption for testing the API connection.
# The original model's preprocessing still needs verification.
PREPROCESSING = "zero_one"


@app.get("/health")
def health():
    return jsonify(
        status="ok",
        message="eKrushi backend is running"
    )


@app.errorhandler(413)
def image_too_large(error):
    return jsonify(
        error="Please select an image smaller than 10 MB."
    ), 413


@app.post("/predict")
def predict():
    uploaded = request.files.get("image")

    if uploaded is None:
        return jsonify(error="No image received."), 400

    try:
        with Image.open(uploaded.stream) as source:
            image = ImageOps.exif_transpose(source).convert("RGB")

            image = image.resize(
                (int(width), int(height)),
                Image.Resampling.BILINEAR,
            )

            pixels = np.asarray(image, dtype=np.float32)

    except (UnidentifiedImageError, OSError, ValueError):
        return jsonify(error="Please upload a valid image."), 400

    if PREPROCESSING == "zero_one":
        pixels = pixels / 255.0
    elif PREPROCESSING == "minus_one_one":
        pixels = pixels / 127.5 - 1.0
    elif PREPROCESSING != "raw":
        return jsonify(error="Invalid preprocessing setting."), 500

    batch = np.expand_dims(pixels, axis=0).astype(np.float32)

    try:
        with model_lock:
            interpreter.set_tensor(input_info["index"], batch)
            interpreter.invoke()

            probabilities = interpreter.get_tensor(
                output_info["index"]
            )[0].copy()

        if not np.all(np.isfinite(probabilities)):
            raise ValueError("Invalid model output.")

        index = int(np.argmax(probabilities))
        label = labels[str(index)]

        disease = label.replace("___", " - ").replace("_", " ")
        confidence = round(float(probabilities[index]) * 100, 2)

        return jsonify(
            disease=disease,
            confidence=confidence,
            description=f"Model prediction: {disease}.",
            treatment="Treatment guidance has not been configured.",
            severity="Not assessed",
        )

    except Exception:
        app.logger.exception("Prediction failed")
        return jsonify(
            error="Prediction failed. Check the backend terminal."
        ), 500


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False,
    )