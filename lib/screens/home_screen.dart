import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/asset_service.dart';
import 'detail_barang_screen.dart';
import 'tambah_barang_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AssetService _assetService = AssetService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  // list kategori
  final List<String> _categories = [
    'Semua',
    'Elektronik',
    'Kendaraan',
    'Peralatan Rumah Tangga',
    'Perkakas & Alat Kerja',
    'Furnitur',
    'Lainnya',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary =
        isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final textMuted = isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    final accentBlue = isDark ? const Color(0xFF60A5FA) : primaryBlue;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        // Judul aplikasi
        title: Text(
          'Keepora',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase().trim()),
                  style: TextStyle(fontSize: 13.5, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cari nama barang...',
                    hintStyle: TextStyle(fontSize: 13.5, color: textMuted),
                    // icon search/pencarian
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: textSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                      borderSide: const BorderSide(
                        color: primaryBlue,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category;

                    return ChoiceChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.white : textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: primaryBlue,
                      backgroundColor: surfaceColor,
                      side: BorderSide(
                        color: isSelected ? primaryBlue : borderColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _assetService.getAssetsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Terjadi kesalahan saat memuat data: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      );
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final name =
                          (data['name'] ?? '').toString().toLowerCase();
                      final category = (data['category'] ?? '').toString();

                      final matchesSearch =
                          _searchQuery.isEmpty || name.contains(_searchQuery);
                      final matchesCategory = _selectedCategory == 'Semua' ||
                          category == _selectedCategory;

                      return matchesSearch && matchesCategory;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 52,
                                color: textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                allDocs.isEmpty
                                    ? 'Belum ada barang tersimpan'
                                    : 'Barang tidak ditemukan',
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                allDocs.isEmpty
                                    ? 'Belum ada barang tersimpan. Tambahkan barang pertama Anda lewat tombol di pojok kanan bawah.'
                                    : 'Coba ubah kata kunci pencarian atau filter kategori.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 155),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>? ?? {};

                        final name = (data['name'] ?? 'Tanpa Nama').toString();
                        final category =
                            (data['category'] ?? 'Umum').toString();
                        final price =
                            (data['purchasePrice'] ?? 'Rp 0').toString();
                        final condition = (data['condition'] ?? '-').toString();
                        final lastMaint =
                            (data['lastMaintenance'] ?? '-').toString();

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DetailBarangScreen(assetId: doc.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E3A5F)
                                        : const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.devices_other_rounded,
                                    color: accentBlue,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF172554)
                                                  : const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF1D4ED8)
                                                    : const Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            child: Text(
                                              category,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: accentBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '$price • $condition',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Perawatan terakhir: $lastMaint',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textMuted,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          Positioned(
            right: 20,
            bottom: 98,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TambahBarangScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                'Barang',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}