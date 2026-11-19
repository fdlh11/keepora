import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/jadwal_service.dart';

class TambahJadwalScreen extends StatefulWidget {
  const TambahJadwalScreen({super.key});

  @override
  State<TambahJadwalScreen> createState() => _TambahJadwalScreenState();
}

class _TambahJadwalScreenState extends State<TambahJadwalScreen> {
  final JadwalService _jadwalService = JadwalService();
  final TextEditingController _namaJadwalController = TextEditingController();
  final TextEditingController _estimasiBiayaController =
      TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  String? _selectedAssetId;
  String? _selectedAssetName;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedJenisPerawatan;
  bool _isLoading = false;

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

  String _formatTanggal(DateTime date) {
    return '${date.day} ${_bulanIndo[date.month]} ${date.year}';
  }

  String _formatJam(TimeOfDay time) {
    final jam = time.hour.toString().padLeft(2, '0');
    final menit = time.minute.toString().padLeft(2, '0');
    return '$jam:$menit WIB';
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

  Future<void> _pilihTanggal() async {
    final minDate = _minScheduleDate;
    final initial = (_selectedDate != null && !_selectedDate!.isBefore(minDate))
        ? _selectedDate!
        : minDate;

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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pilihJam() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF004AAD)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _simpanJadwal() async {
    final namaJadwal = _namaJadwalController.text.trim();

    if (namaJadwal.isEmpty ||
        _selectedAssetId == null ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedJenisPerawatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua kolom wajib terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final pickedDay = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
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

    setState(() => _isLoading = true);

    try {
      final scheduledAt = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final cleanDigits =
          _estimasiBiayaController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final double estimatedCost = double.tryParse(cleanDigits) ?? 0;

      await _jadwalService.tambahJadwal(
        title: namaJadwal,
        assetId: _selectedAssetId!,
        assetName: _selectedAssetName ?? '',
        scheduledAt: scheduledAt,
        maintenanceType: _selectedJenisPerawatan!,
        estimatedCost: estimatedCost,
        notes: _catatanController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal perawatan berhasil ditambahkan.'),
            backgroundColor: Color(0xFF004AAD),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan jadwal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tambah Jadwal Baru',
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
                stream: _jadwalService.streamDaftarBarang(),
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
                          docs.isEmpty
                              ? 'Belum ada data barang'
                              : 'Pilih nama barang',
                          style: TextStyle(
                            color: Colors.grey.shade500,
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
                                    _selectedDate != null
                                        ? _formatTanggal(_selectedDate!)
                                        : 'Pilih Tanggal Jadwal',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedDate != null
                                          ? Colors.black87
                                          : Colors.grey.shade500,
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
                                    _selectedTime != null
                                        ? _formatJam(_selectedTime!)
                                        : 'Pilih Jam',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedTime != null
                                          ? Colors.black87
                                          : Colors.grey.shade500,
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
                    hint: Text(
                      'Pilih jenis perawatan',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13.5,
                      ),
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
                    onChanged: (val) =>
                        setState(() => _selectedJenisPerawatan = val),
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

              // Catatan Tambahan
              _buildLabel('Catatan Tambahan (Opsional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _catatanController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                decoration: _inputDecoration(
                  'Masukkan Catatan Tambahan (opsional)...',
                ),
              ),

              const SizedBox(height: 32),

              // Tombol Tambah Jadwal
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _simpanJadwal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Tambah Jadwal',
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