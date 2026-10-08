/// Konfigurasi endpoint API backend.
///
/// Atur URL backend bersama saat menjalankan/build aplikasi Flutter dengan
/// `--dart-define=API_BASE_URL=https://alamat-api-cloud`.
///
/// Bisa juga dioverride saat build tanpa mengedit file ini:
/// ```
/// flutter run -d chrome --dart-define=API_BASE_URL=https://alamat-api-cloud
/// ```
class ApiConfig {
  const ApiConfig._();

  /// Alamat dasar server presensi.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  /// Endpoint pengiriman data absensi.
  static const String absenEndpoint = '/api/absen';

  /// Timeout request (mengunggah foto bisa lambat di jaringan kampus).
  static const Duration sendTimeout = Duration(seconds: 60);
}
