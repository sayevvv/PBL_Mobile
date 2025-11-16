import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app_moneyclassification/constants.dart';

class ResultPage extends StatefulWidget {
  final File imageFile;
  final String modelName; // <- Ini sudah benar

  const ResultPage({
    super.key,
    required this.imageFile,
    required this.modelName, // <- Ini sudah benar
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  String _predictionResult = "Menganalisis gambar...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _uploadAndPredict();
  }

  Future<void> _uploadAndPredict() async {
    try {
      final imageBytes = await widget.imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Payload ini menggunakan 'modelName' yang dikirim
      final payload = json.encode({
        'image': base64Image,
        'model': widget.modelName // <- Ini sudah benar
      });

      var uri = Uri.parse(BACKEND_URL);

      var response = await http.post(
        uri,
        headers: { 'Content-Type': 'application/json' },
        body: payload,
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        String prediction = jsonResponse['prediction'];
        String modelUsed = jsonResponse['model_used'];
        setState(() {
          _predictionResult = "Prediksi: Rp $prediction\n(Model: $modelUsed)";
        });
      } else {
        setState(() {
          _predictionResult = "Error: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _predictionResult = "Error: Gagal terhubung ke server.\n${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI Halaman Hasil tidak berubah) ...
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Deteksi"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              _isLoading
                  ? const Column(
                children: [
                  CircularProgressIndicator(color: kPrimaryColor),
                  SizedBox(height: 20),
                  Text("Menganalisis...", style: TextStyle(fontSize: 18)),
                ],
              )
                  : Text(
                _predictionResult,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _predictionResult.startsWith("Error")
                      ? Colors.red
                      : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Deteksi Gambar Lain'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}