import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'dart:io';

class PreprocessingService {
  // Constants matching Python
  static const int IMG_SIZE = 250;
  static const int H_BINS = 180;
  static const int S_BINS = 256;
  static const int LBP_POINTS = 24;
  static const int LBP_RADIUS = 8;
  static const int LBP_BINS = 26; // 24 + 2

  // --- Main Entry Point ---
  Future<List<double>?> preprocessAndExtractFeatures(String imagePath) async {
    try {
      print("Processing image at: $imagePath");
      final bytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        print("Error: Failed to decode image. Bytes length: ${bytes.length}");
        return null;
      }

      // Fix: Handle EXIF orientation
      image = img.bakeOrientation(image);

      // 1. Resize & Blur
      image = img.copyResize(image, width: IMG_SIZE, height: IMG_SIZE);
      // Fix: OpenCV (5,5) kernel -> Radius 2 in generic terms (sigma ~1.1)
      image = img.gaussianBlur(image, radius: 2);

      // --- V3 IMPLEMENTATION: Grayscale & Masking ---
      // 1. Convert to Grayscale (Rec 601)
      img.Image grayImage = _toGrayscale(image);

      // 2. Create Mask (Otsu + Inverse Binary)
      img.Image mask = _createBinaryMask(grayImage);

      // 3. Color Features (HSV) - MASKED
      List<double> colorFeatures = _extractColorFeatures(image, mask);

      // 4. Texture Features (LBP) - On Gray
      List<double> textureFeatures = _extractLBPFeatures(grayImage);

      // 5. Shape Features (Hu Moments) - On Mask
      List<double> shapeFeatures = _extractHuMoments(mask);

      // Combine
      final features = [...colorFeatures, ...textureFeatures, ...shapeFeatures];

      // DEBUG LOGGING
      /*
      print("Features Count: ${features.length}");
      print("Color Sample: ${colorFeatures.sublist(0, 5)}");
      print("Texture Sample: ${textureFeatures.sublist(0, 5)}");
      print("Shape Sample: ${shapeFeatures}");
      */

      return features;
    } catch (e) {
      print("Error in preprocessing: $e");
      return null;
    }
  }

  // --- Helper: Manual Grayscale (Rec. 601 / OpenCV Standard) ---
  img.Image _toGrayscale(img.Image src) {
    final gray =
        img.Image(width: src.width, height: src.height, numChannels: 1);
    for (var pixel in src) {
      // OpenCV BGR2GRAY: 0.299*R + 0.587*G + 0.114*B
      // image package provides R, G, B accessors
      double y = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      gray.setPixelR(pixel.x, pixel.y, y.round());
    }
    return gray;
  }

  // --- Feature 1: Color (HSV Histogram) V3: MASKED ---
  List<double> _extractColorFeatures(img.Image image, img.Image mask) {
    List<double> hHist = List.filled(H_BINS, 0.0);
    List<double> sHist = List.filled(S_BINS, 0.0);

    for (var pixel in image) {
      // CHECK MASK: If mask pixel is black (0), skip (Background)
      int mx = pixel.x;
      int my = pixel.y;

      if (mx >= mask.width || my >= mask.height) continue;
      if (mask.getPixel(mx, my).r == 0) continue;

      // Get HSV
      double r = pixel.r / 255.0;
      double g = pixel.g / 255.0;
      double b = pixel.b / 255.0;

      double cmax = math.max(r, math.max(g, b));
      double cmin = math.min(r, math.min(g, b));
      double delta = cmax - cmin;

      // Hue calculation
      double h = 0;
      if (delta == 0) {
        h = 0;
      } else if (cmax == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (cmax == g) {
        h = 60 * (((b - r) / delta) + 2);
      } else {
        h = 60 * (((r - g) / delta) + 4);
      }
      if (h < 0) h += 360;

      // Saturation calculation
      double s = (cmax == 0) ? 0 : (delta / cmax);

      // Map to OpenCV ranges
      // Fix: Use floor() to match standard binning behavior (0.9 -> bin 0)
      int cvH = (h / 2).floor().clamp(0, 179); // 0-179
      int cvS = (s * 255).floor().clamp(0, 255); // 0-255

      hHist[cvH]++;
      sHist[cvS]++;
    }

    // MinMax Normalize (0-1)
    return [..._normalizeMinMax(hHist), ..._normalizeMinMax(sHist)];
  }

  // --- Feature 2: Texture (LBP Uniform) ---
  List<double> _extractLBPFeatures(img.Image gray) {
    List<double> hist = List.filled(LBP_BINS, 0.0);
    int width = gray.width;
    int height = gray.height;

    // LUT for uniformity
    // We can compute uniform label on fly: number of transitions <= 2

    // We need circular neighbors at Radius 8, Points 24
    // Using bilinear interpolation

    for (int y = LBP_RADIUS; y < height - LBP_RADIUS; y++) {
      for (int x = LBP_RADIUS; x < width - LBP_RADIUS; x++) {
        double center = gray.getPixel(x, y).r.toDouble();
        int pattern = 0;

        // Calculate bit pattern (iterate neighbors)
        // Standard LBP starts at angle 0 (Right) and goes counter-clockwise?
        // Skimage: "starts at (R, 0)"

        // Pre-calculating offsets to avoid trig in loop or use lookup?
        // Let's rely on loop for clarity

        int transitions = 0;
        int ones = 0;
        List<int> bits = [];

        for (int p = 0; p < LBP_POINTS; p++) {
          double angle = 2 * math.pi * p / LBP_POINTS;
          // Offset: x + R cos, y - R sin (image coord y is down, but std math is up. standard LBP usually sin is down?)
          // Skimage code: r = -R * sin(angle), c = R * cos(angle)
          double rx = x + LBP_RADIUS * math.cos(angle);
          double ry = y - LBP_RADIUS * math.sin(angle);

          double val = _getBilinearPixel(gray, rx, ry, width, height);

          int bit = (val >= center) ? 1 : 0;
          bits.add(bit);
        }

        // Check Uniformity
        for (int i = 0; i < LBP_POINTS; i++) {
          int current = bits[i];
          int next = bits[(i + 1) % LBP_POINTS];
          if (current != next) transitions++;
        }

        int label;
        if (transitions <= 2) {
          // Uniform: label = number of 1s
          label = bits.fold(0, (sum, bit) => sum + bit);
        } else {
          // Non-uniform
          label = LBP_POINTS + 1;
        }

        hist[label]++;
      }
    }

    return _normalizeMinMax(hist);
  }

  double _getBilinearPixel(img.Image img, double x, double y, int w, int h) {
    // Basic bilinear interpolation
    int x1 = x.floor();
    int y1 = y.floor();
    int x2 = x1 + 1;
    int y2 = y1 + 1;

    if (x1 < 0 || x1 >= w - 1 || y1 < 0 || y1 >= h - 1) return 0;

    double p11 = img.getPixel(x1, y1).r.toDouble();
    double p12 = img.getPixel(x1, y2).r.toDouble();
    double p21 = img.getPixel(x2, y1).r.toDouble();
    double p22 = img.getPixel(x2, y2).r.toDouble();

    double dx = x - x1;
    double dy = y - y1;

    return (1 - dx) * (1 - dy) * p11 +
        dx * (1 - dy) * p21 +
        (1 - dx) * dy * p12 +
        dx * dy * p22;
  }

  // --- Feature 3: Shape (Hu Moments) ---
  List<double> _extractHuMoments(img.Image binary) {
    // 1. Otsu Thresholding (Done outside)
    // img.Image binary = _otsuThreshold(gray);

    // 2. Moments
    Map<String, double> mom = _calculateMoments(binary);

    // 3. Hu Moments from central normalized moments
    // eta_pq = mu_pq / mu_00^((p+q)/2 + 1)

    double mu00 = mom['mu00']!;
    if (mu00 == 0) return List.filled(7, 0.0);

    double normFactor(int p, int q) =>
        math.pow(mu00, (p + q) / 2 + 1) as double;

    double n20 = mom['mu20']! / normFactor(2, 0);
    double n02 = mom['mu02']! / normFactor(0, 2);
    double n11 = mom['mu11']! / normFactor(1, 1);
    double n30 = mom['mu30']! / normFactor(3, 0);
    double n12 = mom['mu12']! / normFactor(1, 2);
    double n21 = mom['mu21']! / normFactor(2, 1);
    double n03 = mom['mu03']! / normFactor(0, 3);

    // Hu Invariants formulae
    double h1 = n20 + n02;
    double h2 = math.pow(n20 - n02, 2) + 4 * math.pow(n11, 2) as double;
    double h3 =
        math.pow(n30 - 3 * n12, 2) + math.pow(3 * n21 - n03, 2) as double;
    double h4 = math.pow(n30 + n12, 2) + math.pow(n21 + n03, 2) as double;

    double h5 = (n30 - 3 * n12) *
            (n30 + n12) *
            (math.pow(n30 + n12, 2) - 3 * math.pow(n21 + n03, 2)) +
        (3 * n21 - n03) *
            (n21 + n03) *
            (3 * math.pow(n30 + n12, 2) - math.pow(n21 + n03, 2));

    double h6 =
        (n20 - n02) * (math.pow(n30 + n12, 2) - math.pow(n21 + n03, 2)) +
            4 * n11 * (n30 + n12) * (n21 + n03);

    double h7 = (3 * n21 - n03) *
            (n30 + n12) *
            (math.pow(n30 + n12, 2) - 3 * math.pow(n21 + n03, 2)) -
        (n30 - 3 * n12) *
            (n21 + n03) *
            (3 * math.pow(n30 + n12, 2) - math.pow(n21 + n03, 2));

    List<double> hu = [h1, h2, h3, h4, h5, h6, h7];

    // Log scaling (Log10)
    // -sign(h) * log10(abs(h) + 1e-7)
    return hu.map((h) {
      return -1 * h.sign * (math.log(h.abs() + 1e-7) / math.ln10);
    }).toList();
  }

  img.Image _createBinaryMask(img.Image gray) {
    // Calculate histogram
    List<int> hist = List.filled(256, 0);
    for (var p in gray) hist[p.r.toInt()]++;

    // Total pixels
    int total = gray.width * gray.height;

    double sum = 0;
    for (int i = 0; i < 256; i++) sum += i * hist[i];

    double sumB = 0;
    int wB = 0;
    int wF = 0;

    double varMax = 0;
    int threshold = 0;

    for (int t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) continue;

      wF = total - wB;
      if (wF == 0) break;

      sumB += t * hist[t];

      double mB = sumB / wB;
      double mF = (sum - sumB) / wF;

      // Between Class Variance
      double varBetween = wB.toDouble() * wF.toDouble() * (mB - mF) * (mB - mF);

      if (varBetween > varMax) {
        varMax = varBetween;
        threshold = t;
      }
    }

    // --- ADAPTIVE MASKING LOGIC (V3 AUTO) ---
    // 1. Create Initial Binary Mask (Standard Otsu: > Threshold => 255)
    img.Image binary = img.Image(width: gray.width, height: gray.height);
    for (var p in gray) {
      int val = p.r.toInt();
      // Standard Binary: > Thresh => 255 (White), <= Thresh => 0 (Black)
      int binVal = (val > threshold) ? 255 : 0;
      binary.setPixel(p.x, p.y, img.ColorRgb8(binVal, binVal, binVal));
    }

    // 2. Border Analysis on the MASK (Check if Background is White)
    int w = binary.width;
    int h = binary.height;
    int borderSize = (math.min(w, h) * 0.05).toInt(); // 5% border

    int whitePixels = 0;
    int totalBorderPixels = 0;

    // Helper to check pixel
    bool isWhite(int x, int y) => binary.getPixel(x, y).r == 255;

    // Top Slice
    for (int y = 0; y < borderSize; y++) {
      for (int x = 0; x < w; x++) {
        if (isWhite(x, y)) whitePixels++;
        totalBorderPixels++;
      }
    }
    // Bottom Slice
    for (int y = h - borderSize; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (isWhite(x, y)) whitePixels++;
        totalBorderPixels++;
      }
    }
    // Left Slice (matching Python's mask[:, 0:borderSize])
    // Range y: [0, h) -> Includes corners (overlap with top/bottom)
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < borderSize; x++) {
        if (isWhite(x, y)) whitePixels++;
        totalBorderPixels++;
      }
    }
    // Right Slice (matching Python's mask[:, w-borderSize:w])
    // Range y: [0, h) -> Includes corners (overlap with top/bottom)
    for (int y = 0; y < h; y++) {
      for (int x = w - borderSize; x < w; x++) {
        if (isWhite(x, y)) whitePixels++;
        totalBorderPixels++;
      }
    }

    double whiteRatio = (totalBorderPixels > 0)
        ? whitePixels.toDouble() / totalBorderPixels.toDouble()
        : 0.0;

    // 3. Logic: If >50% of border is White => Background is White => INVERT
    bool needInvert = whiteRatio > 0.5;

    print(
        "Otsu Thresh: $threshold, Border(5%): $whitePixels/$totalBorderPixels ($whiteRatio), Invert: $needInvert");

    if (needInvert) {
      // Invert the mask
      for (var p in binary) {
        int v = p.r.toInt();
        int inv = (v == 255) ? 0 : 255;
        binary.setPixel(p.x, p.y, img.ColorRgb8(inv, inv, inv));
      }
    }

    return binary;
  }

  Map<String, double> _calculateMoments(img.Image bin) {
    double m00 = 0,
        m10 = 0,
        m01 = 0,
        m20 = 0,
        m11 = 0,
        m02 = 0,
        m30 = 0,
        m21 = 0,
        m12 = 0,
        m03 = 0;

    for (var p in bin) {
      double val = p.r.toDouble(); // 0 or 255
      if (val == 0) continue; // Only consider white pixels? Wait
      // App.py: cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
      // Returns 'thresh' image. 'moments = cv2.moments(thresh)'
      // Typically moments are calculated on non-zero pixels.
      // Since we did Inverted: >T becomes 0 (black), <T becomes 255 (white).
      // So we are calculating shape of the 'dark' objects (background? or subject if subject is dark).

      // Normalized value for calculation? usually just pixel value (255) or binary (1).
      // OpenCV moments use the pixel value as weight.

      double x = p.x.toDouble();
      double y = p.y.toDouble();

      m00 += val;
      m10 += x * val;
      m01 += y * val;
      m20 += x * x * val;
      m11 += x * y * val;
      m02 += y * y * val;
      m30 += x * x * x * val;
      m21 += x * x * y * val;
      m12 += x * y * y * val;
      m03 += y * y * y * val;
    }

    // Central moments
    double cx = m10 / m00;
    double cy = m01 / m00;

    double mu00 = m00;
    // mu_pq = sum( (x-cx)^p * (y-cy)^q * val )

    // Re-literating to match OpenCV 'moments' function output for central moments
    // Or use the formula:
    // mu20 = m20 - cx * m10
    // mu02 = m02 - cy * m01
    // mu11 = m11 - cx * m01
    // etc.

    double mu20 = m20 - cx * m10;
    double mu02 = m02 - cy * m01;
    double mu11 = m11 - cx * m01;

    double mu30 = m30 - 3 * cx * m20 + 2 * cx * cx * m10;
    double mu03 = m03 - 3 * cy * m02 + 2 * cy * cy * m01;
    double mu21 = m21 - 2 * cx * m11 - cy * m20 + 2 * cx * cx * m01;
    double mu12 = m12 - 2 * cy * m11 - cx * m02 + 2 * cy * cy * m10;

    return {
      'mu00': mu00,
      'mu20': mu20,
      'mu02': mu02,
      'mu11': mu11,
      'mu30': mu30,
      'mu03': mu03,
      'mu21': mu21,
      'mu12': mu12
    };
  }

  List<double> _normalizeMinMax(List<double> list) {
    if (list.isEmpty) return list;
    double min = list.reduce(math.min);
    double max = list.reduce(math.max);
    double range = max - min;

    if (range == 0) return List.filled(list.length, 0.0);

    return list.map((e) => (e - min) / range).toList();
  }
}
