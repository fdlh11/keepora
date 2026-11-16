import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';

Future<bool?> showCatatPerawatanDialog({
  required BuildContext context,
  required String assetId,
  required String assetName,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _CatatPerawatanDialog(assetId: assetId, assetName: assetName),
  );
}

class _CatatPerawatanDialog extends StatefulWidget {
  final String assetId;
  final String assetName;

  const _CatatPerawatanDialog({required this.assetId, required this.assetName});

  @override
  State<_CatatPerawatanDialog> createState() => _CatatPerawatanDialogState();
}

class _CatatPerawatanDialogState extends State<_CatatPerawatanDialog> {
  final AssetService _assetService = AssetService();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  bool _isLoading = false;

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

  bool get _hasUnsavedChanges =>
      _dateController.text.trim().isNotEmpty ||
      _costController.text.trim().isNotEmpty ||
      _detailController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _dateController.dispose();
    _costController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  String _formatIndonesianDate(DateTime date) {
    final String monthName = _indonesianMonths[date.month - 1];
    return '${date.day} $monthName ${date.year}';
  }

  String _formatRupiah(String rawInput) {
    final digits = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 'Rp 0';
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString()}';
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0056C6),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _dateController.text = _formatIndonesianDate(picked);
      });
    }
  }

  Future<void> _handleCloseAttempt() async {
    if (_isLoading) return;

    if (!_hasUnsavedChanges) {
      Navigator.pop(context, false);
      return;
    }

    final bool? confirmDiscard = await showDialog<bool>(
      context: context,
      builder: (BuildContext discardContext) {
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
                  'Anda memiliki perubahan yang belum disimpan.\nApakah Anda yakin ingin keluar tanpa menyimpan?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black87,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(discardContext, false),
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
                          'Lanjutkan Mengedit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(discardContext, true),
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
                            fontSize: 13,
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

    if (confirmDiscard == true && mounted) {
      Navigator.pop(context, false);
    }
  }

  Future<void> _submitMaintenance() async {
    final String dateText = _dateController.text.trim();
    final String rawCost = _costController.text.trim();
    final String detailText = _detailController.text.trim();

    if (dateText.isEmpty) {
      _showSnackBar('Tanggal perawatan wajib dipilih.', isError: true);
      return;
    }
    if (detailText.isEmpty) {
      _showSnackBar('Rincian perawatan wajib diisi.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _assetService.addMaintenanceRecord(
        assetId: widget.assetId,
        assetName: widget.assetName,
        maintenanceDate: dateText,
        cost: _formatRupiah(rawCost),
        detail: detailText,
      );

      if (!mounted) return;
      _showSnackBar('Catatan perawatan berhasil diperbarui!');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal menyimpan perawatan: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFE53935) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleCloseAttempt();
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul
              Row(
                children: [
                  InkWell(
                    onTap: _handleCloseAttempt,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Catat Perawatan Baru',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
              const SizedBox(height: 20),

              // Tanggal Perawatan
              _buildLabel('Tanggal Perawatan'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Pilih Tanggal Perawatan',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    suffixIcon: Icon(
                      Icons.calendar_today_outlined,
                      size: 19,
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
              const SizedBox(height: 16),

              // Biaya Perawatan
              _buildLabel('Biaya Perawatan'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan Biaya Perawatan...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rincian Perawatan
              _buildLabel('Rincian Perawatan'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _detailController,
                  maxLines: 3,
                  minLines: 2,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan Rincian Perawatan...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Perbarui
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitMaintenance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
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
