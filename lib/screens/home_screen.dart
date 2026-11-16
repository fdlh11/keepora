import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';
import 'akun_screen.dart';
import 'detail_barang_screen.dart';
import 'tambah_barang_screen.dart';
import 'jadwal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategoryIndex = 0;
  int _currentNavIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final AssetService _assetService = AssetService();

  final List<String> _categories = [
    'Semua',
    'Elektronik',
    'Kendaraan',
    'Peralatan Hobi',
    'Lainnya',
  ];

  @override
  void dispose() {
    _searchController.dispose();
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

  Widget _buildAssetThumbnail(String? imagePath, String category) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imagePath,
            width: 75,
            height: 75,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackThumbnail(category),
          ),
        );
      }

      final File localFile = File(imagePath);
      if (localFile.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            localFile,
            width: 75,
            height: 75,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackThumbnail(category),
          ),
        );
      }
    }

    return _buildFallbackThumbnail(category);
  }

  Widget _buildFallbackThumbnail(String category) {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getDeviceIcon(category),
        color: Colors.grey.shade600,
        size: 34,
      ),
    );
  }

  Future<void> _openDetailBarang(
    String docId,
    Map<String, dynamic> rawData,
  ) async {
    final Map<String, String> deviceMap = {
      'id': docId,
      'name': (rawData['name'] ?? '').toString(),
      'category': (rawData['category'] ?? 'Lainnya').toString(),
      'status': (rawData['status'] ?? 'Kondisi Baik').toString(),
      'purchaseDate': (rawData['purchaseDate'] ?? '-').toString(),
      'purchasePrice': (rawData['purchasePrice'] ?? '-').toString(),
      'conditionDetail': (rawData['conditionDetail'] ?? '').toString(),
      'lastMaintenance': (rawData['lastMaintenance'] ?? '-').toString(),
      'lastMaintenanceCost': (rawData['lastMaintenanceCost'] ?? '-').toString(),
      'maintenanceDetail': (rawData['maintenanceDetail'] ?? '').toString(),
      'image': (rawData['image'] ?? '').toString(),
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailBarangScreen(device: deviceMap),
      ),
    );

    if (!mounted || result == null) return;

    if (result['action'] == 'delete') {
      await _assetService.deleteAsset(docId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${deviceMap['name']} berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result['action'] == 'update' && result['data'] != null) {
      final updated = Map<String, String>.from(result['data']);
      await _assetService.updateAsset(docId, {
        'conditionDetail': updated['conditionDetail'] ?? '',
        'maintenanceDetail': updated['maintenanceDetail'] ?? '',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perubahan detail barang berhasil disimpan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildBerandaTab(Color primaryBlue) {
    final String query = _searchQuery.trim().toLowerCase();

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: _assetService.getAssetsStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final String category = (data?['category'] ?? '').toString();
            final String name = (data?['name'] ?? '').toString();

            final bool matchesCategory =
                _selectedCategoryIndex == 0 ||
                category == _categories[_selectedCategoryIndex];
            final bool matchesSearch =
                query.isEmpty || name.toLowerCase().contains(query);
            return matchesCategory && matchesSearch;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Judul Keepora
                Text(
                  'KEEPORA',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mengelola Barang Pribadi Anda Dalam Satu Aplikasi!',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 18),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      hintText: 'Cari nama barang...',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Kartu Perawatan Mendatang
                Material(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        _currentNavIndex = 1;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Perawatan Mendatang',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(
                                Icons.north_east,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_available_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Belum ada jadwal perawatan',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Tambahkan barang atau atur jadwal perawatan Anda.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Judul dan total barang
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Daftar Barang ',
                            style: GoogleFonts.montserrat(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '${filteredDocs.length} barang',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TambahBarangScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Tambah Barang',
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter kategori
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_categories.length, (index) {
                      final isSelected = _selectedCategoryIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(_categories[index]),
                          selected: isSelected,
                          selectedColor: primaryBlue,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryIndex = index;
                            });
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // List Barang
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (docs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 36,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 42,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Belum ada barang',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Data barang Anda masih kosong. Ketuk "Tambah Barang" untuk mulai mencatat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (filteredDocs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 36,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Barang tidak ditemukan',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tidak ada barang yang cocok dengan pencarian Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>?;
                      final String status = (data?['status'] ?? 'Kondisi Baik')
                          .toString();
                      final String category = (data?['category'] ?? 'Lainnya')
                          .toString();
                      final String name = (data?['name'] ?? '-').toString();
                      final String lastMaintenance =
                          (data?['lastMaintenance'] ?? '-').toString();
                      final String imagePath = (data?['image'] ?? '')
                          .toString();

                      final bool isDamaged = status == 'Kondisi Cacat';
                      final Color badgeBgColor = isDamaged
                          ? Colors.red.shade50
                          : Colors.green.shade50;
                      final Color badgeTextColor = isDamaged
                          ? Colors.red
                          : Colors.green;

                      return Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openDetailBarang(doc.id, data ?? {}),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                _buildAssetThumbnail(imagePath, category),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryBlue.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              category,
                                              style: TextStyle(
                                                color: primaryBlue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeBgColor,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: badgeTextColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: badgeTextColor,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        name,
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Perawatan Terakhir : $lastMaintenance',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color primaryBlue,
  }) {
    final bool isSelected = _currentNavIndex == index;
    final Color itemColor = isSelected ? primaryBlue : Colors.grey.shade600;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentNavIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryBlue.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: itemColor, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0056C6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildBerandaTab(primaryBlue),
          const JadwalScreen(),
          const Center(child: Text('Halaman Riwayat')),
          const AkunScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFFD6DCFA), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: Row(
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  label: 'Beranda',
                  primaryBlue: primaryBlue,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.calendar_today_outlined,
                  label: 'Jadwal',
                  primaryBlue: primaryBlue,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.access_time_outlined,
                  label: 'Riwayat',
                  primaryBlue: primaryBlue,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline,
                  label: 'Akun',
                  primaryBlue: primaryBlue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
