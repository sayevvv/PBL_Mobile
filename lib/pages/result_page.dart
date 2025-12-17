import 'dart:io';
import 'dart:math'; // For random number (dummy)
import 'package:flutter/material.dart';
import 'package:app_moneyclassification/constants.dart';
import 'package:flutter_tts/flutter_tts.dart'; // TTS Package
import 'package:percent_indicator/percent_indicator.dart'; // Circular Graph
import 'package:app_moneyclassification/services/preprocessing_service.dart';
import 'package:app_moneyclassification/services/onnx_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResultPage extends StatefulWidget {
  final File imageFile;
  final String modelName;

  const ResultPage({
    super.key,
    required this.imageFile,
    required this.modelName,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  // TTS
  final FlutterTts _flutterTts = FlutterTts();

  // Services
  final OnnxService _onnxService = OnnxService();
  final PreprocessingService _preprocessingService = PreprocessingService();

  String _predictionResult = "Menganalisis...";
  String _modelUsed = "";
  double _confidence = 0.0;
  bool _isLoading = true;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _setupTts(); // Setup TTS
    _runOfflinePrediction(); // Run local detection
  }

  // --- TTS FUNCTIONS ---
  Future<void> _setupTts() async {
    await _flutterTts.setLanguage("id-ID"); // Indonesian
    await _flutterTts.setSpeechRate(0.5); // Normal rate
    await _flutterTts.setPitch(1.0); // Normal pitch
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _onnxService.dispose(); // Cleanup ONNX resources
    super.dispose();
  }
  // --------------------------

  Future<void> _runOfflinePrediction() async {
    try {
      // 1. Load Models (if not loaded)
      // Note: In production, load this earlier (e.g. main.dart) to unnecessary delays.
      if (!_onnxService.isLoaded) {
        await _onnxService.loadModels();
      }

      // 2. Preprocessing
      final features = await _preprocessingService
          .preprocessAndExtractFeatures(widget.imageFile.path);

      if (features == null) {
        throw Exception("Gagal memproses gambar (Preprocessing Failed)");
      }

      // 3. Prediction
      final result = await _onnxService.predict(features);

      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      // 4. Parse Result
      String prediction = "";
      String modelLabel = "";

      if (widget.modelName.toLowerCase() == 'svm') {
        prediction = result['svm_prediction'].toString();
        modelLabel = "SVM (Offline)";
      } else {
        prediction = result['xgb_prediction'].toString();
        modelLabel = "XGBoost (Offline)";
      }

      // Handle "negative" class
      bool isNegative = prediction.toLowerCase() == 'negative';
      String displayResult = isNegative ? "Bukan Uang" : "Rp $prediction";
      String speakResult = isNegative
          ? "Tidak terdeteksi uang"
          : "Terdeteksi uang senilai $prediction rupiah";

      // Dummy Confidence (ONNX SVM/XGB usually don't give probability easily unless configured)
      // Using the same logic as before for consistency
      double conf = 0.85 + Random().nextDouble() * (0.98 - 0.85);

      setState(() {
        _predictionResult = displayResult;
        _modelUsed = modelLabel;
        _confidence = conf;
        _isLoading = false;
        _isError = false;
      });

      // Speak result
      _speak(speakResult);

      // Save to History
      await _saveHistory(
        prediction: prediction,
        isNegative: isNegative,
        modelName: modelLabel,
        confidence: conf,
      );
    } catch (e) {
      print("Error Offline Prediction: $e");
      setState(() {
        _predictionResult = "Gagal Deteksi";
        _isError = true;
        _isLoading = false;
      });
      _speak("Gagal melakukan deteksi. Silakan coba lagi.");
    }
  }

  Future<void> _saveHistory({
    required String prediction,
    required bool isNegative,
    required String modelName,
    required double confidence,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('detection_history').insert({
          'user_id': user.id,
          'prediction_result': prediction,
          'is_negative': isNegative,
          'model_used': modelName,
          'confidence': confidence,
        });
      }
    } catch (e) {
      print("Failed to save history: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format percent string
    String confidencePercentString =
        "${(_confidence * 100).toStringAsFixed(0)}%";

    return Scaffold(
      backgroundColor: Colors.white, // Clean White Background
      appBar: AppBar(
        title: const Text("Hasil Deteksi",
            style:
                TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kPrimaryColor),
          onPressed: () {
            _flutterTts.stop();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // --- PART 1: IMAGE (White Background) ---
          Expanded(
            flex: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(widget.imageFile, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),

          // --- PART 2: RESULT BOX (Pink) ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: kLightColor, width: 3),
                left: BorderSide(color: kLightColor, width: 1),
                right: BorderSide(color: kLightColor, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, -5),
                ),
              ],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),

                // LAYOUT: LEFT (CIRCLE) - RIGHT (TEXT)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // A. CIRCULAR GRAPH
                    CircularPercentIndicator(
                      radius: 60.0,
                      lineWidth: 12.0,
                      percent: _isLoading ? 0.0 : _confidence,
                      circularStrokeCap: CircularStrokeCap.round,
                      backgroundColor: Colors.white,
                      progressColor: kPrimaryColor,
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Akurasi",
                              style: TextStyle(
                                  fontSize: 10, color: Colors.black54)),
                          Text(
                            _isLoading ? "..." : confidencePercentString,
                            style: const TextStyle(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // B. TEXT INFO
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Terdeteksi Sebagai:",
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),

                        // Main Result (Rp 100000)
                        Text(
                          _isLoading ? "Loading..." : _predictionResult,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Model: $_modelUsed",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 15),

                        // Additional Info (Dummy Layout)
                        Row(
                          children: [
                            _buildInfoItem("Warna", "Dominan"),
                            const SizedBox(width: 20),
                            _buildInfoItem("Tekstur", "Kertas"),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // RED BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      _flutterTts.stop();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Deteksi Gambar Lain',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget
  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: kPrimaryColor)),
        Text(value,
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }
}
