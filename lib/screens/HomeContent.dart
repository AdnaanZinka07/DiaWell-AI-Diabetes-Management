// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ai_insights_screen.dart';
import 'bluetooth_glucose_screen.dart';
import 'notification_screen.dart';

const _kPrimaryBlue = Color(0xFF2563EB);
const _kDarkBlue = Color(0xFF1E3A8A);
const _kGreen = Color(0xFF22C55E);
const _kOrange = Color(0xFFF97316);
const _kRed = Color(0xFFEF4444);
const _kPurple = Color(0xFF8B5CF6);

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  DateTime _selectedDate = DateTime.now();
  late Stream<List<FlSpot>> _chartStream;

  @override
  void initState() {
    super.initState();
    _chartStream = _buildChartStream(_selectedDate);
  }

  /// Returns a live Firestore stream for the given day.
  /// Switching to a stream means the graph updates the moment a new reading
  /// is written — no manual refresh needed after AddSugarLevelScreen returns.
  Stream<List<FlSpot>> _buildChartStream(DateTime date) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[HomeContent] No logged-in user — stream returns empty.');
      return Stream.value([]);
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final nextDay = startOfDay.add(const Duration(days: 1));

    debugPrint(
      '[HomeContent] uid=$uid | querying users/$uid/SugarLevels '
      'from ${startOfDay.toIso8601String()} to ${nextDay.toIso8601String()}',
    );

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('SugarLevels')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(nextDay))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '[HomeContent] Stream emitted ${snapshot.docs.length} doc(s) '
            'for ${startOfDay.toIso8601String().substring(0, 10)}',
          );
          final spots = <FlSpot>[];
          for (final doc in snapshot.docs) {
            // serverTimestamp() is null on the client until the server confirms
            final tsRaw = doc.data()['timestamp'];
            if (tsRaw == null) continue;
            final ts = tsRaw as Timestamp;
            final dt = ts.toDate();
            final level = (doc['level'] as num).toDouble();
            debugPrint(
              '[HomeContent] doc=${doc.id} level=$level '
              'timestamp=${dt.toIso8601String()}',
            );
            spots.add(FlSpot(dt.hour + dt.minute / 60.0, level));
          }
          return spots;
        });
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _chartStream = _buildChartStream(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTimeFromX(double x) {
    final hour = x.floor();
    final minute = ((x - hour) * 60).round();
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _getStatus(double glucose) {
    if (glucose < 70) return 'Low';
    if (glucose <= 180) return 'In Range';
    return 'High';
  }

  Color _getStatusColor(double glucose) {
    if (glucose < 70) return _kRed;
    if (glucose <= 180) return _kGreen;
    return _kOrange;
  }

  String _getSuggestion(double glucose) {
    if (glucose < 70) {
      return 'Take fast-acting carbs and recheck after 15 minutes.';
    } else if (glucose <= 180) {
      return 'Your reading is within range. Keep monitoring regularly.';
    } else {
      return 'Drink water and recheck after 2 hours.';
    }
  }

  IconData _getSuggestionIcon(double glucose) {
    if (glucose < 70) return Icons.warning_amber_rounded;
    if (glucose <= 180) return Icons.check_circle_outline;
    return Icons.local_drink_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), _kDarkBlue],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildDateSelector(context),
              const SizedBox(height: 20),
              StreamBuilder<List<FlSpot>>(
                stream: _chartStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Error loading data: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final spots = snapshot.data ?? [];
                  return Column(
                    children: [
                      _buildLatestReadingCard(spots),
                      const SizedBox(height: 16),
                      _buildChartCard(spots),
                      const SizedBox(height: 16),
                      _buildStatCards(spots),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildActionCards(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 26),
            onPressed: () {},
          ),
          Expanded(
            child: Text(
              'Daily Sugar Level Report',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _kRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Date Selector ─────────────────────────────────────────────────────────

  Widget _buildDateSelector(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => _selectDate(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(
                _formatDate(_selectedDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Latest Reading Card ────────────────────────────────────────────────────

  Widget _buildLatestReadingCard(List<FlSpot> spots) {
    if (spots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _kPrimaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: _kPrimaryBlue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No readings yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add your first sugar level reading using the button below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final latestSpot = spots.last;
    final glucose = latestSpot.y;
    final status = _getStatus(glucose);
    final statusColor = _getStatusColor(glucose);
    final timeStr = _formatTimeFromX(latestSpot.x);
    final suggestion = _getSuggestion(glucose);
    final suggestionIcon = _getSuggestionIcon(glucose);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        // IntrinsicHeight lets the divider stretch to match whichever column
        // is taller, so long suggestion text never overflows the divider.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: glucose value, status, timestamp
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _kPrimaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        color: _kPrimaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${glucose.toStringAsFixed(0)} mg/dL',
                      style: GoogleFonts.lato(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Today at $timeStr',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical divider — height is driven by IntrinsicHeight
              Container(
                width: 1,
                color: const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              // Right: suggestion
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(suggestionIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Suggestion',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Chart Card ────────────────────────────────────────────────────────────

  Widget _buildChartCard(List<FlSpot> spots) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sugar Level Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kPrimaryBlue,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: _kPrimaryBlue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child:
                  spots.isEmpty
                      ? Center(
                        child: Text(
                          'No sugar readings for this date.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      )
                      : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 50,
                            getDrawingHorizontalLine:
                                (value) => const FlLine(
                                  color: Color(0xFFE2E8F0),
                                  strokeWidth: 1,
                                ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                interval: 50,
                                getTitlesWidget:
                                    (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 6,
                                getTitlesWidget: (value, meta) {
                                  final v = value.toInt();
                                  if (v == 0 ||
                                      v == 6 ||
                                      v == 12 ||
                                      v == 18 ||
                                      v == 24) {
                                    return Text(
                                      '$v:00',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: 70,
                                color: _kOrange.withValues(alpha: 0.75),
                                strokeWidth: 1.5,
                                dashArray: [6, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.only(
                                    right: 6,
                                    bottom: 4,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: _kOrange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  labelResolver: (_) => 'Low 70',
                                ),
                              ),
                              HorizontalLine(
                                y: 180,
                                color: _kRed.withValues(alpha: 0.75),
                                strokeWidth: 1.5,
                                dashArray: [6, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.only(
                                    right: 6,
                                    bottom: 4,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: _kRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  labelResolver: (_) => 'High 180',
                                ),
                              ),
                            ],
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              spots: spots,
                              color: _kPrimaryBlue,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              belowBarData: BarAreaData(
                                show: true,
                                color: _kPrimaryBlue.withValues(alpha: 0.12),
                              ),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter:
                                    (spot, percent, bar, index) =>
                                        FlDotCirclePainter(
                                          radius: 4,
                                          color: Colors.white,
                                          strokeWidth: 2,
                                          strokeColor: _kPrimaryBlue,
                                        ),
                              ),
                            ),
                          ],
                          minX: 0,
                          maxX: 24,
                          minY: 0,
                          maxY: 300,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Statistics Cards ───────────────────────────────────────────────────────

  Widget _buildStatCards(List<FlSpot> spots) {
    final isEmpty = spots.isEmpty;
    final average =
        isEmpty
            ? 0.0
            : spots.map((s) => s.y).reduce((a, b) => a + b) / spots.length;
    final highest =
        isEmpty ? 0.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final lowest =
        isEmpty ? 0.0 : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final count = spots.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.bar_chart_rounded,
                  iconColor: _kPrimaryBlue,
                  iconBg: const Color(0xFFEFF6FF),
                  label: 'Average',
                  value: isEmpty ? '--' : average.toStringAsFixed(0),
                  subtext: 'mg/dL',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: _kRed,
                  iconBg: const Color(0xFFFEF2F2),
                  label: 'Highest',
                  value: isEmpty ? '--' : highest.toStringAsFixed(0),
                  subtext: 'mg/dL',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: _kGreen,
                  iconBg: const Color(0xFFF0FDF4),
                  label: 'Lowest',
                  value: isEmpty ? '--' : lowest.toStringAsFixed(0),
                  subtext: 'mg/dL',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.format_list_numbered_rounded,
                  iconColor: _kPurple,
                  iconBg: const Color(0xFFF5F3FF),
                  label: 'Readings',
                  value: '$count',
                  subtext: 'Today',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                subtext,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Action Cards ───────────────────────────────────────────────────────────

  Widget _buildActionCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildActionCard(
            icon: Icons.bluetooth,
            iconColor: _kPrimaryBlue,
            iconBg: const Color(0xFFEFF6FF),
            title: 'Import from Bluetooth',
            subtitle: 'Sync readings from your glucose meter',
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BluetoothGlucoseScreen(),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.insights,
            iconColor: _kPurple,
            iconBg: const Color(0xFFF5F3FF),
            title: 'AI Health Insights',
            subtitle: 'Get personalised health recommendations',
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AIInsightsScreen(),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFFCBD5E1),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
