import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';

class TambahJadwalScreen extends StatefulWidget {
  const TambahJadwalScreen({super.key});

  @override
  State<TambahJadwalScreen> createState() => _TambahJadwalScreenState();
}

class _TambahJadwalScreenState extends State<TambahJadwalScreen> {
  final _formKey = GlobalKey<FormState>();
  final AssetService _assetService = AssetService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedAssetId;
  String _selectedAssetName = '';
  String? _selectedMaintenanceType;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  final List<String> _maintenanceTypes = [
    'Perawatan Rutin',
    'Pembersihan & Pengecekan',
    'Ganti Komponen / Suku Cadang',
    'Servis Berkala',
    'Kalibrasi / Update Sistem',
    'Lainnya',
  ];

  static const List<String> _bulanIndo = [
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
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _titleController.text.trim().isNotEmpty ||
        _selectedAssetId != null ||
        _selectedDate != null ||
        _selectedTime != null ||
        _selectedMaintenanceType != null ||
        _notesController.text.trim().isNotEmpty;
  }

  Future<void> _handleBackPress() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }

    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Perubahan Belum Disimpan',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Anda sedang mengisi jadwal baru. Data yang sudah diisi akan hilang jika Anda keluar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004AAD),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Lanjutkan Mengisi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF004AAD),
                          side: const BorderSide(
                            color: Color(0xFF64A1F4),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Keluar',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldLeave == true && mounted) {
      Navigator.pop(context);
    }
  }

  String _formatTanggalIndo(DateTime date) {
    return '${date.day} ${_bulanIndo[date.month - 1]} ${date.year}';
  }

  String _formatJam(TimeOfDay time) {
    final jam = time.hour.toString().padLeft(2, '0');
    final menit = time.minute.toString().padLeft(2, '0');
    return '$jam:$menit';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0056C6),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0056C6),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAssetId == null || _selectedAssetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih nama barang terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih tanggal jadwal terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih jam jadwal terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedMaintenanceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih jenis perawatan terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final formattedDate = _formatTanggalIndo(scheduledDateTime);
      final formattedTime = _formatJam(_selectedTime!);

      await _assetService.addSchedule({
        'title': _titleController.text.trim(),
        'assetId': _selectedAssetId!,
        'assetName': _selectedAssetName,
        'maintenanceType': _selectedMaintenanceType!,
        'dateFormatted': formattedDate,
        'timeFormatted': formattedTime,
        'scheduledTimestamp': Timestamp.fromDate(scheduledDateTime),
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal perawatan berhasil ditambahkan.'),
            backgroundColor: Color(0xFF0056C6),
          ),
        );
        Navigator.pop(context, true);
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
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.grey.shade100,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0056C6), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0056C6);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: _isSaving ? null : _handleBackPress,
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Nama Jadwal
                  Text(
                    'Nama Jadwal',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    style:
                        const TextStyle(fontSize: 13.5, color: Colors.black87),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama jadwal tidak boleh kosong';
                      }
                      return null;
                    },
                    decoration: _fieldDecoration(
                      hintText: 'Masukkan nama jadwal...',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Nama Barang (Dropdown dari Firestore Assets)
                  Text(
                    'Nama Barang',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: _assetService.getAssetsStream(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedAssetId,
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade600,
                        ),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.black87,
                        ),
                        decoration: _fieldDecoration(
                          hintText: docs.isEmpty
                              ? 'Belum ada barang terdaftar'
                              : 'Pilih nama barang',
                        ),
                        items: docs.map((doc) {
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};
                          final name =
                              (data['name'] ?? 'Tanpa Nama').toString();
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: docs.isEmpty
                            ? null
                            : (value) {
                                if (value == null) return;
                                final selectedDoc = docs.firstWhere(
                                  (doc) => doc.id == value,
                                );
                                final data = selectedDoc.data()
                                        as Map<String, dynamic>? ??
                                    {};
                                setState(() {
                                  _selectedAssetId = value;
                                  _selectedAssetName =
                                      (data['name'] ?? '').toString();
                                });
                              },
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // 3. Tanggal Jadwal & Jam Jadwal (Sejajar)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tanggal Jadwal
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tanggal Jadwal',
                              style: GoogleFonts.montserrat(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedDate == null
                                            ? 'Pilih Tanggal Jadwal'
                                            : _formatTanggalIndo(
                                                _selectedDate!),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _selectedDate == null
                                              ? Colors.grey.shade500
                                              : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
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

                      // Jam Jadwal
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jam Jadwal',
                              style: GoogleFonts.montserrat(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedTime == null
                                            ? 'Pilih Jam'
                                            : _formatJam(_selectedTime!),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _selectedTime == null
                                              ? Colors.grey.shade500
                                              : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 19,
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
                  const SizedBox(height: 18),

                  // 4. Jenis Perawatan
                  Text(
                    'Jenis Perawatan',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMaintenanceType,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade600,
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Colors.black87,
                    ),
                    decoration: _fieldDecoration(
                      hintText: 'Pilih jenis perawatan',
                    ),
                    items: _maintenanceTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMaintenanceType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 18),

                  // 5. Catatan Tambahan (Opsional)
                  Text(
                    'Catatan Tambahan (Opsional)',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 4,
                    minLines: 3,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    decoration: _fieldDecoration(
                      hintText: 'Masukkan Catatan Tambahan (opsional)...',
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 6. Tombol Tambah Jadwal
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submitSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Tambah Jadwal',
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
          ),
        ),
      ),
    );
  }
}