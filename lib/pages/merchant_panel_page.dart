import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Veri modelleri
// ─────────────────────────────────────────────
class MerchantOrder {
  final String orderNo;
  final String customer;
  final String phone;
  final String address;
  final List<Map<String, dynamic>> items;
  final double total;
  final String paymentType;
  final DateTime createdAt;
  String status; // 'new' | 'preparing' | 'ready' | 'on_way' | 'delivered'
  String? assignedCourier;

  MerchantOrder({
    required this.orderNo,
    required this.customer,
    required this.phone,
    required this.address,
    required this.items,
    required this.total,
    required this.paymentType,
    required this.createdAt,
    this.status = 'new',
    this.assignedCourier,
  });
}

class StockItem {
  final int id;
  final String name;
  final String category;
  final String unit;
  final double price;
  int stock;
  int minStock;

  StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    required this.stock,
    this.minStock = 5,
  });

  String get stockStatus {
    if (stock == 0) return 'Tükendi';
    if (stock <= minStock) return 'Kritik';
    return 'Stokta';
  }

  Color get statusColor {
    if (stock == 0) return const Color(0xFFDC2626);
    if (stock <= minStock) return const Color(0xFFF59E0B);
    return const Color(0xFF16A34A);
  }
}

// ─────────────────────────────────────────────
//  Ana Widget
// ─────────────────────────────────────────────
class MerchantPanelPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const MerchantPanelPage({super.key, this.user, this.onBackToStore});

  @override
  State<MerchantPanelPage> createState() => _MerchantPanelPageState();
}

class _MerchantPanelPageState extends State<MerchantPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _stockSearch = '';

  final List<MerchantOrder> _orders = [
    MerchantOrder(
      orderNo: '#TEM-84923',
      customer: 'Ali Kaya',
      phone: '+90 532 111 2244',
      address: 'Cumhuriyet Mah. Atatürk Cad. No:8 Yakutiye/Erzurum',
      items: [
        {'name': 'Dana Kasap Sucuk 500g', 'qty': 2, 'price': 499.00},
        {'name': 'Kaşar Peyniri 600g', 'qty': 1, 'price': 299.00},
      ],
      total: 1297.00,
      paymentType: 'online',
      createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
      status: 'new',
    ),
    MerchantOrder(
      orderNo: '#TEM-84922',
      customer: 'Fatma Kaya',
      phone: '+90 505 300 4455',
      address: 'Dadaşkent Mah. Köprübaşı Sok. No:8 Palandöken/Erzurum',
      items: [
        {'name': 'Köy Tereyağı 1kg', 'qty': 1, 'price': 320.00},
        {'name': 'Civil Peyniri 500g', 'qty': 1, 'price': 240.00},
      ],
      total: 560.00,
      paymentType: 'softpos',
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      status: 'preparing',
      assignedCourier: 'Ahmet Yılmaz',
    ),
    MerchantOrder(
      orderNo: '#TEM-84920',
      customer: 'Zeynep Yılmaz',
      phone: '+90 532 100 2233',
      address: 'Gezköy OSB Mah. 3. Sanayi Cad. No:5 Aziziye/Erzurum',
      items: [
        {'name': 'Dana Kasap Sucuk 500g', 'qty': 2, 'price': 499.00},
        {'name': 'Kaşar Peyniri 600g', 'qty': 1, 'price': 299.00},
      ],
      total: 499.00,
      paymentType: 'softpos',
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
      status: 'on_way',
      assignedCourier: 'Mehmet Demir',
    ),
    MerchantOrder(
      orderNo: '#TEM-84919',
      customer: 'Hasan Şahin',
      phone: '+90 555 444 3322',
      address: 'Yenişehir Mah. 15 Temmuz Bulv. No:22 Erzurum',
      items: [
        {'name': 'Hakiki Bal Petek 500g', 'qty': 2, 'price': 350.00},
      ],
      total: 700.00,
      paymentType: 'online',
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
      status: 'delivered',
      assignedCourier: 'Ahmet Yılmaz',
    ),
  ];

  final List<StockItem> _stocks = [
    StockItem(id: 1, name: 'Dana Kasap Parmak Sucuk 500g', category: 'Kasap', unit: 'Paket', price: 499.00, stock: 25, minStock: 5),
    StockItem(id: 2, name: 'Sıkma File Portakal 2kg', category: 'Manav', unit: 'File', price: 49.90, stock: 3, minStock: 10),
    StockItem(id: 3, name: 'Torku Tam Yağlı Kaşar 600g', category: 'Sarkuteri', unit: 'Adet', price: 299.00, stock: 14, minStock: 5),
    StockItem(id: 4, name: 'Erzurum Hakiki Bal Petek 500g', category: 'Sarkuteri', unit: 'Kavanoz', price: 350.00, stock: 0, minStock: 3),
    StockItem(id: 5, name: 'Köy Tereyağı 1kg', category: 'Sarkuteri', unit: 'Kg', price: 320.00, stock: 8, minStock: 5),
    StockItem(id: 6, name: 'Trabzon Ekşi Mayalı Ekmek 800g', category: 'Fırın', unit: 'Adet', price: 35.00, stock: 42, minStock: 20),
    StockItem(id: 7, name: 'Çaykur Rize Turist Çayı 1000g', category: 'İçecek', unit: 'Kutu', price: 165.00, stock: 2, minStock: 10),
    StockItem(id: 8, name: 'Civil Peyniri 500g', category: 'Sarkuteri', unit: 'Adet', price: 240.00, stock: 17, minStock: 5),
    StockItem(id: 9, name: 'Yerli Kuru Fasulye 1kg', category: 'Bakliyat', unit: 'Torba', price: 120.00, stock: 30, minStock: 10),
    StockItem(id: 10, name: 'Amasya Elması 1kg', category: 'Manav', unit: 'Kg', price: 34.90, stock: 0, minStock: 15),
  ];

  final List<String> _couriers = [
    'Ahmet Yılmaz',
    'Mehmet Demir',
    'Kemal Arslan',
    'Serkan Öztürk',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── İstatistikler ───────────────────────────────────────────────────────
  int get _newOrders      => _orders.where((o) => o.status == 'new').length;
  int get _criticalStocks => _stocks.where((s) => s.stock <= s.minStock).length;

  // ── Renk / Etiket yardımcıları ───────────────────────────────────────────
  Color _orderStatusColor(String s) {
    switch (s) {
      case 'new':       return const Color(0xFFDC2626);
      case 'preparing': return const Color(0xFFF59E0B);
      case 'ready':     return const Color(0xFF8B5CF6);
      case 'on_way':    return const Color(0xFF2563EB);
      case 'delivered': return const Color(0xFF16A34A);
      default:          return Colors.grey;
    }
  }

  String _orderStatusLabel(String s) {
    switch (s) {
      case 'new':       return 'Yeni Sipariş';
      case 'preparing': return 'Hazırlanıyor';
      case 'ready':     return 'Kuryeye Hazır';
      case 'on_way':    return 'Yolda';
      case 'delivered': return 'Teslim Edildi';
      default:          return s;
    }
  }

  String _nextStatusLabel(String s) {
    switch (s) {
      case 'new':       return 'Hazırlamaya Başla';
      case 'preparing': return 'Hazır — Kurye Bekliyor';
      case 'ready':     return 'Kuryeye Teslim Et';
      default:          return '';
    }
  }

  String _nextStatus(String s) {
    switch (s) {
      case 'new':       return 'preparing';
      case 'preparing': return 'ready';
      case 'ready':     return 'on_way';
      default:          return s;
    }
  }

  String _elapsedTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    return '${diff.inHours} sa ${diff.inMinutes % 60} dk önce';
  }

  // ── Kurye atama dialog ──────────────────────────────────────────────────
  void _showAssignCourier(MerchantOrder order) {
    String? selected = order.assignedCourier;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kurye Ata', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(order.orderNo, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _couriers.map((c) => RadioListTile<String>(
              title: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              value: c,
              groupValue: selected,
              activeColor: const Color(0xFFDC2626),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setLocal(() => selected = v),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              onPressed: () {
                setState(() {
                  order.assignedCourier = selected;
                  if (order.status == 'new' || order.status == 'preparing') {
                    order.status = 'ready';
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${order.orderNo} → $selected kuryesine atandı.'),
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sipariş detay bottom sheet ──────────────────────────────────────────
  void _showOrderDetail(MerchantOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(width: 44, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(100)))),
                const SizedBox(height: 20),

                // Başlık
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.orderNo,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                        Text(_elapsedTime(order.createdAt),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                    const Spacer(),
                    _StatusPill(label: _orderStatusLabel(order.status), color: _orderStatusColor(order.status)),
                  ],
                ),
                const Divider(height: 28),

                // Müşteri Bilgileri
                _DetailRow(icon: Icons.person_outline, label: 'Müşteri', value: order.customer),
                _DetailRow(icon: Icons.phone_outlined, label: 'Telefon', value: order.phone),
                _DetailRow(icon: Icons.location_on_outlined, label: 'Adres', value: order.address),
                _DetailRow(
                  icon: Icons.payment_outlined,
                  label: 'Ödeme',
                  value: order.paymentType == 'online' ? 'Online Ödendi' : 'Kapıda SoftPOS',
                  valueColor: order.paymentType == 'online' ? const Color(0xFF16A34A) : const Color(0xFF7C3AED),
                ),
                if (order.assignedCourier != null)
                  _DetailRow(icon: Icons.delivery_dining, label: 'Kurye', value: order.assignedCourier!, valueColor: const Color(0xFF2563EB)),

                const SizedBox(height: 16),
                const Text('Sipariş Kalemleri', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 8),

                // Ürün Listesi
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text('${item['qty']}x', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFFDC2626)))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                            Text('₺${(item['price'] * item['qty']).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0F172A))),
                          ],
                        ),
                      )),
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Text('TOPLAM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                          const Spacer(),
                          Text('₺${order.total.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Aksiyon butonları
                if (order.status != 'delivered' && order.status != 'on_way') ...[
                  // Kurye Ata
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delivery_dining, size: 18),
                      label: Text(
                        order.assignedCourier != null ? 'Kurye Değiştir (${order.assignedCourier})' : 'Kurye Ata',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showAssignCourier(order);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Durum güncelle
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
                      label: Text(
                        _nextStatusLabel(order.status),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orderStatusColor(_nextStatus(order.status)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      onPressed: () {
                        setState(() => order.status = _nextStatus(order.status));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${order.orderNo} durumu güncellendi: ${_orderStatusLabel(order.status)}'),
                            backgroundColor: _orderStatusColor(order.status),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF16A34A)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 8),
                        Text('Sipariş Tamamlandı', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(8)),
              child: const Text('TEMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            const Text('Bayi Paneli', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.home_outlined, color: Color(0xFF0F172A)), onPressed: widget.onBackToStore),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFDC2626),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFDC2626),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.receipt_long_outlined, size: 18),
                text: 'Siparişler${_newOrders > 0 ? "  🔴$_newOrders" : ""}'),
            Tab(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18),
                    if (_criticalStocks > 0)
                      Positioned(
                        top: -4, right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                          child: Text('$_criticalStocks', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                ),
                text: 'Stok Yönetimi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersTab(),
          _buildStockTab(),
        ],
      ),
    );
  }

  // ─── SİPARİŞLER SEKMESİ ────────────────────────────────────────────────
  Widget _buildOrdersTab() {
    // Siparişleri: yeni → hazırlanıyor → hazır → yolda → teslim sırasına göre sırala
    final statusOrder = ['new', 'preparing', 'ready', 'on_way', 'delivered'];
    final sorted = [..._orders]..sort((a, b) =>
        statusOrder.indexOf(a.status).compareTo(statusOrder.indexOf(b.status)));

    return Column(
      children: [
        // Özet şeridi
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatBox(label: 'Yeni', value: '${_orders.where((o) => o.status == "new").length}', color: const Color(0xFFDC2626), icon: Icons.fiber_new),
              _StatBox(label: 'Hazırlanıyor', value: '${_orders.where((o) => o.status == "preparing").length}', color: const Color(0xFFF59E0B), icon: Icons.restaurant_outlined),
              _StatBox(label: 'Yolda', value: '${_orders.where((o) => o.status == "on_way").length}', color: const Color(0xFF2563EB), icon: Icons.delivery_dining),
              _StatBox(label: 'Teslim', value: '${_orders.where((o) => o.status == "delivered").length}', color: const Color(0xFF16A34A), icon: Icons.check_circle_outline),
            ],
          ),
        ),

        Expanded(
          child: sorted.isEmpty
              ? const Center(child: Text('Sipariş yok.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _OrderCard(
                    order: sorted[i],
                    statusLabel: _orderStatusLabel(sorted[i].status),
                    statusColor: _orderStatusColor(sorted[i].status),
                    elapsed: _elapsedTime(sorted[i].createdAt),
                    onTap: () => _showOrderDetail(sorted[i]),
                    onAssignCourier: () => _showAssignCourier(sorted[i]),
                    onStatusChange: sorted[i].status != 'delivered' && sorted[i].status != 'on_way'
                        ? () => setState(() => sorted[i].status = _nextStatus(sorted[i].status))
                        : null,
                    nextStatusLabel: _nextStatusLabel(sorted[i].status),
                    nextStatusColor: _orderStatusColor(_nextStatus(sorted[i].status)),
                  ),
                ),
        ),
      ],
    );
  }

  // ─── STOK SEKMESİ ─────────────────────────────────────────────────────
  Widget _buildStockTab() {
    final filtered = _stocks.where((s) =>
        s.name.toLowerCase().contains(_stockSearch.toLowerCase()) ||
        s.category.toLowerCase().contains(_stockSearch.toLowerCase())).toList();

    final critical = filtered.where((s) => s.stock <= s.minStock).length;

    return Column(
      children: [
        // Arama + özet
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _stockSearch = v),
                decoration: InputDecoration(
                  hintText: 'Ürün veya kategori ara...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
                ),
              ),
              if (critical > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Text('$critical üründe kritik stok seviyesi!',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _StockCard(
              item: filtered[i],
              onDecrement: () {
                if (filtered[i].stock > 0) setState(() => filtered[i].stock--);
              },
              onIncrement: () => setState(() => filtered[i].stock++),
              onManualEdit: () => _showStockEditDialog(filtered[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Manuel stok düzenleme dialog ─────────────────────────────────────
  void _showStockEditDialog(StockItem item) {
    final ctrl = TextEditingController(text: '${item.stock}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Yeni stok miktarını girin:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                suffix: Text(item.unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            onPressed: () {
              final val = int.tryParse(ctrl.text);
              if (val != null && val >= 0) {
                setState(() => item.stock = val);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.name} stoku $val ${item.unit} olarak güncellendi.'),
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }


}

// ─────────────────────────────────────────────────────────────────────────────
//  Sipariş Kartı
// ─────────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final MerchantOrder order;
  final String statusLabel;
  final Color statusColor;
  final String elapsed;
  final VoidCallback onTap;
  final VoidCallback onAssignCourier;
  final VoidCallback? onStatusChange;
  final String nextStatusLabel;
  final Color nextStatusColor;

  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.elapsed,
    required this.onTap,
    required this.onAssignCourier,
    this.onStatusChange,
    required this.nextStatusLabel,
    required this.nextStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNew = order.status == 'new';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isNew ? Border.all(color: const Color(0xFFDC2626), width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: isNew
                  ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı
              Row(
                children: [
                  if (isNew)
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                    ),
                  Text(order.orderNo,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15,
                          color: isNew ? const Color(0xFFDC2626) : const Color(0xFF0F172A))),
                  const Spacer(),
                  _StatusPill(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(elapsed, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),

              const Divider(height: 16),

              // Müşteri + Adres
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(order.customer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(order.address,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                ],
              ),
              const SizedBox(height: 4),

              // Ürün sayısı + Tutar
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('${order.items.length} kalem ürün',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  const Spacer(),
                  Text('₺${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A))),
                ],
              ),

              // Kurye bilgisi
              if (order.assignedCourier != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.delivery_dining, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(order.assignedCourier!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                  ],
                ),
              ],

              // Aksiyon butonları (teslim edilmemiş siparişler)
              if (order.status != 'delivered') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Kurye Ata
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delivery_dining, size: 15),
                        label: Text(
                          order.assignedCourier != null ? 'Kuryeyi Değiştir' : 'Kurye Ata',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: onAssignCourier,
                      ),
                    ),

                    if (onStatusChange != null && order.status != 'on_way') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: nextStatusColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: onStatusChange,
                          child: Text(nextStatusLabel,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stok Kartı — + / - butonları
// ─────────────────────────────────────────────────────────────────────────────
class _StockCard extends StatelessWidget {
  final StockItem item;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onManualEdit;

  const _StockCard({
    required this.item,
    required this.onDecrement,
    required this.onIncrement,
    required this.onManualEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isCritical = item.stock <= item.minStock;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isCritical ? Border.all(color: item.statusColor.withValues(alpha: 0.5), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Kategori rengi şeridi
          Container(
            width: 4, height: 52,
            decoration: BoxDecoration(
              color: item.statusColor,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(width: 14),

          // Ürün bilgisi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: Text(item.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 6),
                    Text('₺${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(item.stockStatus,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: item.statusColor)),
                    ),
                    const SizedBox(width: 6),
                    Text('Min: ${item.minStock} ${item.unit}',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // + / - kontroller
          Column(
            children: [
              // Manuel düzenleme butonu
              GestureDetector(
                onTap: onManualEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: item.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: item.statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item.stock}',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: item.statusColor)),
                      const SizedBox(width: 4),
                      Text(item.unit, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 10, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),

              // + / - satırı
              Row(
                children: [
                  // Azalt (-)
                  _StockButton(
                    icon: Icons.remove,
                    color: item.stock == 0 ? Colors.grey.shade300 : const Color(0xFFFEF2F2),
                    iconColor: item.stock == 0 ? Colors.grey.shade400 : const Color(0xFFDC2626),
                    onTap: item.stock == 0 ? null : onDecrement,
                  ),
                  const SizedBox(width: 8),
                  // Artır (+)
                  _StockButton(
                    icon: Icons.add,
                    color: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    onTap: onIncrement,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const _StockButton({required this.icon, required this.color, required this.iconColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ortak yardımcı widget'lar
// ─────────────────────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          SizedBox(width: 70,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatBox({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
      ],
    );
  }
}
