import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// TEMASAN ERP — Bayi & Şube Yöneticisi Paneli (Merchant / Branch Manager Panel)
/// Özel olarak Şube Müdürlerinin günlük mağaza siparişlerini, şube stoklarını ve kuryelerini yönettiği panel.
class MerchantPanelPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const MerchantPanelPage({super.key, this.user, this.onBackToStore});

  @override
  State<MerchantPanelPage> createState() => _MerchantPanelPageState();
}

class _MerchantPanelPageState extends State<MerchantPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // ── ŞUBE ÖZEL VERİLERİ ──
  List<Map<String, dynamic>> _branchProducts = [];
  List<Map<String, dynamic>> _branchOrders = [];
  String _searchProductQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBranchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBranchData() async {
    setState(() => _isLoading = true);
    try {
      final products = await ApiService.fetchProducts();
      if (mounted && products.isNotEmpty) {
        setState(() {
          _branchProducts = List<Map<String, dynamic>>.from(products);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String branchName = widget.user?['branch_name'] ?? 'Lalapaşa AVM (Yakutiye) Şubesi';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('BAYİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                const Text('TEMASAN Bayi Paneli', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ],
            ),
            Text(branchName, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)), onPressed: _loadBranchData),
          if (widget.onBackToStore != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                icon: const Icon(Icons.storefront, size: 16),
                label: const Text('Mağazaya Dön', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: widget.onBackToStore,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFDC2626),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFFDC2626),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag_outlined, size: 20), text: 'Şube Siparişleri'),
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 20), text: 'Stok Yönetimi'),
            Tab(icon: Icon(Icons.two_wheeler_outlined, size: 20), text: 'Kurye Durumu'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBranchOrdersTab(),
                _buildBranchStockTab(),
                _buildBranchCouriersTab(),
              ],
            ),
    );
  }

  // 1. ŞUBE SİPARİŞLERİ TABI
  Widget _buildBranchOrdersTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('🛒 Mağaza Siparişleri', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              Chip(label: Text('CANLI AKIŞ'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Şubenize Ait Aktif Bekleyen Sipariş Bulunmuyor', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Yeni gelen siparişler burada anlık sesli ve görsel uyarıyla listelenecektir.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. ŞUBE STOK YÖNETİMİ TABI
  Widget _buildBranchStockTab() {
    final filteredProducts = _branchProducts.where((p) {
      final q = _searchProductQuery.toLowerCase();
      final name = (p['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📦 Şube Stok Güncelleme (${_branchProducts.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Şube stoklarında ürün ara...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchProductQuery = val),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final p = filteredProducts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      p['image'] ?? 'https://picsum.photos/seed/product/100/100',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Şube Fiyatı: ₺${p['base_price'] ?? p['price'] ?? 0}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Chip(label: Text('Stokta (48 Adet)'), backgroundColor: Color(0xFFDCFCE7), labelStyle: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.grey), onPressed: () {}),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 3. KURYE DURUMU TABI
  Widget _buildBranchCouriersTab() {
    final couriers = [
      {'name': 'Ahmet Yılmaz', 'phone': '0532 111 22 33', 'plate': '25 AB 123', 'status': 'Online - Boşta', 'battery': '%88'},
      {'name': 'Mehmet Demir', 'phone': '0533 444 55 66', 'plate': '25 EV 456', 'status': 'Online - Teslimatta', 'battery': '%64'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: couriers.length,
      itemBuilder: (context, index) {
        final c = couriers[index];
        final bool isBusy = c['status']!.contains('Teslimatta');

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isBusy ? const Color(0xFFFEF2F2) : const Color(0xFFDCFCE7),
              child: Icon(Icons.two_wheeler, color: isBusy ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
            ),
            title: Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Tel: ${c['phone']} • Plaka: ${c['plate']} • Şarj: ${c['battery']}'),
            trailing: Chip(
              label: Text(c['status']!),
              backgroundColor: isBusy ? const Color(0xFFFEF2F2) : const Color(0xFFDCFCE7),
              labelStyle: TextStyle(color: isBusy ? const Color(0xFFDC2626) : const Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
