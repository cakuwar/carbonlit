import 'package:flutter/material.dart';

class AccessPage extends StatelessWidget {
  const AccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Scale factors based on Figma canvas (448x692)
    final scaleX = size.width / 448;
    final scaleY = size.height / 692;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: Color(0xFFE8E8E8)), // Gray background
        child: Stack(
          children: [
            // Green wave at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipPath(
                clipper: BottomWaveClipper(),
                child: Container(
                  height: 120 * scaleY,
                  color: const Color(0xFF115925),
                ),
              ),
            ),

            // Mission Zero Logo (centered at top)
            Positioned(
              left: 0,
              right: 0,
              top: 80 * scaleY,
              child: Center(
                child: Image.asset(
                  'assets/images/missinzero_logo.png',
                  width: 300 * scaleX,
                  height: 300 * scaleY,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // STUDENT / STAFF Button
            Positioned(
              left: 60 * scaleX,
              right: 60 * scaleX,
              top: 320 * scaleY,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/auth'),
                child: Container(
                  height: 48 * scaleY,
                  decoration: ShapeDecoration(
                    color: const Color(0xFF115925),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    shadows: const [
                      BoxShadow(
                        color: Color(0x3F000000),
                        blurRadius: 4,
                        offset: Offset(0, 4),
                        spreadRadius: 0,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20 * scaleX,
                      ),
                      SizedBox(width: 12 * scaleX),
                      const Text(
                        'STUDENT  /  STAFF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ADMIN Button
            Positioned(
              left: 60 * scaleX,
              right: 60 * scaleX,
              top: 390 * scaleY,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/auth'),
                child: Container(
                  height: 48 * scaleY,
                  decoration: ShapeDecoration(
                    color: const Color(0xFF115925),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    shadows: const [
                      BoxShadow(
                        color: Color(0x3F000000),
                        blurRadius: 4,
                        offset: Offset(0, 4),
                        spreadRadius: 0,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20 * scaleX,
                      ),
                      SizedBox(width: 12 * scaleX),
                      const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
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
    );
  }
}

// Custom clipper for bottom green wave
class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.4);
    
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.1,
      size.width * 0.5,
      size.height * 0.3,
    );
    
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.5,
      size.width,
      size.height * 0.2,
    );
    
    path.lineTo(size.width, size.height);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}