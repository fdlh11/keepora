import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/jadwal_service.dart';

class DetailJadwalScreen extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> data;

  const DetailJadwalScreen({
    super.key,
    required this.scheduleId,
    required this.data,
  });

  @override
  State<DetailJadwalScreen> createState() => _DetailJadwalScreenState();
}

class _DetailJadwalScreenState extends State<DetailJadwalScreen> {
  final JadwalService _jadwalService = JadwalService();
  late Map<String, dynamic> _currentData;
  bool _isProcessing = false;

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
    _currentData = Map<String, dynamic>.from(widget.data);
  }

  String _formatTanggal(DateTime date) {
    return '${date.day} ${_bulanIndo[date.month]} ${date.year}';
  }

  String _formatJam(DateTime date) {
    final jam = date.hour.toString().padLeft(2, '0');
    final menit = date.minute.toString().padLeft(2, '0');
    return '$jam:$menit WIB';
  }

  String _formatRupiah(num value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      if (i > 0 && posFromEnd % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  Future<void> _bukaHalamanEdit() async {
    final updatedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditJadwalScreen(
          scheduleId: widget.scheduleId,
          data: _currentData,
          jadwalService: _jadwalService,
        ),
      ),
    );

    if (updatedData != null && mounted) {
      setState(() {
        _currentData = updatedData;
      });
    }
  }

  Future<void> _konfirmasiHapus() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Jadwal?'),
        content: const Text('Jadwal perawatan ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await _jadwalService.hapusJadwal(widget.scheduleId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus jadwal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _selesaikanJadwalLangsung() async {
    setState(() => _isProcessing = true);
    try {
      await _jadwalService.tandaiSelesai(
        scheduleId: widget.scheduleId,
        scheduleData: _currentData,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal selesai & dipindahkan ke Riwayat Perawatan.'),
            backgroundColor: Color(0xFF004AAD),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan jadwal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);
    final Timestamp? ts = _currentData['scheduledAt'] as Timestamp?;
    final DateTime scheduledAt = ts?.toDate() ?? DateTime.now();
    final String notes = (_currentData['notes'] ?? '').toString();
    final num estimatedCost = (_currentData['estimatedCost'] as num?) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          'Detail Jadwal',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isProcessing ? null : _bukaHalamanEdit,
            icon: const Icon(Icons.edit_outlined, color: Colors.black87),
            tooltip: 'Edit Jadwal',
          ),
          IconButton(
            onPressed: _isProcessing ? null : _konfirmasiHapus,
            icon: const Icon(Icons.delete_outline, color: Colors.black87),
            tooltip: 'Hapus Jadwal',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Nama Jadwal'),
            const SizedBox(height: 6),
            _buildReadOnlyBox((_currentData['title'] ?? '-').toString()),

            const SizedBox(height: 16),

            _buildLabel('Nama Barang'),
            const SizedBox(height: 6),
            _buildReadOnlyBox((_currentData['assetName'] ?? '-').toString()),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Tanggal Jadwal'),
                      const SizedBox(height: 6),
                      _buildReadOnlyBox(_formatTanggal(scheduledAt)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Jam Jadwal'),
                      const SizedBox(height: 6),
                      _buildReadOnlyBox(_formatJam(scheduledAt)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildLabel('Jenis Perawatan'),
            const SizedBox(height: 6),
            _buildReadOnlyBox(
              (_currentData['maintenanceType'] ?? 'Perawatan').toString(),
            ),

            const SizedBox(height: 16),

            _buildLabel('Estimasi Biaya Perawatan'),
            const SizedBox(height: 6),
            _buildReadOnlyBox(_formatRupiah(estimatedCost)),

            const SizedBox(height: 16),

            _buildLabel('Catatan Tambahan (Opsional)'),
            const SizedBox(height: 6),
            _buildReadOnlyBox(notes.isEmpty ? '' : notes, minHeight: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _selesaikanJadwalLangsung,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Tandai Selesai',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildReadOnlyBox(String value, {double minHeight = 48}) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

class EditJadwalScreen extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> data;
  final JadwalService jadwalService;

  const EditJadwalScreen({
    super.key,
    required this.scheduleId,
    required this.data,
    required this.jadwalService,
  });

  @override
  State<EditJadwalScreen> createState() => _EditJadwalScreenState();
}

class _EditJadwalScreenState extends State<EditJadwalScreen> {
  late TextEditingController _namaJadwalController;
  late TextEditingController _estimasiBiayaController;
  late TextEditingController _catatanController;

  String? _selectedAssetId;
  String? _selectedAssetName;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedJenisPerawatan;
  bool _isSaving = false;

  final List<String> _jenisPerawatanList = const [
    'Perawatan',
    'Perbaikan',
    'Pembersihan',
    'Penggantian Komponen',
    'Pengecekan Rutin',
  ];

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

  DateTime get _minScheduleDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  String _formatRibuan(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      if (i > 0 && posFromEnd % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  void _onBiayaChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = _formatRibuan(digits);
    if (formatted != value) {
      _estimasiBiayaController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _namaJadwalController = TextEditingController(
      text: (widget.data['title'] ?? '').toString(),
    );

    final num existingCost = (widget.data['estimatedCost'] as num?) ?? 0;
    _estimasiBiayaController = TextEditingController(
      text: existingCost > 0
          ? _formatRibuan(existingCost.round().toString())
          : '',
    );

    _catatanController = TextEditingController(
      text: (widget.data['notes'] ?? '').toString(),
    );
    _selectedAssetId = (widget.data['assetId'] ?? '').toString();
    _selectedAssetName = (widget.data['assetName'] ?? '').toString();

    final Timestamp? ts = widget.data['scheduledAt'] as Timestamp?;
    final DateTime dt = ts?.toDate() ?? DateTime.now();
    _selectedDate = DateTime(dt.year, dt.month, dt.day);
    _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);

    final existingType =
        (widget.data['maintenanceType'] ?? 'Perawatan').toString();
    _selectedJenisPerawatan = _jenisPerawatanList.contains(existingType)
        ? existingType
        : _jenisPerawatanList.first;
  }

  String _formatTanggal(DateTime date) {
    return '${date.day} ${_bulanIndo[date.month]} ${date.year}';
  }

  String _formatJam(TimeOfDay time) {
    final jam = time.hour.toString().padLeft(2, '0');
    final menit = time.minute.toString().padLeft(2, '0');
    return '$jam:$menit WIB';
  }

  Future<void> _pilihTanggal() async {
    final minDate = _minScheduleDate;
    final initial = _selectedDate.isBefore(minDate) ? minDate : _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF004AAD)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pilihJam() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF004AAD)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _simpanPerubahan() async {
    final namaJadwal = _namaJadwalController.text.trim();
    if (namaJadwal.isEmpty || (_selectedAssetId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama jadwal dan nama barang wajib diisi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final pickedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (pickedDay.isBefore(_minScheduleDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tanggal jadwal harus untuk masa mendatang (minimal besok).',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final cleanDigits =
          _estimasiBiayaController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final double estimatedCost = double.tryParse(cleanDigits) ?? 0;

      await widget.jadwalService.updateJadwal(
        scheduleId: widget.scheduleId,
        title: namaJadwal,
        assetId: _selectedAssetId!,
        assetName: _selectedAssetName ?? '',
        scheduledAt: scheduledAt,
        maintenanceType: _selectedJenisPerawatan,
        estimatedCost: estimatedCost,
        notes: _catatanController.text,
      );

      if (mounted) {
        final updatedMap = {
          ...widget.data,
          'title': namaJadwal,
          'assetId': _selectedAssetId!,
          'assetName': _selectedAssetName ?? '',
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'maintenanceType': _selectedJenisPerawatan,
          'estimatedCost': estimatedCost,
          'notes': _catatanController.text,
        };
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detail jadwal berhasil diperbarui.'),
            backgroundColor: Color(0xFF004AAD),
          ),
        );
        Navigator.pop(context, updatedMap);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui jadwal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _namaJadwalController.dispose();
    _estimasiBiayaController.dispose();
    _catatanController.dispose();
    super.dispose();
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
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          'Edit Detail Jadwal',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama Jadwal
              _buildLabel('Nama Jadwal'),
              const SizedBox(height: 8),
              TextField(
                controller: _namaJadwalController,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration('Masukkan nama jadwal...'),
              ),

              const SizedBox(height: 16),

              // Nama Barang
              _buildLabel('Nama Barang'),
              const SizedBox(height: 8),
              StreamBuilder(
                stream: widget.jadwalService.streamDaftarBarang(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: docs.any((d) => d.id == _selectedAssetId)
                            ? _selectedAssetId
                            : null,
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade600,
                        ),
                        hint: Text(
                          _selectedAssetName?.isNotEmpty == true
                              ? _selectedAssetName!
                              : (docs.isEmpty
                                  ? 'Belum ada data barang'
                                  : 'Pilih nama barang'),
                          style: TextStyle(
                            color: _selectedAssetName?.isNotEmpty == true
                                ? Colors.black87
                                : Colors.grey.shade500,
                            fontSize: 13.5,
                          ),
                        ),
                        items: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>?;
                          final namaBarang =
                              (data?['name'] ?? 'Tanpa Nama').toString();
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              namaBarang,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: docs.isEmpty
                            ? null
                            : (val) {
                                final selectedDoc =
                                    docs.firstWhere((d) => d.id == val);
                                final selectedData =
                                    selectedDoc.data() as Map<String, dynamic>?;
                                setState(() {
                                  _selectedAssetId = val;
                                  _selectedAssetName =
                                      (selectedData?['name'] ?? '').toString();
                                });
                              },
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Tanggal & Jam Jadwal
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Tanggal Jadwal'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pilihTanggal,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatTanggal(_selectedDate),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
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
                        _buildLabel('Jam Jadwal'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pilihJam,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatJam(_selectedTime),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
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

              const SizedBox(height: 16),

              // Jenis Perawatan
              _buildLabel('Jenis Perawatan'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedJenisPerawatan,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade600,
                    ),
                    items: _jenisPerawatanList.map((jenis) {
                      return DropdownMenuItem<String>(
                        value: jenis,
                        child: Text(
                          jenis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedJenisPerawatan = val);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Estimasi Biaya Perawatan
              _buildLabel('Estimasi Biaya Perawatan'),
              const SizedBox(height: 8),
              TextField(
                controller: _estimasiBiayaController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onBiayaChanged,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration('00000').copyWith(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 4),
                    child: Text(
                      'Rp',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Catatan Tambahan (Opsional)
              _buildLabel('Catatan Tambahan (Opsional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _catatanController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration('Masukkan catatan tambahan...'),
              ),

              const SizedBox(height: 32),

              // Tombol Perbarui
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _simpanPerubahan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Perbarui',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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