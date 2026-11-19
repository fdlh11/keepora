import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  void _bukaPopupEdit() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _EditJadwalDialog(
        scheduleId: widget.scheduleId,
        data: _currentData,
        jadwalService: _jadwalService,
        onUpdated: (updatedData) {
          setState(() {
            _currentData = updatedData;
          });
        },
      ),
    );
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

  Future<void> _konfirmasiTandaiSelesai() async {
    final biayaController = TextEditingController(text: '0');
    final catatanSelesaiController = TextEditingController(
      text: (_currentData['notes'] ?? '').toString(),
    );

    final bool? lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Selesaikan Perawatan',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jadwal ini akan dipindahkan ke Riwayat Perawatan.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: biayaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Biaya Perawatan (Rp)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: catatanSelesaiController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan Hasil Perawatan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004AAD),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan ke Riwayat'),
          ),
        ],
      ),
    );

    if (lanjut != true) return;

    setState(() => _isProcessing = true);
    try {
      final cleanCost = biayaController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final double cost = double.tryParse(cleanCost) ?? 0;

      await _jadwalService.tandaiSelesai(
        scheduleId: widget.scheduleId,
        scheduleData: _currentData,
        cost: cost,
        completionNotes: catatanSelesaiController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal selesai & dicatat ke Riwayat Perawatan.'),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
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
            onPressed: _isProcessing ? null : _bukaPopupEdit,
            icon: const Icon(Icons.edit_outlined, color: Colors.black87),
            tooltip: 'Edit Jadwal',
          ),
          IconButton(
            onPressed: _isProcessing ? null : _konfirmasiHapus,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
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

            _buildLabel('Catatan Tambahan (Opsional)'),
            const SizedBox(height: 6),
            _buildReadOnlyBox(notes.isEmpty ? '-' : notes, minHeight: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _konfirmasiTandaiSelesai,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
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
                        fontSize: 15,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}

class _EditJadwalDialog extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> data;
  final JadwalService jadwalService;
  final ValueChanged onUpdated;

  const _EditJadwalDialog({
    required this.scheduleId,
    required this.data,
    required this.jadwalService,
    required this.onUpdated,
  });

  @override
  State<_EditJadwalDialog> createState() => _EditJadwalDialogState();
}

class _EditJadwalDialogState extends State<_EditJadwalDialog> {
  late TextEditingController _namaJadwalController;
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

  @override
  void initState() {
    super.initState();
    _namaJadwalController = TextEditingController(
      text: (widget.data['title'] ?? '').toString(),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
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

    setState(() => _isSaving = true);
    try {
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await widget.jadwalService.updateJadwal(
        scheduleId: widget.scheduleId,
        title: namaJadwal,
        assetId: _selectedAssetId!,
        assetName: _selectedAssetName ?? '',
        scheduledAt: scheduledAt,
        maintenanceType: _selectedJenisPerawatan,
        notes: _catatanController.text,
      );

      if (mounted) {
        widget.onUpdated({
          ...widget.data,
          'title': namaJadwal,
          'assetId': _selectedAssetId!,
          'assetName': _selectedAssetName ?? '',
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'maintenanceType': _selectedJenisPerawatan,
          'notes': _catatanController.text,
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Detail jadwal berhasil diperbarui.'),
            backgroundColor: Color(0xFF004AAD),
          ),
        );
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
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);

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
                    'Edit Detail Jadwal',
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
            const SizedBox(height: 18),
            _buildLabel('Nama Jadwal'),
            const SizedBox(height: 6),
            TextField(
              controller: _namaJadwalController,
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              decoration: _inputDecoration('Masukkan nama jadwal...'),
            ),
            const SizedBox(height: 14),
            _buildLabel('Nama Barang'),
            const SizedBox(height: 6),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Tanggal Jadwal'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pilihTanggal,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                    fontSize: 12.5,
                                    color: Colors.black87,
                                  ),
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
                      _buildLabel('Jam Jadwal'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pilihJam,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                    fontSize: 12.5,
                                    color: Colors.black87,
                                  ),
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
            _buildLabel('Jenis Perawatan'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        style: const TextStyle(fontSize: 13.5),
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
            const SizedBox(height: 14),
            _buildLabel('Catatan Tambahan (Opsional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _catatanController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              decoration: _inputDecoration('Masukkan catatan tambahan...'),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _simpanPerubahan,
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

  Widget _buildLabel(String text) {
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