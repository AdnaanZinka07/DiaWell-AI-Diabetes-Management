import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Design tokens ───────────────────────────────────────────────────────────────
const _primaryBlue = Color(0xFF2563EB);
const _secondaryBlue = Color(0xFF3B82F6);
const _darkBlue = Color(0xFF1E3A8A);
const _background = Color(0xFFF8FAFC);
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _borderGrey = Color(0xFFE5E7EB);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Preserved controllers ────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    // Delay so the widget tree is ready before navigation
    Future.delayed(Duration.zero, _checkIfLoggedIn);
    _loadRememberedEmail();
  }

  // ── Auto-login if session still active ──────────────────────────────────────
  Future<void> _checkIfLoggedIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // ── Load remembered email from SharedPreferences ─────────────────────────────
  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool('rememberMe') ?? false;
    if (remembered && mounted) {
      setState(() {
        _emailCtrl.text = prefs.getString('rememberedEmail') ?? '';
        _rememberMe = true;
      });
    }
  }

  // ── Preserved: email/password sign-in ────────────────────────────────────────
  Future<void> _signInWithEmail() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      _showSnack('Please enter your email and password.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      // Persist or clear remember-me choice
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('rememberedEmail', _emailCtrl.text.trim());
      } else {
        await prefs.setBool('rememberMe', false);
        await prefs.remove('rememberedEmail');
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed. Check your credentials.';
      if (e.code == 'user-not-found') msg = 'No account found for this email.';
      if (e.code == 'wrong-password') {
        msg = 'Incorrect password. Please try again.';
      }
      if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email address.';
      }
      if (mounted) _showSnack(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google sign-in: popup on web, google_sign_in package on mobile ───────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Web: Firebase handles the OAuth popup natively — no native plugin needed
        final provider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // Android / iOS: use google_sign_in package to obtain the credential
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          // User dismissed the account picker
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      // Upsert user document in Users/{uid} so profile data is always present
      final user = userCredential.user;
      if (user != null) {
        final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;
        final data = <String, dynamic>{
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (isNew) data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .set(data, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[GoogleSignIn] FirebaseAuthException ${e.code}: ${e.message}',
      );
      if (mounted) {
        _showSnack(
          'Sign-In failed (${e.code}): ${e.message ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('[GoogleSignIn] Unexpected error: $e');
      if (mounted) _showSnack('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Forgot password ───────────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Please enter your email address first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showSnack('Password reset email sent to $email.', success: true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showSnack(e.message ?? 'Failed to send reset email.');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF22C55E) : null,
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  _buildLogo(),
                  const SizedBox(height: 22),
                  _buildHeading(),
                  const SizedBox(height: 22),
                  _buildIllustration(),
                  const SizedBox(height: 28),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 12),
                  _buildRememberForgotRow(),
                  const SizedBox(height: 26),
                  _buildSignInButton(),
                  const SizedBox(height: 22),
                  _buildOrDivider(),
                  const SizedBox(height: 22),
                  _buildGoogleButton(),
                  const SizedBox(height: 28),
                  _buildSignUpRow(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Logo ───────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_darkBlue, _secondaryBlue],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.water_drop_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Dia',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _darkBlue,
                ),
              ),
              TextSpan(
                text: 'Well',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _secondaryBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 2. Heading ────────────────────────────────────────────────────────────────
  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _textDark,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to continue to your account',
          style: TextStyle(
            fontSize: 15,
            color: _textGrey.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  // ── 3. Healthcare illustration card ──────────────────────────────────────────
  Widget _buildIllustration() {
    return Container(
      width: double.infinity,
      height: 148,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryBlue.withValues(alpha: 0.07),
            _secondaryBlue.withValues(alpha: 0.11),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _primaryBlue.withValues(alpha: 0.12),
          width: 1.2,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Faint decorative circles
          Positioned(
            top: -22,
            right: -22,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -14,
            left: -14,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _secondaryBlue.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Four medical icons centred in the card
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _illIcon(
                  Icons.water_drop_rounded,
                  const Color(0xFFEF4444),
                  'Blood\nSugar',
                ),
                const SizedBox(width: 20),
                _illIcon(Icons.monitor_heart_rounded, _primaryBlue, 'Monitor'),
                const SizedBox(width: 20),
                _illIcon(
                  Icons.medication_rounded,
                  const Color(0xFF22C55E),
                  'Meds',
                ),
                const SizedBox(width: 20),
                _illIcon(
                  Icons.psychology_rounded,
                  const Color(0xFF8B5CF6),
                  'Health',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _illIcon(IconData icon, Color color, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: _textGrey,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // ── 4. Email field ────────────────────────────────────────────────────────────
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 15, color: _textDark),
          decoration: _inputDeco(
            hint: 'Enter your email',
            prefix: Icons.email_rounded,
          ),
        ),
      ],
    );
  }

  // ── 5. Password field ─────────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(fontSize: 15, color: _textDark),
          decoration: _inputDeco(
            hint: 'Enter your password',
            prefix: Icons.lock_rounded,
            suffix: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: _textGrey,
                size: 20,
              ),
              onPressed:
                  () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
      prefixIcon: Icon(prefix, color: _textGrey, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderGrey, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderGrey, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.8),
      ),
    );
  }

  // ── 6. Remember-me + Forgot Password ─────────────────────────────────────────
  Widget _buildRememberForgotRow() {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (v) => setState(() => _rememberMe = v ?? false),
            activeColor: _primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            side: const BorderSide(color: _borderGrey, width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Remember me',
          style: TextStyle(fontSize: 14, color: _textGrey),
        ),
        const Spacer(),
        TextButton(
          onPressed: _forgotPassword,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  // ── 7. Sign In button ─────────────────────────────────────────────────────────
  Widget _buildSignInButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _signInWithEmail,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_darkBlue, _secondaryBlue],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child:
            _isLoading
                ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
                : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
      ),
    );
  }

  // ── 8. OR divider ─────────────────────────────────────────────────────────────
  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: _borderGrey, thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textGrey.withValues(alpha: 0.7),
            ),
          ),
        ),
        const Expanded(child: Divider(color: _borderGrey, thickness: 1.2)),
      ],
    );
  }

  // ── 9. Google button ──────────────────────────────────────────────────────────
  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _signInWithGoogle,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderGrey, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Coloured G mark
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                shape: BoxShape.circle,
                border: Border.all(color: _borderGrey, width: 1),
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4285F4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 10. Sign Up row ───────────────────────────────────────────────────────────
  Widget _buildSignUpRow() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/register'),
        child: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(fontSize: 14, color: _textGrey),
              ),
              TextSpan(
                text: 'Sign up',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
