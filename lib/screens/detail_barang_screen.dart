import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';

class DetailBarangScreen extends StatefulWidget {
  final String assetId;

  const DetailBarangScreen({super.key, required this.assetId});

  @override
  State<DetailBarangScreen> createState() => _DetailBarangScreenState();
}

class _DetailBarangScreenState extends State<DetailBarangScreen> {
  final AssetService _assetService = AssetService();

  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _maintenanceDetailController =
      TextEditingController();

  bool _isInitialized = false;
  bool _isSaving = false;
  String _initialCondition = '';
  String _initialMaintenanceDetail = '';

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
    _conditionController.dispose();
    _maintenanceDetailController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _conditionController.text.trim() != _initialCondition.trim() ||
        _maintenanceDetailController.text.trim() !=
            _initialMaintenanceDetail.trim();
  }

  String _formatTanggalIndo(DateTime date) {
    return '${date.day} ${_bulanIndo[date.month - 1]} ${date.year}';
  }

  String _formatRibuan(String digits) {
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      if (i > 0 && posFromEnd % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Future<void> _handleBackPress() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }

    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                'Perubahan pada kondisi barang atau rincian perawatan belum disimpan. Keluar tanpa menyimpan?',
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
                        'Batal',
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
      ),
    );

    if (shouldLeave == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDeleteAsset() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Hapus Barang',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Barang ini beserta seluruh riwayat dan jadwal perawatannya akan dihapus permanen. Lanjutkan?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _assetService.deleteAsset(widget.assetId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barang berhasil dihapus.'),
            backgroundColor: Color(0xFF004AAD),
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final updatedCondition = _conditionController.text.trim();
      final updatedDetail = _maintenanceDetailController.text.trim();

      await _assetService.updateAsset(widget.assetId, {
        'condition': updatedCondition,
        'maintenanceDetail': updatedDetail,
      });

      _initialCondition = updatedCondition;
      _initialMaintenanceDetail = updatedDetail;

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan berhasil disimpan.'),
            backgroundColor: Color(0xFF004AAD),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan perubahan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _showAddMaintenanceDialog(String assetName) async {
    final costCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSavingRecord = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'Catat Perawatan Baru',
                style: GoogleFonts.montserrat(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tanggal Perawatan',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_formatTanggalIndo(selectedDate)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Biaya Perawatan',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        prefixText: 'Rp ',
                        hintText: '350000',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Rincian Perawatan',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: detailCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Ganti termal pasta & bersihkan kipas',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingRecord
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSavingRecord
                      ? null
                      : () async {
                          if (detailCtrl.text.trim().isEmpty) return;
                          setDialogState(() => isSavingRecord = true);
                          final digits =
                              costCtrl.text.replaceAll('.', '').trim();
                          final formattedCost = digits.isEmpty
                              ? 'Rp 0'
                              : 'Rp ${_formatRibuan(digits)}';
                          final cleanDetail = detailCtrl.text.trim();

                          await _assetService.addMaintenanceRecord(
                            assetId: widget.assetId,
                            assetName: assetName,
                            maintenanceDate: _formatTanggalIndo(selectedDate),
                            cost: formattedCost,
                            detail: cleanDetail,
                          );

                          _maintenanceDetailController.text = cleanDetail;
                          _initialMaintenanceDetail = cleanDetail;

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Catatan perawatan berhasil disimpan.',
                                ),
                                backgroundColor: Color(0xFF004AAD),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004AAD),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _whiteInfoCard({
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _editableBoxDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF004AAD), width: 1.4),
      ),
    );
  }

  Widget _buildAssetPhoto(String photoUrl) {
    if (photoUrl.isEmpty) return _photoPlaceholder();

    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Part = photoUrl.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _photoPlaceholder(),
        );
      } catch (_) {
        return _photoPlaceholder();
      }
    }

    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _photoPlaceholder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);

    return StreamBuilder<QuerySnapshot>(
      stream: _assetService.getAssetsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF3F4F6),
            body: Center(child: CircularProgressIndicator(color: primaryBlue)),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final matched = docs.where((d) => d.id == widget.assetId).toList();

        if (matched.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            appBar: AppBar(backgroundColor: const Color(0xFFF3F4F6)),
            body: const Center(child: Text('Data barang tidak ditemukan.')),
          );
        }

        final data = matched.first.data() as Map<String, dynamic>? ?? {};
        final name = (data['name'] ?? '-').toString();
        final category = (data['category'] ?? 'Umum').toString();
        final photoUrl = (data['photoUrl'] ?? '').toString();
        final purchaseType = (data['purchaseType'] ?? 'Baru').toString();
        final purchaseDate = (data['purchaseDate'] ?? '-').toString();
        final purchasePrice = (data['purchasePrice'] ?? 'Rp 0').toString();
        final lastMaintenance = (data['lastMaintenance'] ?? '-').toString();
        final lastMaintenanceCost =
            (data['lastMaintenanceCost'] ?? 'Rp 0').toString();

        if (!_isInitialized) {
          _initialCondition = (data['condition'] ?? '').toString();
          _initialMaintenanceDetail =
              (data['maintenanceDetail'] ?? '').toString();
          _conditionController.text = _initialCondition;
          _maintenanceDetailController.text = _initialMaintenanceDetail;
          _isInitialized = true;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _handleBackPress();
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF3F4F6),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: _isSaving ? null : _handleBackPress,
              ),
              title: Text(
                'Detail Barang',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Hapus Barang',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                  onPressed: _isSaving ? null : _confirmDeleteAsset,
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Foto Barang Lebar
                  Container(
                    width: double.infinity,
                    height: 205,
                    color: const Color(0xFFE5E7EB),
                    child: _buildAssetPhoto(photoUrl),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nama Barang + Badge Kategori
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.montserrat(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFF93C5FD)),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Informasi Pembelian
                        Text(
                          'Informasi Pembelian',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _whiteInfoCard(
                                label: purchaseType == 'Second'
                                    ? 'Tanggal Pembelian (Second)'
                                    : 'Tanggal Pembelian',
                                value: purchaseDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _whiteInfoCard(
                                label: 'Harga Pembelian',
                                value: purchasePrice,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Kondisi Barang (bisa diedit)
                        Text(
                          'Kondisi Barang',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _conditionController,
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            height: 1.35,
                          ),
                          decoration: _editableBoxDecoration(
                            'Masukkan kondisi barang...',
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Catatan Perawatan Terakhir
                        Text(
                          'Catatan Perawatan Terakhir',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _whiteInfoCard(
                                label: 'Tanggal Perawatan Terakhir',
                                value: lastMaintenance,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _whiteInfoCard(
                                label: 'Biaya Perawatan Terakhir',
                                value: lastMaintenanceCost,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Rincian Perawatan (Bisa Diedit)
                        Text(
                          'Rincian Perawatan',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _maintenanceDetailController,
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            height: 1.35,
                          ),
                          decoration: _editableBoxDecoration(
                            'Belum ada catatan perawatan.',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showAddMaintenanceDialog(name),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Catat Perawatan Baru',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Tombol Simpan Perubahan
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
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
                                    'Simpan Perubahan',
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _photoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          size: 46,
          color: Colors.grey.shade500,
        ),
        const SizedBox(height: 6),
        Text(
          'Foto Barang',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}