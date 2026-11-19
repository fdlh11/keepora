import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/jadwal_service.dart';
import 'detail_jadwal_screen.dart';
import 'tambah_jadwal_screen.dart';

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  final JadwalService _jadwalService = JadwalService();

  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  static const List<String> _bulanIndo = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

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

  static const List<String> _namaHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatBadgeTanggal(DateTime date) {
    return '${date.day} ${_bulanSingkat[date.month]} ${date.year}';
  }

  String _formatCountdownDanJam(DateTime scheduledAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay =
        DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    final diffDays = targetDay.difference(today).inDays;

    final jam = scheduledAt.hour.toString().padLeft(2, '0');
    final menit = scheduledAt.minute.toString().padLeft(2, '0');
    final jamStr = '$jam.$menit WIB';

    if (diffDays < 0) {
      return 'Terlewat / $jamStr';
    } else if (diffDays == 0) {
      return 'Hari ini / $jamStr';
    } else {
      return '$diffDays Hari / $jamStr';
    }
  }

  List<DateTime> _getTwoWeekDates() {
    // Mulai dari Senin pada minggu yang berisi tanggal terpilih (atau awal bulan fokus)
    final anchor = (_selectedDate.year == _focusedMonth.year &&
            _selectedDate.month == _focusedMonth.month)
        ? _selectedDate
        : _focusedMonth;
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    return List.generate(14, (i) => monday.add(Duration(days: i)));
  }

  void _gantiBulan(int delta) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
      final now = DateTime.now();
      if (_focusedMonth.year == now.year && _focusedMonth.month == now.month) {
        _selectedDate = DateTime(now.year, now.month, now.day);
      } else {
        _selectedDate = _focusedMonth;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final calendarDates = _getTwoWeekDates();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Jadwal Perawatan',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _jadwalService.streamJadwalAktif(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryBlue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat jadwal: ${snapshot.error}',
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

          final List<DateTime> allScheduledDates = docs.map((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            return (data['scheduledAt'] as Timestamp?)?.toDate() ??
                DateTime.now();
          }).toList();

          final int jumlahJadwalBulanIni = allScheduledDates
              .where((dt) =>
                  dt.year == _focusedMonth.year &&
                  dt.month == _focusedMonth.month)
              .length;

          return Column(
            children: [
              // Card Kalender 2 Minggu
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header Bulan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => _gantiBulan(-1),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 22,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '${_bulanIndo[_focusedMonth.month]} ${_focusedMonth.year}',
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        InkWell(
                          onTap: () => _gantiBulan(1),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Label Hari Senin - Minggu
                    Row(
                      children: _namaHari
                          .map(
                            (hari) => Expanded(
                              child: Center(
                                child: Text(
                                  hari,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),

                    // Baris Tanggal Minggu 1 & 2
                    for (int row = 0; row < 2; row++) ...[
                      Row(
                        children: List.generate(7, (col) {
                          final date = calendarDates[row * 7 + col];
                          final bool isToday = _isSameDay(date, today);
                          final bool isSelected =
                              _isSameDay(date, _selectedDate);
                          final bool hasSchedule = allScheduledDates
                              .any((d) => _isSameDay(d, date));
                          final bool isCurrentMonth =
                              date.month == _focusedMonth.month;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDate = date;
                                  _focusedMonth =
                                      DateTime(date.year, date.month, 1);
                                });
                              },
                              child: Container(
                                height: 34,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasSchedule
                                      ? primaryBlue
                                      : Colors.transparent,
                                  border: isToday && !hasSchedule
                                      ? Border.all(
                                          color: primaryBlue,
                                          width: 1.4,
                                        )
                                      : (isSelected && !hasSchedule
                                          ? Border.all(
                                              color: Colors.grey.shade400,
                                              width: 1.2,
                                            )
                                          : null),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: (hasSchedule || isToday)
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: hasSchedule
                                        ? Colors.white
                                        : (isCurrentMonth
                                            ? Colors.black87
                                            : Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],

                    const SizedBox(height: 8),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 8),

                    // Footer Info Kalender
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hari ini: ${today.day} ${_bulanIndo[today.month]}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$jumlahJadwalBulanIni jadwal bulan ini',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Header Section: Jadwal Berikutnya + Tombol + Jadwal
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jadwal Berikutnya',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TambahJadwalScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        'Jadwal',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Daftar Card Jadwal
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_note_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Belum Ada Jadwal Perawatan',
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tekan tombol + Jadwal di atas untuk menambahkan pengingat perawatan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};
                          final Timestamp? ts =
                              data['scheduledAt'] as Timestamp?;
                          final DateTime scheduledAt =
                              ts?.toDate() ?? DateTime.now();
                          final bool isOverdue =
                              scheduledAt.isBefore(DateTime.now());

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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Baris Badge Tanggal & Countdown/Jam
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primaryBlue,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _formatBadgeTanggal(scheduledAt),
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isOverdue
                                              ? const Color(0xFFFEE2E2)
                                              : const Color(0xFFFFEDD5),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _formatCountdownDanJam(scheduledAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isOverdue
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFFEA580C),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Nama Jadwal
                                  Text(
                                    (data['title'] ?? '-').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),

                                  // Nama Barang
                                  Text(
                                    (data['assetName'] ?? '-').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Badge Jenis Perawatan
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      (data['maintenanceType'] ?? 'Perawatan')
                                          .toString(),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}