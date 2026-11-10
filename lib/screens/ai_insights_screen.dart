import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/ai_api_service.dart';

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({super.key});

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  final AiApiService _aiApiService = AiApiService();

  // Firestore readings state
  bool _fetchingReadings = true;
  List<double> _glucoseReadings = [];
  String? _readingsFetchError;

  // Per-card loading / result / error
  bool _riskLoading = false;
  bool _glucoseLoading = false;
  bool _anomalyLoading = false;

  Map<String, dynamic>? _riskResult;
  Map<String, dynamic>? _glucoseResult;
  Map<String, dynamic>? _anomalyResult;

  String? _riskError;
  String? _glucoseError;
  String? _anomalyError;

  @override
  void initState() {
    super.initState();
    _fetchGlucoseReadings();
  }

  Future<void> _fetchGlucoseReadings() async {
    setState(() {
      _fetchingReadings = true;
      _readingsFetchError = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _readingsFetchError = 'No logged-in user found.';
          _fetchingReadings = false;
        });
        return;
      }

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('SugarLevels')
              .orderBy('timestamp', descending: true)
              .limit(12)
              .get();

      // Reverse from newest-first into chronological order for LSTM input.
      final readings =
          snapshot.docs
              .map((doc) => (doc['level'] as num).toDouble())
              .toList()
              .reversed
              .toList();

      // ignore: avoid_print
      print(
        '[AIInsightsScreen] Fetched ${readings.length} glucose readings: $readings',
      );

      if (!mounted) return;
      setState(() {
        _glucoseReadings = readings;
        _fetchingReadings = false;
      });
    } catch (error) {
      // ignore: avoid_print
      print('[AIInsightsScreen] Error fetching glucose readings: $error');
      if (!mounted) return;
      setState(() {
        _readingsFetchError = error.toString();
        _fetchingReadings = false;
      });
    }
  }

  Future<void> _predictRisk() async {
    setState(() {
      _riskLoading = true;
      _riskError = null;
      _riskResult = null;
    });

    try {
      final result = await _aiApiService.predictRisk(
        pregnancies: 2,
        glucose: 140,
        bloodPressure: 80,
        skinThickness: 25,
        insulin: 100,
        bmi: 28.5,
        diabetesPedigreeFunction: 0.5,
        age: 35,
      );

      if (!mounted) return;
      setState(() {
        if (result['error'] == true) {
          _riskError = _messageFromError(result);
        } else {
          _riskResult = result;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _riskError = error.toString());
    } finally {
      if (mounted) setState(() => _riskLoading = false);
    }
  }

  Future<void> _predictGlucose() async {
    if (_glucoseReadings.length < 12) {
      setState(() {
        _glucoseError =
            'At least 12 glucose readings are required for forecasting.';
        _glucoseResult = null;
      });
      return;
    }

    setState(() {
      _glucoseLoading = true;
      _glucoseError = null;
      _glucoseResult = null;
    });

    try {
      // ignore: avoid_print
      print(
        '[AIInsightsScreen] Sending ${_glucoseReadings.length} readings to predictGlucose: $_glucoseReadings',
      );

      final result = await _aiApiService.predictGlucose(
        glucoseReadings: _glucoseReadings,
      );

      if (!mounted) return;
      setState(() {
        if (result['error'] == true) {
          _glucoseError = _messageFromError(result);
        } else {
          _glucoseResult = result;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _glucoseError = error.toString());
    } finally {
      if (mounted) setState(() => _glucoseLoading = false);
    }
  }

  Future<void> _detectAnomaly() async {
    if (_glucoseReadings.length < 2) {
      setState(() {
        _anomalyError =
            'At least 2 glucose readings are required for anomaly detection.';
        _anomalyResult = null;
      });
      return;
    }

    setState(() {
      _anomalyLoading = true;
      _anomalyError = null;
      _anomalyResult = null;
    });

    try {
      final latest = _glucoseReadings.last;
      final previous = _glucoseReadings[_glucoseReadings.length - 2];

      // ignore: avoid_print
      print(
        '[AIInsightsScreen] Sending to detectAnomaly: glucose=$latest, previousGlucose=$previous',
      );

      final result = await _aiApiService.detectAnomaly(
        glucose: latest,
        previousGlucose: previous,
      );

      if (!mounted) return;
      setState(() {
        if (result['error'] == true) {
          _anomalyError = _messageFromError(result);
        } else {
          _anomalyResult = result;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _anomalyError = error.toString());
    } finally {
      if (mounted) setState(() => _anomalyLoading = false);
    }
  }

  String _messageFromError(Map<String, dynamic> error) {
    final message = error['message'];
    if (message is String) return message;
    return 'Something went wrong. Please check that the backend is running.';
  }

  String _displayValue(dynamic value) {
    if (value == null) return '--';
    if (value is num) {
      final rounded = value.toStringAsFixed(2);
      return rounded.endsWith('.00') ? value.toStringAsFixed(0) : rounded;
    }
    return value.toString();
  }

  String _displayConfidence(dynamic value) {
    if (value is! num) return '--';
    final percent = value <= 1 ? value * 100 : value;
    return '${percent.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final count = _glucoseReadings.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            children: [
              const Text(
                'AI Health Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'DiaWell-AI decision support',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),

              // Readings status banner
              _ReadingsBanner(
                fetching: _fetchingReadings,
                count: count,
                error: _readingsFetchError,
                onRetry: _fetchGlucoseReadings,
              ),

              const SizedBox(height: 16),

              _InsightCard(
                icon: Icons.favorite_rounded,
                accentColor: const Color(0xFFE11D48),
                title: 'Diabetes Risk Prediction',
                subtitle: 'Profile sample: glucose 140, BMI 28.5, age 35',
                buttonLabel: 'Predict Risk',
                loading: _riskLoading,
                onPressed: _predictRisk,
                errorMessage: _riskError,
                result:
                    _riskResult == null
                        ? null
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ResultRow(
                              label: 'Risk level',
                              value: _displayValue(_riskResult!['risk_level']),
                            ),
                            _ResultRow(
                              label: 'Prediction',
                              value: _displayValue(
                                _riskResult!['prediction_label'],
                              ),
                            ),
                            _ResultRow(
                              label: 'Confidence',
                              value: _displayConfidence(
                                _riskResult!['confidence'],
                              ),
                            ),
                            const SizedBox(height: 10),
                            _DisclaimerBox(
                              text: _displayValue(
                                _riskResult!['decision_support_disclaimer'],
                              ),
                            ),
                          ],
                        ),
              ),
              const SizedBox(height: 14),

              _InsightCard(
                icon: Icons.timeline_rounded,
                accentColor: const Color(0xFF0D9488),
                title: 'Glucose Forecasting',
                subtitle:
                    _fetchingReadings
                        ? 'Loading your glucose history…'
                        : count >= 12
                        ? 'Using your latest $count readings from history'
                        : 'Need 12 readings — $count recorded so far',
                buttonLabel: 'Predict Next Glucose',
                loading: _glucoseLoading,
                onPressed: _predictGlucose,
                errorMessage: _glucoseError,
                result:
                    _glucoseResult == null
                        ? null
                        : Column(
                          children: [
                            _MetricTile(
                              label: 'Predicted glucose',
                              value:
                                  '${_displayValue(_glucoseResult!['predicted_glucose'])} mg/dL',
                              icon: Icons.bloodtype_rounded,
                            ),
                            const SizedBox(height: 8),
                            _ResultRow(
                              label: 'Risk level',
                              value: _displayValue(
                                _glucoseResult!['risk_level'],
                              ),
                            ),
                          ],
                        ),
              ),
              const SizedBox(height: 14),

              _InsightCard(
                icon: Icons.warning_amber_rounded,
                accentColor: const Color(0xFFF97316),
                title: 'Anomaly Detection',
                subtitle:
                    _fetchingReadings
                        ? 'Loading your glucose history…'
                        : count >= 2
                        ? 'Latest ${_glucoseReadings.last.toStringAsFixed(0)} mg/dL'
                            ' vs previous ${_glucoseReadings[count - 2].toStringAsFixed(0)} mg/dL'
                        : 'Need at least 2 readings — $count recorded so far',
                buttonLabel: 'Detect Anomaly',
                loading: _anomalyLoading,
                onPressed: _detectAnomaly,
                errorMessage: _anomalyError,
                result:
                    _anomalyResult == null
                        ? null
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ResultRow(
                              label: 'Anomaly status',
                              value: _displayValue(
                                _anomalyResult!['anomaly_status'],
                              ),
                            ),
                            _ResultRow(
                              label: 'Risk level',
                              value: _displayValue(
                                _anomalyResult!['risk_level'],
                              ),
                            ),
                            _ResultRow(
                              label: 'Glucose change',
                              value:
                                  '${_displayValue(_anomalyResult!['glucose_change'])} mg/dL',
                            ),
                            _ResultRow(
                              label: 'Confidence',
                              value: _displayConfidence(
                                _anomalyResult!['confidence'],
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
}

// ---------------------------------------------------------------------------
// Readings status banner
// ---------------------------------------------------------------------------

class _ReadingsBanner extends StatelessWidget {
  const _ReadingsBanner({
    required this.fetching,
    required this.count,
    required this.onRetry,
    this.error,
  });

  final bool fetching;
  final int count;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (fetching) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Loading glucose readings from Firestore…',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Could not load readings: $error',
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 12.5,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final color =
        count >= 12
            ? const Color(0xFF14532D)
            : count >= 2
            ? const Color(0xFF78350F)
            : const Color(0xFF7F1D1D);

    final bg =
        count >= 12
            ? const Color(0xFFDCFCE7)
            : count >= 2
            ? const Color(0xFFFEF9C3)
            : const Color(0xFFFEE2E2);

    final icon =
        count >= 12 ? Icons.check_circle_outline : Icons.info_outline_rounded;

    final message =
        count >= 12
            ? '$count readings loaded — ready for all AI features'
            : count >= 2
            ? '$count readings loaded — anomaly detection available; need 12 for forecasting'
            : '$count reading${count == 1 ? '' : 's'} loaded — add more to unlock AI features';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Icon(Icons.refresh, color: color, size: 18),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card widget
// ---------------------------------------------------------------------------

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.loading,
    required this.onPressed,
    this.errorMessage,
    this.result,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool loading;
  final VoidCallback onPressed;
  final String? errorMessage;
  final Widget? result;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onPressed,
                icon:
                    loading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.auto_awesome_rounded),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accentColor.withValues(alpha: 0.55),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(message: errorMessage!),
            ],
            if (result != null) ...[const SizedBox(height: 14), result!],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper display widgets
// ---------------------------------------------------------------------------

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerBox extends StatelessWidget {
  const _DisclaimerBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
