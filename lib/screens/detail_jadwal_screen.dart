import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';

// =============================================================================
// 1. HALAMAN DETAIL JADWAL (FULL SCREEN + POP UP KONFIRMASI HAPUS JADWAL)
// =============================================================================
class DetailJadwalScreen extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> scheduleData;

  const DetailJadwalScreen({
    super.key,
    required this.scheduleId,
    required this.scheduleData,
  });

  @override
  State<DetailJadwalScreen> createState() => _DetailJadwalScreenState();
}

class _DetailJadwalScreenState extends State<DetailJadwalScreen> {
  final AssetService _assetService = AssetService();
  late Map<String, dynamic> _currentData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentData = Map<String, dynamic>.from(widget.scheduleData);
  }

  Future<void> _markAsCompleted() async {
    final title = (_currentData['title'] ?? '-').toString();
    final assetId = (_currentData['assetId'] ?? '').toString();
    final assetName = (_currentData['assetName'] ?? '-').toString();
    final dateFormatted = (_currentData['dateFormatted'] ?? '-').toString();

    setState(() => _isLoading = true);

    try {
      await _assetService.completeSchedule(
        scheduleId: widget.scheduleId,
        assetId: assetId,
        assetName: assetName,
        maintenanceTitle: title,
        dateFormatted: dateFormatted,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal ditandai selesai dan masuk ke riwayat.'),
            backgroundColor: Color(0xFF0056C6),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyelesaikan jadwal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (confirmContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hapus Jadwal',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Jadwal ini akan dihapus permanen. Apakah Anda yakin ingin melanjutkan?',
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
                      onPressed: () => Navigator.pop(confirmContext, true),
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
                        'Ya, Hapus',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
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
                        'Batal',
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
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _assetService.deleteSchedule(widget.scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jadwal perawatan dihapus.'),
              backgroundColor: Color(0xFF0056C6),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus jadwal: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToEdit() async {
    final updatedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditJadwalScreen(
          scheduleId: widget.scheduleId,
          scheduleData: _currentData,
        ),
      ),
    );

    if (updatedData != null && mounted) {
      setState(() {
        _currentData = updatedData;
      });
    }
  }

  Widget _buildReadOnlyBox({
    required String text,
    double? minHeight,
    bool isPlaceholder = false,
  }) {
    return Container(
      width: double.infinity,
      constraints:
          minHeight != null ? BoxConstraints(minHeight: minHeight) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          color: isPlaceholder ? Colors.grey.shade500 : Colors.black87,
          height: 1.35,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0056C6);

    final title = (_currentData['title'] ?? '-').toString();
    final assetName = (_currentData['assetName'] ?? '-').toString();
    final dateFormatted = (_currentData['dateFormatted'] ?? '-').toString();
    final rawTime = (_currentData['timeFormatted'] ?? '-').toString();
    final maintenanceType =
        (_currentData['maintenanceType'] ?? 'Perawatan').toString();
    final notes = (_currentData['notes'] ?? '').toString().trim();
    final isCompleted = _currentData['isCompleted'] == true;

    final displayTime =
        rawTime.contains('WIB') || rawTime == '-' ? rawTime : '$rawTime WIB';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
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
            tooltip: 'Edit Jadwal',
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.black87,
              size: 22,
            ),
            onPressed: _isLoading ? null : _navigateToEdit,
          ),
          IconButton(
            tooltip: 'Hapus Jadwal',
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.black87,
              size: 23,
            ),
            onPressed: _isLoading ? null : _confirmDelete,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
              _buildReadOnlyBox(text: title),
              const SizedBox(height: 18),

              // 2. Nama Barang
              Text(
                'Nama Barang',
                style: GoogleFonts.montserrat(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildReadOnlyBox(text: assetName.isEmpty ? '-' : assetName),
              const SizedBox(height: 18),

              // 3. Tanggal Jadwal & Jam Jadwal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        _buildReadOnlyBox(text: dateFormatted),
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
                          'Jam Jadwal',
                          style: GoogleFonts.montserrat(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildReadOnlyBox(text: displayTime),
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
              _buildReadOnlyBox(text: maintenanceType),
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
              _buildReadOnlyBox(
                text: notes.isEmpty ? 'Tidak ada catatan tambahan.' : notes,
                minHeight: 84,
                isPlaceholder: notes.isEmpty,
              ),
              const SizedBox(height: 36),

              // 6. Tombol Tandai Selesai
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_isLoading || isCompleted) ? null : _markAsCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isCompleted ? Colors.grey.shade400 : primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          isCompleted ? 'Sudah Selesai' : 'Tandai Selesai',
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
    );
  }
}

// =============================================================================
// 2. HALAMAN EDIT DETAIL JADWAL (FULL SCREEN + KONFIRMASI PERUBAHAN BELUM DISIMPAN)
// =============================================================================
class EditJadwalScreen extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> scheduleData;

  const EditJadwalScreen({
    super.key,
    required this.scheduleId,
    required this.scheduleData,
  });

  @override
  State<EditJadwalScreen> createState() => _EditJadwalScreenState();
}

class _EditJadwalScreenState extends State<EditJadwalScreen> {
  final _formKey = GlobalKey<FormState>();
  final AssetService _assetService = AssetService();

  late TextEditingController _titleController;
  late TextEditingController _notesController;

  late String _initialTitle;
  late String _initialAssetId;
  late String _initialMaintenanceType;
  late String _initialNotes;
  DateTime? _initialDate;
  TimeOfDay? _initialTime;

  String? _selectedAssetId;
  String _selectedAssetName = '';
  late String _selectedMaintenanceType;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  final List<String> _maintenanceTypes = [
    'Perawatan',
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
  void initState() {
    super.initState();
    final data = widget.scheduleData;

    _initialTitle = (data['title'] ?? '').toString();
    _initialAssetId = (data['assetId'] ?? '').toString();
    _initialNotes = (data['notes'] ?? '').toString();

    final rawType = (data['maintenanceType'] ?? 'Perawatan').toString();
    _initialMaintenanceType = _maintenanceTypes.contains(rawType)
        ? rawType
        : _maintenanceTypes.first;

    _titleController = TextEditingController(text: _initialTitle);
    _notesController = TextEditingController(text: _initialNotes);

    _selectedAssetId = _initialAssetId.isEmpty ? null : _initialAssetId;
    _selectedAssetName = (data['assetName'] ?? '').toString();
    _selectedMaintenanceType = _initialMaintenanceType;

    final rawTimestamp = data['scheduledTimestamp'];
    if (rawTimestamp is Timestamp) {
      final dt = rawTimestamp.toDate();
      _initialDate = DateTime(dt.year, dt.month, dt.day);
      _initialTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      _selectedDate = _initialDate;
      _selectedTime = _initialTime;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    final dateChanged = _selectedDate?.year != _initialDate?.year ||
        _selectedDate?.month != _initialDate?.month ||
        _selectedDate?.day != _initialDate?.day;
    final timeChanged = _selectedTime?.hour != _initialTime?.hour ||
        _selectedTime?.minute != _initialTime?.minute;

    return _titleController.text.trim() != _initialTitle ||
        (_selectedAssetId ?? '') != _initialAssetId ||
        _selectedMaintenanceType != _initialMaintenanceType ||
        _notesController.text.trim() != _initialNotes ||
        dateChanged ||
        timeChanged;
  }

  Future<void> _handleBackPress() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }

    final bool? shouldDiscard = await showDialog<bool>(
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
                  'Anda sedang mengubah jadwal. Data yang sudah diubah akan hilang jika Anda keluar.',
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

    if (shouldDiscard == true && mounted) {
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
      setState(() => _selectedDate = picked);
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
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _updateSchedule() async {
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

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal dan jam jadwal tidak boleh kosong.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final combinedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final formattedDate = _formatTanggalIndo(combinedDateTime);
      final formattedTime = _formatJam(_selectedTime!);
      final timestamp = Timestamp.fromDate(combinedDateTime);

      final updatedPayload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'assetId': _selectedAssetId!,
        'assetName': _selectedAssetName,
        'maintenanceType': _selectedMaintenanceType,
        'dateFormatted': formattedDate,
        'timeFormatted': formattedTime,
        'scheduledTimestamp': timestamp,
        'notes': _notesController.text.trim(),
      };

      await _assetService.updateSchedule(widget.scheduleId, updatedPayload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal perawatan berhasil diperbarui.'),
            backgroundColor: Color(0xFF0056C6),
          ),
        );
        Navigator.pop(context, {
          ...widget.scheduleData,
          ...updatedPayload,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui jadwal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.grey.shade100,
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
    final displayDate = _selectedDate != null
        ? _formatTanggalIndo(_selectedDate!)
        : (widget.scheduleData['dateFormatted'] ?? 'Pilih Tanggal').toString();
    final displayTime = _selectedTime != null
        ? '${_formatJam(_selectedTime!)} WIB'
        : (widget.scheduleData['timeFormatted'] ?? 'Pilih Jam').toString();

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
                      final hasMatchingId = docs.any(
                        (doc) => doc.id == _selectedAssetId,
                      );

                      return DropdownButtonFormField<String>(
                        initialValue: hasMatchingId ? _selectedAssetId : null,
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade600,
                        ),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                            fontSize: 13.5, color: Colors.black87),
                        decoration: _fieldDecoration(
                          hintText: _selectedAssetName.isNotEmpty
                              ? _selectedAssetName
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

                  // 3. Tanggal Jadwal & Jam Jadwal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                        displayDate,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
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
                                        displayTime,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87,
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
                    style:
                        const TextStyle(fontSize: 13.5, color: Colors.black87),
                    decoration: _fieldDecoration(),
                    items: _maintenanceTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMaintenanceType = value);
                      }
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
                      hintText: 'Masukkan catatan tambahan (opsional)...',
                    ),
                  ),
                  const SizedBox(height: 36),

                  // 6. Tombol Perbarui
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updateSchedule,
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
          ),
        ),
      ),
    );
  }
}