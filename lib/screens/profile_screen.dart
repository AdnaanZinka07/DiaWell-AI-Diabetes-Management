import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'reports_screen.dart';
import 'add_medication_screen.dart';
import 'ai_insights_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _primaryBlue = Color(0xFF2563EB);
const _secondaryBlue = Color(0xFF3B82F6);
const _darkBlue = Color(0xFF1E3A8A);
const _background = Color(0xFFF8FAFC);
const _softBlue = Color(0xFFEFF6FF);
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _purple = Color(0xFF8B5CF6);
const _orange = Color(0xFFF97316);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User get _user => _auth.currentUser!;

  // ── Name resolution ─────────────────────────────────────────────────────────
  String _resolveName(Map<String, dynamic> d) {
    final n = (d['name'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    final fn = (d['fullName'] as String?)?.trim();
    if (fn != null && fn.isNotEmpty) return fn;
    final un = (d['username'] as String?)?.trim();
    if (un != null && un.isNotEmpty) return un;
    final dn = _user.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    return 'User';
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  // ── Edit Profile ────────────────────────────────────────────────────────────
  void _openEditProfile(Map<String, dynamic> userData) {
    final resolvedName = _resolveName(userData);
    final nameCtrl = TextEditingController(
      text: resolvedName == 'User' ? '' : resolvedName,
    );
    final typeCtrl = TextEditingController(
      text: (userData['diabetesType'] as String?) ?? '',
    );
    final goalCtrl = TextEditingController(
      text: (userData['bloodSugarGoal'] as String?) ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        bool saving = false;
        return StatefulBuilder(
          builder:
              (ctx, setS) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _editField(nameCtrl, 'Full Name', Icons.person_rounded),
                      const SizedBox(height: 14),
                      _editField(
                        typeCtrl,
                        'Diabetes Type',
                        Icons.medical_services_rounded,
                      ),
                      const SizedBox(height: 14),
                      _editField(
                        goalCtrl,
                        'Blood Sugar Goal',
                        Icons.bar_chart_rounded,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              saving
                                  ? null
                                  : () async {
                                    setS(() => saving = true);
                                    try {
                                      await _db
                                          .collection('Users')
                                          .doc(_user.uid)
                                          .set({
                                            'name': nameCtrl.text.trim(),
                                            'diabetesType':
                                                typeCtrl.text.trim(),
                                            'bloodSugarGoal':
                                                goalCtrl.text.trim(),
                                          }, SetOptions(merge: true));
                                      final n = nameCtrl.text.trim();
                                      if (n.isNotEmpty) {
                                        await _user.updateDisplayName(n);
                                      }
                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Profile updated successfully',
                                          ),
                                          backgroundColor: _green,
                                        ),
                                      );
                                    } catch (e) {
                                      setS(() => saving = false);
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child:
                              saving
                                  ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 15, color: _textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textGrey),
        prefixIcon: Icon(icon, color: _primaryBlue, size: 22),
        filled: true,
        fillColor: _softBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('Users').doc(_user.uid).snapshots(),
        builder: (context, snap) {
          final userData = (snap.data?.data() as Map<String, dynamic>?) ?? {};
          final name = _resolveName(userData);
          final email =
              (_user.email?.isNotEmpty == true)
                  ? _user.email!
                  : 'No email available';
          final imageUrl = (userData['profileImage'] as String?) ?? '';
          final diabetesType =
              (userData['diabetesType'] as String?)?.trim().isNotEmpty == true
                  ? userData['diabetesType'] as String
                  : 'Not set';
          final bloodSugarGoal =
              (userData['bloodSugarGoal'] as String?)?.trim().isNotEmpty == true
                  ? userData['bloodSugarGoal'] as String
                  : '80–180 mg/dL';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header with avatar overlapping ──────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    _buildHeader(context),
                    Positioned(
                      bottom: -56,
                      child: _buildAvatar(name, imageUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 72), // 56 avatar overhang + 16 gap
                // ── User identity ────────────────────────────────────────────
                Center(child: _buildUserInfo(name, email, userData)),
                const SizedBox(height: 24),

                // ── Scrollable content ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEmailCard(email),
                      const SizedBox(height: 24),
                      _buildHealthOverview(diabetesType, bloodSugarGoal),
                      const SizedBox(height: 24),
                      _buildManageSection(context),
                      const SizedBox(height: 24),
                      _buildSettingsSection(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 1. Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_darkBlue, _secondaryBlue],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle — top-right
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
          // Decorative circle — left
          Positioned(
            top: 50,
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
          // Header content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BackButton(),
                      const Spacer(),
                      // Bell icon with red dot
                      Stack(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.notifications_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Positioned(
                            top: 9,
                            right: 9,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your health and app preferences',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Avatar ───────────────────────────────────────────────────────────────
  Widget _buildAvatar(String name, String imageUrl) {
    return Stack(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 52,
            backgroundColor: _primaryBlue,
            backgroundImage:
                imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child:
                imageUrl.isEmpty
                    ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                    : null,
          ),
        ),
        // Camera icon — visual only
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. User info ─────────────────────────────────────────────────────────────
  Widget _buildUserInfo(
    String name,
    String email,
    Map<String, dynamic> userData,
  ) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(email, style: const TextStyle(fontSize: 14, color: _textGrey)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _openEditProfile(userData),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryBlue, _secondaryBlue],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Email card ────────────────────────────────────────────────────────────
  Widget _buildEmailCard(String email) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.email_rounded,
              color: _primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email',
                  style: TextStyle(fontSize: 12, color: _textGrey),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Health Overview ───────────────────────────────────────────────────────
  Widget _buildHealthOverview(String diabetesType, String bloodSugarGoal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Health Overview',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildProfileRow(
                icon: Icons.medical_services_rounded,
                iconBg: _primaryBlue.withValues(alpha: 0.12),
                iconColor: _primaryBlue,
                title: 'Diabetes Type',
                subtitle: diabetesType,
                showDivider: true,
              ),
              _buildProfileRow(
                icon: Icons.bar_chart_rounded,
                iconBg: _purple.withValues(alpha: 0.12),
                iconColor: _purple,
                title: 'Blood Sugar Goal',
                subtitle: bloodSugarGoal,
                showDivider: true,
              ),
              // Last reading — live from Firestore users/{uid}/SugarLevels
              StreamBuilder<QuerySnapshot>(
                stream:
                    _db
                        .collection('users')
                        .doc(_user.uid)
                        .collection('SugarLevels')
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .snapshots(),
                builder: (ctx, snap) {
                  String lastLabel = 'No data yet';
                  String? badge;
                  Color badgeColor = _textGrey;

                  if (snap.hasData && snap.data!.docs.isNotEmpty) {
                    final doc =
                        snap.data!.docs.first.data() as Map<String, dynamic>;
                    final level = (doc['level'] as num?)?.toDouble() ?? 0;
                    final ts = (doc['timestamp'] as Timestamp?)?.toDate();
                    final timeStr =
                        ts != null
                            ? DateFormat('MMM d, h:mm a').format(ts.toLocal())
                            : '';
                    lastLabel =
                        '${level.toStringAsFixed(0)} mg/dL  •  $timeStr';

                    if (level < 70) {
                      badge = 'Low';
                      badgeColor = _orange;
                    } else if (level <= 180) {
                      badge = 'In Range';
                      badgeColor = _green;
                    } else {
                      badge = 'High';
                      badgeColor = _red;
                    }
                  }

                  return _buildProfileRow(
                    icon: Icons.water_drop_rounded,
                    iconBg: _red.withValues(alpha: 0.10),
                    iconColor: _red,
                    title: 'Last Reading',
                    subtitle: lastLabel,
                    badge: badge,
                    badgeColor: badgeColor,
                    showDivider: false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 6. Manage Section ────────────────────────────────────────────────────────
  Widget _buildManageSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildProfileRow(
                icon: Icons.folder_copy_rounded,
                iconBg: _green.withValues(alpha: 0.12),
                iconColor: _green,
                title: 'Medical Reports',
                subtitle: 'View and upload your medical reports',
                showChevron: true,
                showDivider: true,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsScreen()),
                    ),
              ),
              _buildProfileRow(
                icon: Icons.medication_rounded,
                iconBg: _purple.withValues(alpha: 0.12),
                iconColor: _purple,
                title: 'Medication Reminders',
                subtitle: 'View and manage your medication reminders',
                showChevron: true,
                showDivider: true,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddMedicationScreen(),
                      ),
                    ),
              ),
              _buildProfileRow(
                icon: Icons.psychology_rounded,
                iconBg: _orange.withValues(alpha: 0.12),
                iconColor: _orange,
                title: 'Health Insights',
                subtitle: 'AI-powered insights and tips for you',
                showChevron: true,
                showDivider: false,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AIInsightsScreen(),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 7. App Settings Section ──────────────────────────────────────────────────
  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'App Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildProfileRow(
                icon: Icons.star_rounded,
                iconBg: _orange.withValues(alpha: 0.12),
                iconColor: _orange,
                title: 'Rate Us',
                subtitle: 'Help us improve by rating our app',
                showChevron: true,
                showDivider: true,
                onTap:
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rate Us — coming soon!')),
                    ),
              ),
              _buildProfileRow(
                icon: Icons.feedback_rounded,
                iconBg: _purple.withValues(alpha: 0.12),
                iconColor: _purple,
                title: 'Feedback',
                subtitle: 'Share your thoughts and suggestions',
                showChevron: true,
                showDivider: true,
                onTap:
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feedback — coming soon!')),
                    ),
              ),
              _buildProfileRow(
                icon: Icons.privacy_tip_rounded,
                iconBg: _textGrey.withValues(alpha: 0.12),
                iconColor: _textGrey,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                showChevron: true,
                showDivider: true,
                onTap:
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy Policy — coming soon!'),
                      ),
                    ),
              ),
              _buildLogoutRow(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Row builder ──────────────────────────────────────────────────────────────
  Widget _buildProfileRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    bool showChevron = false,
    required bool showDivider,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: _textGrey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? _green).withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor ?? _green,
                      ),
                    ),
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _textGrey,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 76,
            endIndent: 16,
            color: Color(0xFFF1F5F9),
          ),
      ],
    );
  }

  // ── Logout row ───────────────────────────────────────────────────────────────
  Widget _buildLogoutRow() {
    return InkWell(
      onTap: _logout,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.logout_rounded, color: _red, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _red,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Sign out from your account',
                    style: TextStyle(fontSize: 12, color: _textGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _red, size: 22),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton();

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
