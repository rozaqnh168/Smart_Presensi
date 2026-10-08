import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// Hasil pengiriman absensi dari server.
class AbsenResult {
  const AbsenResult({required this.success, this.message});

  final bool success;
  final String? message;

  factory AbsenResult.success(String message) =>
      AbsenResult(success: true, message: message);

  factory AbsenResult.failure(String message) =>
      AbsenResult(success: false, message: message);
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.nrp,
    required this.courseName,
    required this.courseNote,
    required this.latitude,
    required this.longitude,
    required this.photoPath,
    required this.attendedAt,
  });

  final int id;
  final String nrp;
  final String courseName;
  final String courseNote;
  final String latitude;
  final String longitude;
  final String photoPath;
  final DateTime? attendedAt;

  factory AttendanceRecord.fromJson(Map<dynamic, dynamic> json) {
    final rawDate = json['waktu_absen'];
    final parsedDate = rawDate is String
        ? DateTime.tryParse(rawDate.replaceFirst(' ', 'T'))
        : null;

    return AttendanceRecord(
      id: _parseInt(json['id']),
      nrp: _readString(json['nrp']),
      courseName: _readString(json['mata_kuliah'], fallback: 'Belum tercatat'),
      courseNote: _readString(json['catatan'], fallback: ''),
      latitude: _readString(json['latitude']),
      longitude: _readString(json['longitude']),
      photoPath: _readString(json['foto_path']),
      attendedAt: parsedDate,
    );
  }

  static String _readString(dynamic value, {String fallback = '-'}) =>
      value == null || value.toString().isEmpty ? fallback : value.toString();

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }
}

/// Client HTTP untuk pengiriman data presensi ke server.
class AbsenApiService {
  AbsenApiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: ApiConfig.sendTimeout,
              sendTimeout: ApiConfig.sendTimeout,
              // Endpoint memakai HTTP (bukan HTTPS) di jaringan lokal,
              // jadi pastikan tidak ada validasi sertifikat yang menghalangi.
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  final Dio _dio;

  /// Mengirim data presensi ke `POST /api/absen` sebagai `multipart/form-data`.
  ///
  /// Field:
  /// - `nrp`       : NRP mahasiswa (String)
  /// - `latitude`  : koordinat lintang (String)
  /// - `longitude` : koordinat bujur (String)
  /// - `foto`      : file gambar hasil jepretan kamera
  ///
  /// Foto dapat berupa file di perangkat ([photoPath], aplikasi mobile) atau
  /// bytes di memori ([photoBytes], aplikasi web/laptop — hasil `XFile`
  /// dari kamera web tidak memiliki path file fisik).
  ///
  /// Mengembalikan [AbsenResult.success] bila server merespons 200,
  /// atau [AbsenResult.failure] berisi pesan error yang bisa ditampilkan.
  Future<AbsenResult> submitAbsensi({
    required String nrp,
    required String courseName,
    String courseNote = '',
    required String latitude,
    required String longitude,
    String? photoPath,
    Uint8List? photoBytes,
  }) async {
    MultipartFile fotoPart;
    if (photoBytes != null) {
      fotoPart = MultipartFile.fromBytes(
        photoBytes,
        filename: 'absen_$nrp.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      );
    } else if (photoPath != null) {
      final photoFile = File(photoPath);
      if (!await photoFile.exists()) {
        return AbsenResult.failure('File foto tidak ditemukan di perangkat.');
      }
      fotoPart = await MultipartFile.fromFile(
        photoPath,
        filename: 'absen_$nrp.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      );
    } else {
      return AbsenResult.failure('Foto absensi belum tersedia.');
    }

    final formData = FormData.fromMap({
      'nrp': nrp,
      'mata_kuliah': courseName,
      'catatan': courseNote,
      'latitude': latitude,
      'longitude': longitude,
      'foto': fotoPart,
    });

    try {
      final response = await _dio.post<dynamic>(
        ApiConfig.absenEndpoint,
        data: formData,
      );

      if (response.statusCode == 200) {
        // Ambil pesan dari server bila ada, jika tidak pakai default.
        final dynamic data = response.data;
        final serverMessage = data is Map && data['message'] is String
            ? data['message'] as String
            : null;
        return AbsenResult.success(serverMessage ?? 'Absensi Berhasil');
      }

      // Status selain 200 (mis. 400/422): coba ambil pesan error server.
      final dynamic errData = response.data;
      final serverError = errData is Map && errData['message'] is String
          ? errData['message'] as String
          : null;
      return AbsenResult.failure(
        serverError ?? 'Server menolak permintaan (${response.statusCode}).',
      );
    } on DioException catch (e) {
      return AbsenResult.failure(_describeDioError(e));
    }
  }

  Future<List<AttendanceRecord>> fetchHistory(String nrp) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConfig.absenEndpoint,
        queryParameters: {'nrp': nrp},
      );

      if (response.statusCode != 200) {
        final dynamic data = response.data;
        final message = data is Map && data['message'] is String
            ? data['message'] as String
            : 'Gagal memuat riwayat (HTTP ${response.statusCode}).';
        throw StateError(message);
      }

      final dynamic responseData = response.data;
      if (responseData is! Map || responseData['data'] is! List) {
        throw const FormatException('Format riwayat dari server tidak valid.');
      }

      return (responseData['data'] as List).map((row) {
        if (row is! Map) {
          throw const FormatException('Data riwayat dari server tidak valid.');
        }
        return AttendanceRecord.fromJson(row);
      }).toList();
    } on DioException catch (e) {
      throw StateError(_describeDioError(e));
    }
  }

  /// Menerjemahkan [DioException] menjadi pesan ramah pengguna.
  String _describeDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server merespons terlalu lama. Coba lagi.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Pastikan backend berjalan '
            'dan alamat API benar. Jika memakai HP, pastikan HP dan laptop '
            'berada di jaringan yang sama.';
      case DioExceptionType.badResponse:
        return 'Server mengembalikan respons tidak valid.';
      case DioExceptionType.cancel:
        return 'Pengiriman dibatalkan.';
      default:
        return 'Terjadi kesalahan jaringan: ${e.message ?? e.error}';
    }
  }
}
