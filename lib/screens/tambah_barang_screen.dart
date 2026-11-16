import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/asset_service.dart';

class TambahBarangScreen extends StatefulWidget {
  const TambahBarangScreen({super.key});

  @override
  State<TambahBarangScreen> createState() => _TambahBarangScreenState();
}

class _TambahBarangScreenState extends State<TambahBarangScreen> {
  final AssetService _assetService = AssetService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _purchaseDateController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _secondHandDateController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<String> _categories = [
    'Elektronik',
    'Kendaraan',
    'Peralatan Hobi',
    'Lainnya',
  ];

  String? _selectedCategory;
  File? _selectedImage;
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

  bool get _hasNewDate => _purchaseDateController.text.trim().isNotEmpty;
  bool get _hasSecondHandDate =>
      _secondHandDateController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _purchaseDateController.dispose();
    _purchasePriceController.dispose();
    _conditionController.dispose();
    _secondHandDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatIndonesianDate(DateTime date) {
    final String monthName = _indonesianMonths[date.month - 1];
    return '${date.day} $monthName ${date.year}';
  }

  String _formatRupiah(String rawInput) {
    final digits = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '-';
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

  Future<void> _pickDate({
    required TextEditingController targetController,
    required TextEditingController otherController,
  }) async {
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
        targetController.text = _formatIndonesianDate(picked);
        otherController.clear();
      });
    }
  }

  void _clearDate(TextEditingController controller) {
    setState(() {
      controller.clear();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengambil gambar. Silakan coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                Text(
                  'Pilih Sumber Foto',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF0056C6),
                  ),
                  title: const Text('Ambil Foto dari Kamera'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF0056C6),
                  ),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    final String name = _nameController.text.trim();
    final String category = _selectedCategory ?? '';
    final String newPurchaseDate = _purchaseDateController.text.trim();
    final String secondHandDate = _secondHandDateController.text.trim();
    final String rawPrice = _purchasePriceController.text.trim();
    final String conditionText = _conditionController.text.trim();
    final String notes = _notesController.text.trim();

    if (name.isEmpty) {
      _showError('Nama barang wajib diisi.');
      return;
    }
    if (category.isEmpty) {
      _showError('Silakan pilih kategori barang terlebih dahulu.');
      return;
    }
    if (newPurchaseDate.isEmpty && secondHandDate.isEmpty) {
      _showError(
        'Silakan pilih salah satu: Tanggal Beli (Baru) atau Tanggal Pembelian (Barang Second).',
      );
      return;
    }
    if (conditionText.isEmpty) {
      _showError('Kondisi perangkat wajib diisi.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bool isDamaged =
          conditionText.toLowerCase().contains('cacat') ||
          conditionText.toLowerCase().contains('rusak');

      // Salin foto dari cache ke folder permanen aplikasi agar tidak terhapus sistem
      String savedImagePath = '';
      if (_selectedImage != null && await _selectedImage!.exists()) {
        final String fileName =
            'asset_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Directory appDir = Directory.systemTemp.parent;
        final Directory permanentDir = Directory(
          '${appDir.path}/app_flutter/assets_images',
        );
        if (!await permanentDir.exists()) {
          await permanentDir.create(recursive: true);
        }
        final File copiedFile = await _selectedImage!.copy(
          '${permanentDir.path}/$fileName',
        );
        savedImagePath = copiedFile.path;
      }

      final bool isSecondHand = secondHandDate.isNotEmpty;
      final String activePurchaseDate = isSecondHand
          ? secondHandDate
          : newPurchaseDate;

      await _assetService.addAsset({
        'name': name,
        'category': category,
        'status': isDamaged ? 'Kondisi Cacat' : 'Kondisi Baik',
        'purchaseType': isSecondHand ? 'Second' : 'Baru',
        'purchaseDate': activePurchaseDate,
        'secondHandDate': isSecondHand ? secondHandDate : '-',
        'purchasePrice': _formatRupiah(rawPrice),
        'conditionDetail': conditionText,
        'notes': notes,
        'lastMaintenance': 'Belum pernah',
        'lastMaintenanceCost': 'Rp 0',
        'maintenanceDetail': notes.isNotEmpty
            ? notes
            : 'Belum ada catatan perawatan.',
        'image': savedImagePath,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name berhasil ditambahkan!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal menyimpan barang: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLabel(String text, {bool isDisabled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: isDisabled ? Colors.grey.shade400 : Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0056C6);

    // Status kunci kolom tanggal (mutually exclusive)
    final bool isNewDateDisabled = _hasSecondHandDate;
    final bool isSecondHandDisabled = _hasNewDate;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kotak Unggah Foto Barang
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300, width: 1.2),
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
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ganti Foto',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              color: primaryBlue,
                              size: 38,
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
                            const Text(
                              'Ambil Foto atau Pilih dari Galeri',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Nama Barang
              _buildLabel('Nama Barang'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan nama barang...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pilih Kategori
              _buildLabel('Pilih Kategori'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey,
                    ),
                    hint: const Text(
                      'Pilih Kategori Barang...',
                      style: TextStyle(color: Colors.grey, fontSize: 13.5),
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tanggal Beli (Barang Baru) & Harga Beli
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(
                          'Tanggal Beli',
                          isDisabled: isNewDateDisabled,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isNewDateDisabled
                                ? Colors.grey.shade200
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _purchaseDateController,
                            readOnly: true,
                            enabled: !isNewDateDisabled,
                            onTap: isNewDateDisabled
                                ? null
                                : () => _pickDate(
                                    targetController: _purchaseDateController,
                                    otherController: _secondHandDateController,
                                  ),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: isNewDateDisabled
                                  ? 'Terisi barang second'
                                  : 'Tanggal pembelian...',
                              hintStyle: TextStyle(
                                color: isNewDateDisabled
                                    ? Colors.grey.shade400
                                    : Colors.grey,
                                fontSize: 12.5,
                              ),
                              suffixIcon: _hasNewDate
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Hapus tanggal beli',
                                      onPressed: () =>
                                          _clearDate(_purchaseDateController),
                                    )
                                  : Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: isNewDateDisabled
                                          ? Colors.grey.shade400
                                          : Colors.grey,
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
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
                        _buildLabel('Harga Beli'),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _purchasePriceController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Harga beli...',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 12.5,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Kondisi Perangkat
              _buildLabel('Kondisi Perangkat'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _conditionController,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan kondisi perangkat...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tanggal Pembelian (Barang Second)
              _buildLabel(
                'Tanggal Pembelian (Barang Second)',
                isDisabled: isSecondHandDisabled,
              ),
              Container(
                decoration: BoxDecoration(
                  color: isSecondHandDisabled
                      ? Colors.grey.shade200
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _secondHandDateController,
                  readOnly: true,
                  enabled: !isSecondHandDisabled,
                  onTap: isSecondHandDisabled
                      ? null
                      : () => _pickDate(
                          targetController: _secondHandDateController,
                          otherController: _purchaseDateController,
                        ),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: isSecondHandDisabled
                        ? 'Terisi tanggal beli baru'
                        : 'Pilih tanggal pembelian BS...',
                    hintStyle: TextStyle(
                      color: isSecondHandDisabled
                          ? Colors.grey.shade400
                          : Colors.grey,
                      fontSize: 13.5,
                    ),
                    suffixIcon: _hasSecondHandDate
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Hapus tanggal pembelian barang second',
                            onPressed: () =>
                                _clearDate(_secondHandDateController),
                          )
                        : Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: isSecondHandDisabled
                                ? Colors.grey.shade400
                                : Colors.grey,
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Catatan Tambahan (Opsional)
              _buildLabel('Catatan Tambahan (Opsional)'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 3,
                  minLines: 2,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan Catatan Tambahan (opsional)...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),

              // Tombol Tambah Barang
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
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
    );
  }
}
