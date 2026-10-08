import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/geofence_service.dart';

/// Hasil dari proses absen (untuk menentukan snackbar di UI).
enum AbsenStatus { valid, outsideCampus, error }

/// State global aplikasi: sesi login pengguna dan status lokasi presensi.
///
/// Menggunakan [ChangeNotifier] + package `provider` agar UI dapat
/// bereaksi terhadap perubahan state secara reaktif.
class AuthProvider extends ChangeNotifier {
  String? _nrp;
  bool _isLoggedIn = false;

  /// NRP mahasiswa yang sedang login.
  String? get nrp => _nrp;
  bool get isLoggedIn => _isLoggedIn;

  // ----- Status lokasi presensi -----
  bool _isFetchingLocation = false;
  bool get isFetchingLocation => _isFetchingLocation;

  double? _latitude;
  double? get latitude => _latitude;

  double? _longitude;
  double? get longitude => _longitude;

  double? _distanceToCampus;
  double? get distanceToCampus => _distanceToCampus;

  bool _isWithinCampus = false;
  bool get isWithinCampus => _isWithinCampus;

  String? _locationMessage;
  String? get locationMessage => _locationMessage;

  /// Proses login sederhana (dummy).
  ///
  /// Validasi: NRP wajib diisi (min. 6 karakter) dan password min. 6 karakter.
  /// Mengembalikan pesan error (String) bila gagal, atau `null` bila sukses.
  /// TODO: ganti dengan panggilan API backend yang sebenarnya.
  String? login(String nrp, String password) {
    if (nrp.trim().length < 6) {
      return 'NRP minimal 6 karakter.';
    }
    if (password.length < 6) {
      return 'Password minimal 6 karakter.';
    }

    _nrp = nrp.trim();
    _isLoggedIn = true;
    notifyListeners();
    return null;
  }

  /// Keluar dari sesi dan reset semua state.
  void logout() {
    _nrp = null;
    _isLoggedIn = false;
    _resetLocation();
    notifyListeners();
  }

  /// Alur tombol "Mulai Absen":
  /// 1. Cek & minta izin lokasi.
  /// 2. Ambil posisi GPS saat ini.
  /// 3. Hitung jarak ke pusat kampus (geofencing).
  /// 4. Kembalikan status valid / di luar area / error.
  Future<AbsenStatus> startAbsen() async {
    if (_isFetchingLocation) return AbsenStatus.error;

    _isFetchingLocation = true;
    _latitude = null;
    _longitude = null;
    _distanceToCampus = null;
    _isWithinCampus = false;
    _locationMessage = 'Mendeteksi lokasi GPS...';
    notifyListeners();

    // 1. Izin lokasi.
    final permissionError = await GeofenceService.ensurePermission();
    if (permissionError != null) {
      _isFetchingLocation = false;
      _locationMessage = permissionError;
      notifyListeners();
      return AbsenStatus.error;
    }

    try {
      // 2. Posisi GPS saat ini.
      final position = await GeofenceService.getCurrentPosition();
      _latitude = position.latitude;
      _longitude = position.longitude;
      _locationMessage = 'Lokasi GPS berhasil didapatkan.';
      notifyListeners();

      // 3. Geofencing: posisi harus berada di dalam kotak Tower 2 ITS.
      final distance = GeofenceService.distanceToCampus(position);
      _distanceToCampus = distance;
      _isWithinCampus = GeofenceService.isWithinCampus(position);

      _isFetchingLocation = false;
      notifyListeners();
      return _isWithinCampus ? AbsenStatus.valid : AbsenStatus.outsideCampus;
    } catch (e) {
      _isFetchingLocation = false;
      _locationMessage = 'Gagal mendapatkan lokasi: ${e.toString()}';
      notifyListeners();
      return AbsenStatus.error;
    }
  }

  /// Memperbarui koordinat dan status geofence dari aliran posisi GPS aktif.
  void updateLivePosition(Position position) {
    _latitude = position.latitude;
    _longitude = position.longitude;
    _distanceToCampus = GeofenceService.distanceToCampus(position);
    _isWithinCampus = GeofenceService.isWithinCampus(position);
    _locationMessage = _isWithinCampus
        ? 'Lokasi GPS diperbarui secara realtime.'
        : 'Lokasi berada di luar kotak absensi Tower 2 ITS.';
    notifyListeners();
  }

  void _resetLocation() {
    _isFetchingLocation = false;
    _latitude = null;
    _longitude = null;
    _distanceToCampus = null;
    _isWithinCampus = false;
    _locationMessage = null;
  }
}
