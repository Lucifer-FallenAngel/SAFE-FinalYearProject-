import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'  # suppress TensorFlow INFO/WARN
import warnings
warnings.filterwarnings("ignore")

import sys
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing import image

# Load model once
model = tf.keras.models.load_model("fake_image_detector_model.h5")

def predict_image(img_path):
    try:
        img = image.load_img(img_path, target_size=(128, 128))  # adjust input size if needed
        img_array = image.img_to_array(img) / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        prediction = model.predict(img_array, verbose=0)

        # 🔍 Debug: print raw model output
        print("RAW_OUTPUT:", prediction.tolist(), file=sys.stderr)

        # Case 1: sigmoid (single probability)
        if prediction.shape[-1] == 1:
            score = float(prediction[0][0])
            is_fake = score > 0.5   # may need flipping based on your training labels
            confidence = score if is_fake else 1 - score

        # Case 2: softmax (2-class output)
        else:
            score_fake = float(prediction[0][1])  # assume index 1 = fake
            is_fake = score_fake > 0.5
            confidence = score_fake if is_fake else 1 - score_fake

        return {"isFake": is_fake, "confidence": confidence}

    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No image path provided"}))
        sys.exit(1)

    img_path = sys.argv[1]
    result = predict_image(img_path)
    # ✅ print ONLY JSON for backend to parse
    print(json.dumps(result))
