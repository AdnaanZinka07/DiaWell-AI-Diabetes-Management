import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _kPrimaryBlue = Color(0xFF2563EB);
const _kDarkBlue = Color(0xFF1E3A8A);
const _kSoftBlue = Color(0xFFEFF6FF);
const _kPurple = Color(0xFF6366F1);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kTextDark = Color(0xFF111827);
const _kTextGrey = Color(0xFF6B7280);

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final TextEditingController _medicationNameController =
      TextEditingController();
  final TextEditingController _insulinDosageController =
      TextEditingController();
  DateTime? _selectedDateTime;

  List<Map<String, dynamic>> _medicationSchedule = [];

  DateTime? pickedDate;
  TimeOfDay? pickedTime;

  @override
  void initState() {
    super.initState();
    _fetchMedicationList();
  }

  Future<void> _fetchMedicationList() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .collection('Medications')
            .orderBy('datetime')
            .get();

    setState(() {
      _medicationSchedule =
          snapshot.docs.map((doc) {
            final data = doc.data();
            final date = (data['datetime'] as Timestamp?)?.toDate();
            return {
              'id': doc.id,
              'tablet': data['tablet'],
              'insulin': data['insulin'],
              'datetime':
                  date != null
                      ? DateFormat.yMMMd().add_jm().format(date)
                      : "N/A",
            };
          }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (date != null) setState(() => pickedDate = date);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => pickedTime = time);
  }

  void _combineDateTime() {
    if (pickedDate != null && pickedTime != null) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate!.year,
          pickedDate!.month,
          pickedDate!.day,
          pickedTime!.hour,
          pickedTime!.minute,
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select both date and time.")),
      );
    }
  }

  void _pickDateTime() async {
    await _selectDate(context);
    if (!mounted) return;
    await _selectTime(context);
    _combineDateTime();
  }

  void _confirmAndSave() async {
    final user = FirebaseAuth.instance.currentUser;
    final medicationName = _medicationNameController.text.trim();
    final insulinDosage = _insulinDosageController.text.trim();

    if (medicationName.isEmpty ||
        insulinDosage.isEmpty ||
        _selectedDateTime == null ||
        user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields and select a date & time.'),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .collection('Medications')
          .add({
            'tablet': medicationName,
            'insulin': insulinDosage,
            'datetime': _selectedDateTime,
          });

      _medicationNameController.clear();
      _insulinDosageController.clear();
      setState(() => _selectedDateTime = null);

      _fetchMedicationList();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication added successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _deleteEntry(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final entry = _medicationSchedule[index];

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('Medications')
        .doc(entry['id'])
        .delete();

    _fetchMedicationList();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry deleted successfully!')),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormCard(),
                  const SizedBox(height: 20),
                  _buildSaveButton(),
                  const SizedBox(height: 24),
                  _buildMedicationListSection(),
                  const SizedBox(height: 20),
                  _buildReminderCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), _kDarkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Add Medication',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 40), // balance back button
            ],
          ),
        ),
      ),
    );
  }

  // ─── Form Card ──────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
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
      child: Column(
        children: [
          // Row 1 – Tablet Name (plain widget, no GestureDetector so TextField gets taps)
          _buildFormRowContent(
            icon: Icons.medication_rounded,
            iconBg: _kPurple.withValues(alpha: 0.12),
            iconColor: _kPurple,
            label: 'Tablet Name',
            showDivider: true,
            child: TextField(
              controller: _medicationNameController,
              decoration: const InputDecoration(
                hintText: 'Enter tablet name',
                hintStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _kTextDark,
              ),
            ),
          ),
          // Row 2 – Insulin Dosage
          _buildFormRowContent(
            icon: Icons.opacity,
            iconBg: _kPrimaryBlue.withValues(alpha: 0.1),
            iconColor: _kPrimaryBlue,
            label: 'Insulin Dosage',
            showDivider: true,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kSoftBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'mg/dL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kPrimaryBlue,
                ),
              ),
            ),
            child: TextField(
              controller: _insulinDosageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Enter dosage',
                hintStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _kTextDark,
              ),
            ),
          ),
          // Row 3 – Date & Time (tappable row — child is Text, not TextField)
          GestureDetector(
            onTap: _pickDateTime,
            behavior: HitTestBehavior.opaque,
            child: _buildFormRowContent(
              icon: Icons.calendar_month_rounded,
              iconBg: _kGreen.withValues(alpha: 0.1),
              iconColor: _kGreen,
              label: 'Date & Time',
              showDivider: false,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 22,
              ),
              child: Text(
                _selectedDateTime != null
                    ? DateFormat.yMMMd().add_jm().format(_selectedDateTime!)
                    : 'Tap to select',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      _selectedDateTime != null
                          ? _kTextDark
                          : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stateless layout for a single form row.
  /// Does NOT wrap in GestureDetector so that TextField children keep focus.
  Widget _buildFormRowContent({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required Widget child,
    Widget? trailing,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    child,
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  // ─── Save Button ────────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _confirmAndSave,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), _kDarkBlue],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _kPrimaryBlue.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Save Medication',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Medication List ─────────────────────────────────────────────────────────

  Widget _buildMedicationListSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Medications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _kTextDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'View, manage and track your added medications',
                        style: TextStyle(fontSize: 12, color: _kTextGrey),
                      ),
                    ],
                  ),
                ),
                // Visual-only filter pill (no existing filter logic)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _kSoftBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 13,
                        color: _kPrimaryBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _kPrimaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          // Items or empty state
          _medicationSchedule.isEmpty
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 40,
                        color: Color(0xFFCBD5E1),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No medications added yet.',
                        style: TextStyle(color: _kTextGrey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _medicationSchedule.length,
                separatorBuilder:
                    (_, __) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                itemBuilder:
                    (context, index) =>
                        _buildMedicationItem(_medicationSchedule[index], index),
              ),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(Map<String, dynamic> item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Pill icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: _kPurple,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Name, dosage badge, date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['tablet'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _kPrimaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${item['insulin'] ?? 'N/A'} mg/dL',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kPrimaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: _kTextGrey,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        item['datetime'] ?? 'N/A',
                        style: const TextStyle(fontSize: 11, color: _kTextGrey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit — visual only, no existing edit logic
              _buildActionCircle(
                icon: Icons.edit_rounded,
                color: _kPrimaryBlue,
                bgColor: _kPrimaryBlue.withValues(alpha: 0.1),
                onTap: () {},
              ),
              const SizedBox(width: 8),
              // Delete — calls existing _deleteEntry
              _buildActionCircle(
                icon: Icons.delete_rounded,
                color: _kRed,
                bgColor: _kRed.withValues(alpha: 0.1),
                onTap: () => _deleteEntry(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  // ─── Reminder Card ───────────────────────────────────────────────────────────

  Widget _buildReminderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSoftBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPrimaryBlue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _kPrimaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: _kPrimaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medication Reminder',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Set reminders to take your medications',
                  style: TextStyle(fontSize: 12, color: _kTextGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Visual button — no reminder logic exists in original file
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _kPrimaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Set Reminder',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
