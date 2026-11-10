import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothGlucoseService {
  static const String _glucoseServiceUuid = '1808';
  static const String _glucoseMeasurementUuid = '2a18';

  Future<void> saveGlucoseReading(double level) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    debugPrint(
      '[BT Service] Saving glucose: level=$level mg/dL, '
      'source=bluetooth, uid=$uid',
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('SugarLevels')
        .add({
          'level': level,
          'timestamp': FieldValue.serverTimestamp(),
          'source': 'bluetooth',
        });

    debugPrint('[BT Service] Saved to users/$uid/SugarLevels successfully.');
  }

  /// Discovers BLE services and reads glucose in mg/dL, or null if unavailable.
  Future<double?> readGlucoseFromDevice(BluetoothDevice device) async {
    debugPrint(
      '[BT Service] Discovering services on ${device.platformName} '
      '(${device.remoteId.str})…',
    );
    try {
      final services = await device.discoverServices();
      debugPrint('[BT Service] Found ${services.length} service(s).');

      // Look for the standard BLE Glucose service (UUID 0x1808)
      for (final service in services) {
        if (_uuidContains(service.uuid, _glucoseServiceUuid)) {
          debugPrint('[BT Service] Found glucose service: ${service.uuid}');
          for (final char in service.characteristics) {
            if (_uuidContains(char.uuid, _glucoseMeasurementUuid) &&
                char.properties.read) {
              debugPrint(
                '[BT Service] Reading glucose characteristic: ${char.uuid}',
              );
              final bytes = await char.read();
              final value = _parseGlucoseMeasurement(bytes);
              debugPrint('[BT Service] Parsed glucose value: $value mg/dL');
              return value;
            }
          }
        }
      }

      debugPrint(
        '[BT Service] No standard glucose service found. '
        'Trying heuristic fallback…',
      );

      // Fallback: scan every readable characteristic for a plausible glucose value
      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.read) {
            final bytes = await char.read();
            final value = _tryParseAsGlucose(bytes);
            if (value != null) {
              debugPrint(
                '[BT Service] Heuristic match on ${char.uuid}: $value mg/dL',
              );
              return value;
            }
          }
        }
      }

      debugPrint('[BT Service] No glucose value found on device.');
      return null;
    } catch (e) {
      debugPrint('[BT Service] Error reading from device: $e');
      return null;
    }
  }

  bool _uuidContains(Guid uuid, String fragment) =>
      uuid.toString().toLowerCase().contains(fragment.toLowerCase());

  // Parses the standard BLE Glucose Measurement Characteristic (0x2A18).
  double? _parseGlucoseMeasurement(List<int> bytes) {
    if (bytes.length < 10) return null;
    try {
      final flags = bytes[0];
      // Offset: 1 (seq#) + 2 (base time 7 bytes starts at 3, ends at 9) = 10
      int idx = 10;
      if ((flags & 0x01) != 0) idx += 2; // optional time offset present

      if (bytes.length > idx + 1 && (flags & 0x02) != 0) {
        final rawSfloat = (bytes[idx + 1] << 8) | bytes[idx];
        final exp = (rawSfloat >> 12) & 0xF;
        final mantissa = rawSfloat & 0xFFF;
        final signedExp = exp > 7 ? exp - 16 : exp;
        final signedMantissa = mantissa > 2047 ? mantissa - 4096 : mantissa;
        double conc = signedMantissa * _pow10(signedExp);

        // Bit 2: 0 = kg/L → mg/dL (*100000), 1 = mol/L → mg/dL (*18018)
        conc *= (flags & 0x04) == 0 ? 100000.0 : 18018.0;

        if (conc > 10 && conc < 1000) {
          return double.parse(conc.toStringAsFixed(1));
        }
      }
    } catch (_) {}
    return null;
  }

  double _pow10(int exp) {
    double result = 1.0;
    if (exp >= 0) {
      for (int i = 0; i < exp; i++) {
        result *= 10.0;
      }
    } else {
      for (int i = 0; i > exp; i--) {
        result /= 10.0;
      }
    }
    return result;
  }

  // Heuristic: try little-endian uint16 or single byte in a plausible glucose range.
  double? _tryParseAsGlucose(List<int> bytes) {
    if (bytes.length >= 2) {
      final v = bytes[0] | (bytes[1] << 8);
      if (v >= 20 && v <= 600) return v.toDouble();
    }
    if (bytes.length == 1 && bytes[0] >= 20 && bytes[0] <= 300) {
      return bytes[0].toDouble();
    }
    return null;
  }
}
