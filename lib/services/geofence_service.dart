import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Konfigurasi kotak geofencing di sekitar Gedung Tower 2 ITS.
class CampusGeofence {
  /// Titik pusat kampus: Gedung Tower 2 ITS, Kampus ITS Sukolilo, Surabaya.
  static const double centerLatitude = -7.28525;
  static const double centerLongitude = 112.79534;

  /// Panjang setiap sisi kotak area presensi (meter).
  static const double sideLengthMeters = 30.0;

  static const double _halfSideMeters = sideLengthMeters / 2;

  /// Batas kotak dihitung dari titik pusat menggunakan pendekatan lokal.
  static final double latitudeOffset =
      _halfSideMeters / 6371000 * 180 / math.pi;
  static final double longitudeOffset =
      _halfSideMeters /
      (6371000 * math.cos(centerLatitude * math.pi / 180)) *
      180 /
      math.pi;

  static double get southLatitude => centerLatitude - latitudeOffset;
  static double get northLatitude => centerLatitude + latitudeOffset;
  static double get westLongitude => centerLongitude - longitudeOffset;
  static double get eastLongitude => centerLongitude + longitudeOffset;
}

/// Kumpulan utilitas lokasi & geofencing.
class GeofenceService {
  const GeofenceService._();

  /// Radius bumi dalam meter (rata-rata WGS-84).
  static const double _earthRadiusM = 6371000.0;

  /// Memastikan layanan GPS aktif dan izin lokasi diberikan.
  ///
  /// Mengembalikan `null` bila semua siap, atau pesan error bila
  /// pengguna menolak izin / GPS mati.
  static Future<String?> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Layanan GPS tidak aktif. Nyalakan lokasi di pengaturan perangkat.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Izin lokasi ditolak. Presensi membutuhkan akses lokasi.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return 'Izin lokasi diblokir permanen. Aktifkan lewat pengaturan aplikasi.';
    }

    // permission == whileInUse || always
    return null;
  }

  /// Mengambil posisi GPS saat ini.
  static Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  /// Menghitung jarak (meter) dari [position] ke titik pusat kampus.
  ///
  /// Menggunakan rumus Haversine di atas bola bumi. Alternatif praktis:
  /// `Geolocator.distanceBetween(...)` menghasilkan nilai serupa.
  static double distanceToCampus(Position position) {
    final lat1Rad = _degToRad(position.latitude);
    final lat2Rad = _degToRad(CampusGeofence.centerLatitude);
    final dLat = _degToRad(CampusGeofence.centerLatitude - position.latitude);
    final dLon = _degToRad(CampusGeofence.centerLongitude - position.longitude);

    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusM * c;
  }

  /// `true` bila posisi ada di dalam kotak 30 × 30 meter Tower 2 ITS.
  static bool isWithinCampus(Position position) {
    return position.latitude >= CampusGeofence.southLatitude &&
        position.latitude <= CampusGeofence.northLatitude &&
        position.longitude >= CampusGeofence.westLongitude &&
        position.longitude <= CampusGeofence.eastLongitude;
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}
