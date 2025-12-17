
import joblib
import json
import numpy as np
import os

# Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(BASE_DIR, 'assets', 'models')
SCALER_PATH = os.path.join(ASSETS_DIR, 'svm_scaler_v3.joblib')
LE_PATH = os.path.join(ASSETS_DIR, 'label_encoder_v3.joblib')
OUTPUT_JSON_PATH = os.path.join(ASSETS_DIR, 'model_params.json')

def export_params():
    data = {}

    # 1. Export Scaler (StandardScaler)
    try:
        scaler = joblib.load(SCALER_PATH)
        print("Scaler loaded.")
        
        # StandardScaler stores mean_ and scale_
        data['scaler'] = {
            'mean': scaler.mean_.tolist(),
            'scale': scaler.scale_.tolist()
        }
        print(f"Scaler params extracted. Mean len: {len(data['scaler']['mean'])}")
    except Exception as e:
        print(f"Error loading scaler: {e}")
        return

    # 2. Export Label Encoder
    try:
        le = joblib.load(LE_PATH)
        print("Label Encoder loaded.")
        
        data['label_encoder'] = {
            'classes': le.classes_.tolist()
        }
        print(f"Label Encoder classes extracted: {data['label_encoder']['classes']}")
    except Exception as e:
        print(f"Error loading label encoder: {e}")
        return

    # 3. Save to JSON
    with open(OUTPUT_JSON_PATH, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Successfully exported parameters to {OUTPUT_JSON_PATH}")

if __name__ == "__main__":
    export_params()
