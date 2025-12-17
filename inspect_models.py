import onnxruntime as ort
import sys

def inspect_model(model_path):
    try:
        session = ort.InferenceSession(model_path)
        print(f"--- Inspecting {model_path} ---")
        
        print("\nInputs:")
        for i in session.get_inputs():
            print(f"  Name: {i.name}")
            print(f"  Shape: {i.shape}")
            print(f"  Type: {i.type}")
            
        print("\nOutputs:")
        for o in session.get_outputs():
            print(f"  Name: {o.name}")
            print(f"  Shape: {o.shape}")
            print(f"  Type: {o.type}")
            
    except Exception as e:
        print(f"Error inspecting {model_path}: {e}")

if __name__ == "__main__":
    inspect_model("assets/models/svm_model_v3.onnx")
    print("\n" + "="*30 + "\n")
    inspect_model("assets/models/xgb_model_v3.onnx")
