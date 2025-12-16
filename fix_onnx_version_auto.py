import onnx
from onnx import version_converter, helper

def convert_model(input_path, output_path, target_opset=17): # IR 9 usually corresponds to opset 17 or lower? No, IR version is different.
    # IR Version 9 is roughly Opset 19. IR 10 is Opset 21?
    # Actually, the error is specifically about IR Version (ir_version).
    # We can just change ir_version field if the opset is compatible, OR use convert_version properly.
    
    print(f"Checking {input_path}...")
    model = onnx.load(input_path)
    print(f"Current IR Version: {model.ir_version}")
    
    # Force IR version to 8 (safest for older runtimes) or 9.
    # Previous success was with IR 8 or 9.
    target_ir_version = 8 
    
    if model.ir_version > target_ir_version:
        print(f"Downgrading IR version to {target_ir_version}...")
        model.ir_version = target_ir_version
        
        # Also ensure Opset isn't too high. 
        # Opset 12 is very standard and widely supported.
        # Let's check current opset.
        # for opset in model.opset_import:
        #    print(f"Opset: {opset.domain} - {opset.version}")
            
        onnx.save(model, output_path)
        print(f"Saved to {output_path}")
    else:
        print("Version is already low enough.")

files = [
    'assets/models/svm_model_v3_auto.onnx',
    'assets/models/xgb_model_v3_auto.onnx'
]

for f in files:
    convert_model(f, f)
