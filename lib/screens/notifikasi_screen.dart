import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/jadwal_service.dart';
import '../services/notification_service.dart';
import '../utils/top_notif.dart';
import 'detail_jadwal_screen.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  final JadwalService _jadwalService = JadwalService();
  final NotificationService _notifService = NotificationService.instance;

  static const List<String> _bulanSingkat = [
    '',
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

  String _formatTanggalJam(DateTime dt) {
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_bulanSingkat[dt.month]} ${dt.year} • $jam:$menit WIB';
  }

  ({String label, String message, Color bg, Color text, Color border})
      _getReminderMeta(
    DateTime scheduledAt,
    String title,
    String assetName,
    bool isDark,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay =
        DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    final diffDays = targetDay.difference(today).inDays;

    if (diffDays < 0) {
      return (
        label: 'Terlewat ${diffDays.abs()} Hari',
        message:
            'Jadwal "$title" untuk $assetName telah melewati batas waktu yang ditentukan.',
        bg: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
        text: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
        border: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5),
      );
    } else if (diffDays == 0) {
      return (
        label: 'Hari Ini',
        message:
            'Waktunya melakukan "$title" untuk barang $assetName hari ini.',
        bg: isDark ? const Color(0xFF452700) : const Color(0xFFFEF3C7),
        text: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        border: isDark ? const Color(0xFFD97706) : const Color(0xFFFBBF24),
      );
    } else if (diffDays == 1) {
      return (
        label: 'Besok',
        message:
            'Pengingat H-1: Jadwal "$title" untuk $assetName dijadwalkan besok.',
        bg: isDark ? const Color(0xFF172554) : const Color(0xFFDBEAFE),
        text: isDark ? const Color(0xFF60A5FA) : const Color(0xFF004AAD),
        border: isDark ? const Color(0xFF1D4ED8) : const Color(0xFF93C5FD),
      );
    } else {
      return (
        label: '$diffDays Hari Lagi',
        message:
            'Jadwal "$title" untuk $assetName akan jatuh tempo dalam $diffDays hari.',
        bg: isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7),
        text: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
        border: isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC),
      );
    }
  }

  IconData _getMaintenanceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'perbaikan':
        return Icons.build_outlined;
      case 'pembersihan':
        return Icons.cleaning_services_outlined;
      case 'penggantian komponen':
        return Icons.settings_suggest_outlined;
      case 'pengecekan rutin':
        return Icons.fact_check_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Future<void> _kirimTesNotifikasi() async {
    try {
      await _notifService.showTestNotification();
      if (mounted) {
        showTopNotif(context, 'Notifikasi tes berhasil dikirim ke bilah status.');
      }
    } catch (e) {
      if (mounted) {
        showTopNotif(context, 'Gagal mengirim tes notifikasi: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final textSecondary =
        isDark ? Colors.grey.shade400 : const Color(0xFF4B5563);
    final accentBlue = isDark ? const Color(0xFF60A5FA) : primaryBlue;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: textPrimary),
        ),
        title: Text(
          'Notifikasi',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _kirimTesNotifikasi,
            tooltip: 'Tes Notifikasi',
            icon: Icon(
              Icons.notification_add_outlined,
              color: accentBlue,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _jadwalService.streamJadwalAktif(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryBlue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat notifikasi: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final docs = [...(snapshot.data?.docs ?? [])]..sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>? ?? {};
              final dataB = b.data() as Map<String, dynamic>? ?? {};
              final tsA = (dataA['scheduledAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              final tsB = (dataB['scheduledAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              return tsA.compareTo(tsB);
            });

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 36,
                        color: accentBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum Ada Pengingat',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Semua jadwal perawatan aktif Anda akan muncul otomatis di sini sebagai pengingat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final title = (data['title'] ?? 'Perawatan Barang').toString();
              final assetName = (data['assetName'] ?? '-').toString();
              final type =
                  (data['maintenanceType'] ?? 'Perawatan').toString();
              final scheduledAt =
                  (data['scheduledAt'] as Timestamp?)?.toDate() ??
                      DateTime.now();

              final meta =
                  _getReminderMeta(scheduledAt, title, assetName, isDark);

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailJadwalScreen(
                        scheduleId: doc.id,
                        data: data,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF172554)
                              : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getMaintenanceIcon(type),
                          color: accentBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: meta.bg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: meta.border),
                                  ),
                                  child: Text(
                                    meta.label,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: meta.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              meta.message,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textSecondary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 13.5,
                                  color: accentBlue,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _formatTanggalJam(scheduledAt),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: accentBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}