
import onnx
import os

# Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(BASE_DIR, 'assets', 'models')
SVM_MODEL_PATH = os.path.join(ASSETS_DIR, 'svm_model_v3.onnx')
XGB_MODEL_PATH = os.path.join(ASSETS_DIR, 'xgb_model_v3.onnx')

TARGET_IR_VERSION = 9

def downgrade_model(model_path):
    print(f"Processing: {model_path}")
    try:
        # Load the model
        model = onnx.load(model_path)
        print(f"  Current IR Version: {model.ir_version}")
        print(f"  Current Opset Import: {[x.version for x in model.opset_import]}")

        if model.ir_version > TARGET_IR_VERSION:
            print(f"  Downgrading IR version from {model.ir_version} to {TARGET_IR_VERSION}...")
            model.ir_version = TARGET_IR_VERSION
            
            # Save the model back
            onnx.save(model, model_path)
            print("  Saved successfully.")
        else:
            print("  IR Version is already compatible.")

    except Exception as e:
        print(f"  Error processing model: {e}")

if __name__ == "__main__":
    downgrade_model(SVM_MODEL_PATH)
    print("-" * 20)
    downgrade_model(XGB_MODEL_PATH)
