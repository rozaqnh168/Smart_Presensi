import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/course_config.dart';
import '../providers/auth_provider.dart';
import '../services/geofence_service.dart';
import '../theme/colors.dart';
import '../widgets/attendance_location_map.dart';
import 'attendance_history_page.dart';
import 'selfie_page.dart';

/// Halaman dashboard: info NRP, tombol "Mulai Absen" (GPS + geofencing),
/// dan status lokasi.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _courseNoteController = TextEditingController();
  String? _selectedCourse;

  @override
  void dispose() {
    _courseNoteController.dispose();
    super.dispose();
  }

  /// Menjalankan alur absen dan menampilkan snackbar hasil geofencing.
  Future<void> _handleAbsen(BuildContext context) async {
    final courseName = _selectedCourse;
    if (courseName == null) return;
    final courseNote = _courseNoteController.text.trim();

    final auth = context.read<AuthProvider>();
    final status = await auth.startAbsen();

    if (!context.mounted) return;

    final (message, color, icon) = switch (status) {
      AbsenStatus.valid => (
        'Lokasi valid, siap mengambil foto',
        Colors.green,
        Icons.check_circle_rounded,
      ),
      AbsenStatus.outsideCampus => (
        'Anda berada di luar kotak absensi Tower 2 ITS '
            '(${CampusGeofence.sideLengthMeters.toStringAsFixed(0)} × '
            '${CampusGeofence.sideLengthMeters.toStringAsFixed(0)} m).',
        Colors.red,
        Icons.error_rounded,
      ),
      AbsenStatus.error => (
        auth.locationMessage ?? 'Gagal mengambil lokasi.',
        Colors.orange,
        Icons.warning_rounded,
      ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

    // Lokasi valid → lanjut ke halaman swafoto setelah snackbar sebentar.
    if (status == AbsenStatus.valid) {
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SelfiePage(
            courseName: courseName,
            courseNote: courseNote,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Smart Presensi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Riwayat absen',
            icon: const Icon(Icons.history_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () {
              final nrp = auth.nrp;
              if (nrp == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AttendanceHistoryPage(nrp: nrp),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textDark,
            ),
            onPressed: () => auth.logout(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ----- Kartu sambutan + NRP pengguna -----
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Selamat datang',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Mahasiswa',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                color: Colors.white,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'NRP',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    auth.nrp ?? '-',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mata Kuliah',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCourse,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Pilih mata kuliah',
                            prefixIcon: Icon(Icons.menu_book_rounded),
                          ),
                          items: CourseConfig.courses
                              .map(
                                (course) => DropdownMenuItem(
                                  value: course,
                                  child: Text(
                                    course,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: auth.isFetchingLocation
                              ? null
                              : (course) =>
                                    setState(() => _selectedCourse = course),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _courseNoteController,
                          maxLength: 500,
                          maxLines: 3,
                          minLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Catatan mata kuliah (opsional)',
                            hintText: 'Tambahkan catatan untuk absensi ini',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ----- Tombol besar "Mulai Absen" -----
                  Container(
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed:
                          auth.isFetchingLocation || _selectedCourse == null
                          ? null
                          : () => _handleAbsen(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedCourse == null
                            ? AppColors.textMuted
                            : Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: auth.isFetchingLocation
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(
                              Icons.near_me_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                      label: Text(
                        auth.isFetchingLocation
                            ? 'Mendeteksi Lokasi...'
                            : 'Mulai Absen',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      final nrp = auth.nrp;
                      if (nrp == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AttendanceHistoryPage(nrp: nrp),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Lihat Riwayat Absensi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ----- Area status lokasi (Latitude / Longitude / jarak) -----
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textDark.withValues(alpha: 0.035),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.explore_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Status Lokasi',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            if (auth.isWithinCampus)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF8F0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Dalam area',
                                  style: TextStyle(
                                    color: Color(0xFF238451),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _LocationRow(
                          label: 'Latitude',
                          value: auth.latitude?.toStringAsFixed(6) ?? '-',
                        ),
                        _LocationRow(
                          label: 'Longitude',
                          value: auth.longitude?.toStringAsFixed(6) ?? '-',
                        ),
                        _LocationRow(
                          label: 'Jarak',
                          value: auth.distanceToCampus != null
                              ? '${auth.distanceToCampus!.toStringAsFixed(1)} m'
                              : '-',
                        ),
                        if (auth.locationMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: auth.isFetchingLocation
                                  ? const Color(0xFFF4F5FA)
                                  : (auth.isWithinCampus
                                        ? const Color(0xFFEAF8F0)
                                        : const Color(0xFFFFF5E8)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              auth.locationMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: auth.isFetchingLocation
                                    ? AppColors.textMuted
                                    : (auth.isWithinCampus
                                          ? const Color(0xFF238451)
                                          : const Color(0xFF9A5B08)),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        if (auth.latitude != null &&
                            auth.longitude != null) ...[
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris label–nilai untuk menampilkan koordinat & jarak.
class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.grey),
          ),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
