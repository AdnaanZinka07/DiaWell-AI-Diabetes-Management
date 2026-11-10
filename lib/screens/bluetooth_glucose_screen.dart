import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/bluetooth_glucose_service.dart';

enum _ScanState { idle, scanning, done }

enum _ConnectState { idle, busy }

class BluetoothGlucoseScreen extends StatefulWidget {
  const BluetoothGlucoseScreen({super.key});

  @override
  State<BluetoothGlucoseScreen> createState() => _BluetoothGlucoseScreenState();
}

class _BluetoothGlucoseScreenState extends State<BluetoothGlucoseScreen> {
  final _service = BluetoothGlucoseService();

  _ScanState _scanState = _ScanState.idle;
  _ConnectState _connectState = _ConnectState.idle;

  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  String _statusMessage = '';

  // Simulated reading section
  final _simController = TextEditingController();
  final _simFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    _simController.dispose();
    super.dispose();
  }

  // ─── BLE Scan ────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    if (_scanState == _ScanState.scanning) return;

    debugPrint('[BT Screen] Starting BLE scan…');

    setState(() {
      _results.clear();
      _scanState = _ScanState.scanning;
      _statusMessage = 'Scanning for BLE devices…';
    });

    try {
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          for (final r in results) {
            final already = _results.any(
              (e) => e.device.remoteId == r.device.remoteId,
            );
            if (!already) {
              _results.add(r);
              debugPrint(
                '[BT Screen] Found device: ${_name(r.device)} '
                '(${r.device.remoteId.str}) RSSI=${r.rssi}',
              );
            }
          }
        });
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 10));

      if (!mounted) return;
      debugPrint(
        '[BT Screen] Scan complete. ${_results.length} device(s) found.',
      );
      setState(() {
        _scanState = _ScanState.done;
        _statusMessage =
            _results.isEmpty
                ? 'No devices found. Make sure your device is on and nearby.'
                : '${_results.length} device(s) found. Tap one to connect.';
      });
    } catch (e) {
      debugPrint('[BT Screen] Scan error: $e');
      if (!mounted) return;
      setState(() {
        _scanState = _ScanState.done;
        _statusMessage = 'Scan failed: $e';
      });
    }
  }

  // ─── BLE Connect & Read ──────────────────────────────────────────────────

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connectState == _ConnectState.busy) return;

    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();

    debugPrint(
      '[BT Screen] Connecting to ${_name(device)} (${device.remoteId.str})…',
    );

    setState(() {
      _connectState = _ConnectState.busy;
      _statusMessage = 'Connecting to ${_name(device)}…';
    });

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      debugPrint('[BT Screen] Connected to ${_name(device)}.');

      if (!mounted) return;
      setState(() => _statusMessage = 'Reading glucose characteristic…');

      final value = await _service.readGlucoseFromDevice(device);

      if (!mounted) return;

      if (value != null) {
        debugPrint('[BT Screen] Glucose value read: $value mg/dL');
        setState(() {
          _statusMessage = 'Glucose reading: ${value.toStringAsFixed(1)} mg/dL';
        });
        _showSaveDialog(value);
      } else {
        debugPrint('[BT Screen] No glucose characteristic found on device.');
        setState(() {
          _statusMessage =
              'No standard glucose characteristic found. '
              'Use the field below to enter a value.';
        });
      }
    } catch (e) {
      debugPrint('[BT Screen] Connection error: $e');
      if (!mounted) return;
      setState(() => _statusMessage = 'Connection error: $e');
      _showError('Could not connect to device. Please try again.');
    } finally {
      try {
        await device.disconnect();
        debugPrint('[BT Screen] Disconnected from ${_name(device)}.');
      } catch (_) {}
      if (mounted) setState(() => _connectState = _ConnectState.idle);
    }
  }

  // ─── Save ────────────────────────────────────────────────────────────────

  Future<void> _saveReading(double value) async {
    debugPrint('[BT Screen] Saving glucose value: $value mg/dL');
    try {
      await _service.saveGlucoseReading(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${value.toStringAsFixed(1)} mg/dL to your records!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // HomeContent StreamBuilder updates automatically
    } catch (e) {
      debugPrint('[BT Screen] Save error: $e');
      if (!mounted) return;
      _showError('Error saving reading: $e');
    }
  }

  void _submitSimulated() {
    if (!_simFormKey.currentState!.validate()) return;
    final value = double.parse(_simController.text.trim());
    debugPrint('[BT Screen] Simulated reading submitted: $value mg/dL');
    _saveReading(value);
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  void _showSaveDialog(double value) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Save Glucose Reading'),
            content: Text(
              'Detected: ${value.toStringAsFixed(1)} mg/dL\n\n'
              'Save to your health records?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveReading(value);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _name(BluetoothDevice device) {
    final n = device.platformName;
    return n.isNotEmpty ? n : device.remoteId.str;
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final busy = _connectState == _ConnectState.busy;
    final scanning = _scanState == _ScanState.scanning;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Import from Bluetooth',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Scrollable BLE section ──────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                busy
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_searching,
                                size: 48,
                                color:
                                    scanning || busy
                                        ? Colors.blueAccent
                                        : Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _statusMessage.isEmpty
                                    ? 'Tap "Start Scan" to find nearby BLE devices.'
                                    : _statusMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (scanning || busy) ...[
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Scan button
                      ElevatedButton.icon(
                        onPressed: scanning || busy ? null : _startScan,
                        icon: const Icon(Icons.search),
                        label: Text(scanning ? 'Scanning…' : 'Start Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E3C72),
                          disabledBackgroundColor: Colors.white38,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_results.isNotEmpty) ...[
                        Text(
                          'Nearby Devices',
                          style: GoogleFonts.lato(
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Device list
                      Expanded(
                        child:
                            _results.isEmpty
                                ? Center(
                                  child: Text(
                                    _scanState == _ScanState.idle
                                        ? 'No scan started yet.'
                                        : scanning
                                        ? 'Looking for devices…'
                                        : 'No BLE devices found nearby.',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: _results.length,
                                  itemBuilder: (context, index) {
                                    final result = _results[index];
                                    final device = result.device;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.bluetooth,
                                          color: Colors.blueAccent,
                                        ),
                                        title: Text(
                                          _name(device),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(device.remoteId.str),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${result.rssi} dBm',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.chevron_right),
                                          ],
                                        ),
                                        onTap:
                                            busy
                                                ? null
                                                : () =>
                                                    _connectToDevice(device),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Simulated Bluetooth Reading ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _simFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.science_outlined,
                                color: Colors.blueAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Simulated Bluetooth Reading',
                                style: GoogleFonts.lato(
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Use this to test without a real glucose meter.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _simController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Glucose Level (mg/dL)',
                              hintText: 'e.g. 120',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter a glucose value';
                              }
                              final n = double.tryParse(v.trim());
                              if (n == null) return 'Enter a valid number';
                              if (n < 10 || n > 1000) {
                                return 'Value must be between 10–1000 mg/dL';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: busy ? null : _submitSimulated,
                            icon: const Icon(Icons.save_alt),
                            label: const Text('Save Simulated Reading'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3C72),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
