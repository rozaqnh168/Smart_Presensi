import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../providers/auth_provider.dart';
import '../services/absen_api_service.dart';
import '../services/device_tilt.dart';
import '../theme/colors.dart';
import '../widgets/attendance_location_map.dart';

/// Halaman swafoto (selfie) untuk absensi.
///
/// - Kamera depan terbuka secara default.
/// - Tombol jepret hanya aktif jika HP ditegakkan (elevasi 60–90°)
///   berdasarkan accelerometer — mencegah HP diletakkan di meja.
///   Di web/laptop tidak ada accelerometer, jadi cek kemiringan dilewati.
/// - Setelah jepret: preview foto + koordinat GPS + tombol kirim.
class SelfiePage extends StatefulWidget {
  const SelfiePage({
    super.key,
    required this.courseName,
    this.courseNote = '',
  });

  final String courseName;
  final String courseNote;

  @override
  State<SelfiePage> createState() => _SelfiePageState();
}

class _SelfiePageState extends State<SelfiePage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isInitializingCamera = true;
  String? _cameraError;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<Position>? _locationSubscription;
  double _elevation = 0;

  String? _photoPath;

  /// Bytes foto saat berjalan di web (XFile kamera web tidak punya path).
  Uint8List? _photoBytes;

  bool _isSending = false;

  /// Accelerometer hanya ada di HP (Android/iOS). Di web dan desktop tidak
  /// ada sensor kemiringan sehingga gate "HP tegak" harus dilewati.
  bool get _hasAccelerometer =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get _isUpright => !_hasAccelerometer || DeviceTilt.isUpright(_elevation);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    if (_hasAccelerometer) _listenAccelerometer();
    _listenLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _locationSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  void _listenLocation() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen(
      (position) {
        if (mounted) {
          context.read<AuthProvider>().updateLivePosition(position);
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pembaruan GPS realtime terhenti. Periksa izin lokasi.',
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Bebaskan kamera saat app tidak aktif agar bisa dipakai app lain.
      controller.dispose();
      setState(() => _cameraController = null);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  /// Inisialisasi kamera depan (fallback ke kamera pertama yang tersedia).
  Future<void> _initCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no-camera', 'Tidak ada kamera tersedia.');
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
    } on CameraException catch (e) {
      // Termasuk kasus izin kamera ditolak (CameraAccessDenied).
      setState(() => _cameraError = _describeCameraError(e));
    } finally {
      if (mounted) setState(() => _isInitializingCamera = false);
    }
  }

  String _describeCameraError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Izin kamera ditolak. Aktifkan izin kamera melalui pengaturan aplikasi.';
      case 'CameraAccessRestricted':
        return 'Akses kamera dibatasi oleh perangkat.';
      default:
        return 'Kamera gagal dimuat: ${e.description ?? e.code}';
    }
  }

  /// Pantau accelerometer untuk menghitung sudut elevasi HP.
  void _listenAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final elevation = DeviceTilt.elevationDegrees(
        gx: event.x,
        gy: event.y,
        gz: event.z,
      );
      // Hanya rebuild bila status tegak berubah atau pergeseran cukup besar.
      if ((elevation - _elevation).abs() > 1 ||
          _isUpright != DeviceTilt.isUpright(elevation)) {
        setState(() => _elevation = elevation);
      } else {
        _elevation = elevation;
      }
    });
  }

  /// Ambil swafoto.
  Future<void> _takePicture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!_isUpright) return; // pengaman tambahan di sisi logika.

    try {
      final photo = await controller.takePicture();
      if (kIsWeb) {
        // Di web, XFile tidak punya path file fisik — baca sebagai bytes.
        final bytes = await photo.readAsBytes();
        setState(() => _photoBytes = bytes);
      } else {
        setState(() => _photoPath = photo.path);
      }
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: ${e.description}')),
      );
    }
  }

  /// Kirim absensi (foto + koordinat GPS) ke server via dio multipart.
  Future<void> _submitAbsensi() async {
    final auth = context.read<AuthProvider>();
    final nrp = auth.nrp;
    final latitude = auth.latitude;
    final longitude = auth.longitude;
    final photoPath = _photoPath;
    final photoBytes = _photoBytes;

    if (nrp == null ||
        latitude == null ||
        longitude == null ||
        !auth.isWithinCampus ||
        (photoPath == null && photoBytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !auth.isWithinCampus
                ? 'Lokasi Anda di luar kotak absensi Tower 2 ITS. Kembali ke dalam kotak sebelum mengirim.'
                : 'Data absensi belum lengkap. Ulangi dari dashboard.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    final result = await AbsenApiService().submitAbsensi(
      nrp: nrp,
      courseName: widget.courseName,
      courseNote: widget.courseNote,
      latitude: latitude.toStringAsFixed(6),
      longitude: longitude.toStringAsFixed(6),
      photoPath: photoPath,
      photoBytes: photoBytes,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.success) {
      // Sukses (status 200): dialog "Absensi Berhasil".
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                result.message ?? 'Absensi Berhasil',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kehadiran Anda berhasil dicatat.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.of(context).pop(); // kembali ke Dashboard.
    } else {
      // Gagal: tampilkan pesan error, tetap di preview agar bisa dicoba lagi.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(result.message ?? 'Pengiriman gagal.')),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _photoPath != null || _photoBytes != null
          ? AppColors.background
          : Colors.black,
      appBar: AppBar(
        title: const Text(
          'Foto Selfie',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: _photoPath != null || _photoBytes != null
            ? AppColors.background
            : Colors.black,
        foregroundColor: _photoPath != null || _photoBytes != null
            ? AppColors.textDark
            : Colors.white,
        elevation: 0,
      ),
      body: _photoPath != null || _photoBytes != null
          ? _buildPreview(context, auth)
          : _buildCameraView(context),
    );
  }

  // ----- Tampilan kamera (sebelum jepret) -----

  Widget _buildCameraView(BuildContext context) {
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Preview kamera atau pesan error.
          if (_isInitializingCamera)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_cameraError != null)
            _CameraErrorView(message: _cameraError!, onRetry: _initCamera)
          else if (_cameraController != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CameraPreview(_cameraController!),
            ),

          // Bingkai panduan wajah.
          if (_cameraController != null)
            Center(
              child: Container(
                width: 240,
                height: 320,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.75),
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(120),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),

          if (_cameraController != null)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.face_retouching_natural_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Posisikan wajah di dalam bingkai',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Peringatan bila HP tidak tegak (hanya perangkat dengan accelerometer).
          if (_hasAccelerometer)
            Positioned(
              top: 68,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: _isUpright ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: _isUpright,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.screen_rotation_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tegakkan HP Anda untuk memotret '
                            '(elevasi saat ini ${_elevation.toStringAsFixed(0)}°)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Tombol jepret di bawah.
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  !_hasAccelerometer
                      ? 'Siap memotret'
                      : _isUpright
                      ? 'Posisi HP tegak — siap memotret'
                      : 'Tombol jepret nonaktif',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _ShutterButton(
                  enabled: _isUpright && _cameraController != null,
                  onPressed: _takePicture,
                ),
                const SizedBox(height: 10),
                Text(
                  'Ketuk tombol untuk mengambil foto',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----- Tampilan preview foto (setelah jepret) -----

  /// Widget foto hasil jepretan: bytes di memori (web) atau file (mobile).
  Widget _buildPhoto() {
    final errorView = Container(
      height: 380,
      color: Colors.white12,
      alignment: Alignment.center,
      child: const Text(
        'Gagal memuat foto',
        style: TextStyle(color: Colors.white),
      ),
    );

    final bytes = _photoBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        height: 380,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => errorView,
      );
    }
    return Image.file(
      File(_photoPath!),
      height: 380,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => errorView,
    );
  }

  Widget _buildPreview(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----- Foto yang baru diambil -----
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  _buildPhoto(),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Foto siap',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ----- Kartu koordinat GPS (tahap geofencing) -----
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textDark.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Koordinat Absensi',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PreviewRow(label: 'NRP', value: auth.nrp ?? '-'),
                  _PreviewRow(
                    label: 'Mata Kuliah',
                    value: widget.courseName,
                  ),
                  if (widget.courseNote.isNotEmpty)
                    _PreviewRow(
                      label: 'Catatan',
                      value: widget.courseNote,
                    ),
                  _PreviewRow(
                    label: 'Latitude',
                    value: auth.latitude?.toStringAsFixed(6) ?? '-',
                  ),
                  _PreviewRow(
                    label: 'Longitude',
                    value: auth.longitude?.toStringAsFixed(6) ?? '-',
                  ),
                  _PreviewRow(
                    label: 'Jarak',
                    value:
                        '${auth.distanceToCampus?.toStringAsFixed(1) ?? '-'} m',
                  ),
                  if (auth.latitude != null && auth.longitude != null) ...[
                    const SizedBox(height: 16),
                    AttendanceLocationMap(
                      latitude: auth.latitude!,
                      longitude: auth.longitude!,
                      showCampusBoundary: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ----- Tombol Kirim Absensi -----
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isSending || !auth.isWithinCampus
                    ? null
                    : _submitAbsensi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSending
                      ? 'Mengirim...'
                      : auth.isWithinCampus
                      ? 'Kirim Absensi'
                      : 'Di luar area absensi',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ----- Tombol ulangi -----
            TextButton.icon(
              onPressed: _isSending
                  ? null
                  : () => setState(() {
                      _photoPath = null;
                      _photoBytes = null;
                    }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ambil Ulang Foto'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol jepret bulat besar; redup & tidak responsif saat nonaktif.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled ? Colors.white : Colors.white38,
          width: 4,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Material(
        color: enabled ? Colors.white : Colors.white24,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Pesan error kamera dengan tombol coba lagi.
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_rounded,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

/// Baris label–nilai di kartu preview.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
