import 'dart:math' as math;

/// Utilitas kemiringan perangkat berdasarkan data accelerometer.
///
/// Ketika HP diletakkan mendatar di meja, gravitasi (±9.8 m/s²) bekerja
/// hampir sepenuhnya pada sumbu Y perangkat. Ketika HP ditegakkan
/// (menghadap wajah), gravitasi bekerja pada sumbu Z (sumbu keluar layar).
/// Sudut elevasi = `atan2(|gz|, |gy|)`:
///   - mendatar di meja  → ~0°
///   - tegak sempurna    → ~90°
class DeviceTilt {
  const DeviceTilt._();

  /// Rentang sudut elevasi (derajat) yang dianggap "HP ditegakkan"
  /// dan tombol jepret diaktifkan.
  static const double minElevationDeg = 60;
  static const double maxElevationDeg = 90;

  /// Menghitung sudut elevasi HP (0–90°) dari nilai accelerometer.
  ///
  /// [gx], [gy], [gz] dalam m/s² (termasuk gravitasi).
  static double elevationDegrees({
    required double gx,
    required double gy,
    required double gz,
  }) {
    final angle = math.atan2(gz.abs(), gy.abs());
    return angle * 180.0 / math.pi;
  }

  /// `true` bila HP dalam posisi tegak (elevasi 60–90°) sehingga
  /// tombol jepret boleh ditekan.
  static bool isUpright(double elevationDeg) {
    return elevationDeg >= minElevationDeg && elevationDeg <= maxElevationDeg;
  }
}
