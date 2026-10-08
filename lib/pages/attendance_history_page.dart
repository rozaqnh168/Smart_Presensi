import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/absen_api_service.dart';
import '../theme/colors.dart';
import '../widgets/attendance_location_map.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key, required this.nrp});

  final String nrp;

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final _searchController = TextEditingController();
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _refreshWarning;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshHistorySilently(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await AbsenApiService().fetchHistory(widget.nrp);
      if (!mounted) return;
      setState(() {
        _records = records;
        _isLoading = false;
        _refreshWarning = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _refreshHistorySilently() async {
    if (_isRefreshing || !mounted) return;
    _isRefreshing = true;

    try {
      final records = await AbsenApiService().fetchHistory(widget.nrp);
      if (!mounted) return;
      setState(() {
        _records = records;
        _errorMessage = null;
        _refreshWarning = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _refreshWarning =
            'Pembaruan otomatis gagal. Periksa koneksi atau tekan muat ulang. '
            '$error';
      });
    } finally {
      _isRefreshing = false;
    }
  }

  List<AttendanceRecord> get _filteredRecords {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _records;
    return _records.where((record) {
      final date = _formatDate(record.attendedAt).toLowerCase();
      final rawDate = record.attendedAt?.toIso8601String().toLowerCase() ?? '';
      return record.courseName.toLowerCase().contains(query) ||
          record.courseNote.toLowerCase().contains(query) ||
          date.contains(query) ||
          rawDate.contains(query) ||
          record.latitude.toLowerCase().contains(query) ||
          record.longitude.toLowerCase().contains(query);
    }).toList();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Waktu tidak tersedia';
    final localDate = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = localDate.day.toString().padLeft(2, '0');
    final month = months[localDate.month - 1];
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    final second = localDate.second.toString().padLeft(2, '0');
    return '$day $month ${localDate.year} • $hour:$minute:$second';
  }

  String _photoUrl(String photoPath) {
    final parsed = Uri.tryParse(photoPath);
    if (parsed != null && parsed.hasScheme) return photoPath;
    return '${ApiConfig.baseUrl}$photoPath';
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Riwayat Absensi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari mata kuliah, tanggal, atau lokasi',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pencarian',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                if (_refreshWarning != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      _refreshWarning!,
                      style: const TextStyle(
                        color: Color(0xFF9A5B08),
                        fontSize: 12,
                      ),
                    ),
                  ),
                Expanded(child: _buildBody(records)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<AttendanceRecord> records) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final error = _errorMessage;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.textMuted,
                size: 46,
              ),
              const SizedBox(height: 12),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return const _HistoryEmptyState(message: 'Belum ada riwayat absensi.');
    }
    if (records.isEmpty) {
      return const _HistoryEmptyState(
        message: 'Tidak ada riwayat yang cocok dengan pencarian.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final record = records[index];
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withValues(alpha: 0.035),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.photoPath.isNotEmpty && record.photoPath != '-')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _photoUrl(record.photoPath),
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 190,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 190,
                        width: double.infinity,
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.textMuted,
                              size: 32,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Foto selfie tidak dapat dimuat',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.no_photography_outlined,
                          color: AppColors.textMuted,
                          size: 30,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Foto selfie tidak tersedia',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        record.courseName,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _HistoryInfoRow(
                  icon: Icons.schedule_rounded,
                  text: _formatDate(record.attendedAt),
                ),
                if (record.courseNote.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _HistoryInfoRow(
                    icon: Icons.sticky_note_2_outlined,
                    text: record.courseNote,
                  ),
                ],
                const SizedBox(height: 7),
                _HistoryInfoRow(
                  icon: Icons.location_on_outlined,
                  text: '${record.latitude}, ${record.longitude}',
                ),
                if (double.tryParse(record.latitude) case final latitude?)
                  if (double.tryParse(record.longitude)
                      case final longitude?) ...[
                    const SizedBox(height: 14),
                    AttendanceLocationMap(
                      key: ValueKey('history-map-${record.id}'),
                      latitude: latitude,
                      longitude: longitude,
                      title: 'Lokasi absensi',
                      showLiveIndicator: false,
                      mapHeight: 180,
                    ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryInfoRow extends StatelessWidget {
  const _HistoryInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
