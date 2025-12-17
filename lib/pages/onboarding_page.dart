import 'package:flutter/material.dart';
import 'package:app_moneyclassification/constants.dart';
import 'package:app_moneyclassification/pages/login_page.dart';
import 'package:app_moneyclassification/pages/detection_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Konten Halaman (bisa digeser)
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: const [
                  // Halaman 1
                  OnboardingContent(
                    title: "Welcome To\nMoney Categorizer",
                    imagePath: 'assets/welcome/1.png',
                  ),
                  // Halaman 2
                  OnboardingContent(
                    title: "Understand your money\nin seconds.",
                    imagePath: 'assets/welcome/2.png',
                  ),
                ],
              ),
            ),

            // Indikator Titik (Dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) => buildDot(index, context)),
            ),
            const SizedBox(height: 20),

            // Tombol "Next" atau "Get Started"
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == 0) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                      );
                    } else {
                      // Pindah ke Halaman Login
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()),
                      );
                    }
                  },
                  child: Text(_currentPage == 0 ? "Next" : "Get started"),
                ),
              ),
            ),
            if (_currentPage == 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DetectionPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPrimaryColor, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Continue as Guest",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget untuk titik indikator
  AnimatedContainer buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 5),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? kPrimaryColor : Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// Widget untuk konten di dalam PageView
class OnboardingContent extends StatelessWidget {
  const OnboardingContent({
    super.key,
    required this.title,
    this.imageIcon,
    this.imagePath,
  });

  final String title;
  final IconData? imageIcon;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            "Monerize",
            style: TextStyle(
              color: kPrimaryColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: imagePath != null
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Image.asset(
                          imagePath!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(
                        imageIcon ?? Icons.error,
                        size: 150,
                        color: kPrimaryColor.withOpacity(0.7),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
