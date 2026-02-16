import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
import warnings
warnings.filterwarnings("ignore")

import sys
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing import image

# 🔥 ALWAYS LOAD MODEL USING ABSOLUTE PATH
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "fake_image_detector_model.h5")

model = tf.keras.models.load_model(MODEL_PATH)

def predict_image(img_path):
    try:
        # 🔍 Safety checks
        if not os.path.exists(img_path):
            return {"error": f"Image not found: {img_path}"}

        img = image.load_img(img_path, target_size=(128, 128))
        img_array = image.img_to_array(img) / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        with tf.device('/CPU:0'):
            prediction = model.predict(img_array, verbose=0)


        # Case 1: sigmoid output
        if prediction.shape[-1] == 1:
            score = float(prediction[0][0])
            is_fake = score > 0.5
            confidence = score if is_fake else 1 - score

        # Case 2: softmax output
        else:
            score_fake = float(prediction[0][1])
            is_fake = score_fake > 0.5
            confidence = score_fake if is_fake else 1 - score_fake

        return {
            "isFake": is_fake,
            "confidence": round(confidence, 4)
        }

    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No image path provided"}))
        sys.exit(1)

    img_path = sys.argv[1]
    result = predict_image(img_path)

    # ✅ CRITICAL: print ONLY JSON to stdout
    print(json.dumps(result))
