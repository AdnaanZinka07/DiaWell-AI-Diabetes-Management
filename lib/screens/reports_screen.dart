import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _kPrimaryBlue = Color(0xFF2563EB);
const _kDarkBlue = Color(0xFF1E3A8A);
const _kSecondaryBlue = Color(0xFF3B82F6);
const _kSoftBlue = Color(0xFFEFF6FF);
const _kRed = Color(0xFFEF4444);
const _kBodyBg = Color(0xFFF8FAFC);
const _kTextDark = Color(0xFF111827);
const _kTextGrey = Color(0xFF6B7280);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // ── Preserved: upload ────────────────────────────────────────────────────────
  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name;
        final fileBytes = file.bytes;

        if (fileBytes != null) {
          final storageRef = FirebaseStorage.instance.ref().child(
            'reports/$fileName',
          );
          final uploadTask = storageRef.putData(fileBytes);

          await uploadTask;

          final downloadURL = await storageRef.getDownloadURL();

          await FirebaseFirestore.instance.collection('Reports').add({
            'fileName': fileName,
            'downloadURL': downloadURL,
            'storagePath': 'reports/$fileName',
            'timestamp': FieldValue.serverTimestamp(),
          });

          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('File uploaded: $fileName')));

          setState(() {});
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No file selected')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Preserved: fetch ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchUploadedReports() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('Reports')
            .orderBy('timestamp', descending: true)
            .get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'fileName': doc['fileName'],
        'downloadURL': doc['downloadURL'],
        'storagePath':
            doc.data().containsKey('storagePath') ? doc['storagePath'] : null,
        'timestamp':
            (doc['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      };
    }).toList();
  }

  // ── Preserved: delete ────────────────────────────────────────────────────────
  Future<void> _deleteReport(String docId, String? storagePath) async {
    final confirmDelete = await _showDeleteConfirmation();

    if (confirmDelete) {
      try {
        if (storagePath != null) {
          await FirebaseStorage.instance.ref(storagePath).delete();
        }

        await FirebaseFirestore.instance
            .collection('Reports')
            .doc(docId)
            .delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted successfully!')),
        );

        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting report: $e')));
      }
    }
  }

  // ── Preserved: delete confirmation dialog (styled to match UI) ───────────────
  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                actionsPadding: const EdgeInsets.all(16),
                title: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: _kRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Delete Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _kTextDark,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'Are you sure you want to delete this report? This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kTextGrey,
                    height: 1.5,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: _kTextGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBodyBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header ────────────────────────────────────────────────
          _buildHeader(),

          // ── Upload card ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: _buildUploadCard(),
          ),

          // ── Section label ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: const Text(
              'Your Reports',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _kTextDark,
              ),
            ),
          ),

          // ── Reports list — Expanded so it fills remaining space ────────────
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchUploadedReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _kPrimaryBlue),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: _kTextGrey),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                final reports = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    return _buildReportCard(reports[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kDarkBlue, _kSecondaryBlue],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle — top-right
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Decorative circle — bottom-left
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Faint folder/document icon — far right
          Positioned(
            right: 24,
            bottom: 20,
            child: Icon(
              Icons.folder_copy_rounded,
              color: Colors.white.withValues(alpha: 0.1),
              size: 80,
            ),
          ),
          // Header content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(alignment: Alignment.centerLeft, child: _BackButton()),
                  const SizedBox(height: 16),
                  const Text(
                    'Medical Reports',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload, view and manage your health documents',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.4,
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

  // ─── 2. Upload Card ──────────────────────────────────────────────────────────

  Widget _buildUploadCard() {
    return GestureDetector(
      onTap: _pickAndUploadFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _kPrimaryBlue.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _kPrimaryBlue.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon panel
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kSoftBlue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                color: _kPrimaryBlue,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _kTextDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'PDF, DOCX, JPG or PNG',
                    style: TextStyle(fontSize: 13, color: _kTextGrey),
                  ),
                ],
              ),
            ),
            // Arrow
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kPrimaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. Report Card ──────────────────────────────────────────────────────────

  Widget _buildReportCard(Map<String, dynamic> report) {
    final fileName = report['fileName'] as String;
    final downloadURL = report['downloadURL'] as String;
    final docId = report['id'] as String;
    final storagePath = report['storagePath'] as String?;
    final timestamp = report['timestamp'] as DateTime;

    final formatted = DateFormat(
      'MMM d, yyyy  •  h:mm a',
    ).format(timestamp.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // File type icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _fileIconBg(fileName),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              _fileIcon(fileName),
              color: _fileIconColor(fileName),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Uploaded  $formatted',
                  style: const TextStyle(fontSize: 11.5, color: _kTextGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Open / view
              _actionBtn(
                icon: Icons.open_in_new_rounded,
                color: _kPrimaryBlue,
                bg: _kSoftBlue,
                onTap: () async {
                  final uri = Uri.parse(downloadURL);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              // Delete (only when storagePath exists)
              if (storagePath != null) ...[
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.delete_rounded,
                  color: _kRed,
                  bg: _kRed.withValues(alpha: 0.10),
                  onTap: () => _deleteReport(docId, storagePath),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ─── 4. Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: _kSoftBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                color: _kPrimaryBlue,
                size: 42,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No Reports Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload your first medical report\nusing the button above.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _kTextGrey, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers: file type icon + colour ────────────────────────────────────────

  IconData _fileIcon(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileIconColor(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'pdf':
        return _kRed;
      case 'doc':
      case 'docx':
        return _kPrimaryBlue;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const Color(0xFF10B981);
      default:
        return _kPrimaryBlue;
    }
  }

  Color _fileIconBg(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'pdf':
        return _kRed.withValues(alpha: 0.10);
      case 'doc':
      case 'docx':
        return _kSoftBlue;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const Color(0xFF10B981).withValues(alpha: 0.10);
      default:
        return _kSoftBlue;
    }
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
