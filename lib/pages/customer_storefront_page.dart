import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/feature_flags_service.dart';
import '../widgets/tema_logo_painter.dart';

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
  bool _loading = true;
  bool _savingConsent = false;
  String? _error;
  int _tab = 0;
  int? _branchId;
  String _category = 'Tümü';
  String _search = '';
  bool _smsConsent = false;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _campaigns = [];
  final List<Map<String, dynamic>> _cart = [];

  @override
  void initState() {
    super.initState();
    _smsConsent = _bool(widget.user?['sms_consent']);
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerStorefrontPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?['id'] != widget.user?['id']) {
      _smsConsent = _bool(widget.user?['sms_consent']);
      if (widget.user == null) _cart.clear();
    }
  }

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
    if (_branchId == null || !_flags.sanalMarket) {
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

  int _quantity(int id) {
    final item = _cart.where((line) => _int(line['id']) == id);
    return item.isEmpty ? 0 : _int(item.first['quantity']);
  }

  void _changeCart(Map<String, dynamic> product, int delta) {
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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Row(
            children: [
              TemaLogoPainter(size: 36),
              SizedBox(width: 10),
              Expanded(child: Text('TEMA Sanal Market')),
            ],
          ),
          actions: [
            IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: IndexedStack(
            index: _tab, children: [_market(), _basket(), _account()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.storefront_outlined), label: 'Market'),
            NavigationDestination(
              icon: Badge(
                  isLabelVisible: _cartCount > 0,
                  label: Text('$_cartCount'),
                  child: const Icon(Icons.shopping_cart_outlined)),
              label: 'Sepet',
            ),
            const NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Hesabım'),
          ],
        ),
      );

  Widget _market() {
    if (_loading && _branches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_flags.sanalMarket) {
      return _Empty(
          message: 'Sanal market geçici olarak kapalı.', retry: _load);
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
    final user = widget.user;
    if (user == null) {
      return Center(
          child: FilledButton.icon(
              onPressed: widget.onOpenLogin,
              icon: const Icon(Icons.login),
              label: const Text('Giriş yap')));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
          child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(user['name']?.toString() ?? 'TEMA Kullanıcısı'),
        subtitle: Text('${user['phone'] ?? ''}\n${user['role'] ?? ''}'),
        isThreeLine: true,
      )),
      if (user['role'] == 'Customer')
        SwitchListTile(
          title: const Text('Kampanya SMS izni'),
          subtitle: const Text(
              'İsteğe bağlıdır; dilediğiniz zaman kapatabilirsiniz.'),
          value: _smsConsent,
          onChanged: _savingConsent ? null : _saveConsent,
        ),
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
    ]);
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
