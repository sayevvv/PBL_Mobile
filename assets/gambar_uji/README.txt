FOLDER GAMBAR UJI
=================

Letakkan file gambar uang kertas yang ingin diuji di folder ini.

Format yang didukung:
- .jpg / .jpeg
- .png
- .bmp
- .gif
- .tiff

Cara penggunaan:
1. Letakkan gambar-gambar uji di folder ini
2. Jalankan: python test_api.py
3. Script akan otomatis menguji SEMUA gambar di folder ini

Contoh struktur:
gambar_uji/
├── uang_50000_depan.jpg
├── uang_100000_depan.jpg
├── uang_20000_belakang.png
└── ...

Catatan:
- Pastikan server Flask (app.py) sedang berjalan
- Gambar akan diuji satu per satu dengan model yang dipilih (SVM/XGBoost)
- Hasil akan ditampilkan di terminal
