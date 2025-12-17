<p align="center">
  <img src="assets/logo/monerize.png" alt="Monerize Logo" width="150">
</p>

# Monerize

**Monerize** adalah aplikasi mobile berbasis Flutter yang dikembangkan untuk membantu tunanetra dan pengguna lainnya dalam mengenali nominal uang Rupiah secara cepat dan akurat menggunakan kecerdasan buatan (AI).

Aplikasi ini menggunakan model *Machine Learning* (SVM & XGBoost) yang berjalan secara offline (lokal) di perangkat, sehingga pengguna dapat melakukan deteksi kapan saja tanpa memerlukan koneksi internet.

## 🚀 Fitur Utama

### 1. Deteksi Uang (Money Detection)
*   **Offline First**: Menggunakan model ONNX (SVM & XGBoost) yang tertanam langsung di aplikasi.
*   **Dukungan Suara (TTS)**: Hasil deteksi dibacakan secara otomatis menggunakan fitur *Text-to-Speech* (TTS) bahasa Indonesia, sangat membantu bagi pengguna tunanetra.
*   **Fleksibel**: Mendukung input gambar dari Kamera (langsung) atau Galeri.
*   **Dual Model**: Pengguna dapat memilih antara algoritma SVM (*Support Vector Machine*) atau XGBoost untuk hasil prediksi.

### 2. Mode Tamu (Guest Mode)
*   Pengguna dapat langsung menggunakan fitur deteksi tanpa perlu mendaftar atau *login*.
*   Cocok untuk penggunaan cepat atau saat tidak ada koneksi internet.
*   *Catatan: Riwayat deteksi tidak tersimpan dalam mode ini.*

### 3. Manajemen Akun & Riwayat
*   **Autentikasi Aman**: Login dan Register menggunakan Supabase Auth.
*   **Riwayat Deteksi**: Menyimpan hasil deteksi sebelumnya (nominal, tanggal, model yang digunakan) ke *cloud database* (Supabase).
*   **Sinkronisasi**: Data riwayat dapat diakses kembali saat pengguna login di perangkat lain.

## 🛠️ Cara Kerja Aplikasi

Aplikasi ini bekerja dengan alur sebagai berikut:

1.  **Input Gambar**: Pengguna mengambil foto uang atau memilih dari galeri.
2.  **Preprocessing**: Gambar diubah ukurannya dan diesktrasikan fitur-fiturnya (*feature extraction*) agar sesuai dengan format input model AI.
3.  **Inference (AI)**:
    *   Data gambar dikirim ke `OnnxService`.
    *   Model (SVM atau XGBoost) memproses data dan memberikan prediksi label (misal: "100000").
4.  **Output**:
    *   Aplikasi menampilkan nominal uang di layar.
    *   Sistem suara membacakan hasil: *"Terdeteksi uang senilai seratus ribu rupiah"*.
    *   Jika pengguna login, data disimpan ke database.

## 📂 Struktur Proyek

Berikut adalah gambaran singkat struktur folder aplikasi (di dalam folder `lib/`):

*   **`main.dart`**: Titik awal aplikasi, konfigurasi tema, dan routing.
*   **`constants.dart`**: Menyimpan konfigurasi global seperti warna tema dan API Key.
*   **`pages/`**: Berisi halaman-halaman antarmuka pengguna (UI).
    *   `onboarding_page.dart`: Halaman perkenalan dan pemilihan mode (Login/Tamu).
    *   `login_page.dart` / `register_page.dart`: Halaman autentikasi.
    *   `detection_page.dart`: Halaman utama untuk mengambil gambar.
    *   `result_page.dart`: Halaman hasil yang menjalankan proses AI.
    *   `account_page.dart`: Halaman profil dan riwayat deteksi.
*   **`services/`**: Berisi logika bisnis utama.
    *   `onnx_service.dart`: Menangani pemuatan model AI dan proses prediksi.
    *   `preprocessing_service.dart`: Mengolah gambar mentah menjadi format matriks yang bisa dibaca AI.
    *   `auth_service.dart`: Menangani logika komunikasi dengan Supabase Auth.

## 💻 Teknologi yang Digunakan

*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **Machine Learning**: ONNX Runtime (Model SVM & XGBoost)
*   **Backend / Database**: [Supabase](https://supabase.com/)
*   **Text-to-Speech**: `flutter_tts`
*   **State Management**: `setState` & `FutureBuilder` (Native Flutter)

## 📦 Cara Menjalankan

1.  Pastikan **Flutter SDK** sudah terinstal.
2.  Clone repository ini.
3.  Jalankan perintah `flutter pub get` untuk mengunduh dependensi.
4.  Jalankan aplikasi di emulator atau perangkat fisik dengan `flutter run`.

---
*Dibuat untuk memenuhi tugas PBL (Project Based Learning) Mobile Development.*
