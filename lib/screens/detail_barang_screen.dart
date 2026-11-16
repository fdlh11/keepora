import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'catat_perawatan_screen.dart';

class DetailBarangScreen extends StatefulWidget {
  final Map<String, String> device;

  const DetailBarangScreen({super.key, required this.device});

  @override
  State<DetailBarangScreen> createState() => _DetailBarangScreenState();
}

class _DetailBarangScreenState extends State<DetailBarangScreen> {
  late TextEditingController _conditionDetailController;
  late TextEditingController _maintenanceDetailController;

  @override
  void initState() {
    super.initState();
    _conditionDetailController = TextEditingController(
      text:
          widget.device['conditionDetail'] ??
          'Kondisi baik, lecet sedikit, berjalan normal',
    );
    _maintenanceDetailController = TextEditingController(
      text:
          widget.device['maintenanceDetail'] ??
          'Ganti termal pasta, pembersihan debu kipas dan pengecekan mesin',
    );
  }

  @override
  void dispose() {
    _conditionDetailController.dispose();
    _maintenanceDetailController.dispose();
    super.dispose();
  }

  IconData _getDeviceIcon(String? category) {
    switch (category) {
      case 'Elektronik':
        return Icons.devices_other_outlined;
      case 'Kendaraan':
        return Icons.two_wheeler_outlined;
      case 'Peralatan Hobi':
        return Icons.sports_tennis_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildHeaderImage() {
    final String imagePath = widget.device['image'] ?? '';

    if (imagePath.isNotEmpty) {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return Image.network(
          imagePath,
          width: double.infinity,
          height: 210,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackHeader(),
        );
      }

      final File localFile = File(imagePath);
      if (localFile.existsSync()) {
        return Image.file(
          localFile,
          width: double.infinity,
          height: 210,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackHeader(),
        );
      }
    }

    return _buildFallbackHeader();
  }

  Widget _buildFallbackHeader() {
    return Container(
      width: double.infinity,
      height: 210,
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          _getDeviceIcon(widget.device['category']),
          size: 64,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
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
                  'Hapus Barang',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Apakah Anda ingin menghapus barang ini dari daftar?\nSemua riwayat perawatan juga akan terhapus.',
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
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context, {'action': 'delete'});
                        },
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
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
                            fontSize: 14,
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
  }

  void _saveChanges() {
    final updatedDevice = Map<String, String>.from(widget.device);
    updatedDevice['conditionDetail'] = _conditionDetailController.text.trim();
    updatedDevice['maintenanceDetail'] = _maintenanceDetailController.text
        .trim();

    Navigator.pop(context, {'action': 'update', 'data': updatedDevice});
  }

  Widget _buildInfoBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0056C6);

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
          'Detail Barang',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black87),
            tooltip: 'Hapus Barang',
            onPressed: _showDeleteDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar Barang
              _buildHeaderImage(),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama Barang + Kategori
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.device['name'] ?? '-',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.device['category'] ?? '-',
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoBox(
                            label: 'Tanggal Pembelian',
                            value:
                                widget.device['purchaseDate'] ??
                                '15 Agustus 2026',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoBox(
                            label: 'Harga Pembelian',
                            value:
                                widget.device['purchasePrice'] ??
                                'Rp 4.450.000',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Kondisi Perangkat
                    Text(
                      'Kondisi Perangkat',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _conditionDetailController,
                        maxLines: 2,
                        minLines: 1,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Masukkan catatan kondisi perangkat...',
                          hintStyle: TextStyle(
                            fontSize: 13,
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
                    const SizedBox(height: 18),

                    // Catatan Perawatan Terakhir
                    Text(
                      'Catatan Perawatan Terakhir',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoBox(
                            label: 'Tanggal Perawatan Terakhir',
                            value: widget.device['lastMaintenance'] ?? '-',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoBox(
                            label: 'Biaya Perawatan Terakhir',
                            value:
                                widget.device['lastMaintenanceCost'] ??
                                'Rp 350.000',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Rincian Perawatan
                    Text(
                      'Rincian Perawatan',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _maintenanceDetailController,
                        maxLines: 3,
                        minLines: 2,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Masukkan rincian perawatan...',
                          hintStyle: TextStyle(
                            fontSize: 13,
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
                    const SizedBox(height: 8),

                    // Tautan Catat Perawatan Baru
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () async {
                          final bool? isUpdated =
                              await showCatatPerawatanDialog(
                                context: context,
                                assetId: widget.device['id'] ?? '',
                                assetName: widget.device['name'] ?? '',
                              );

                          if (isUpdated == true && mounted) {
                            setState(() {});
                          }
                        },
                        child: Text(
                          'Catat Perawatan Baru',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tombol Simpan Perubahan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
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
  }
}
