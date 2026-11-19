import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/asset_service.dart';

class TambahBarangScreen extends StatefulWidget {
  const TambahBarangScreen({super.key});

  @override
  State<TambahBarangScreen> createState() => _TambahBarangScreenState();
}

class _TambahBarangScreenState extends State<TambahBarangScreen> {
  final _formKey = GlobalKey<FormState>();
  final AssetService _assetService = AssetService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  File? _selectedImage;
  String? _selectedCategory;
  DateTime? _purchaseDate;
  DateTime? _secondHandPurchaseDate;
  bool _isSaving = false;

  final List<String> _categories = [
    'Elektronik',
    'Kendaraan',
    'Peralatan Rumah Tangga',
    'Perkakas & Alat Kerja',
    'Furnitur',
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
    _nameController.dispose();
    _priceController.dispose();
    _conditionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _selectedImage != null ||
        _nameController.text.trim().isNotEmpty ||
        _selectedCategory != null ||
        _purchaseDate != null ||
        _priceController.text.trim().isNotEmpty ||
        _conditionController.text.trim().isNotEmpty ||
        _secondHandPurchaseDate != null ||
        _notesController.text.trim().isNotEmpty;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Text(
                  'Pilih Sumber Foto',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF004AAD),
                    ),
                  ),
                  title: const Text(
                    'Ambil Foto dari Kamera',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Gunakan kamera perangkat untuk memotret barang',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF004AAD),
                    ),
                  ),
                  title: const Text(
                    'Pilih dari Galeri',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Pilih foto barang yang sudah tersimpan di HP',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 6),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade600,
                      ),
                    ),
                    title: Text(
                      'Hapus Foto Terpilih',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.red.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() => _selectedImage = null);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
                'Anda sedang mengisi barang baru. Data yang sudah diisi akan hilang jika Anda keluar.',
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
      ),
    );

    if (shouldLeave == true && mounted) {
      Navigator.pop(context);
    }
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

  Future<void> _pickDate({required bool isSecondHand}) async {
    if (!isSecondHand && _secondHandPurchaseDate != null) return;
    if (isSecondHand && _purchaseDate != null) return;

    final now = DateTime.now();
    final initial = isSecondHand
        ? (_secondHandPurchaseDate ?? now)
        : (_purchaseDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
        if (isSecondHand) {
          _secondHandPurchaseDate = picked;
          _purchaseDate = null;
        } else {
          _purchaseDate = picked;
          _secondHandPurchaseDate = null;
        }
      });
    }
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kategori barang terlebih dahulu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_purchaseDate == null && _secondHandPurchaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan pilih Tanggal Beli (baru) atau Tanggal Pembelian (Barang Second).',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String uploadedPhotoUrl = '';
      if (_selectedImage != null) {
        uploadedPhotoUrl =
            await _assetService.uploadAssetImage(_selectedImage!);
      }

      final rawPrice = _priceController.text.replaceAll('.', '').trim();
      final formattedPrice =
          rawPrice.isEmpty ? 'Rp 0' : 'Rp ${_formatRibuan(rawPrice)}';

      final bool isSecondHand = _secondHandPurchaseDate != null;
      final String activeDateFormatted = isSecondHand
          ? _formatTanggalIndo(_secondHandPurchaseDate!)
          : _formatTanggalIndo(_purchaseDate!);

      await _assetService.addAsset({
        'name': _nameController.text.trim(),
        'category': _selectedCategory!,
        'purchaseType': isSecondHand ? 'Second' : 'Baru',
        'purchaseDate': activeDateFormatted,
        'secondHandPurchaseDate': isSecondHand ? activeDateFormatted : '',
        'purchasePrice': formattedPrice,
        'condition': _conditionController.text.trim(),
        'notes': _notesController.text.trim(),
        'photoUrl': uploadedPhotoUrl,
        'lastMaintenance': '-',
        'lastMaintenanceCost': 'Rp 0',
        'maintenanceDetail': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barang berhasil ditambahkan.'),
            backgroundColor: Color(0xFF004AAD),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan barang: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String hint, {String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF004AAD), width: 1.4),
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
    const primaryBlue = Color(0xFF004AAD);
    final bool isRegularDisabled = _secondHandPurchaseDate != null;
    final bool isSecondHandDisabled = _purchaseDate != null;

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
            'Tambah Barang Baru',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. Kotak Unggah Foto Barang / Pratinjau Foto
                  InkWell(
                    onTap: _isSaving ? null : _showImageSourceSheet,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      height: _selectedImage != null ? 190 : null,
                      padding: _selectedImage != null
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFD6D6D6),
                          width: 1,
                        ),
                      ),
                      child: _selectedImage != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Ganti Foto',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 36,
                                  color: primaryBlue,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Unggah Foto Barang',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ambil Foto atau Pilih dari Galeri',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 1. Nama Barang
                  Text(
                    'Nama Barang',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 13.5),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Nama barang wajib diisi'
                        : null,
                    decoration: _inputDecoration('Masukkan nama barang...'),
                  ),
                  const SizedBox(height: 16),

                  // 2. Pilih Kategori
                  Text(
                    'Pilih Kategori',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade600,
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                    decoration: _inputDecoration('Pilih Kategori Barang...'),
                    items: _categories
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                  const SizedBox(height: 16),

                  // 3. Tanggal Beli (Baru) & Harga Beli
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tanggal Pembelian',
                              style: GoogleFonts.montserrat(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isRegularDisabled
                                    ? Colors.grey.shade400
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: isRegularDisabled
                                  ? null
                                  : () => _pickDate(isSecondHand: false),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isRegularDisabled
                                      ? const Color(0xFFE5E7EB)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFD6D6D6),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isRegularDisabled
                                            ? 'Barang second dipilih'
                                            : (_purchaseDate == null
                                                ? 'Tanggal pembelian...'
                                                : _formatTanggalIndo(
                                                    _purchaseDate!)),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isRegularDisabled ||
                                                  _purchaseDate == null
                                              ? Colors.grey.shade500
                                              : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_purchaseDate != null)
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _purchaseDate = null),
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 17,
                                            color: Colors.red.shade400,
                                          ),
                                        ),
                                      )
                                    else ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 17,
                                        color: isRegularDisabled
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ],
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
                              'Harga Beli',
                              style: GoogleFonts.montserrat(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _RibuanFormatter(),
                              ],
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                      ? 'Wajib diisi'
                                      : null,
                              decoration: _inputDecoration(
                                'Harga beli...',
                                prefixText: 'Rp ',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Kondisi Barang
                  Text(
                    'Kondisi Barang',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _conditionController,
                    style: const TextStyle(fontSize: 13.5),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Kondisi barang wajib diisi'
                        : null,
                    decoration: _inputDecoration('Masukkan kondisi barang...'),
                  ),
                  const SizedBox(height: 16),

                  // 5. Tanggal Pembelian (Barang Second)
                  Text(
                    'Tanggal Pembelian (Barang Second)',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isSecondHandDisabled
                          ? Colors.grey.shade400
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: isSecondHandDisabled
                        ? null
                        : () => _pickDate(isSecondHand: true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSecondHandDisabled
                            ? const Color(0xFFE5E7EB)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD6D6D6)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isSecondHandDisabled
                                  ? 'Tanggal pembelian (barang baru) sudah dipilih'
                                  : (_secondHandPurchaseDate == null
                                      ? 'Pilih tanggal pembelian BS...'
                                      : _formatTanggalIndo(
                                          _secondHandPurchaseDate!)),
                              style: TextStyle(
                                fontSize: 13,
                                color: isSecondHandDisabled ||
                                        _secondHandPurchaseDate == null
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (_secondHandPurchaseDate != null)
                            GestureDetector(
                              onTap: () => setState(
                                  () => _secondHandPurchaseDate = null),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: isSecondHandDisabled
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Catatan Tambahan (Opsional)
                  Text(
                    'Catatan Tambahan (Opsional)',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    minLines: 2,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: _inputDecoration(
                      'Masukkan Catatan Tambahan (opsional)...',
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 7. Tombol Tambah Barang
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAsset,
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
                              'Tambah Barang',
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