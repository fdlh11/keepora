import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  final AssetService _assetService = AssetService();

  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  static const List<String> _indonesianMonths = [
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

  static const List<String> _shortIndonesianMonths = [
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

  static const List<String> _weekDaysHeader = [
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

  String _formatShortDate(DateTime date) {
    return '${date.day} ${_shortIndonesianMonths[date.month - 1]} ${date.year}';
  }

  String _formatFullIndonesianDate(DateTime date) {
    return '${date.day} ${_indonesianMonths[date.month - 1]} ${date.year}';
  }

  String _formatTimeWib(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour.$minute WIB';
  }

  /// Menghasilkan 14 hari (2 baris x 7 kolom) mulai dari hari Senin minggu aktif
  List<DateTime> _getTwoWeekDays() {
    final now = DateTime.now();
    final DateTime anchor =
        (_focusedMonth.year == now.year && _focusedMonth.month == now.month)
        ? DateTime(now.year, now.month, now.day)
        : _focusedMonth;

    final int offsetFromMonday = anchor.weekday - DateTime.monday;
    final DateTime firstMonday = anchor.subtract(
      Duration(days: offsetFromMonday),
    );

    return List.generate(14, (index) => firstMonday.add(Duration(days: index)));
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
        1,
      );
      _selectedDate = _focusedMonth;
    });
  }

  /// Menghitung label & skema warna pill hitung mundur sesuai urgensi hari
  ({String label, Color bgColor, Color borderColor, Color textColor})
  _getCountdownBadge(DateTime scheduledDate, String timeLabel) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    final int diffDays = target.difference(today).inDays;

    final String dayText;
    if (diffDays < 0) {
      dayText = 'Terlewat ${diffDays.abs()} Hari';
    } else if (diffDays == 0) {
      dayText = 'Hari Ini';
    } else {
      dayText = '$diffDays Hari';
    }

    final String fullText = timeLabel.isNotEmpty
        ? '$dayText / $timeLabel'
        : dayText;

    if (diffDays <= 8) {
      return (
        label: fullText,
        bgColor: const Color(0xFFFFEBEB),
        borderColor: const Color(0xFFEF7E7E),
        textColor: const Color(0xFFD94343),
      );
    } else if (diffDays <= 14) {
      return (
        label: fullText,
        bgColor: const Color(0xFFFFF1E4),
        borderColor: const Color(0xFFF3A86B),
        textColor: const Color(0xFFD97724),
      );
    } else {
      return (
        label: fullText,
        bgColor: const Color(0xFFE7FCE8),
        borderColor: const Color(0xFF6AD473),
        textColor: const Color(0xFF289933),
      );
    }
  }

  void _showAddScheduleSheet() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController timeController = TextEditingController();

    String? selectedAssetId;
    String? selectedAssetName;
    String selectedType = 'Perawatan';
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext modalContext, StateSetter setModalState) {
            const primaryBlue = Color(0xFF0056C6);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tambah Jadwal',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Jadwalkan perawatan atau perbaikan perangkat Anda.',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 18),

                    // Pilih Barang dari Firestore
                    Text(
                      'Pilih Barang',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: _assetService.getAssetsStream(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedAssetId,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey,
                              ),
                              hint: Text(
                                docs.isEmpty
                                    ? 'Belum ada barang terdaftar'
                                    : 'Pilih barang Anda...',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13.5,
                                ),
                              ),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              items: docs.map((doc) {
                                final data =
                                    doc.data() as Map<String, dynamic>? ?? {};
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(
                                    data['name']?.toString() ?? 'Tanpa Nama',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: docs.isEmpty
                                  ? null
                                  : (value) {
                                      final matchedDoc = docs.firstWhere(
                                        (d) => d.id == value,
                                      );
                                      final matchedData =
                                          matchedDoc.data()
                                              as Map<String, dynamic>? ??
                                          {};
                                      setModalState(() {
                                        selectedAssetId = value;
                                        selectedAssetName =
                                            matchedData['name']?.toString() ??
                                            '';
                                      });
                                    },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Jenis Kegiatan (Perawatan / Perbaikan)
                    Text(
                      'Kategori Agenda',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Perawatan', 'Perbaikan'].map((type) {
                        final bool active = selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: active,
                            selectedColor: primaryBlue.withValues(alpha: 0.14),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(
                              color: active
                                  ? primaryBlue
                                  : Colors.grey.shade300,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: active ? primaryBlue : Colors.black87,
                            ),
                            onSelected: (_) {
                              setModalState(() => selectedType = type);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Nama Kegiatan
                    Text(
                      'Nama Kegiatan',
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: titleController,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Ganti Thermal Pasta',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tanggal & Waktu (WIB) berdampingan
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: dateController,
                                  readOnly: true,
                                  onTap: () async {
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: modalContext,
                                      initialDate: selectedDate ?? now,
                                      firstDate: now.subtract(
                                        const Duration(days: 1),
                                      ),
                                      lastDate: DateTime(2100),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                                  primary: primaryBlue,
                                                  onPrimary: Colors.white,
                                                  onSurface: Colors.black,
                                                ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        selectedDate = picked;
                                        dateController.text = _formatShortDate(
                                          picked,
                                        );
                                      });
                                    }
                                  },
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'Pilih tanggal...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12.5,
                                    ),
                                    suffixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      size: 17,
                                      color: Colors.grey,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jam (WIB)',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: timeController,
                                  readOnly: true,
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: modalContext,
                                      initialTime:
                                          selectedTime ??
                                          const TimeOfDay(hour: 13, minute: 0),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        selectedTime = picked;
                                        timeController.text = _formatTimeWib(
                                          picked,
                                        );
                                      });
                                    }
                                  },
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: '13.00 WIB',
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12.5,
                                    ),
                                    suffixIcon: Icon(
                                      Icons.access_time_outlined,
                                      size: 17,
                                      color: Colors.grey,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (selectedAssetId == null ||
                                    selectedAssetName == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Silakan pilih barang terlebih dahulu.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Nama kegiatan wajib diisi.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                if (selectedDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tanggal jadwal wajib dipilih.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);

                                final TimeOfDay finalTime =
                                    selectedTime ??
                                    const TimeOfDay(hour: 13, minute: 0);
                                final DateTime fullScheduledDateTime = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                  finalTime.hour,
                                  finalTime.minute,
                                );

                                try {
                                  await _assetService.addSchedule({
                                    'assetId': selectedAssetId,
                                    'assetName': selectedAssetName,
                                    'title': title,
                                    'scheduleType': selectedType,
                                    'scheduledDate': _formatShortDate(
                                      selectedDate!,
                                    ),
                                    'scheduledTime': _formatTimeWib(finalTime),
                                    'scheduledTimestamp': Timestamp.fromDate(
                                      fullScheduledDateTime,
                                    ),
                                  });

                                  if (!mounted) return;
                                  Navigator.pop(sheetContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Jadwal berhasil ditambahkan!',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  setModalState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal menyimpan: $e'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Simpan Jadwal',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      dateController.dispose();
      timeController.dispose();
    });
  }

  void _showScheduleActionSheet({
    required String scheduleId,
    required String assetId,
    required String title,
    required String assetName,
  }) {
    const primaryBlue = Color(0xFF0056C6);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  assetName,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: primaryBlue,
                  ),
                  title: const Text('Tandai Sudah Selesai'),
                  subtitle: const Text(
                    'Catat otomatis ke riwayat perawatan barang',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final todayStr = _formatFullIndonesianDate(DateTime.now());
                    await _assetService.completeSchedule(
                      scheduleId: scheduleId,
                      assetId: assetId,
                      maintenanceTitle: title,
                      dateFormatted: todayStr,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Jadwal selesai & tercatat di riwayat!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Hapus Jadwal',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _assetService.deleteSchedule(scheduleId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0056C6);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<DateTime> twoWeekDays = _getTwoWeekDays();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _assetService.getSchedulesStream(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];

            // Filter jadwal yang belum selesai
            final upcomingDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?['isCompleted'] != true;
            }).toList();

            // Kumpulkan semua tanggal jadwal di bulan yang sedang dilihat
            final List<DateTime> scheduledDates = [];
            int schedulesInFocusedMonth = 0;

            for (final doc in upcomingDocs) {
              final data = doc.data() as Map<String, dynamic>?;
              final Timestamp? ts = data?['scheduledTimestamp'] as Timestamp?;
              if (ts != null) {
                final dt = ts.toDate();
                scheduledDates.add(DateTime(dt.year, dt.month, dt.day));
                if (dt.year == _focusedMonth.year &&
                    dt.month == _focusedMonth.month) {
                  schedulesInFocusedMonth++;
                }
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Judul Halaman di Tengah
                  Center(
                    child: Text(
                      'Jadwal Perawatan',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kartu Kalender 2-Mingguan
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Navigasi Bulan (< November 2026 >)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _changeMonth(-1),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.chevron_left_rounded,
                                  size: 22,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              '${_indonesianMonths[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _changeMonth(1),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
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

                        // Header Nama Hari (Senin - Minggu)
                        Row(
                          children: _weekDaysHeader.map((dayName) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  dayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),

                        // Baris 1 (Hari 1-7) & Baris 2 (Hari 8-14)
                        ...List.generate(2, (rowIndex) {
                          final weekSlice = twoWeekDays.sublist(
                            rowIndex * 7,
                            (rowIndex + 1) * 7,
                          );
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: rowIndex == 0 ? 8 : 10,
                            ),
                            child: Row(
                              children: weekSlice.map((date) {
                                final bool isToday = _isSameDay(date, today);
                                final bool hasEvent = scheduledDates.any(
                                  (d) => _isSameDay(d, date),
                                );
                                final bool isSelected = _isSameDay(
                                  date,
                                  _selectedDate,
                                );
                                final bool isCurrentMonth =
                                    date.month == _focusedMonth.month;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedDate = date;
                                      });
                                    },
                                    child: Center(
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: hasEvent
                                              ? primaryBlue
                                              : isSelected
                                              ? primaryBlue.withValues(
                                                  alpha: 0.12,
                                                )
                                              : Colors.transparent,
                                          border: isToday && !hasEvent
                                              ? Border.all(
                                                  color: primaryBlue,
                                                  width: 1.5,
                                                )
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${date.day}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 13,
                                              fontWeight: (hasEvent || isToday)
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: hasEvent
                                                  ? Colors.white
                                                  : isCurrentMonth
                                                  ? Colors.black87
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }),

                        Divider(height: 1, color: Colors.grey.shade200),
                        const SizedBox(height: 10),

                        // Footer Kalender: Hari ini & Jumlah Jadwal Bulan Ini
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hari ini: ${today.day} ${_indonesianMonths[today.month - 1]}',
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
                                const SizedBox(width: 6),
                                Text(
                                  '$schedulesInFocusedMonth jadwal bulan ini',
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
                  const SizedBox(height: 20),

                  // Header: Jadwal Berikutnya + Tambah Jadwal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Jadwal Berikutnya',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showAddScheduleSheet,
                        child: Text(
                          'Tambah Jadwal',
                          style: GoogleFonts.montserrat(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Daftar Kartu Jadwal
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      ),
                    )
                  else if (upcomingDocs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 36,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 46,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Belum ada jadwal berikutnya',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ketuk "Tambah Jadwal" di kanan atas untuk membuat pengingat perawatan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: upcomingDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final doc = upcomingDocs[index];
                        final data = doc.data() as Map<String, dynamic>? ?? {};

                        final String title = data['title']?.toString() ?? '-';
                        final String assetName =
                            data['assetName']?.toString() ?? '-';
                        final String assetId =
                            data['assetId']?.toString() ?? '';
                        final String scheduleType =
                            data['scheduleType']?.toString() ?? 'Perawatan';
                        final String timeLabel =
                            data['scheduledTime']?.toString() ?? '13.00 WIB';

                        final Timestamp? ts =
                            data['scheduledTimestamp'] as Timestamp?;
                        final DateTime schedDate = ts != null
                            ? ts.toDate()
                            : DateTime.now();
                        final String dateLabel =
                            data['scheduledDate']?.toString() ??
                            _formatShortDate(schedDate);

                        final badge = _getCountdownBadge(schedDate, timeLabel);

                        return GestureDetector(
                          onTap: () => _showScheduleActionSheet(
                            scheduleId: doc.id,
                            assetId: assetId,
                            title: title,
                            assetName: assetName,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Baris Atas: Pill Tanggal Biru & Pill Countdown
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryBlue,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        dateLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badge.bgColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: badge.borderColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        badge.label,
                                        style: TextStyle(
                                          color: badge.textColor,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Judul Kegiatan
                                Text(
                                  title,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 3),

                                // Nama Barang
                                Text(
                                  assetName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Pill Kategori (Perawatan / Perbaikan)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF7FB0F8),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    scheduleType,
                                    style: const TextStyle(
                                      color: primaryBlue,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
