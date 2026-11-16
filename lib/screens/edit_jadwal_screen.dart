import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';

Future<bool?> showEditJadwalDialog({
  required BuildContext context,
  required String scheduleId,
  required Map<String, dynamic> scheduleData,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _EditJadwalDialog(
      scheduleId: scheduleId,
      scheduleData: scheduleData,
    ),
  );
}

class _EditJadwalDialog extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> scheduleData;

  const _EditJadwalDialog({
    required this.scheduleId,
    required this.scheduleData,
  });

  @override
  State<_EditJadwalDialog> createState() => _EditJadwalDialogState();
}

class _EditJadwalDialogState extends State<_EditJadwalDialog> {
  final _formKey = GlobalKey<FormState>();
  final AssetService _assetService = AssetService();

  late TextEditingController _titleController;
  late TextEditingController _notesController;

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

    _titleController = TextEditingController(
      text: (data['title'] ?? '').toString(),
    );
    _notesController = TextEditingController(
      text: (data['notes'] ?? '').toString(),
    );

    final rawAssetId = (data['assetId'] ?? '').toString();
    _selectedAssetId = rawAssetId.isEmpty ? null : rawAssetId;
    _selectedAssetName = (data['assetName'] ?? '').toString();

    final rawType = (data['maintenanceType'] ?? 'Perawatan').toString();
    _selectedMaintenanceType = _maintenanceTypes.contains(rawType)
        ? rawType
        : _maintenanceTypes.first;

    final rawTimestamp = data['scheduledTimestamp'];
    if (rawTimestamp is Timestamp) {
      final dt = rawTimestamp.toDate();
      _selectedDate = dt;
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
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

      await _assetService.updateSchedule(widget.scheduleId, {
        'title': _titleController.text.trim(),
        'assetId': _selectedAssetId!,
        'assetName': _selectedAssetName,
        'maintenanceType': _selectedMaintenanceType,
        'dateFormatted': formattedDate,
        'timeFormatted': formattedTime,
        'scheduledTimestamp': Timestamp.fromDate(combinedDateTime),
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal perawatan berhasil diperbarui.'),
            backgroundColor: Color(0xFF0056C6),
          ),
        );
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Pop Up
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
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
                  const SizedBox(width: 22),
                ],
              ),
              const SizedBox(height: 18),

              // 1. Nama Jadwal
              Text(
                'Nama Jadwal',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
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
              const SizedBox(height: 16),

              // 2. Nama Barang (Dropdown dari Firestore Assets)
              Text(
                'Nama Barang',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
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
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: _fieldDecoration(
                      hintText: _selectedAssetName.isNotEmpty
                          ? _selectedAssetName
                          : 'Pilih nama barang',
                    ),
                    items: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final name = (data['name'] ?? 'Tanpa Nama').toString();
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
                            final data =
                                selectedDoc.data() as Map<String, dynamic>? ??
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
              const SizedBox(height: 16),

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
                            fontSize: 13,
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
                            fontSize: 13,
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
              const SizedBox(height: 16),

              // 4. Jenis Perawatan
              Text(
                'Jenis Perawatan',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
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
                style: const TextStyle(fontSize: 13, color: Colors.black87),
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
              const SizedBox(height: 16),

              // 5. Catatan Tambahan (Opsional)
              Text(
                'Catatan Tambahan (Opsional)',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
                decoration: _fieldDecoration(
                  hintText: 'Masukkan catatan tambahan (opsional)...',
                ),
              ),
              const SizedBox(height: 24),

              // 6. Tombol Perbarui
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
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
    );
  }
}