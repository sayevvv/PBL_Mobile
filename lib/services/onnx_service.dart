import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class OnnxService {
  OrtSession? _svmSession;
  OrtSession? _xgbSession;

  // Scaler Params
  List<double>? _scalerMean;
  List<double>? _scalerScale;

  // Label Encoder Params
  List<String>? _classes;

  bool get isLoaded =>
      _svmSession != null && _xgbSession != null && _scalerMean != null;

  Future<void> loadModels() async {
    try {
      // 1. Initialize ONNX Runtime
      OrtEnv.instance.init();

      // 2. Load Models from Assets
      // ONNX Runtime needs file path, so we copy assets to temp dir
      final svmPath =
          await _copyAssetToLocal('assets/models/svm_model_v3_auto.onnx');
      final xgbPath =
          await _copyAssetToLocal('assets/models/xgb_model_v3_auto.onnx');

      final sessionOptions = OrtSessionOptions();

      // Fix: Wrap path in File object
      _svmSession = OrtSession.fromFile(File(svmPath), sessionOptions);
      _xgbSession = OrtSession.fromFile(File(xgbPath), sessionOptions);

      // 3. Load Parameters (Scaler & Encoder)
      await _loadParams();

      print("ONNX Models and Parameters loaded successfully.");
    } catch (e) {
      print("Error loading models: $e");
    }
  }

  Future<void> _loadParams() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/models/model_params.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      _scalerMean = List<double>.from(data['scaler']['mean']);
      _scalerScale = List<double>.from(data['scaler']['scale']);
      _classes = List<String>.from(data['label_encoder']['classes']);
    } catch (e) {
      print("Error loading model_params.json: $e");
    }
  }

  Future<String> awaitcopyAssetToLocal(String assetPath) async {
    return _copyAssetToLocal(assetPath);
  }

  Future<String> _copyAssetToLocal(String assetPath) async {
    final filename = assetPath.split('/').last;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');

    // Always overwrite to ensure we have the latest model (e.g. after updates/fixes)
    // if (await file.exists()) {
    //   return file.path;
    // }

    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Map<String, dynamic>> predict(List<double> features) async {
    if (!isLoaded) return {'error': 'Models not loaded'};

    try {
      // --- SVM Prediction ---
      // 1. Scale Features
      List<double> scaledFeatures = [];
      for (int i = 0; i < features.length; i++) {
        double val = (features[i] - _scalerMean![i]) / _scalerScale![i];
        scaledFeatures.add(val);
      }

      // 2. Run SVM Inference
      final svmRunOptions = OrtRunOptions();
      final svmInputs = {'float_input': _createOrtValue(scaledFeatures)};
      final svmOutputs = _svmSession!.run(svmRunOptions, svmInputs);

      // Fix: Conditional access and non-null cast
      final svmLabelIdx = (svmOutputs[0]?.value as List)[0] as int;
      final svmLabel = _classes![svmLabelIdx];

      // Fix: Safe release
      for (var out in svmOutputs) {
        out?.release();
      }

      // --- XGBoost Prediction ---
      final xgbRunOptions = OrtRunOptions();
      final xgbInputs = {'float_input': _createOrtValue(features)}; // Unscaled
      final xgbOutputs = _xgbSession!.run(xgbRunOptions, xgbInputs);

      final xgbLabelIdx = (xgbOutputs[0]?.value as List)[0] as int;
      final xgbLabel = _classes![xgbLabelIdx];

      for (var out in xgbOutputs) {
        out?.release();
      }

      return {
        'svm_prediction': svmLabel,
        'xgb_prediction': xgbLabel,
        'features_count': features.length
      };
    } catch (e) {
      print("Prediction Error: $e");
      return {'error': e.toString()};
    }
  }

  // Create Float32 Tensor [1, N_FEATURES]
  OrtValueTensor _createOrtValue(List<double> data) {
    final shape = [1, data.length];
    // Fix: Unused variable removed, direct usage
    return OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(data), shape);
  }

  void dispose() {
    _svmSession?.release();
    _xgbSession?.release();
    OrtEnv.instance.release();
  }
}
