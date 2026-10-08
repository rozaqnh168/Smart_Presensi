import 'package:flutter_test/flutter_test.dart';
import 'package:smart_presensi/services/device_tilt.dart';

void main() {
  group('DeviceTilt.elevationDegrees', () {
    test('HP mendatar di meja → elevasi ~0°', () {
      // Gravitasi penuh pada sumbu Y (layar menghadap ke atas).
      final angle = DeviceTilt.elevationDegrees(gx: 0, gy: -9.8, gz: 0);
      expect(angle, closeTo(0, 1));
    });

    test('HP tegak sempurna menghadap wajah → elevasi ~90°', () {
      // Gravitasi penuh pada sumbu Z (keluar layar).
      final angle = DeviceTilt.elevationDegrees(gx: 0, gy: 0, gz: -9.8);
      expect(angle, closeTo(90, 1));
    });

    test('HP miring 45° → elevasi ~45°', () {
      final angle = DeviceTilt.elevationDegrees(
        gx: 0,
        gy: -9.8 / 2,
        gz: -9.8 / 2,
      );
      expect(angle, closeTo(45, 1));
    });
  });

  group('DeviceTilt.isUpright (gerbang tombol jepret)', () {
    test('elevasi 0–59° → tombol nonaktif', () {
      expect(DeviceTilt.isUpright(0), isFalse);
      expect(DeviceTilt.isUpright(30), isFalse);
      expect(DeviceTilt.isUpright(59.9), isFalse);
    });

    test('elevasi 60–90° → tombol aktif', () {
      expect(DeviceTilt.isUpright(60), isTrue);
      expect(DeviceTilt.isUpright(75), isTrue);
      expect(DeviceTilt.isUpright(90), isTrue);
    });
  });
}
