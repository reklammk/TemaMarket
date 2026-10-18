import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/feature_flags_service.dart';
import '../utils/customer_profile_utils.dart';
import '../widgets/tema_logo_painter.dart';
import 'subdomain_landing_page.dart';

class CustomerStorefrontPage extends StatefulWidget {
  final int initialTab;
  final Map<String, dynamic>? user;
  final VoidCallback? onOpenLogin;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenMerchant;
  final VoidCallback? onOpenCourier;
  final VoidCallback? onLogout;
  final VoidCallback? onAccountDeleted;

  const CustomerStorefrontPage({
    super.key,
    this.initialTab = 0,
    this.user,
    this.onOpenLogin,
    this.onOpenAdmin,
    this.onOpenMerchant,
    this.onOpenCourier,
    this.onLogout,
    this.onAccountDeleted,
  });

  @override
  State<CustomerStorefrontPage> createState() => _CustomerStorefrontPageState();
}

class _CustomerStorefrontPageState extends State<CustomerStorefrontPage> {
  FeatureFlags _flags = const FeatureFlags();
  bool _loading = true;
  bool _savingConsent = false;
  bool _savingDiscountPreferences = false;
  bool _deletingAccount = false;
  String? _error;
  int _tab = 0;
  int? _branchId;
  String _category = 'Tümü';
  String _search = '';
  bool _smsConsent = false;
  Set<String> _discountPreferences = <String>{};
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _subdomainPages = [];
  final List<Map<String, dynamic>> _cart = [];
  bool _showSanalMarketView = false;
  int _campaignTab = 0;

  static final List<Map<String, dynamic>> _defaultBrochures = [
    {
      'id': 1,
      'title': 'Haftanın Yıldız İndirimleri',
      'dates': '17 - 24 Ekim 2026',
      'image': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
      'description': 'Temel gıda, temizlik ve taze manav reyonlarında geçerli aktüel broşürümüz.',
    },
    {
      'id': 2,
      'title': 'Tema Kasaphane & Mandıra Günleri',
      'dates': 'Bu Hafta Sonu Özel',
      'image': 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?w=800',
      'description': 'Kendi kasaphanemizden taze dana kuşbaşı, köfte, tereyağı ve yayık peynirinde dev fırsatlar.',
    },
    {
      'id': 3,
      'title': 'Tema Fırın & Bakliyat Bereket Kataloğu',
      'dates': 'Ekim Ayı Boyunca',
      'image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800',
      'description': 'Geleneksel ekmekler, sıcak unlu mamuller ve yerli hasat kuru bakliyat indirimleri.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 4);
    _smsConsent = _bool(widget.user?['sms_consent']);
    _discountPreferences =
        parseDiscountPreferences(widget.user?['discount_preferences']);
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerStorefrontPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?['id'] != widget.user?['id']) {
      _smsConsent = _bool(widget.user?['sms_consent']);
      _discountPreferences =
          parseDiscountPreferences(widget.user?['discount_preferences']);
      if (widget.user == null) _cart.clear();
    }
  }

  Map<String, dynamic>? get _currentUser => ApiService.currentUser ?? widget.user;

  bool _bool(dynamic value) =>
      value == true ||
      value == 1 ||
      value == '1' ||
      value?.toString().toLowerCase() == 'true';
  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  List<Map<String, dynamic>> _maps(List<dynamic> list) =>
      list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  List<Map<String, dynamic>> _customerAddresses = [];
  List<Map<String, dynamic>> _customerOrders = [];
  Map<String, dynamic>? _loyaltyData;
  bool _loadingAccountData = false;

  Future<void> _loadAccountData() async {
    final user = _currentUser;
    if (user == null || user['role'] != 'Customer') return;
    setState(() => _loadingAccountData = true);

    try {
      final addrs = await ApiService.fetchCustomerAddresses();
      if (mounted) setState(() => _customerAddresses = _maps(addrs));
    } catch (e) {
      debugPrint('Adresler yüklenirken hata: $e');
    }

    try {
      final ords = await ApiService.fetchCustomerOrders();
      if (mounted) setState(() => _customerOrders = _maps(ords));
    } catch (e) {
      debugPrint('Siparişler yüklenirken hata: $e');
    }

    try {
      final loyalty = await ApiService.fetchLoyaltyPoints();
      if (mounted) setState(() => _loyaltyData = loyalty);
    } catch (e) {
      debugPrint('TemaPuan yüklenirken hata: $e');
    }

    if (mounted) setState(() => _loadingAccountData = false);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        FeatureFlagsService.loadFlags(),
        ApiService.fetchBranches(),
        ApiService.fetchCampaigns(),
        ApiService.fetchSubdomainPages(),
      ]);
      if (!mounted) return;
      final branches = _maps(result[1] as List<dynamic>);
      setState(() {
        _flags = result[0] as FeatureFlags;
        _branches = branches;
        _campaigns = _maps(result[2] as List<dynamic>);
        _subdomainPages = _maps(result[3] as List<dynamic>);
        _branchId ??= branches.isEmpty ? null : _int(branches.first['id']);
      });
      await _loadProducts();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts() async {
    if (_branchId == null) {
      if (mounted) setState(() => _products = []);
      return;
    }
    try {
      final products = await ApiService.fetchProducts(branchId: _branchId);
      if (!mounted) return;
      setState(() {
        _products = _maps(products);
        _cart.removeWhere((line) {
          final matches = _products
              .where((product) => _int(product['id']) == _int(line['id']));
          return matches.isEmpty || _int(matches.first['stock']) <= 0;
        });
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  List<String> get _categories {
    const base = [
      'Tümü',
      'Tema Kasaphane',
      'Tema Mandıra',
      'Tema Fırın',
      'Tema Bakliyat',
    ];
    final other = _products
        .map((p) => p['sub_brand']?.toString() ?? 'Genel')
        .where((c) =>
            !base.contains(c) &&
            c.toLowerCase() != 'kasap' &&
            c.toLowerCase() != 'şarküteri')
        .toSet()
        .toList()
      ..sort();
    return [...base, ...other];
  }

  bool _matchesCategory(String productCategory, String selectedCategory) {
    if (selectedCategory == 'Tümü') return true;
    final cat = productCategory.toLowerCase();
    final sel = selectedCategory.toLowerCase();

    if (sel == 'tema kasaphane') {
      return cat.contains('kasap') ||
          cat.contains('et ') ||
          cat == 'et' ||
          cat == 'tema kasaphane';
    }
    if (sel == 'tema mandıra') {
      return cat.contains('şarküteri') ||
          cat.contains('mandıra') ||
          cat.contains('süt') ||
          cat.contains('peynir') ||
          cat == 'tema mandıra';
    }
    if (sel == 'tema fırın') {
      return cat.contains('fırın') ||
          cat.contains('ekmek') ||
          cat.contains('unlu') ||
          cat == 'tema fırın';
    }
    if (sel == 'tema bakliyat') {
      return cat.contains('bakliyat') ||
          cat.contains('kuru gıda') ||
          cat == 'tema bakliyat';
    }
    return productCategory == selectedCategory;
  }

  List<Map<String, dynamic>> get _visibleProducts {
    final query = _search.trim().toLowerCase();
    return _products.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? '';
      final category = product['sub_brand']?.toString() ?? 'Genel';
      return _matchesCategory(category, _category) &&
          (query.isEmpty ||
              name.contains(query) ||
              category.toLowerCase().contains(query));
    }).toList();
  }

  List<Map<String, dynamic>> get _discountedProducts {
    final products = _products
        .where((product) =>
            _double(product['original_price']) > _double(product['base_price']))
        .toList();
    products.sort((a, b) {
      final aPreferred =
          _discountPreferences.contains(a['sub_brand']?.toString() ?? 'Genel');
      final bPreferred =
          _discountPreferences.contains(b['sub_brand']?.toString() ?? 'Genel');
      if (aPreferred != bPreferred) return aPreferred ? -1 : 1;
      final aDiscount = _double(a['original_price']) - _double(a['base_price']);
      final bDiscount = _double(b['original_price']) - _double(b['base_price']);
      return bDiscount.compareTo(aDiscount);
    });
    return products;
  }

  List<String> get _preferenceCategories {
    final categories = <String>{
      ..._discountPreferences,
      ..._categories.where((category) => category != 'Tümü'),
    }.toList()
      ..sort();
    return categories.take(12).toList();
  }

  int _quantity(int id) {
    final item = _cart.where((line) => _int(line['id']) == id);
    return item.isEmpty ? 0 : _int(item.first['quantity']);
  }

  void _changeCart(Map<String, dynamic> product, int delta) {
    if (!_flags.sanalMarket) {
      _message(
        'Sanal Market şu an siparişe kapalı. Ürünleri incelemeye devam edebilirsiniz.',
        error: true,
      );
      return;
    }
    final id = _int(product['id']);
    final stock = _int(product['stock']);
    final index = _cart.indexWhere((line) => _int(line['id']) == id);
    final current = index < 0 ? 0 : _int(_cart[index]['quantity']);
    final next = current + delta;
    if (stock <= 0 || id <= 0) return;
    if (next > stock) {
      _message('Stokta en fazla $stock adet bulunuyor.');
      return;
    }
    setState(() {
      if (next <= 0 && index >= 0) {
        _cart.removeAt(index);
      } else if (index >= 0) {
        _cart[index]['quantity'] = next;
      } else if (next > 0) {
        _cart.add({...product, 'quantity': next});
      }
    });
  }

  int get _cartCount =>
      _cart.fold(0, (total, line) => total + _int(line['quantity']));
  double get _cartTotal => _cart.fold(
      0,
      (total, line) =>
          total + _double(line['base_price']) * _int(line['quantity']));

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _callBranch(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return;
    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: normalized),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _message('Telefon uygulaması açılamadı.', error: true);
      }
    } catch (_) {
      if (mounted) _message('Telefon uygulaması açılamadı.', error: true);
    }
  }

  Future<void> _openBranchLocation(Map<String, dynamic> branch) async {
    final address = branch['address']?.toString().trim() ?? '';
    final district = branch['city_district']?.toString().trim() ?? '';
    final name = branch['name']?.toString().trim() ?? 'TEMA Market';
    final query = [name, address, district]
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
    if (query.isEmpty) return;
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': query},
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _message('Harita uygulaması açılamadı.', error: true);
      }
    } catch (_) {
      if (mounted) _message('Harita uygulaması açılamadı.', error: true);
    }
  }

  Future<void> _selectBranch(int id) async {
    if (id <= 0) return;
    setState(() {
      _branchId = id;
      _cart.clear();
      _category = 'Tümü';
      _tab = 0;
    });
    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: HeaderTemaLogo(isSanalMarket: _showSanalMarketView),
          actions: [
            if (widget.onOpenAdmin != null)
              IconButton(
                tooltip: 'Yönetici Paneli',
                icon: const Icon(Icons.admin_panel_settings_outlined,
                    color: Color(0xFFDC2626)),
                onPressed: widget.onOpenAdmin,
              ),
            IconButton(
              tooltip: 'Yenile',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _currentTabBody(),
        bottomNavigationBar: _floatingNavbar(),
      );

  Widget _currentTabBody() {
    switch (_tab) {
      case 1:
        return _branchesPage();
      case 2:
        return _basket();
      case 3:
        return _forYouPage();
      case 4:
        return _account();
      case 0:
      default:
        return _showSanalMarketView ? _market() : _homeLandingPage();
    }
  }

  void _handleNavTap(int index) {
    if (index == 0 && _tab == 0 && _showSanalMarketView) {
      setState(() => _showSanalMarketView = false);
      return;
    }
    if (index == 2 && !_flags.sanalMarket) {
      _message(
        'Sanal Market şu an siparişe kapalı. Ürünleri incelemeye devam edebilirsiniz.',
        error: true,
      );
      return;
    }
    if (index == 4 && widget.user == null && widget.onOpenLogin != null) {
      widget.onOpenLogin!.call();
      return;
    }
    setState(() => _tab = index);
    if (index == 4) {
      _loadAccountData();
    }
  }

  Widget _floatingNavbar() {
    const navItems = <({int id, IconData icon, String label})>[
      (id: 0, icon: Icons.home_rounded, label: 'Ana Sayfa'),
      (id: 1, icon: Icons.store_rounded, label: 'Şubeler'),
      (id: 2, icon: Icons.shopping_bag_outlined, label: 'Sepetim'),
      (id: 3, icon: Icons.auto_awesome_rounded, label: 'Sizin İçin'),
      (id: 4, icon: Icons.person_rounded, label: 'Hesabım'),
    ];

    return SafeArea(
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xDD211E22),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 24,
              spreadRadius: 2,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: navItems.map((item) {
            final selected = _tab == item.id;
            Widget icon = Icon(
              item.icon,
              color: selected ? const Color(0xFFDC2626) : Colors.white70,
              size: 22,
            );
            if (item.id == 2 && _flags.sanalMarket && _cartCount > 0) {
              icon = Badge(label: Text('$_cartCount'), child: icon);
            }

            return Tooltip(
              message: item.label,
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: Material(
                  color: selected ? Colors.white : Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _handleNavTap(item.id),
                    child: SizedBox.square(
                      dimension: selected ? 46 : 44,
                      child: Center(child: icon),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _branchesPage() {
    if (_loading && _branches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_branches.isEmpty) {
      return _Empty(
        message: _error ?? 'Şube bilgisi bulunamadı.',
        retry: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _branches.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Şubelerimiz',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            );
          }
          final branch = _branches[index - 1];
          final id = _int(branch['id']);
          final selected = id == _branchId;
          final address = branch['address']?.toString().trim() ?? '';
          final district = branch['city_district']?.toString().trim() ?? '';
          final phone = branch['phone']?.toString().trim() ?? '';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: selected
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFF1F5F9),
                        foregroundColor:
                            selected ? Colors.white : Colors.black54,
                        child: const Icon(Icons.store_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          branch['name']?.toString() ?? 'TEMA Market Şubesi',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFFDC2626),
                        ),
                    ],
                  ),
                  if (district.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _branchDetail(Icons.location_city_outlined, district),
                  ],
                  if (address.isNotEmpty && address != district) ...[
                    const SizedBox(height: 8),
                    _branchDetail(Icons.location_on_outlined, address),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _branchDetail(Icons.phone_outlined, phone),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: address.isEmpty && district.isEmpty
                              ? null
                              : () => _openBranchLocation(branch),
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text('Yol Tarifi'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              phone.isEmpty ? null : () => _callBranch(phone),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Ara'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selected ? null : () => _selectBranch(id),
                      icon: Icon(selected
                          ? Icons.check_rounded
                          : Icons.shopping_basket_outlined),
                      label: Text(
                        selected ? 'Seçili Şube' : 'Bu Şubeden Alışveriş Yap',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _branchDetail(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      );

  Widget _forYouPage() {
    final discounted = _discountedProducts;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kampanyalar & Fırsatlar',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Aktüel Fırsatlar',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sekmeler: Tekli Ürün İndirimleri vs Aktüel Broşürler
          Row(
            children: [
              ChoiceChip(
                label: const Text('Tekli Ürün İndirimleri'),
                selected: _campaignTab == 0,
                onSelected: (_) => setState(() => _campaignTab = 0),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Aktüel Broşürler'),
                selected: _campaignTab == 1,
                onSelected: (_) => setState(() => _campaignTab = 1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_campaignTab == 1) ...[
            // Aktüel Broşürler Sekmesi
            ..._defaultBrochures.map((brochure) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.network(
                        brochure['image']?.toString() ?? '',
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 140,
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(Icons.menu_book_rounded,
                                size: 48, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  brochure['title']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    brochure['dates']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              brochure['description']?.toString() ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                                icon: const Icon(Icons.fullscreen, size: 20),
                                label: const Text('Broşürü Tam Ekran İncele'),
                                onPressed: () => _openBrochureViewer(brochure),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ] else ...[
            // Tekli Ürün İndirimleri Sekmesi
            if (_discountPreferences.isNotEmpty) ...[
              _InfoBanner(
                icon: Icons.tune_rounded,
                text:
                    'Tercihlerinize göre önce ${_discountPreferences.join(', ')} '
                    'kategorilerindeki fırsatlar gösteriliyor.',
              ),
              const SizedBox(height: 12),
            ],
            if (!_flags.kampanyalar)
              const _InfoBanner(
                icon: Icons.campaign_outlined,
                text: 'Kampanyalar şu anda yayında değil.',
              )
            else if (_campaigns.isNotEmpty) ...[
              ..._campaigns.map(
                (campaign) => Card(
                  color: const Color(0xFFB91C1C),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.local_offer, color: Colors.white),
                    title: Text(
                      campaign['title']?.toString() ?? 'Kampanya',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(
                      campaign['description']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (discounted.isEmpty)
              const _InfoBanner(
                icon: Icons.auto_awesome_outlined,
                text: 'Şu anda indirimli ürün bulunmuyor.',
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 600 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 315,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: discounted.length,
                    itemBuilder: (_, index) => _product(discounted[index]),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _homeLandingPage() {
    final user = widget.user;
    final phone = user?['phone']?.toString() ?? '';
    final rawCardNo = user?['tema_card_number']?.toString();
    final cardNo = (rawCardNo != null && rawCardNo.isNotEmpty)
        ? rawCardNo
        : (phone.isNotEmpty ? temaAvantajCardNumber(phone) : '');
    final formattedCardNo =
        cardNo.isNotEmpty ? formatTemaAvantajCardNumber(cardNo) : '';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Tema Avantaj Kart Giriş & Teşvik Kartı (Item 7 & 8)
          _homeAvantajCardIncentive(user, cardNo, formattedCardNo, phone),
          const SizedBox(height: 16),

          // 2. Sanal Market Hero Yönlendirme Kartı (Item 2)
          _homeSanalMarketHeroBanner(),
          const SizedBox(height: 20),

          // 3. Aktüel Broşürler & İndirim Bülteni (Item 5)
          _homeBrochuresSection(),
          const SizedBox(height: 20),

          // 4. Haftanın Öne Çıkan Tekli Ürün İndirimleri (Item 5)
          if (_discountedProducts.isNotEmpty) ...[
            _homeSpotDiscountsSection(),
            const SizedBox(height: 20),
          ],

          // 5. Tema Özel Dünyası: Kasaphane, Mandıra, Fırın, Bakliyat (Item 3 & 4)
          _homeBrandedCategoriesSection(),
          const SizedBox(height: 20),

          // 6. Şubelerimiz Bölümü
          _homeBranchesSection(),
          const SizedBox(height: 20),

          // 7. Hakkımızda Bölümü
          _homeAboutSection(),
          const SizedBox(height: 20),

          // 8. Tema İnşaat & Şirketler Grubu
          _homeCorporateGroupSection(),
          const SizedBox(height: 16),

          // 7. Kariyer & İş Başvurusu (Item 11)
          _homeCareerSection(),
          const SizedBox(height: 24),

          // 8. Kurumsal Bilgiler & Footer (Item 1)
          _homeFooterInfo(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _homeAvantajCardIncentive(
    Map<String, dynamic>? user,
    String cardNo,
    String formattedCardNo,
    String phone,
  ) {
    final isLoggedIn = user != null && (user['id'] != null || phone.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33DC2626),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Tema Avantaj Kart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.25),
                  border: Border.all(color: Colors.amber.shade300, width: 1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'VIP AVANTAJ',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoggedIn) ...[
            Text(
              'Hoş Geldiniz, ${user['name']?.toString().isNotEmpty == true ? user['name'] : 'Değerli Müşterimiz'}!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kart No: $formattedCardNo',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                label: const Text(
                  'Barkodumu Kasada Okut',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: () => _showBarcodeDialog(cardNo, phone),
              ),
            ),
          ] else ...[
            const Text(
              'Tüm Alışverişlerinizde Özel İndirim ve Puan Kazanın!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hemen giriş yapın veya üye olun; adınıza anında 17 haneli Tema Avantaj Kartınız tanımlansın, market ve sanal markette ayrıcalıkların keyfini çıkarın.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      if (widget.onOpenLogin != null) {
                        widget.onOpenLogin!();
                      } else {
                        setState(() => _tab = 4);
                      }
                    },
                    child: const Text(
                      'Giriş Yap / Üye Ol',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => setState(() => _tab = 4),
                    child: const Text(
                      'Avantajları Keşfet',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _homeSanalMarketHeroBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SANAL MARKET',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.flash_on, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _flags.sanalMarket ? 'Siparişe Açık' : 'İnceleme Modu',
                          style: TextStyle(
                            color: _flags.sanalMarket ? Colors.greenAccent : Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'TEMA SANAL MARKET',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kasaphane, mandıra, fırın, manav ve temel gıda reyonlarımızdan taptaze ürünler aynı gün kapınızda!',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hızlı ve güvenli teslimat • Kapıda nakit veya kartla ödeme',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 22),
                    label: const Text(
                      'Sanal Market\'e Git (Alışverişe Başla) →',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    onPressed: () {
                      setState(() {
                        _showSanalMarketView = true;
                        _tab = 0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeBrochuresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book_rounded, color: Color(0xFFDC2626), size: 22),
                SizedBox(width: 8),
                Text(
                  'Aktüel Broşürler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() {
                _tab = 3;
                _campaignTab = 1;
              }),
              child: const Text('Tümünü Gör'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _defaultBrochures.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, index) {
              final brochure = _defaultBrochures[index];
              return Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Image.network(
                          brochure['image']?.toString() ?? '',
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 130,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(Icons.picture_as_pdf_outlined, size: 36, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              brochure['dates']?.toString() ?? '',
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            brochure['title']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            brochure['description']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFDC2626)),
                                foregroundColor: const Color(0xFFDC2626),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _openBrochureViewer(brochure),
                              child: const Text('Broşürü İncele', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        ),
      ],
    );
  }

  Widget _homeSpotDiscountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department, color: Color(0xFFEA580C), size: 24),
                SizedBox(width: 8),
                Text(
                  'Haftanın Yıldız İndirimleri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() {
                _tab = 3;
                _campaignTab = 0;
              }),
              child: const Text('Tüm İndirimler'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 315,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _discountedProducts.take(8).length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => SizedBox(
              width: 205,
              child: _product(_discountedProducts[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _homeBrandedCategoriesSection() {
    final rawPages = _subdomainPages.isNotEmpty
        ? _subdomainPages.where((p) => p['is_active'] != false).toList()
        : ApiService.defaultSubdomainPages;

    final sections = rawPages.map((p) {
      final sub = p['subdomain']?.toString() ?? 'kasap';
      final hex = (p['color_hex']?.toString() ?? '#DC2626').replaceAll('#', '');
      Color parsedColor;
      try {
        parsedColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {
        parsedColor = const Color(0xFFDC2626);
      }
      IconData iconData = Icons.storefront_outlined;
      if (sub.contains('kasap')) {
        iconData = Icons.set_meal_outlined;
      } else if (sub.contains('sarkuteri')) {
        iconData = Icons.egg_alt_outlined;
      } else if (sub.contains('mandira')) {
        iconData = Icons.local_drink_outlined;
      } else if (sub.contains('firin')) {
        iconData = Icons.bakery_dining_outlined;
      } else if (sub.contains('bakliyat')) {
        iconData = Icons.grain_outlined;
      } else if (sub.contains('insaat')) {
        iconData = Icons.apartment_outlined;
      }

      return <String, dynamic>{
        'title': p['title']?.toString() ?? 'Tema Reyon',
        'subdomain': sub,
        'subtitle': p['slogan']?.toString() ?? '',
        'desc': p['description']?.toString() ?? '',
        'icon': iconData,
        'color': parsedColor,
        'category': p['category']?.toString() ?? 'Tema Kasaphane',
        'hasTracking': sub.contains('kasap'),
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text(
              'Tema\'nın Özel Dünyası & Subdomain Sayfaları',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sections.map((sec) {
          final sub = sec['subdomain'] as String;
          final color = sec['color'] as Color;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.12),
                        radius: 22,
                        child: Icon(sec['icon'] as IconData, color: color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sec['title'] as String,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SubdomainLandingPage(
                                          subdomainSlug: sub,
                                          onBackToMain: () => Navigator.of(context).pop(),
                                          onOpenSanalMarket: () {
                                            Navigator.of(context).pop();
                                            setState(() {
                                              _category = sec['category'] as String;
                                              _showSanalMarketView = true;
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: color.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.open_in_new, size: 12, color: color),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$sub.temamarket.com',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              sec['subtitle'] as String,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sec['desc'] as String,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (sec['hasTracking'] == true) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: color),
                              foregroundColor: color,
                            ),
                            icon: const Icon(Icons.verified_outlined, size: 16),
                            label: const Text('Canlı Sevk Takibi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            onPressed: _openKasaphaneModal,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: color),
                            foregroundColor: color,
                          ),
                          icon: const Icon(Icons.language, size: 16),
                          label: const Text('Özel Sayfa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SubdomainLandingPage(
                                  subdomainSlug: sub,
                                  onBackToMain: () => Navigator.of(context).pop(),
                                  onOpenSanalMarket: () {
                                    Navigator.of(context).pop();
                                    setState(() {
                                      _category = sec['category'] as String;
                                      _showSanalMarketView = true;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _category = sec['category'] as String;
                              _showSanalMarketView = true;
                            });
                          },
                          child: const Text('Ürünleri İncele', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _homeCorporateGroupSection() {
    return Card(
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.apartment_rounded, color: Color(0xFF334155), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tema Şirketler Grubu (Tema İnşaat vb.)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Gıda ve perakendeden konut projelerine, kentsel dönüşümden taahhüt işlerine uzanan Tema güvencesiyle inşaat ve yapı projelerimizi keşfedin.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  foregroundColor: const Color(0xFF334155),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Grup Şirketlerimizi & Projelerimizi Gör'),
                onPressed: _openCorporateEntitiesModal,
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _homeBranchesSection() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: Color(0xFFDC2626), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Şubelerimiz',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '24 ŞUBE',
                    style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Erzurum ve çevre ilçelerde 24 modern şubemizle taze ve güvenilir ürünleri mahallenize ulaştırıyoruz.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
            ),
            const SizedBox(height: 12),
            // Öne çıkan 2 merkezi şube özeti
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lalapaşa AVM Şubesi',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Yakutiye',
                        style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Cumhuriyet Cd. | 6.000 m² Satış Alanı | 08:00 - 22:00',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Yenişehir AVM Şubesi',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Palandöken',
                        style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Hacı Salih Efendi Mh. | 3.900 m² Satış Alanı | 08:00 - 22:00',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Tüm 24 Şubemizi Haritada ve Listede Gör'),
                onPressed: () {
                  setState(() => _tab = 1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeAboutSection() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_outlined, color: Color(0xFF16A34A), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '1989\'dan Günümüze Erzurum\'un Güvenilir Markası',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tema Marketçilik A.Ş. olarak veteriner hekim kontrollü kendi et kombinamız, günlük taze taş fırınlarımız ve mandıra süt üretimimizle sofralarınıza kalite taşıyoruz.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Text('35 Yıl', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                        Text('Tecrübe', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Text('24+', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                        Text('Şube', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Text('650+', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                        Text('Personel', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  foregroundColor: const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Kurumsal Bilgilerimiz ve Tarihçemiz'),
                onPressed: _openAboutModal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAboutModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.business_rounded, color: Color(0xFFDC2626), size: 26),
                      SizedBox(width: 8),
                      Text(
                        'Hakkımızda',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '1989\'dan Günümüze Tema Marketler Zinciri',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kurucumuz Zülküf BAKAÇ tarafından 1989 yılında Erzurum\'da temelleri atılan markamız Tema Marketler Zinciri, çeyrek asrı aşkın süredir dürüst esnaflık geleneğini modern perakendecilik anlayışıyla harmanlamaktadır.\n\n'
                'Kendi et kombina tesisimiz Tema Kasaphane ile veteriner kontrolünde helal kesim yerli besi etleri, Tema Mandıra ile günlük doğal süt ürünlerini ve Tema Fırın ile taş fırın lezzetlerini reyonlarımıza taşıyoruz.\n\n'
                'Erzurum\'un öz sermayesiyle kurulan şirketimiz, 650\'den fazla çalışanıyla kentimizin istihdamına ve ekonomik gücüne doğrudan katkı sağlamaktadır.',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.45),
              ),
              const Divider(height: 28),
              const Text(
                'Vizyonumuz & Misyonumuz',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Müşteri memnuniyetini, ürün tazeliğini ve dürüst fiyat politikasını her şeyin üstünde tutarak; Doğu Anadolu\'nun en güvenilir, sürdürülebilir ve öncü perakende zinciri olmak.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homeCareerSection() {
    return Card(
      color: const Color(0xFFEFF6FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.work_outline_rounded, color: Color(0xFF2563EB), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tema Ailesine Katılın (İş Başvurusu)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Şubelerimiz, lojistik depomuz, Tema Kasaphane ve Tema İnşaat projelerimiz için dinamik çalışma arkadaşları arıyoruz.',
              style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                label: const Text('Kariyer & İş Başvuru Formunu Aç'),
                onPressed: _openJobApplicationModal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeFooterInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFDC2626), size: 20),
              SizedBox(width: 6),
              Text(
                'temamarket.com',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Erzurum geneli geniş şube ağımız, Tema Kasaphane, Tema Mandıra, Tema Fırın ve Sanal Market hizmetimizle sofralarınıza tazelik ve bereket taşıyoruz.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
          ),
          const Divider(height: 20),
          const Row(
            children: [
              Icon(Icons.headset_mic_outlined, size: 16, color: Color(0xFFDC2626)),
              SizedBox(width: 6),
              Text('Müşteri Hizmetleri: 0850 300 00 00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.chat_outlined, size: 16, color: Colors.green),
              SizedBox(width: 6),
              Text('WhatsApp Destek: 0530 000 00 00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.public_outlined, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text('Web: https://temamarket.com', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              '© 2026 temamarket.com - Tüm Hakları Saklıdır.',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _market() {
    if (_loading && _branches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_branches.isEmpty) {
      return _Empty(
          message: _error ?? 'Siparişe açık şube bulunmuyor.', retry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Tanıtım & Ana Sayfaya Dönüş butonu
          Card(
            color: const Color(0xFFFEF2F2),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
            ),
            margin: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _showSanalMarketView = false),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tanıtım & İmaj Sayfasına Geri Dön',
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.home_outlined, color: Color(0xFFDC2626), size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (!_flags.sanalMarket) ...[
            const _InfoBanner(
              icon: Icons.lock_clock_outlined,
              text:
                  'Sanal Market şu an siparişe kapalı. Ürünleri ve kampanyaları incelemeye devam edebilirsiniz.',
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            initialValue: _branchId,
            decoration: const InputDecoration(
                labelText: 'Teslimat şubesi', prefixIcon: Icon(Icons.store)),
            items: _branches
                .map((branch) => DropdownMenuItem(
                    value: _int(branch['id']),
                    child: Text(branch['name']?.toString() ?? 'Şube')))
                .toList(),
            onChanged: (id) async {
              if (id == null || id == _branchId) return;
              setState(() {
                _branchId = id;
                _cart.clear();
                _category = 'Tümü';
              });
              await _loadProducts();
            },
          ),
          if (_flags.kampanyalar && _campaigns.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _campaigns.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final item = _campaigns[index];
                  return Container(
                    width: 270,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFB91C1C),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title']?.toString() ?? 'Kampanya',
                              maxLines: 1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(item['description']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70)),
                        ]),
                  );
                },
              ),
            ),
          ],
          if (_discountedProducts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'İndirimli Ürünler',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _tab = 3),
                  child: const Text('Tümünü Gör'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 315,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _discountedProducts.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) => SizedBox(
                  width: 205,
                  child: _product(_discountedProducts[index]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Ürün ara'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final category = _categories[index];
                return ChoiceChip(
                    label: Text(category),
                    selected: category == _category,
                    onSelected: (_) => setState(() => _category = category));
              },
            ),
          ),
          const SizedBox(height: 14),
          if (_visibleProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(_error ?? 'Bu şubede uygun ürün bulunmuyor.',
                  textAlign: TextAlign.center),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth >= 600
                        ? 3
                        : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 315,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10),
                  itemCount: _visibleProducts.length,
                  itemBuilder: (_, index) => _product(_visibleProducts[index]),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _product(Map<String, dynamic> product) {
    final id = _int(product['id']);
    final stock = _int(product['stock']);
    final quantity = _quantity(id);
    final price = _double(product['base_price']);
    final original = _double(product['original_price']);
    final image = product['image']?.toString() ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF1F5F9),
              child: image.startsWith('http')
                  ? Image.network(image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.shopping_bag_outlined, size: 48))
                  : const Icon(Icons.shopping_bag_outlined, size: 48),
            ),
          ),
          const SizedBox(height: 8),
          Text(product['name']?.toString() ?? 'Ürün',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Row(children: [
            Text('₺${price.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            if (original > price) ...[
              const SizedBox(width: 6),
              Text('₺${original.toStringAsFixed(2)}',
                  style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.black45))
            ],
          ]),
          if (stock <= 0)
            const SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: null, child: Text('Tükendi')))
          else if (!_flags.sanalMarket)
            const SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: null,
                child: Text('Siparişe kapalı'),
              ),
            )
          else if (quantity == 0)
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () => _changeCart(product, 1),
                    child: const Text('Sepete ekle')))
          else
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                  onPressed: () => _changeCart(product, -1),
                  icon: const Icon(Icons.remove_circle_outline)),
              Text('$quantity',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              IconButton(
                  onPressed:
                      quantity < stock ? () => _changeCart(product, 1) : null,
                  icon: const Icon(Icons.add_circle)),
            ]),
        ]),
      ),
    );
  }

  Widget _basket() {
    if (!_flags.sanalMarket) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _InfoBanner(
            icon: Icons.lock_outline,
            text: 'Sanal Market şu an siparişe kapalı.',
          ),
        ),
      );
    }
    if (_cart.isEmpty) return const Center(child: Text('Sepetiniz boş.'));
    return Column(children: [
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _cart.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, index) {
            final item = _cart[index];
            return ListTile(
              title: Text(item['name']?.toString() ?? 'Ürün'),
              subtitle:
                  Text('₺${_double(item['base_price']).toStringAsFixed(2)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    onPressed: () => _changeCart(item, -1),
                    icon: const Icon(Icons.remove_circle_outline)),
                Text('${_int(item['quantity'])}'),
                IconButton(
                    onPressed: () => _changeCart(item, 1),
                    icon: const Icon(Icons.add_circle_outline)),
              ]),
            );
          },
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _checkout,
                  child: Text(
                      'Siparişi tamamla • ₺${_cartTotal.toStringAsFixed(2)}'))),
        ),
      ),
    ]);
  }

  Future<void> _checkout() async {
    if (!_flags.sanalMarket) {
      _message('Sanal Market şu an siparişe kapalı.', error: true);
      return;
    }
    if (widget.user?['role']?.toString() != 'Customer') {
      _message('Sipariş için müşteri hesabıyla giriş yapın.');
      widget.onOpenLogin?.call();
      return;
    }
    final controller = TextEditingController();
    var busy = false;
    final key = ApiService.createIdempotencyKey();
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          StatefulBuilder(builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Teslimat adresi',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                const Text('Ödeme: Kapıda nakit'),
                const SizedBox(height: 14),
                TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        hintText: 'Mahalle, cadde, bina ve daire bilgisi')),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final address = controller.text.trim();
                            if (address.length < 10) {
                              _message('Açık teslimat adresini girin.',
                                  error: true);
                              return;
                            }
                            setSheetState(() => busy = true);
                            try {
                              await ApiService.createOrder({
                                'branch_id': _branchId,
                                'delivery_address': address,
                                'payment_method': 'Nakit',
                                'items': _cart
                                    .map((line) => {
                                          'product_id': _int(line['id']),
                                          'quantity': _int(line['quantity'])
                                        })
                                    .toList(),
                              }, idempotencyKey: key);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, true);
                              }
                            } catch (error) {
                              if (mounted) {
                                _message(error.toString(), error: true);
                              }
                              if (sheetContext.mounted) {
                                setSheetState(() => busy = false);
                              }
                            }
                          },
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Onayla • ₺${_cartTotal.toStringAsFixed(2)}'),
                  ),
                ),
              ]),
        );
      }),
    );
    controller.dispose();
    if (done == true && mounted) {
      setState(() {
        _cart.clear();
        _tab = 0;
      });
      await _loadProducts();
      if (mounted) _message('Siparişiniz alındı.');
    }
  }

  Widget _account() {
    final user = _currentUser;
    if (user == null) {
      return Center(
          child: FilledButton.icon(
              onPressed: widget.onOpenLogin,
              icon: const Icon(Icons.login),
              label: const Text('Giriş yap')));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.person, color: Color(0xFFDC2626), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name']?.toString() ?? 'TEMA Müşterisi',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          user['phone']?.toString() ?? '',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        if (user['city_district'] != null && user['city_district'].toString().isNotEmpty)
                          Text(
                            user['city_district'].toString(),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFFDC2626)),
                    tooltip: 'Profili Düzenle',
                    onPressed: _showEditProfileDialog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (user['role'] == 'Customer') ...[
        const SizedBox(height: 8),
        _loyaltySection(),
        const SizedBox(height: 8),
        _addressesSection(),
        const SizedBox(height: 8),
        _ordersSection(),
        const SizedBox(height: 8),
        _temaCard(user),
        const SizedBox(height: 12),
        _discountPreferencesCard(),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Kampanya SMS izni'),
          subtitle: const Text(
              'İsteğe bağlıdır; dilediğiniz zaman kapatabilirsiniz.'),
          value: _smsConsent,
          onChanged: _savingConsent ? null : _saveConsent,
        ),
      ],
      ListTile(
        leading: const Icon(Icons.work_outline),
        title: const Text('Kariyer & İş Başvuru Formu'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openJobApplicationModal,
      ),
      ListTile(
        leading: const Icon(Icons.verified_outlined),
        title: const Text('Tema Kasaphane Süreci & Canlı Takip'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openKasaphaneModal,
      ),
      ListTile(
        leading: const Icon(Icons.apartment_outlined),
        title: const Text('Tema Şirketler Grubu (Tema İnşaat vb.)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openCorporateEntitiesModal,
      ),
      ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('KVKK ve gizlilik metni'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => launchUrl(Uri.parse('https://temamarket.com/kvkk'),
            mode: LaunchMode.externalApplication),
      ),
      if (widget.onOpenAdmin != null)
        ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Yönetici paneli'),
            onTap: widget.onOpenAdmin),
      if (widget.onOpenMerchant != null)
        ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Bayi paneli'),
            onTap: widget.onOpenMerchant),
      if (widget.onOpenCourier != null)
        ListTile(
            leading: const Icon(Icons.delivery_dining),
            title: const Text('Kurye paneli'),
            onTap: widget.onOpenCourier),
      const Divider(),
      ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Çıkış yap'),
          onTap: widget.onLogout),
      if (user['role'] == 'Customer') ...[
        const Divider(),
        ListTile(
          key: const Key('delete-account-tile'),
          leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
          title: const Text(
            'Hesabı sil',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Kişisel bilgileriniz kalıcı olarak silinir.'),
          onTap: _deletingAccount ? null : _confirmAccountDeletion,
        ),
      ],
    ]);
  }

  void _showEditProfileDialog() {
    final user = _currentUser;
    final nameCtrl = TextEditingController(text: user?['name']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: user?['email']?.toString() ?? '');
    final districtCtrl = TextEditingController(text: user?['city_district']?.toString() ?? '');
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Profili Düzenle', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'E-posta'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: districtCtrl,
                decoration: const InputDecoration(labelText: 'İlçe / Bölge'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                setDlgState(() => saving = true);
                try {
                  await ApiService.updateFullProfile(
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    cityDistrict: districtCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setState(() {});
                    _message('Profiliniz güncellendi.');
                  }
                } catch (e) {
                  if (mounted) _message(e.toString(), error: true);
                }
              },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loyaltySection() {
    final points = _loyaltyData?['total_points'] ?? _loyaltyData?['points'] ?? 0;
    final tlEquiv = _loyaltyData?['tl_equivalent'];
    final value = tlEquiv is num ? tlEquiv.toDouble() : (points is num ? points / 10.0 : 0.0);
    final history = _loyaltyData?['history'] as List<dynamic>?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text('TemaPuan Bakiyeniz', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$points Puan (₺${value.toStringAsFixed(2)})',
                    style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Her alışverişinizde TemaPuan kazanın, bir sonraki market siparişinizde anında indirim olarak kullanın.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (history != null && history.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Son Puan Hareketleri', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey.shade800)),
              const SizedBox(height: 8),
              ...history.take(3).map((h) {
                final hMap = h is Map ? h : {};
                final hPoints = hMap['points'] ?? 0;
                final hType = hMap['type'] ?? 'Kazanım';
                final hDesc = hMap['description'] ?? '';
                final isPositive = hType == 'Kazanım';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(isPositive ? Icons.add_circle : Icons.remove_circle, size: 16, color: isPositive ? Colors.green : Colors.red),
                      const SizedBox(width: 6),
                      Expanded(child: Text(hDesc.toString(), style: const TextStyle(fontSize: 12))),
                      Text('${isPositive ? '+' : '-'}$hPoints Puan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isPositive ? Colors.green.shade700 : Colors.red.shade700)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _addressesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text('Kayıtlı Adreslerim', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAddAddressDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ekle'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            if (_loadingAccountData)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (_customerAddresses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Henüz kayıtlı adresiniz bulunmuyor.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customerAddresses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final addr = _customerAddresses[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(addr['title']?.toString() ?? 'Adres', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${addr['address'] ?? ''} (${addr['city_district'] ?? ''})'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                      onPressed: () async {
                        final id = _int(addr['id']);
                        if (id > 0) {
                          await ApiService.deleteCustomerAddress(id);
                          _loadAccountData();
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAddAddressDialog() {
    final titleCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final districtCtrl = TextEditingController(text: 'Erzurum');
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Yeni Adres Ekle', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Adres Başlığı (Ev, İş)')),
              const SizedBox(height: 12),
              TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Açık Adres'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'İlçe')),
            ],
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: saving ? null : () async {
                if (titleCtrl.text.trim().isEmpty || addrCtrl.text.trim().isEmpty) return;
                setDlgState(() => saving = true);
                try {
                  await ApiService.addCustomerAddress(
                    title: titleCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
                    cityDistrict: districtCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAccountData();
                } catch (e) {
                  if (mounted) _message(e.toString(), error: true);
                }
              },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Geçmiş Siparişlerim', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingAccountData)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (_customerOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Henüz verilmiş bir siparişiniz yok.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customerOrders.length > 5 ? 5 : _customerOrders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final ord = _customerOrders[i];
                  final status = ord['status']?.toString() ?? 'Hazırlanıyor';
                  final total = _double(ord['total_amount']);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(ord['order_number']?.toString() ?? '#Sipariş', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${ord['created_at'] ?? ''} • ₺${total.toStringAsFixed(2)}'),
                    trailing: Chip(
                      label: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      backgroundColor: status == 'Teslim Edildi' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      side: BorderSide.none,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _temaCard(Map<String, dynamic> user) {
    final phone = user['phone']?.toString() ?? '';
    final cardNo = user['tema_card_number']?.toString().isNotEmpty == true
        ? user['tema_card_number'].toString()
        : temaAvantajCardNumber(phone);
    final displayBarcode =
        cardNo.isNotEmpty ? cardNo : customerPhoneBarcodeValue(phone);
    final formattedCardNo = formatTemaAvantajCardNumber(displayBarcode);

    return Semantics(
      container: true,
      label: 'Tema Avantaj Kart, kart no: $displayBarcode, telefon: $phone',
      child: Container(
        key: const Key('tema-card'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF252B), Color(0xFF991B1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33DC2626),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Tema Avantaj Kart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'VIP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formattedCardNo,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kasada bu barkodu okutarak anında indirim ve puan kazanabilirsiniz.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: displayBarcode.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Barkod için telefon/kart numarası bulunamadı.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: displayBarcode,
                          height: 72,
                          drawText: false,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayBarcode,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discountPreferencesCard() {
    return Card(
      key: const Key('discount-preferences-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kişiselleştirilmiş İndirim Tercihleri',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'İlgilendiğiniz kategorileri seçin; fırsatlar size göre sıralansın.',
            ),
            const SizedBox(height: 12),
            if (_preferenceCategories.isEmpty)
              const Text('Tercih seçenekleri ürünlerle birlikte yüklenecek.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _preferenceCategories.map((category) {
                  final selected = _discountPreferences.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: _savingDiscountPreferences
                        ? null
                        : (value) => setState(() {
                              if (value) {
                                _discountPreferences.add(category);
                              } else {
                                _discountPreferences.remove(category);
                              }
                            }),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _savingDiscountPreferences || _preferenceCategories.isEmpty
                        ? null
                        : _saveDiscountPreferences,
                icon: _savingDiscountPreferences
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Tercihleri Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAccountDeletion() async {
    final controller = TextEditingController();
    var confirmationMatches = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 42,
          ),
          title: const Text('Hesabınız kalıcı olarak silinsin mi?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adresleriniz, iletişim izinleriniz ve hesap bilgileriniz '
                'silinir. Yasal olarak saklanması gereken sipariş kayıtları '
                'kişisel bilgilerinizden arındırılır. Bu işlem geri alınamaz.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Onaylamak için aşağıya SIL yazın.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('delete-account-confirmation-field'),
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'SIL'),
                onChanged: (value) => setDialogState(
                  () =>
                      confirmationMatches = value.trim().toUpperCase() == 'SIL',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              key: const Key('delete-account-confirm'),
              onPressed: confirmationMatches
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hesabı kalıcı olarak sil'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (confirmed != true || !mounted) return;
    setState(() => _deletingAccount = true);
    try {
      await ApiService.deleteAccount();
      if (!mounted) return;
      _cart.clear();
      _message('Hesabınız ve kişisel bilgileriniz silindi.');
      widget.onAccountDeleted?.call();
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Future<void> _saveDiscountPreferences() async {
    setState(() => _savingDiscountPreferences = true);
    try {
      final user = await ApiService.updateProfilePreferences(
        discountPreferences: _discountPreferences.toList()..sort(),
      );
      if (!mounted) return;
      setState(() {
        _discountPreferences =
            parseDiscountPreferences(user['discount_preferences']);
      });
      _message('İndirim tercihleriniz kaydedildi.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingDiscountPreferences = false);
    }
  }

  Future<void> _saveConsent(bool value) async {
    final previous = _smsConsent;
    setState(() {
      _smsConsent = value;
      _savingConsent = true;
    });
    try {
      await ApiService.updateProfilePreferences(smsConsent: value);
      if (mounted) _message('Tercihiniz kaydedildi.');
    } catch (error) {
      if (mounted) {
        setState(() => _smsConsent = previous);
        _message(error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _savingConsent = false);
    }
  }

  void _openBrochureViewer(Map<String, dynamic> brochure) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brochure['title']?.toString() ?? 'Aktüel Broşür',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          brochure['dates']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Image.network(
                      brochure['image']?.toString() ?? '',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 250,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(Icons.menu_book, size: 64, color: Colors.grey),
                        ),
                      ),
                    ),
                    if (brochure['description'] != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          brochure['description'].toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Bu Kampanyadan Alışverişe Başla'),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _showSanalMarketView = true;
                    _tab = 0;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBarcodeDialog(String barcode, String phone) {
    final displayBarcode = barcode.isNotEmpty
        ? barcode
        : (phone.isNotEmpty ? temaAvantajCardNumber(phone) : '');
    if (displayBarcode.isEmpty) return;
    final formattedCardNo = formatTemaAvantajCardNumber(displayBarcode);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 26),
            SizedBox(width: 8),
            Text('Tema Avantaj Kart', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formattedCardNo,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1.5, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kasada bu barkodu okutarak anında indirim kazanın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: displayBarcode,
                    height: 80,
                    drawText: false,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayBarcode,
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _openJobApplicationModal() {
    final nameCtrl = TextEditingController(text: widget.user?['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: widget.user?['phone']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: widget.user?['email']?.toString() ?? '');
    final experienceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedPosition = 'Kasiyer';
    String selectedBranch = _branches.isNotEmpty ? (_branches.first['name']?.toString() ?? 'Merkez') : 'Tüm Şubeler';
    bool submitting = false;

    final positions = [
      'Kasiyer',
      'Reyon Görevlisi',
      'Tema Kasaphane Elemanı / Kasap Ustası',
      'Tema Mandıra / Şarküteri Elemanı',
      'Tema Fırın Ustası / Unlu Mamuller',
      'Depo & Lojistik Sevkiyat',
      'Kurye / Şoför',
      'Mağaza Müdürü / Şef',
      'Tema İnşaat (Mühendis / Mimar / Usta)',
      'Genel Başvuru',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.work_outline_rounded, color: Color(0xFF2563EB), size: 24),
                        SizedBox(width: 8),
                        Text('Kariyer & İş Başvuru Formu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tema Market ve Grup Şirketlerimize katılmak için lütfen aşağıdaki bilgileri eksiksiz doldurunuz.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Ad Soyad *', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon Numarası *', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPosition,
                  decoration: const InputDecoration(labelText: 'Başvurulan Pozisyon *', prefixIcon: Icon(Icons.badge_outlined)),
                  items: positions.map((pos) => DropdownMenuItem(value: pos, child: Text(pos, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedPosition = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBranch,
                  decoration: const InputDecoration(labelText: 'Tercih Edilen Şube', prefixIcon: Icon(Icons.store_outlined)),
                  items: [
                    ..._branches.map((b) => DropdownMenuItem(value: b['name']?.toString() ?? 'Şube', child: Text(b['name']?.toString() ?? 'Şube', style: const TextStyle(fontSize: 13)))),
                    const DropdownMenuItem(value: 'Tüm Şubeler / Farketmez', child: Text('Tüm Şubeler / Farketmez', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedBranch = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: experienceCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Eğitim & Deneyim Özeti', hintText: 'Örn: Lise mezunu, 2 yıl market kasiyerliği tecrübesi...'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Ek Notlar / Açıklama', hintText: 'Varsa sertifikalarınız veya eklemek istedikleriniz...'),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    onPressed: submitting
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              _message('Lütfen ad soyad ve telefon alanlarını doldurunuz.', error: true);
                              return;
                            }
                            setModalState(() => submitting = true);
                            try {
                              await ApiService.submitJobApplication({
                                'full_name': name,
                                'phone': phone,
                                'email': emailCtrl.text.trim(),
                                'position': selectedPosition,
                                'branch': selectedBranch,
                                'experience': experienceCtrl.text.trim(),
                                'notes': notesCtrl.text.trim(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                _message('Başvurunuz başarıyla iletildi! İK ekibimiz sizinle iletişime geçecektir.');
                              }
                            } catch (e) {
                              setModalState(() => submitting = false);
                              if (mounted) _message(e.toString(), error: true);
                            }
                          },
                    child: submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Başvuruyu Gönder', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openKasaphaneModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: ApiService.fetchKasaphaneTracking(),
        builder: (ctx, snapshot) {
          final items = snapshot.data ?? [];
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollCtrl) => Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_outlined, color: Color(0xFFDC2626), size: 26),
                          SizedBox(width: 8),
                          Text('Tema Kasaphane Süreci', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Text(
                      'Veteriner hekimlerimiz kontrolünde kesilen hayvanlarımız, soğuk zincir bozulmadan şubelerimize ulaştırılır. Canlı parti ve sevkiyat durumunu aşağıdan takip edebilirsiniz.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Şu an aktif sevk kaydı bulunmamaktadır.', textAlign: TextAlign.center),
                    )
                  else
                    ...items.map((item) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Parti No: ${item['batch_no'] ?? ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item['delivery_status']?.toString() ?? 'Şubelere Sevk Edildi',
                                        style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _detailRow('Kesim Tarihi:', item['slaughter_date']?.toString() ?? ''),
                                _detailRow('Veteriner Onay No:', item['vet_report_no']?.toString() ?? ''),
                                _detailRow('İlgili Şubeler:', item['branches']?.toString() ?? 'Tüm Şubeler'),
                                if (item['notes']?.toString().isNotEmpty == true)
                                  _detailRow('Açıklama:', item['notes']?.toString() ?? ''),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCorporateEntitiesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: ApiService.fetchCorporateEntities(),
        builder: (ctx, snapshot) {
          final entities = snapshot.data ?? [];
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollCtrl) => Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.apartment_rounded, color: Color(0xFF334155), size: 26),
                          SizedBox(width: 8),
                          Text('Tema Şirketler Grubu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tema güvencesiyle perakendeden inşaata, lojistikten üretime uzanan yatırımlarımız.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (entities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Kayıtlı grup şirketi bulunamadı.', textAlign: TextAlign.center),
                    )
                  else
                    ...entities.map((item) => Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Color(0xFFF1F5F9),
                                      child: Icon(Icons.business_outlined, color: Color(0xFF0F172A), size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title']?.toString() ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                          ),
                                          Text(
                                            item['category']?.toString() ?? 'Grup Şirketi',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item['description']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                                ),
                                if (item['website']?.toString().isNotEmpty == true) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () {
                                      final url = item['website'].toString();
                                      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
                                      launchUrl(uri, mode: LaunchMode.externalApplication);
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(Icons.link, size: 16, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        Text(
                                          item['website'].toString(),
                                          style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, decoration: TextDecoration.underline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;
  const _Empty({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.info_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Tekrar dene')),
        ]),
      );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC2410C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
