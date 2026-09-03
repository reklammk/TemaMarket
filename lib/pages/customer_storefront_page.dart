import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/feature_flags_service.dart';
import '../utils/customer_profile_utils.dart';

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
  final List<Map<String, dynamic>> _cart = [];

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
      ]);
      if (!mounted) return;
      final branches = _maps(result[1] as List<dynamic>);
      setState(() {
        _flags = result[0] as FeatureFlags;
        _branches = branches;
        _campaigns = _maps(result[2] as List<dynamic>);
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

  List<String> get _categories => [
        'Tümü',
        ...(_products
            .map((p) => p['sub_brand']?.toString() ?? 'Genel')
            .toSet()
            .toList()
          ..sort()),
      ];

  List<Map<String, dynamic>> get _visibleProducts {
    final query = _search.trim().toLowerCase();
    return _products.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? '';
      final category = product['sub_brand']?.toString() ?? 'Genel';
      return (_category == 'Tümü' || category == _category) &&
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
          title: Image.asset(
            'assets/logo.png',
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'TEMA Market',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          actions: [
            IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh))
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
        return _market();
    }
  }

  void _handleNavTap(int index) {
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
          const Text(
            'Sizin İçin',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
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
          else if (_campaigns.isEmpty)
            const _InfoBanner(
              icon: Icons.auto_awesome_outlined,
              text: 'Şu anda aktif kampanya bulunmuyor.',
            )
          else
            ..._campaigns.map(
              (campaign) => Card(
                color: const Color(0xFFB91C1C),
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
          if (discounted.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'İndirimli Ürünler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
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
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('KVKK ve gizlilik metni'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => launchUrl(Uri.parse('https://temasanalmarket.com/kvkk'),
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
    final barcodeValue = customerPhoneBarcodeValue(phone);
    return Semantics(
      container: true,
      label: 'TEMA Kart, müşteri telefonu $phone',
      child: Container(
        key: const Key('tema-card'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF252B), Color(0xFFB91C1C)],
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
            const Row(
              children: [
                Icon(Icons.credit_card_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'TEMA Kart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Kasada bu barkodu okutabilirsiniz.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: barcodeValue.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Barkod için telefon numarası bulunamadı.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: barcodeValue,
                          height: 72,
                          drawText: false,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
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
