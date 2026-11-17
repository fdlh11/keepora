import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  final AssetService _assetService = AssetService();

  late DateTime _selectedMonthYear;
  String _selectedFilter = 'Semua';

  final List<String> _filters = const ['Semua', 'Perawatan', 'Perbaikan'];

  static const List<String> _bulanLengkap = [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthYear = DateTime(now.year, now.month);
  }

  List<DateTime> _generateMonthOptions(List<QueryDocumentSnapshot> docs) {
    final Set<String> keys = {};
    final List<DateTime> result = [];

    void addMonth(DateTime dt) {
      final key = '${dt.year}-${dt.month}';
      if (keys.add(key)) {
        result.add(DateTime(dt.year, dt.month));
      }
    }

    // Tambahkan bulan sekarang & 11 bulan terakhir sebagai opsi default
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      addMonth(DateTime(now.year, now.month - i));
    }

    // Tambahkan bulan dari dokumen riwayat yang ada di Firestore
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final dt = _extractDate(data);
      addMonth(dt);
    }

    result.sort((a, b) => b.compareTo(a));
    return result;
  }

  DateTime _extractDate(Map<String, dynamic> data) {
    final completedTs = data['completedAt'] as Timestamp?;
    if (completedTs != null) return completedTs.toDate();

    final createdTs = data['createdAt'] as Timestamp?;
    if (createdTs != null) return createdTs.toDate();

    return DateTime.now();
  }

  int _parseCostToInt(dynamic rawCost) {
    if (rawCost == null) return 0;
    if (rawCost is num) return rawCost.round();
    final digits = rawCost.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  String _formatRupiah(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final posFromEnd = str.length - i;
      if (i > 0 && posFromEnd % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp $buffer';
  }

  String _formatBadgeDateTime(DateTime dt) {
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_bulanSingkat[dt.month]} ${dt.year} / $jam.$menit WIB';
  }

  String _formatBulanTahun(DateTime dt) {
    return '${_bulanLengkap[dt.month]} ${dt.year}';
  }

  String _normalizeCategory(Map<String, dynamic> data) {
    final raw = (data['maintenanceType'] ?? 'Perawatan').toString().trim();
    if (raw.toLowerCase() == 'perbaikan') return 'Perbaikan';
    return 'Perawatan';
  }

  void _bukaPopupEdit(
    String assetId,
    String historyId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _EditRiwayatDialog(
        assetId: assetId,
        historyId: historyId,
        data: data,
        assetService: _assetService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Riwayat Biaya & Perawatan',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _assetService.getAllMaintenanceHistoryStream(),
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
                  'Gagal memuat riwayat: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final List<QueryDocumentSnapshot> allDocs =
              List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? [])
                ..sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>? ?? {};
                  final dataB = b.data() as Map<String, dynamic>? ?? {};
                  return _extractDate(dataB).compareTo(_extractDate(dataA));
                });

          final monthOptions = _generateMonthOptions(allDocs);
          if (!monthOptions.any(
            (m) =>
                m.year == _selectedMonthYear.year &&
                m.month == _selectedMonthYear.month,
          )) {
            _selectedMonthYear = monthOptions.first;
          }

          // Hitung total pengeluaran pada bulan & tahun yang dipilih
          int totalMonthlySpend = 0;
          for (final doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final dt = _extractDate(data);
            if (dt.year == _selectedMonthYear.year &&
                dt.month == _selectedMonthYear.month) {
              totalMonthlySpend += _parseCostToInt(data['cost']);
            }
          }

          // Filter daftar kartu riwayat berdasarkan chip (Semua / Perawatan / Perbaikan)
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final normalizedType = _normalizeCategory(data);
            if (_selectedFilter == 'Semua') return true;
            return normalizedType == _selectedFilter;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kartu Biru Ringkasan Pengeluaran
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 22),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total Pengeluaran bulan ini',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<DateTime>(
                              value: monthOptions.firstWhere(
                                (m) =>
                                    m.year == _selectedMonthYear.year &&
                                    m.month == _selectedMonthYear.month,
                              ),
                              dropdownColor: primaryBlue,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              items: monthOptions.map((monthDate) {
                                return DropdownMenuItem<DateTime>(
                                  value: monthDate,
                                  child: Text(
                                    _formatBulanTahun(monthDate),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedMonthYear = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatRupiah(totalMonthlySpend),
                        style: GoogleFonts.montserrat(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Judul Section & Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Perbaikan/Perawatan Terakhir',
                      style: GoogleFonts.montserrat(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: _filters.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: primaryBlue,
                            backgroundColor: const Color(0xFFF3F4F6),
                            side: BorderSide(
                              color: isSelected
                                  ? primaryBlue
                                  : Colors.grey.shade400,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() => _selectedFilter = filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Daftar Kartu Riwayat
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 54,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Belum Ada Riwayat',
                                style: GoogleFonts.montserrat(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Riwayat akan otomatis tercatat saat jadwal perawatan ditandai selesai atau dicatat di detail barang.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};

                          final String assetId = (data['assetId'] ??
                                  doc.reference.parent.parent?.id ??
                                  '')
                              .toString();
                          final String assetName =
                              (data['assetName'] ?? 'Barang').toString();
                          final String rawTitle =
                              (data['title'] ?? '').toString().trim();
                          final String detail =
                              (data['detail'] ?? data['notes'] ?? '')
                                  .toString()
                                  .trim();
                          final String displayTitle = rawTitle.isNotEmpty
                              ? rawTitle
                              : (detail.isNotEmpty
                                  ? detail
                                  : 'Perawatan $assetName');
                          final String categoryLabel =
                              _normalizeCategory(data);
                          final DateTime completedDate = _extractDate(data);
                          final int costValue = _parseCostToInt(data['cost']);

                          return Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade300,
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
                                // Baris Atas: Badge Tanggal/Jam + Tombol Edit
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryBlue,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _formatBadgeDateTime(completedDate),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: assetId.isEmpty
                                          ? null
                                          : () => _bukaPopupEdit(
                                                assetId,
                                                doc.id,
                                                data,
                                              ),
                                      borderRadius: BorderRadius.circular(8),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.edit_note_rounded,
                                          size: 24,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Judul Perawatan/Perbaikan
                                Text(
                                  displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // Nama Barang
                                Text(
                                  assetName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Baris Bawah: Pil Jenis (Perawatan/Perbaikan) + Biaya
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF93C5FD),
                                        ),
                                      ),
                                      child: Text(
                                        categoryLabel,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.black87,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Biaya '),
                                          TextSpan(
                                            text: _formatRupiah(costValue),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

// Pop-up Edit Riwayat Perawatan
class _EditRiwayatDialog extends StatefulWidget {
  final String assetId;
  final String historyId;
  final Map<String, dynamic> data;
  final AssetService assetService;

  const _EditRiwayatDialog({
    required this.assetId,
    required this.historyId,
    required this.data,
    required this.assetService,
  });

  @override
  State<_EditRiwayatDialog> createState() => _EditRiwayatDialogState();
}

class _EditRiwayatDialogState extends State<_EditRiwayatDialog> {
  late TextEditingController _judulController;
  late TextEditingController _biayaController;
  late TextEditingController _catatanController;

  late String _selectedJenis;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isSaving = false;

  final List<String> _jenisOptions = const ['Perawatan', 'Perbaikan'];

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

  @override
  void initState() {
    super.initState();
    final rawTitle = (widget.data['title'] ?? '').toString().trim();
    final rawDetail =
        (widget.data['detail'] ?? widget.data['notes'] ?? '').toString().trim();
    final assetName = (widget.data['assetName'] ?? '').toString();

    _judulController = TextEditingController(
      text: rawTitle.isNotEmpty
          ? rawTitle
          : (rawDetail.isNotEmpty ? rawDetail : 'Perawatan $assetName'),
    );

    final rawCost = widget.data['cost'];
    final digits = rawCost is num
        ? rawCost.round().toString()
        : (rawCost ?? '0').toString().replaceAll(RegExp(r'[^0-9]'), '');
    _biayaController = TextEditingController(text: digits.isEmpty ? '0' : digits);

    _catatanController = TextEditingController(text: rawDetail);

    final rawType = (widget.data['maintenanceType'] ?? 'Perawatan').toString();
    _selectedJenis =
        rawType.toLowerCase() == 'perbaikan' ? 'Perbaikan' : 'Perawatan';

    final ts = (widget.data['completedAt'] as Timestamp?) ??
        (widget.data['createdAt'] as Timestamp?);
    final dt = ts?.toDate() ?? DateTime.now();
    _selectedDate = DateTime(dt.year, dt.month, dt.day);
    _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  @override
  void dispose() {
    _judulController.dispose();
    _biayaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  String _formatTanggal(DateTime dt) {
    return '${dt.day} ${_bulanIndo[dt.month]} ${dt.year}';
  }

  String _formatJam(TimeOfDay time) {
    final jam = time.hour.toString().padLeft(2, '0');
    final menit = time.minute.toString().padLeft(2, '0');
    return '$jam:$menit WIB';
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pilihJam() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _simpan() async {
    final judul = _judulController.text.trim();
    if (judul.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul riwayat wajib diisi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final digits =
          _biayaController.text.replaceAll(RegExp(r'[^0-9]'), '').trim();
      final int costInt = int.tryParse(digits) ?? 0;

      await widget.assetService.updateMaintenanceRecord(
        assetId: widget.assetId,
        historyId: widget.historyId,
        title: judul,
        maintenanceType: _selectedJenis,
        maintenanceDate: _formatTanggal(_selectedDate),
        completedAtDate: combinedDateTime,
        cost: costInt,
        detail: _catatanController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Riwayat perawatan berhasil diperbarui.'),
            backgroundColor: Color(0xFF004AAD),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui riwayat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);
    final assetName = (widget.data['assetName'] ?? '-').toString();

    return Dialog(
      backgroundColor: const Color(0xFFF3F4F6),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Text(
                    'Edit Riwayat',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
            const SizedBox(height: 16),

            _label('Nama Barang'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Text(
                assetName,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(height: 14),

            _label('Judul Perawatan / Perbaikan'),
            const SizedBox(height: 6),
            TextField(
              controller: _judulController,
              style: const TextStyle(fontSize: 13.5),
              decoration: _inputDecoration('Masukkan judul...'),
            ),
            const SizedBox(height: 14),

            _label('Kategori'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedJenis,
                  isExpanded: true,
                  items: _jenisOptions.map((item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, style: const TextStyle(fontSize: 13.5)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedJenis = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Tanggal'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pilihTanggal,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatTanggal(_selectedDate),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 17,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Jam'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pilihJam,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatJam(_selectedTime),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              Icon(
                                Icons.access_time_rounded,
                                size: 17,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _label('Biaya'),
            const SizedBox(height: 6),
            TextField(
              controller: _biayaController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13.5),
              decoration: _inputDecoration('0').copyWith(prefixText: 'Rp '),
            ),
            const SizedBox(height: 14),

            _label('Catatan Rincian'),
            const SizedBox(height: 6),
            TextField(
              controller: _catatanController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13.5),
              decoration: _inputDecoration('Masukkan rincian perawatan...'),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Perbarui',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF004AAD), width: 1.4),
      ),
    );
  }
}