import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_moneyclassification/constants.dart';
import 'package:app_moneyclassification/pages/result_page.dart';
import 'package:app_moneyclassification/pages/account_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Fungsi untuk mengambil gambar (dari Galeri atau Kamera)
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _navigateToResultPage(String modelName) {
    if (_selectedImage == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          imageFile: _selectedImage!,
          modelName: modelName, // <- Kirim 'svm' atau 'xgboost'
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monerize"),
        automaticallyImplyLeading: false, // Hapus tombol kembali
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: kPrimaryColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Kotak Penampil Gambar
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: kLightColor, width: 2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: _selectedImage == null
                  ? const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 100,
                        color: kPrimaryColor,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            const SizedBox(height: 30),

            // 2. Tombol Galeri
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text("Open Gallery"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kPrimaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Tombol Kamera
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text("Open Camera"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kPrimaryColor,
                  side: const BorderSide(color: kPrimaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 4. Tombol Deteksi SVM
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Nonaktifkan tombol jika tidak ada gambar
                onPressed: _selectedImage == null
                    ? null
                    : () => _navigateToResultPage('svm'), // Kirim 'svm'
                child: const Text('Detect using SVM'),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Tombol Deteksi XGBoost
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Nonaktifkan tombol jika tidak ada gambar
                onPressed: _selectedImage == null
                    ? null
                    : () => _navigateToResultPage('xgboost'), // Kirim 'xgboost'
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey, // Warna berbeda agar jelas
                ),
                child: const Text('Detect using XGBoost'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
