
import os
import cv2
import numpy as np
import joblib
import onnxruntime as ort
from skimage.feature import local_binary_pattern

# --- CONSTANTS (Must match app.py) ---
IMG_SIZE = (250, 250)
H_BINS = 180
S_BINS = 256
LBP_POINTS = 24
LBP_RADIUS = 8
LBP_BINS = int(LBP_POINTS + 2)

# --- PATHS ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PBL_BACKEND_DIR = os.path.join(BASE_DIR, 'PBL-Backend')
ASSETS_DIR = os.path.join(BASE_DIR, 'assets')

# Model Paths
MODEL_SVM_ONNX = os.path.join(ASSETS_DIR, 'models', 'svm_model_v3.onnx')
MODEL_XGB_ONNX = os.path.join(ASSETS_DIR, 'models', 'xgb_model_v3.onnx')

# Helper Paths (Scaler & Encoder from Backend)
# Helper Paths (Scaler & Encoder from Assets)
SCALER_SVM_PATH = os.path.join(ASSETS_DIR, 'models', 'svm_scaler_v3.joblib')
LE_PATH = os.path.join(ASSETS_DIR, 'models', 'label_encoder_v3.joblib')

# Test Images Path
TEST_IMAGES_DIR = os.path.join(ASSETS_DIR, 'gambar_uji')

def preprocess_and_extract_features_v2(image_path):
    """
    Replicates extract_features_v2 from app.py
    """
    try:
        # Read image
        image = cv2.imread(image_path)
        if image is None:
            print(f"Error: Could not read image {image_path}")
            return None

        # --- PREPROCESSING ---
        image = cv2.resize(image, IMG_SIZE)
        image = cv2.GaussianBlur(image, (5, 5), 0)

        hsv_image = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        gray_image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        # --- FEATURE 1: COLOR (HSV HISTOGRAM) ---
        h_hist = cv2.calcHist([hsv_image], [0], None, [H_BINS], [0, 180])
        s_hist = cv2.calcHist([hsv_image], [1], None, [S_BINS], [0, 256])

        h_hist = cv2.normalize(h_hist, None, 0, 1, cv2.NORM_MINMAX)
        s_hist = cv2.normalize(s_hist, None, 0, 1, cv2.NORM_MINMAX)

        color_features = np.concatenate((h_hist, s_hist)).flatten()

        # --- FEATURE 2: TEXTURE (LBP) ---
        lbp = local_binary_pattern(gray_image, LBP_POINTS, LBP_RADIUS, method='uniform')
        (texture_features, _) = np.histogram(lbp.ravel(),
                                             bins=LBP_BINS,
                                             range=(0, LBP_BINS))

        texture_features = cv2.normalize(texture_features, None, 0, 1, cv2.NORM_MINMAX)
        texture_features = texture_features.flatten()

        # --- FEATURE 3: SHAPE (HU MOMENTS) ---
        _, thresh = cv2.threshold(gray_image, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        moments = cv2.moments(thresh)
        hu_moments = cv2.HuMoments(moments)

        # Logit transform to handle range
        shape_features = -np.sign(hu_moments) * np.log10(np.abs(hu_moments) + 1e-7)
        shape_features = shape_features.flatten()

        # --- COMBINE ALL FEATURES ---
        final_feature_vector = np.concatenate((color_features, texture_features, shape_features))

        return final_feature_vector

    except Exception as e:
        print(f"Error transforming image {image_path}: {e}")
        return None

def main():
    print("--- Running ONNX Verification Script ---")
    
    # 1. Load Helper Objects
    try:
        print(f"Loading Scaler from: {SCALER_SVM_PATH}")
        scaler_svm = joblib.load(SCALER_SVM_PATH)
        
        print(f"Loading Label Encoder from: {LE_PATH}")
        le = joblib.load(LE_PATH)
        print("Helpers loaded successfully.")
    except Exception as e:
        print(f"CRITICAL ERROR: Failed to load helper files. {e}")
        return

    # 2. Load ONNX Models
    try:
        print(f"Loading SVM ONNX from: {MODEL_SVM_ONNX}")
        svm_session = ort.InferenceSession(MODEL_SVM_ONNX)
        
        print(f"Loading XGBoost ONNX from: {MODEL_XGB_ONNX}")
        xgb_session = ort.InferenceSession(MODEL_XGB_ONNX)
        print("ONNX Models loaded successfully.")
    except Exception as e:
        print(f"CRITICAL ERROR: Failed to load ONNX models. {e}")
        return

    # 3. Process Test Images
    if not os.path.exists(TEST_IMAGES_DIR):
         print(f"Test images directory not found: {TEST_IMAGES_DIR}")
         return

    image_files = [f for f in os.listdir(TEST_IMAGES_DIR) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
    print(f"\nFound {len(image_files)} test images in {TEST_IMAGES_DIR}\n")

    for img_file in image_files: # Limit to first 5 for brevity if needed, but let's run all
        img_path = os.path.join(TEST_IMAGES_DIR, img_file)
        print(f"Processing: {img_file}")

        # Extract Features
        features = preprocess_and_extract_features_v2(img_path)
        if features is None:
            continue

        # Reshape for inference (1, N_FEATURES)
        features_2d = features.reshape(1, -1)

        # --- SVM INFERENCE ---
        # SVM requires Scaling
        try:
            features_scaled = scaler_svm.transform(features_2d).astype(np.float32)
            
            # Run ONNX Inference
            input_name = svm_session.get_inputs()[0].name
            svm_pred_onx = svm_session.run(None, {input_name: features_scaled})
            
            # Parse Result
            svm_label_idx = svm_pred_onx[0][0]
            if isinstance(svm_label_idx, (np.int64, np.int32, int)):
                 svm_label_str = le.inverse_transform([svm_label_idx])[0]
            else:
                 # In case ONNX returns raw float/other, handle if needed, but typically it returns the label or index
                 # Based on inspect output: 'label' is int64.
                 svm_label_str = le.inverse_transform([svm_label_idx])[0]

            print(f"  [SVM] Prediction: {svm_label_str}")

        except Exception as e:
            print(f"  [SVM] Error: {e}")

        # --- XGBOOST INFERENCE ---
        # XGBoost usually handles unscaled data, but check if app.py scaled it.
        # app.py says: "elif model_choice == 'xgboost': # 4. (Scaling TIDAK DIPERLUKAN untuk XGBoost)"
        try:
             # ONNX runtime expects float32
             features_2d_float32 = features_2d.astype(np.float32)
             
             input_name_xgb = xgb_session.get_inputs()[0].name
             xgb_pred_onx = xgb_session.run(None, {input_name_xgb: features_2d_float32})
             
             xgb_label_idx = xgb_pred_onx[0][0]
             xgb_label_str = le.inverse_transform([xgb_label_idx])[0]
             
             print(f"  [XGB] Prediction: {xgb_label_str}")
             
        except Exception as e:
             print(f"  [XGB] Error: {e}")
             
        print("-" * 30)

if __name__ == "__main__":
    main()
