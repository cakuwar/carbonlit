import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'signup_page.dart';

class AuthenticationPage extends StatefulWidget {
  const AuthenticationPage({super.key});

  @override
  State<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Scale factors based on Figma canvas (453x804)
    final scaleX = size.width / 453;
    final scaleY = size.height / 804;

    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              gradient: const LinearGradient(
                begin: Alignment(0.50, -0.00),
                end: Alignment(0.50, 1.00),
                colors: [Color(0xFF115925), Color(0xFFD3D3D3)],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: Stack(
              children: [
                // Background earth image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/earth.png',
                    fit: BoxFit.cover,
                  ),
                ),

                // Scrollable content
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24 * scaleX),
                      child: Column(
                        children: [
                          SizedBox(height: 10 * scaleY),

                          // Back button row
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 10 * scaleY),

                          // Logos - bigger size
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/missinzero_logo.png',
                                height: 150 * scaleY,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: 24 * scaleX),
                              Image.asset(
                                'assets/images/carbonlit_logo.png',
                                height: 150 * scaleY,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),

                          SizedBox(height: 24 * scaleY),

                          // White card
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(24 * scaleX),
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Title
                                const Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 32,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    height: 1.30,
                                    letterSpacing: -0.64,
                                  ),
                                ),
                                SizedBox(height: 12 * scaleY),

                                // Toggle text - Navigate to Sign Up page
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Don't have an account?",
                                      style: TextStyle(
                                        color: Color(0xFF6C7278),
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                        height: 1.40,
                                        letterSpacing: -0.12,
                                      ),
                                    ),
                                    SizedBox(width: 6 * scaleX),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const SignUpPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          color: Color(0xFF4D81E7),
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                          height: 1.40,
                                          letterSpacing: -0.12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24 * scaleY),

                                // Email field
                                _buildInputField(
                                  label: 'Email',
                                  controller: _emailController,
                                  hintText: 'Enter your email',
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                ),
                                SizedBox(height: 16 * scaleY),

                                // Password field
                                _buildInputField(
                                  label: 'Password',
                                  controller: _passwordController,
                                  hintText: 'Enter your password',
                                  isPassword: true,
                                  scaleX: scaleX,
                                  scaleY: scaleY,
                                ),
                                SizedBox(height: 16 * scaleY),

                                // Remember me & Forgot password
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            onChanged: (value) {
                                              setState(() => _rememberMe = value ?? false);
                                            },
                                            activeColor: const Color(0xFF4D81E7),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                              side: const BorderSide(
                                                color: Color.fromRGBO(0, 0, 0, 1),
                                                width: 4,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 5 * scaleX),
                                        const Text(
                                          'Remember me',
                                          style: TextStyle(
                                            color: Color(0xFF6C7278),
                                            fontSize: 12,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w500,
                                            height: 1.50,
                                            letterSpacing: -0.12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        // TODO: Implement forgot password
                                      },
                                      child: const Text(
                                        'Forgot Password ?',
                                        style: TextStyle(
                                          color: Color(0xFF4D81E7),
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                          height: 1.40,
                                          letterSpacing: -0.12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24 * scaleY),

                                // Error message
                                if (authProvider.error != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline,
                                            color: Colors.red.shade600, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            authProvider.error!,
                                            style: TextStyle(
                                                color: Colors.red.shade700, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Log In button
                                GestureDetector(
                                  onTap: authProvider.isLoading
                                      ? null
                                      : () => _handleAuth(authProvider),
                                  child: Container(
                                    width: double.infinity,
                                    height: 48,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: ShapeDecoration(
                                      color: const Color(0xFF115925),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      shadows: const [
                                        BoxShadow(
                                          color: Color(0x7A253EA7),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                          spreadRadius: 0,
                                        )
                                      ],
                                    ),
                                    child: Center(
                                      child: authProvider.isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                        Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Log In',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w500,
                                                height: 1.40,
                                                letterSpacing: -0.14,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 24 * scaleY),

                                // Or divider
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: const Color(0xFFEDF1F3),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'Or',
                                        style: TextStyle(
                                          color: Color(0xFF6C7278),
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                          height: 1.50,
                                          letterSpacing: -0.12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: const Color(0xFFEDF1F3),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24 * scaleY),

                                // Continue with Google
                                _buildSocialButton(
                                  icon: Icons.g_mobiledata,
                                  label: 'Continue with Google',
                                  iconColor: const Color(0xFF4285F4),
                                  onTap: () {
                                    // TODO: Implement Google sign-in
                                  },
                                ),
                                SizedBox(height: 15 * scaleY),

                                // Continue with Microsoft
                                _buildSocialButton(
                                  icon: Icons.window,
                                  label: 'Continue with Microsoft',
                                  iconColor: const Color(0xFF00A4EF),
                                  onTap: () {
                                    // TODO: Implement Microsoft sign-in
                                  },
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 40 * scaleY),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ...existing code...

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool isPassword = false,
    required double scaleX,
    required double scaleY,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6C7278),
            fontSize: 12,
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w500,
            height: 1.60,
            letterSpacing: -0.24,
          ),
        ),
        SizedBox(height: 2 * scaleY),
        Container(
          width: double.infinity,
          height: 46,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(
                width: 1,
                color: Color(0xFFEDF1F3),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x3DE4E5E7),
                blurRadius: 2,
                offset: Offset(0, 1),
                spreadRadius: 0,
              )
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? _obscurePassword : false,
            style: const TextStyle(
              color: Color(0xFF1A1C1E),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              height: 1.40,
              letterSpacing: -0.14,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: InputBorder.none,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey.shade500,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(
              width: 1,
              color: Color(0xFFEFF0F6),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A1C1E),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                height: 1.40,
                letterSpacing: -0.14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAuth(AuthProvider authProvider) async {
    // if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text('Please fill all fields'),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    //   return;
     Navigator.pushReplacementNamed(context, '/home');
    }

//     // TODO: Replace with backend authentication
//     await authProvider.signIn(
//       email: _emailController.text,
//       password: _passwordController.text,
//     );

//     // Navigate to home if authenticated
//     if (authProvider.isAuthenticated && mounted) {
//       Navigator.pushReplacementNamed(context, '/home');
//     }
//   }
}