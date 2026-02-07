import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFECF1FD),
              Color(0xFFDFF9FB),
              Color(0xFFBFF2BF),
              Color(0xFF9CD69C),
              Color(0xFF376834),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Forest background at the bottom
            Positioned(
              bottom: 0,
              left: -50,
              right: 0,
              child: Image.asset(
                'assets/images/forest.png', // Replace with your forest image path
                fit: BoxFit.cover,
                height: height * 0.85, // Adjust height dynamically,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Top bar with profile picture
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.05,
                      vertical: height * 0.02,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                        'Welcome!',
                        style: TextStyle(
                          color: Color(0xFF010101),
                          fontSize: 35,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                        GestureDetector(
                          onTap: () {
                            // Add navigation or action for profile
                            Navigator.pushNamed(context, '/profile');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile tapped')),
                            );
                          },
                          child: CircleAvatar(
                            radius: width * 0.10,
                            backgroundColor: const Color.fromRGBO(241, 239, 239, 1),
                            backgroundImage: AssetImage('assets/images/profile.png'), // Replace with your profile image path
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: height * 0.02),
                  // Subtitle text
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.1),
                    child: const Text(
                      'Your footprint tells a story. Let’s make it one of responsibility, awareness and positive change.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF010101),
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.05),
                  // Carbon Calculator button
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/carbon_calculator');
                      // Add navigation or action for Carbon Calculator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Carbon Calculator tapped')),
                      );
                    },
                    child: Container(
                      width: width * 0.7,
                      height: height * 0.08,
                      decoration: BoxDecoration(
                        color: const Color(0xFF115925),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3F000000),
                            blurRadius: 4,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Carbon Calculator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.03),
                  // Dashboard button
                  GestureDetector(
                    onTap: () {
                      // Add navigation or action for Dashboard
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dashboard tapped')),
                      );
                    },
                    child: Container(
                      width: width * 0.7,
                      height: height * 0.08,
                      decoration: BoxDecoration(
                        color: const Color(0xFF115925),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3F000000),
                            blurRadius: 4,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}