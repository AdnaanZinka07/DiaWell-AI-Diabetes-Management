import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kPrimaryBlue = Color(0xFF2563EB);
const _kSecondaryBlue = Color(0xFF3B82F6);
const _kSoftBlue = Color(0xFFEFF6FF);
const _kBodyBg = Color(0xFFF0F4FF); // light blue-grey body background
const _kRed = Color(0xFFEF4444);
const _kOrange = Color(0xFFF59E0B);
const _kTextDark = Color(0xFF111827);
const _kTextGrey = Color(0xFF6B7280);

class AddSugarLevelScreen extends StatefulWidget {
  const AddSugarLevelScreen({super.key});

  @override
  State<AddSugarLevelScreen> createState() => _AddSugarLevelScreenState();
}

class _AddSugarLevelScreenState extends State<AddSugarLevelScreen> {
  // ── Preserved: controller + form key ──────────────────────────────────────
  final TextEditingController _levelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── Preserved: save / submit logic ────────────────────────────────────────
  Future<void> _addSugarLevel() async {
    if (_formKey.currentState!.validate()) {
      try {
        final uid = FirebaseAuth.instance.currentUser!.uid;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('SugarLevels')
            .add({
              'level': double.parse(_levelController.text),
              'timestamp': FieldValue.serverTimestamp(),
            });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blood sugar level recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _levelController.clear();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Preserved: clear logic ────────────────────────────────────────────────
  void _clearInput() {
    _levelController.clear();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      // Primary blue shows through the rounded top corners of the body
      // container, creating the seamless header→body curve effect.
      backgroundColor: _kPrimaryBlue,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── Header + hero in one Clip.none Stack ────────────────────────
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                _buildHeader(context),
                // Hero with sparkles — overlaps header bottom by 72 px
                Positioned(
                  bottom: -72,
                  child: _buildHeroWithSparkles(),
                ),
              ],
            ),

            // ── Light-blue-grey body with rounded top ────────────────────────
            // minHeight ensures the blue scaffold doesn't peek through at bottom
            // on tall screens/tablets.
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: screenH * 0.62),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _kBodyBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                // top padding = 72 (bottom hero half) + 20 spacing
                padding: const EdgeInsets.fromLTRB(20, 92, 20, 40),
                child: Column(
                  children: [
                    _buildSugarInputCard(),
                    const SizedBox(height: 16),
                    _buildQuickTipsCard(),
                    const SizedBox(height: 28),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 1. Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimaryBlue, _kSecondaryBlue],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Faint decorative circle — top-right
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Faint decorative circle — left
          Positioned(
            top: 40,
            left: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // ECG line — right side of header
          Positioned(
            right: 0,
            bottom: 60,
            child: SizedBox(
              width: 200,
              height: 72,
              child: CustomPaint(painter: _HeaderEcgPainter()),
            ),
          ),
          // Nav content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
              child: Row(
                children: [
                  // Back button — 52 × 52, translucent circle with white border
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Add Sugar Level',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. Hero blood drop with surrounding sparkles ────────────────────────────

  Widget _buildHeroWithSparkles() {
    return SizedBox(
      width: 200,
      height: 164, // 144 hero + 20 above for sparkles
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // The hero circle
          _buildBloodDropHero(),
          // Sparkle marks — arranged around the hero like the reference image
          Positioned(
            top: 4,
            left: 18,
            child: _sparkle(16, Colors.white.withValues(alpha: 0.7)),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: _sparkle(12, Colors.white.withValues(alpha: 0.55)),
          ),
          Positioned(
            top: 38,
            left: 4,
            child: _sparkle(8, Colors.white.withValues(alpha: 0.45)),
          ),
          Positioned(
            top: 42,
            right: 4,
            child: _sparkle(9, Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _sparkle(double size, Color color) {
    return Icon(Icons.add, color: color, size: size);
  }

  Widget _buildBloodDropHero() {
    return Container(
      width: 144,
      height: 144,
      decoration: BoxDecoration(
        // Light blue ring
        color: const Color(0xFFBFDBFE).withValues(alpha: 0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _kPrimaryBlue.withValues(alpha: 0.28),
            blurRadius: 36,
            spreadRadius: 4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _kPrimaryBlue.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Red blood drop
              const Icon(Icons.water_drop, color: _kRed, size: 60),
              // White ECG/heartbeat line overlaid on the drop
              Positioned(
                bottom: 32,
                child: SizedBox(
                  width: 34,
                  height: 14,
                  child: CustomPaint(painter: _DropEcgPainter()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 3. Sugar Input Card ────────────────────────────────────────────────────

  Widget _buildSugarInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blood Sugar Level (mg/dL)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 18),
          // ── Input container with blue border ─────────────────────────────
          // Form wraps just the TextFormField to preserve the _formKey validator.
          // minHeight 72 lets the container expand when an error message appears.
          Container(
            constraints: const BoxConstraints(minHeight: 72),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPrimaryBlue, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left icon panel — light blue square background
                Container(
                  width: 54,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: _kSoftBlue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    color: _kPrimaryBlue,
                    size: 26,
                  ),
                ),
                // TextFormField — preserved controller + validator
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _levelController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _kTextDark,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter sugar level',
                        hintStyle: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14),
                        errorStyle: TextStyle(fontSize: 10, height: 1.2),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a blood sugar level';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                // mg/dL suffix
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    'mg/dL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kTextGrey.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── Normal Range ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kSoftBlue,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _kPrimaryBlue.withValues(alpha: 0.15),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kPrimaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Normal Range',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _kTextDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fasting: 70 – 130 mg/dL',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kTextGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'After Meal: less than 180 mg/dL',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kTextGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Shield-check decorative icon
                Icon(
                  Icons.security_rounded,
                  color: _kPrimaryBlue.withValues(alpha: 0.35),
                  size: 40,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. Quick Tips Card ──────────────────────────────────────────────────────

  Widget _buildQuickTipsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Orange lightbulb container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lightbulb_rounded, color: _kOrange, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Tips',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Enter your current blood sugar level to track and analyse your health better.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kTextGrey,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Action Buttons ───────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Clear — white bg + red border
        Expanded(
          child: GestureDetector(
            onTap: _clearInput,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kRed, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _kRed.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restart_alt_rounded, color: _kRed, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _kRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Submit — solid blue with white text
        Expanded(
          child: GestureDetector(
            onTap: _addSugarLevel,
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: _kPrimaryBlue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimaryBlue.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Submit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── ECG line inside the blood drop icon ─────────────────────────────────────

class _DropEcgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final y = size.height * 0.5;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width * 0.22, y)
      ..lineTo(size.width * 0.30, y - size.height * 0.55)
      ..lineTo(size.width * 0.38, y + size.height * 0.55)
      ..lineTo(size.width * 0.50, y - size.height * 0.90)
      ..lineTo(size.width * 0.60, y + size.height * 0.45)
      ..lineTo(size.width * 0.68, y)
      ..lineTo(size.width, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Decorative ECG line in the header (right side) ──────────────────────────

class _HeaderEcgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final y = size.height * 0.5;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width * 0.15, y)
      ..lineTo(size.width * 0.24, y - size.height * 0.18)
      ..lineTo(size.width * 0.31, y + size.height * 0.40)
      ..lineTo(size.width * 0.37, y - size.height * 0.65)
      ..lineTo(size.width * 0.44, y + size.height * 0.30)
      ..lineTo(size.width * 0.51, y)
      ..lineTo(size.width * 0.65, y)
      ..lineTo(size.width * 0.72, y - size.height * 0.15)
      ..lineTo(size.width * 0.78, y + size.height * 0.35)
      ..lineTo(size.width * 0.84, y - size.height * 0.55)
      ..lineTo(size.width * 0.90, y + size.height * 0.25)
      ..lineTo(size.width, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
