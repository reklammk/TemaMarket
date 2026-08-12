import 'dart:async';
import 'package:flutter/material.dart';
import '../services/feature_flags_service.dart';
import '../services/api_service.dart';

class CustomerStorefrontPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onOpenLogin;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenMerchant;
  final VoidCallback? onOpenCourier;
  final VoidCallback? onLogout;

  const CustomerStorefrontPage({
    super.key,
    this.user,
    this.onOpenLogin,
    this.onOpenAdmin,
    this.onOpenMerchant,
    this.onOpenCourier,
    this.onLogout,
  });

  @override
  State<CustomerStorefrontPage> createState() => _CustomerStorefrontPageState();
}

class _CustomerStorefrontPageState extends State<CustomerStorefrontPage> {
  FeatureFlags _flags = const FeatureFlags();
  Timer? _flagsTimer;
  List<Map<String, dynamic>> _liveProducts = [];

  // Colors
  static const Color primaryRed = Color(0xFFDC2626);
  static const Color darkNavy = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color redBg = Color(0xFFFEF2F2);
  static const Color redBorder = Color(0xFFFECDD3);

  @override
  void initState() {
    super.initState();
    _loadFlags();
    _scheduleNextFlagPoll();
    _loadProductsFromApi();
    _loadBranchesFromApi();
  }

  Future<void> _loadBranchesFromApi() async {
    try {
      final list = await ApiService.fetchBranches();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _branchDetails = list.map((b) => {
            'name': b['name']?.toString() ?? 'Şube',
            'district': b['address']?.toString() ?? b['district']?.toString() ?? 'Erzurum',
            'phone': b['phone']?.toString() ?? '0 (442) 234 11 22',
            'status': (b['is_active'] == false) ? 'Şu an Kapalı' : 'AÇIK - Canlı Teslimat',
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProductsFromApi() async {
    try {
      final list = await ApiService.fetchProducts();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _liveProducts = list.map((item) => {
            'id': item['id'],
            'name': item['name'],
            'price': (item['base_price'] is num)
                ? (item['base_price'] as num).toDouble()
                : double.tryParse(item['base_price']?.toString() ?? '0') ?? 0.0,
            'orig_price': item['original_price'] != null
                ? ((item['original_price'] is num)
                    ? (item['original_price'] as num).toDouble()
                    : double.tryParse(item['original_price'].toString()))
                : null,
            'sub_brand': item['sub_brand'] ?? item['category']?['name'] ?? 'Genel',
            'image': item['image'] ?? 'https://picsum.photos/seed/product/400/400',
          }).toList();
        });
      }
    } catch (_) {}
  }

  void _scheduleNextFlagPoll() {
    _flagsTimer?.cancel();
    _flagsTimer = Timer(
      FeatureFlagsService.recommendedPollInterval,
      () async {
        await _loadFlags();
        if (mounted) _scheduleNextFlagPoll();
      },
    );
  }

  @override
  void dispose() {
    _flagsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFlags() async {
    final flags = await FeatureFlagsService.loadFlags();
    if (mounted) {
      if (!flags.isIdenticalTo(_flags) ||
          (!flags.sanalMarket && _cart.isNotEmpty)) {
        setState(() {
          _flags = flags;
          if (!flags.sanalMarket && _cart.isNotEmpty) {
            _cart.clear();
          }
        });
      }
    }
  }

  final List<Map<String, dynamic>> _cart = [];
  String _selectedBranch = 'Lalapaşa AVM (Yakutiye)';
  String _selectedCategory = 'Tümü';
  String _searchQuery = '';
  int _heroSliderIndex = 0;

  List<Map<String, String>> _branchDetails = [
    {'name': 'Lalapaşa AVM (Yakutiye)', 'district': 'Yakutiye / Erzurum', 'phone': '0 (442) 234 11 22', 'status': 'AÇIK - Canlı Teslimat'},
    {'name': 'Pasinler (Pasinler)', 'district': 'Pasinler / Erzurum', 'phone': '0 (442) 661 22 33', 'status': 'AÇIK - Canlı Teslimat'},
  ];

  final List<Map<String, dynamic>> _popularProducts = [
    {'id': 101, 'name': 'Dana Kasap Antrikot 1 kg', 'price': 690.00, 'orig_price': 790.00, 'sub_brand': 'Kasap', 'image': 'https://picsum.photos/seed/meat1/400/400', 'badge': 'ÇOK SATAN'},
    {'id': 102, 'name': 'Yerli Amasya Elması 1 kg', 'price': 34.90, 'orig_price': 45.00, 'sub_brand': 'Manav', 'image': 'https://picsum.photos/seed/apple2/400/400', 'badge': 'Taze Hasat'},
    {'id': 103, 'name': 'Erzurum Hakiki Bal Petek 500 g', 'price': 350.00, 'orig_price': 420.00, 'sub_brand': 'Sarkuteri', 'image': 'https://picsum.photos/seed/honey3/400/400', 'badge': 'YÖRESEL'},
  ];

  final List<Map<String, dynamic>> _discountedProducts = [
    {'id': 301, 'name': 'Torku Tam Yağlı Kaşar 600 g', 'price': 299.00, 'orig_price': 479.00, 'sub_brand': 'Sarkuteri', 'image': 'https://picsum.photos/seed/kasar3/400/400', 'discount_rate': '%37 İNDİRİM'},
    {'id': 302, 'name': 'Dana Kasap Parmak Sucuk 500 g', 'price': 499.00, 'orig_price': 625.00, 'sub_brand': 'Kasap', 'image': 'https://picsum.photos/seed/sucuk1/400/400', 'discount_rate': '%20 İNDİRİM'},
  ];

  final List<Map<String, dynamic>> _products = [
    {'id': 1, 'name': 'Dana Kasap Parmak Sucuk 500 g', 'price': 499.00, 'orig_price': 625.00, 'sub_brand': 'Kasap', 'image': 'https://picsum.photos/seed/sucuk1/400/400'},
    {'id': 2, 'name': 'Sıkma File Portakal 2 kg', 'price': 49.90, 'orig_price': 65.00, 'sub_brand': 'Manav', 'image': 'https://picsum.photos/seed/orange2/400/400'},
  ];

  void _addToCart(Map<String, dynamic> product) {
    if (!_flags.sanalMarket) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sanal Market şu an siparişe kapalıdır. Ürünlerimizi şubelerimizde bulabilirsiniz.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          backgroundColor: primaryRed,
        ),
      );
      return;
    }
    setState(() {
      final index = _cart.indexWhere((i) => i['id'] == product['id']);
      if (index >= 0) {
        _cart[index]['qty'] = (_cart[index]['qty'] as int) + 1;
      } else {
        _cart.add({...product, 'qty': 1});
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['name']} sepete eklendi.'), duration: const Duration(seconds: 1), backgroundColor: const Color(0xFF16A34A)),
    );
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cart[index]['qty'] > 1) {
        _cart[index]['qty'] -= 1;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  Future<void> _sendOrder() async {
    if (_cart.isEmpty || !_flags.sanalMarket) return;
    final orderItems = _cart.map((item) => {
      'product_id': item['id'],
      'quantity': item['qty'],
      'unit_price': item['price'],
    }).toList();

    final orderPayload = {
      'tenant_id': 1,
      'branch_id': 1,
      'customer_name': widget.user?['name'] ?? ApiService.currentUser?['name'] ?? 'Müşteri',
      'customer_phone': widget.user?['phone'] ?? ApiService.currentUser?['phone'] ?? '05321002233',
      'delivery_address': _selectedBranch,
      'payment_method': 'Nakit',
      'items': orderItems,
    };

    try {
      await ApiService.createOrder(orderPayload);
      setState(() => _cart.clear());
      if (mounted) {
        Navigator.pop(context); // Close cart drawer
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Siparişiniz alındı!'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sipariş hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCartDrawer() {
    if (!_flags.sanalMarket) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sanal Market şu an siparişe kapalıdır.'), backgroundColor: primaryRed),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = _cart.fold(0.0, (sum, i) => sum + (i['price'] * i['qty']));
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sepetim (${_cart.length} ürün)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkNavy)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('₺${item['price']} x ${item['qty']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: primaryRed),
                              onPressed: () {
                                _removeFromCart(index);
                                setModalState(() {});
                              },
                            ),
                            Text('${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: primaryRed),
                              onPressed: () {
                                setState(() {
                                  _cart[index]['qty'] += 1;
                                });
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Kupon kodu',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: darkNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                            onPressed: () {},
                            child: const Text('Uygula', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          onPressed: _cart.isEmpty ? null : _sendOrder,
                          child: Text('Sipariş Ver (₺${total.toStringAsFixed(2)})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavbar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Row 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(100)),
                      child: const Text('TEMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                    const SizedBox(width: 6),
                    const Text('sanalmarket', style: TextStyle(color: primaryRed, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5)),
                  ],
                ),
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: redBg, borderRadius: BorderRadius.circular(100)),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: primaryRed, size: 16),
                        const SizedBox(width: 4),
                        Text(_selectedBranch, style: const TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
                        const Icon(Icons.keyboard_arrow_down, color: primaryRed, size: 16),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: widget.onOpenLogin,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: redBg, shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: primaryRed, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showCartDrawer,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: redBg, shape: BoxShape.circle),
                            child: const Icon(Icons.shopping_cart, color: primaryRed, size: 20),
                          ),
                          if (_cart.isNotEmpty)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: darkNavy, shape: BoxShape.circle),
                                child: Text('${_cart.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
          // Row 2: Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                'Tümü', 'İndirimli Ürünler', 'TEMA KASAP', 'TEMA MANAV', 'TEMA SARKUTERİ', 'TEMA FIRIN', 'TEMA İÇECEK'
              ].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryRed : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: isSelected ? primaryRed : slate100),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : slate500,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Row 3: Search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Ürün, kategori veya marka ara...',
                hintStyle: const TextStyle(color: slate500, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: slate500),
                filled: true,
                fillColor: slate50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSlider() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [primaryRed, darkNavy]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -60,
                  top: -60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text('YENİ KAMPANYA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      const SizedBox(height: 12),
                      const Text('Taze Et Ürünlerinde\n%20 İndirim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, height: 1.2)),
                      const SizedBox(height: 4),
                      Text('Sadece bu hafta sonuna özel', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('Kupon: KASAP20', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            SizedBox(width: 8),
                            Icon(Icons.copy, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 20,
                  top: 20,
                  bottom: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network('https://picsum.photos/seed/meat1/400/400', width: 100, fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () {},
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () {},
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: index == _heroSliderIndex ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == _heroSliderIndex ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(100),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVIPCardBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [darkNavy, slate800]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.credit_card, color: Color(0xFFEAB308), size: 20),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(4)), child: const Text('KİŞİYE ÖZEL İNDİRİM', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0x33EAB308), borderRadius: BorderRadius.circular(4)), child: const Text('TEMA VIP KART', style: TextStyle(color: Color(0xFFFEF08A), fontSize: 9, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('TEMA VIP Kartınızı Oluşturun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Özel avantajları keşfedin', style: TextStyle(color: slate500, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAB308),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            onPressed: () {},
            child: const Text('VIP Kartım ➔', style: TextStyle(color: darkNavy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessPartnerBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [darkNavy, slate800]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(4)), child: const Text('TEMA FIRSATLAR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              const Expanded(child: Text('TEMA Market İş Ortaklığı ve Gayrimenkul Kiralama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                  onPressed: () {},
                  child: const Text('Aktüel Broşürler', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEAB308), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                  onPressed: () {},
                  child: const Text('Bayimiz Olmak İster Misiniz?', style: TextStyle(color: darkNavy, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p, bool isDiscounted) {
    int qty = _cart.firstWhere((item) => item['id'] == p['id'], orElse: () => {'qty': 0})['qty'] ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDiscounted ? redBorder : slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(p['image'], height: 120, width: double.infinity, fit: BoxFit.cover),
              ),
              if (p['discount_rate'] != null || p['badge'] != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: primaryRed, borderRadius: BorderRadius.circular(100)),
                    child: Text(p['discount_rate'] ?? p['badge'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: darkNavy, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('₺${p['price']}', style: const TextStyle(fontWeight: FontWeight.w900, color: primaryRed, fontSize: 16)),
                    if (p['orig_price'] != null) ...[
                      const SizedBox(width: 6),
                      Text('₺${p['orig_price']}', style: const TextStyle(color: slate500, decoration: TextDecoration.lineThrough, fontSize: 12)),
                    ],
                    const Text(' / unit', style: TextStyle(color: slate500, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 12),
                qty > 0
                    ? Container(
                        height: 36,
                        decoration: BoxDecoration(color: redBg, borderRadius: BorderRadius.circular(100)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: const Icon(Icons.remove, color: primaryRed, size: 16), onPressed: () => _removeFromCart(_cart.indexWhere((i) => i['id'] == p['id']))),
                            Text('$qty unit', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryRed, fontSize: 12)),
                            IconButton(icon: const Icon(Icons.add, color: primaryRed, size: 16), onPressed: () => _addToCart(p)),
                          ],
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                          icon: const Icon(Icons.add, color: Colors.white, size: 16),
                          label: const Text('Hemen Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => _addToCart(p),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountedSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.white, redBg]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: redBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: redBorder)), child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.local_offer, size: 12, color: primaryRed), SizedBox(width: 4), Text('HAFTANIN İNDİRİMLERİ', style: TextStyle(color: primaryRed, fontSize: 10, fontWeight: FontWeight.bold))])),
          const SizedBox(height: 8),
          const Text('🏷️ İndirimli Ürünler & Şube Fırsatları', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: darkNavy)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _discountedProducts.length,
            itemBuilder: (context, index) => _buildProductCard(_discountedProducts[index], true),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: slate50, borderRadius: BorderRadius.circular(100), border: Border.all(color: slate100)), child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.local_fire_department, size: 12, color: Colors.orange), SizedBox(width: 4), Text('ÇOK SATANLAR & TREND', style: TextStyle(color: darkNavy, fontSize: 10, fontWeight: FontWeight.bold))])),
          const SizedBox(height: 8),
          const Text('🔥 Popüler Ürünler', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: darkNavy)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _popularProducts.length,
            itemBuilder: (context, index) => _buildProductCard(_popularProducts[index], false),
          ),
        ],
      ),
    );
  }

  Widget _buildAllProductsSection() {
    final catalogList = _liveProducts.isNotEmpty ? _liveProducts : _products;
    final filteredCatalog = catalogList.where((p) {
      if (_selectedCategory == 'İndirimli Ürünler') return (p['orig_price'] != null && p['orig_price'] > p['price']);
      if (_selectedCategory != 'Tümü') {
        final cleanCat = _selectedCategory.replaceAll('TEMA ', '').trim().toLowerCase();
        final subBrand = (p['sub_brand'] ?? p['category'] ?? '').toString().toLowerCase();
        if (!subBrand.contains(cleanCat) && !cleanCat.contains(subBrand)) return false;
      }
      if (_searchQuery.trim().isNotEmpty) return p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return true;
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_selectedCategory == 'Tümü' ? 'Tüm Ürünler' : _selectedCategory, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: darkNavy)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredCatalog.length,
            itemBuilder: (context, index) => _buildProductCard(filteredCatalog[index], false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavbar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildBusinessPartnerBanner(),
                    _buildHeroSlider(),
                    _buildVIPCardBanner(),
                    _buildDiscountedSection(),
                    _buildPopularSection(),
                    _buildAllProductsSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
