import 'package:flutter/material.dart';

class OpeningPage extends StatelessWidget {
  const OpeningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Scale factors based on Figma canvas (453x792)
    final scaleX = size.width / 453;
    final scaleY = size.height / 792;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Color(0xFF115925)),
        child: Stack(
          children: [
            // Gray bottom section (from Figma)
            Positioned(
              left: 0,
              top: 387.46 * scaleY,
              child: Container(
                width: 453 * scaleX,
                height: 405 * scaleY,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.elliptical(200, 90),
                    topRight: Radius.elliptical(200, 90),
                  ),
                ),
              ),
            ),
            // Logo image (from Figma)
            Positioned(
              left: -70.70 * scaleX,
              top: 71.68 * scaleY,
              child: SizedBox(
                width: 594.40 * scaleX,
                height: 594.40 * scaleY,
                child: Center(
                  child: Image.asset(
                    'assets/images/carbonlit_logo.png',
                    width: 500 * scaleX,
                    height: 500 * scaleY,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Get Started button (from Figma)
            Positioned(
              left: 14.48 * scaleX,
              top: 697 * scaleY,
              child: Container(
                width: 439 * scaleX,
                padding: EdgeInsets.only(top: 16 * scaleY, right: 16 * scaleX),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/access'),
                        child: Container(
                          height: 56 * scaleY,
                          padding: EdgeInsets.symmetric(horizontal: 32 * scaleX, vertical: 12 * scaleY),
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFF8F9F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF0E5A54),
                                  fontSize: 16,
                                  fontFamily: 'Figtree',
                                  fontWeight: FontWeight.w600,
                                  height: 1.60,
                                  letterSpacing: -0.19,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

