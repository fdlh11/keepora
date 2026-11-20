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

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _maintenanceDetailController =
      TextEditingController();

  bool _isInitialized = false;
  bool _isSaving = false;

  String _selectedCategory = 'Umum';
  String _purchaseDate = '';
  DateTime? _selectedPurchaseDate;

  String _initialName = '';
  String _initialCategory = 'Umum';
  String _initialPurchaseDate = '';
  String _initialPurchasePriceDigits = '';
  String _initialCondition = '';
  String _initialMaintenanceDetail = '';

  // Kategorin barang
  static const List<String> _defaultCategories = [
    'Elektronik',
    'Kendaraan',
    'Furnitur',
    'Peralatan Rumah',
    'Gadget',
    'Olahraga & Hobi',
    'Umum',
    'Lainnya',
  ];

  // List bulan
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
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && mounted) {
        if (_nameController.text.trim().isEmpty) {
          setState(() {
            _nameController.text = _initialName;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _purchasePriceController.dispose();
    _conditionController.dispose();
    _maintenanceDetailController.dispose();
    super.dispose();
  }

  String _formatTanggalIndo(DateTime date) {
    return '${date.day} ${_bulanIndo[date.month - 1]} ${date.year}';
  }

  DateTime? _parseTanggalIndo(String dateStr) {
    final parts = dateStr.trim().split(' ');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final monthIndex = _bulanIndo.indexWhere(
      (b) => b.toLowerCase() == parts[1].toLowerCase(),
    );
    final year = int.tryParse(parts[2]);
    if (day == null || monthIndex == -1 || year == null) return null;
    return DateTime(year, monthIndex + 1, day);
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

  String _extractDigits(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  List<String> _getCategoryOptions() {
    final options = List<String>.from(_defaultCategories);
    if (_selectedCategory.isNotEmpty && !options.contains(_selectedCategory)) {
      options.insert(0, _selectedCategory);
    }
    return options;
  }

  bool get _hasUnsavedChanges {
    final currentPriceDigits = _extractDigits(_purchasePriceController.text);
    return _nameController.text.trim() != _initialName.trim() ||
        _selectedCategory.trim() != _initialCategory.trim() ||
        _purchaseDate.trim() != _initialPurchaseDate.trim() ||
        currentPriceDigits != _initialPurchasePriceDigits ||
        _conditionController.text.trim() != _initialCondition.trim() ||
        _maintenanceDetailController.text.trim() !=
            _initialMaintenanceDetail.trim();
  }

  Future<void> _pickPurchaseDate() async {
    final now = DateTime.now();
    final initial = _selectedPurchaseDate ?? now;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF004AAD),
                    onPrimary: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF004AAD),
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
        _selectedPurchaseDate = picked;
        _purchaseDate = _formatTanggalIndo(picked);
      });
    }
  }

  Future<void> _handleBackPress() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // pop up perubahan belum disimpan
    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Perubahan Belum Disimpan',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin keluar tanpa menyimpan?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004AAD),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          // button lanjut edit
                          child: Text(
                            'Lanjutkan Mengedit',
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // button keluar
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF004AAD),
                          side: const BorderSide(
                            color: Color(0xFF64A1F4),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Keluar',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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

  // pop up konfirmasi hapus barang
  Future<void> _confirmDeleteAsset() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hapus Barang',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda ingin menghapus barang ini dari daftar? Semua riwayat perawatan juga akan terhapus.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // button konfirmasi hapus
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004AAD),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Ya, Hapus',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // button batal
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF004AAD),
                          side: const BorderSide(
                            color: Color(0xFF64A1F4),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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

  Future<void> _saveChanges(String purchaseType) async {
    final updatedName = _nameController.text.trim();
    if (updatedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama barang tidak boleh kosong.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _nameFocusNode.unfocus();
    setState(() => _isSaving = true);

    try {
      final rawPriceDigits = _extractDigits(_purchasePriceController.text);
      final formattedPrice = rawPriceDigits.isEmpty
          ? 'Rp 0'
          : 'Rp ${_formatRibuan(rawPriceDigits)}';
      final updatedCategory = _selectedCategory.trim();
      final updatedDate = _purchaseDate.trim();
      final updatedCondition = _conditionController.text.trim();
      final updatedDetail = _maintenanceDetailController.text.trim();

      final Map<String, dynamic> updatePayload = {
        'name': updatedName,
        'category': updatedCategory,
        'purchaseDate': updatedDate,
        'purchasePrice': formattedPrice,
        'condition': updatedCondition,
        'maintenanceDetail': updatedDetail,
      };

      if (purchaseType == 'Second') {
        updatePayload['secondHandPurchaseDate'] = updatedDate;
      }

      await _assetService.updateAsset(widget.assetId, updatePayload);

      _initialName = updatedName;
      _initialCategory = updatedCategory;
      _initialPurchaseDate = updatedDate;
      _initialPurchasePriceDigits = rawPriceDigits;
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

  Widget _infoCard({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _editableBoxDecoration(
    String hint,
    bool isDark, {
    String? prefixText,
  }) {
    final borderColor =
        isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      prefixText: prefixText,
      prefixStyle: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF004AAD), width: 1.4),
      ),
    );
  }

  Widget _buildAssetPhoto(String photoUrl, bool isDark) {
    if (photoUrl.isEmpty) return _photoPlaceholder(isDark);

    if (photoUrl.startsWith('data:image')) {
      try {
        final base64Part = photoUrl.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _photoPlaceholder(isDark),
        );
      } catch (_) {
        return _photoPlaceholder(isDark);
      }
    }

    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _photoPlaceholder(isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF004AAD);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black;

    return StreamBuilder<QuerySnapshot>(
      stream: _assetService.getAssetsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: bgColor,
            body: const Center(
              child: CircularProgressIndicator(color: primaryBlue),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final matched = docs.where((d) => d.id == widget.assetId).toList();

        if (matched.isEmpty) {
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(backgroundColor: bgColor),
            body: const Center(child: Text('Data barang tidak ditemukan.')),
          );
        }

        final data = matched.first.data() as Map<String, dynamic>? ?? {};
        final rawName = (data['name'] ?? '-').toString();
        final rawCategory = (data['category'] ?? 'Umum').toString();
        final photoUrl = (data['photoUrl'] ?? '').toString();
        final purchaseType = (data['purchaseType'] ?? 'Baru').toString();
        final rawPurchaseDate = (data['purchaseDate'] ?? '-').toString();
        final rawPurchasePrice = (data['purchasePrice'] ?? 'Rp 0').toString();
        final lastMaintenance = (data['lastMaintenance'] ?? '-').toString();
        final lastMaintenanceCost =
            (data['lastMaintenanceCost'] ?? 'Rp 0').toString();

        if (!_isInitialized) {
          _initialName = rawName;
          _nameController.text = rawName;

          _initialCategory = rawCategory.isEmpty ? 'Umum' : rawCategory;
          _selectedCategory = _initialCategory;

          _initialPurchaseDate = rawPurchaseDate;
          _purchaseDate = rawPurchaseDate;
          _selectedPurchaseDate = _parseTanggalIndo(rawPurchaseDate);

          _initialPurchasePriceDigits = _extractDigits(rawPurchasePrice);
          _purchasePriceController.text =
              _formatRibuan(_initialPurchasePriceDigits);

          _initialCondition = (data['condition'] ?? '').toString();
          _initialMaintenanceDetail =
              (data['maintenanceDetail'] ?? '').toString();
          _conditionController.text = _initialCondition;
          _maintenanceDetailController.text = _initialMaintenanceDetail;
          _isInitialized = true;
        }

        final categoryOptions = _getCategoryOptions();

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _handleBackPress();
          },
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              // Icon back/kembali
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimary),
                onPressed: _isSaving ? null : _handleBackPress,
              ),
              // icon detail barang
              title: Text(
                'Detail Barang',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              // icon hapus barang
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
                  Container(
                    width: double.infinity,
                    height: 205,
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFE5E7EB),
                    child: _buildAssetPhoto(photoUrl, isDark),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                enabled: !_isSaving,
                                maxLines: null,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _nameFocusNode.unfocus(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            PopupMenuButton<String>(
                              enabled: !_isSaving,
                              color: surfaceColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              onSelected: (newValue) {
                                setState(() {
                                  _selectedCategory = newValue;
                                });
                              },
                              itemBuilder: (context) {
                                return categoryOptions.map((cat) {
                                  return PopupMenuItem<String>(
                                    value: cat,
                                    height: 40,
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: cat == _selectedCategory
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: cat == _selectedCategory
                                            ? (isDark
                                                ? const Color(0xFF60A5FA)
                                                : primaryBlue)
                                            : (isDark
                                                ? Colors.white
                                                : Colors.black87),
                                      ),
                                    ),
                                  );
                                }).toList();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF172554)
                                      : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF1D4ED8)
                                        : const Color(0xFF93C5FD),
                                  ),
                                ),
                                child: Text(
                                  _selectedCategory,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF60A5FA)
                                        : primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Informasi Pembelian - bisa diedit
                        Text(
                          'Informasi Pembelian',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    purchaseType == 'Second'
                                        ? 'Tanggal Pembelian (Second)'
                                        : 'Tanggal Pembelian',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // field pilih tanggal
                                  InkWell(
                                    onTap:
                                        _isSaving ? null : _pickPurchaseDate,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _purchaseDate.isEmpty
                                                  ? 'Pilih tanggal...'
                                                  : _purchaseDate,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // icon kalender
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 16,
                                            color: isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // field harga pembelian
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Harga Pembelian',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 48,
                                    child: TextField(
                                      controller: _purchasePriceController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        _RibuanFormatter(),
                                      ],
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      decoration: _editableBoxDecoration(
                                        '0',
                                        isDark,
                                        prefixText: 'Rp ',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Kondisi Barang - Dapat diedit
                        Text(
                          'Kondisi Barang',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // field kondisi abrang
                        TextField(
                          controller: _conditionController,
                          maxLines: 3,
                          minLines: 2,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.35,
                          ),
                          decoration: _editableBoxDecoration(
                            'Masukkan kondisi barang...',
                            isDark,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Catatan Perawatan Terakhir - ga bisa diedit/read only
                        Text(
                          'Catatan Perawatan Terakhir',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // card tanggal perawatan terakhir
                        Row(
                          children: [
                            Expanded(
                              child: _infoCard(
                                label: 'Tanggal Perawatan Terakhir',
                                value: lastMaintenance,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // card biaya perawatan terakhir
                            Expanded(
                              child: _infoCard(
                                label: 'Biaya Perawatan Terakhir',
                                value: lastMaintenanceCost,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Rincian Perawatan - dapat diedit
                        Text(
                          'Rincian Perawatan',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // field catatan perawatan
                        TextField(
                          controller: _maintenanceDetailController,
                          maxLines: 3,
                          minLines: 2,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.35,
                          ),
                          decoration: _editableBoxDecoration(
                            'Belum ada catatan perawatan.',
                            isDark,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // button simpan perubahan
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () => _saveChanges(purchaseType),
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

  Widget _photoPlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      // icon gambar foto
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
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _RibuanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      if (i > 0 && posFromEnd % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}