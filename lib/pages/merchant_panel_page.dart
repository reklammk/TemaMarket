import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Bayi paneli yalnızca oturumdaki bayi hesabına atanımış şubenin
/// sipariş, stok ve kurye verilerini gösterir.
class MerchantPanelPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const MerchantPanelPage({super.key, this.user, this.onBackToStore});

  @override
  State<MerchantPanelPage> createState() => _MerchantPanelPageState();
}

class _MerchantPanelPageState extends State<MerchantPanelPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _couriers = [];
  String _productQuery = '';
  final Set<int> _busyOrders = {};

  int get _branchId => _asInt(widget.user?['branch_id']);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _loadData() async {
    if (_branchId <= 0) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Bu bayi hesabına sunucuda bir şube atanmamış.';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.fetchOrders(branchId: _branchId),
        ApiService.fetchProducts(branchId: _branchId),
        ApiService.fetchCouriers(branchId: _branchId),
      ]);
      if (!mounted) return;
      setState(() {
        _orders = _maps(results[0]);
        _products = _maps(results[1]);
        _couriers = _maps(results[2]);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _maps(List<dynamic> values) => values
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();

  Future<void> _editStock(Map<String, dynamic> product) async {
    final productId = _asInt(product['id']);
    final controller =
        TextEditingController(text: '${_asInt(product['stock'])}');
    final newStock = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product['name']?.toString() ?? 'Stok güncelle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Yeni stok adedi'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 0) Navigator.pop(context, value);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newStock == null || productId <= 0) return;

    try {
      await ApiService.updateProductStock(productId, newStock);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stok sunucuda güncellendi.')),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _prepareOrder(Map<String, dynamic> order) async {
    final id = _asInt(order['id']);
    if (id <= 0 || _busyOrders.contains(id)) return;
    setState(() => _busyOrders.add(id));
    try {
      await ApiService.updateOrderStatus(id, 'Hazırlanıyor');
      await _loadData();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busyOrders.remove(id));
    }
  }

  Future<void> _chooseCourier(Map<String, dynamic> order) async {
    if (_couriers.isEmpty) {
      _showError('Bu şubeye atanımış aktif kurye bulunmuyor.');
      return;
    }
    final courier = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Kurye seçin'),
        children: _couriers
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delivery_dining),
                  title: Text(item['name']?.toString() ?? 'Kurye'),
                  subtitle: Text(
                      item['vehicle_type']?.toString() ?? 'Araç belirtilmemiş'),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (courier == null) return;
    final orderId = _asInt(order['id']);
    final courierId = _asInt(courier['id']);
    if (orderId <= 0 || courierId <= 0) return;
    setState(() => _busyOrders.add(orderId));
    try {
      await ApiService.assignCourier(orderId, courierId);
      await _loadData();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busyOrders.remove(orderId));
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user?['role']?.toString() != 'Merchant') {
      return const Scaffold(
        body:
            Center(child: Text('Bu sayfaya yalnızca bayi hesabı erişebilir.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bayi Paneli',
                style: TextStyle(fontWeight: FontWeight.w900)),
            Text(
              widget.user?['company_name']?.toString() ?? 'Atanmış şube',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
              onPressed: _loading ? null : _loadData,
              icon: const Icon(Icons.refresh)),
          if (widget.onBackToStore != null)
            IconButton(
                onPressed: widget.onBackToStore,
                icon: const Icon(Icons.storefront_outlined)),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Siparişler'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stok'),
            Tab(icon: Icon(Icons.delivery_dining_outlined), text: 'Kuryeler'),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _orders.isEmpty && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _orders.isEmpty && _products.isEmpty) {
      return _EmptyState(message: _error!, onRetry: _loadData);
    }
    return TabBarView(
      controller: _tabs,
      children: [_ordersTab(), _stockTab(), _couriersTab()],
    );
  }

  Widget _ordersTab() {
    if (_orders.isEmpty) {
      return _EmptyState(
          message: 'Bu şubeye ait sipariş bulunmuyor.', onRetry: _loadData);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) => _orderCard(_orders[index]),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final id = _asInt(order['id']);
    final status = order['status']?.toString() ?? 'Alındı';
    final busy = _busyOrders.contains(id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['order_number']?.toString() ?? 'Sipariş #$id',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            Text(order['customer_name']?.toString() ?? '-'),
            Text(order['delivery_address']?.toString() ?? '-',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text(
                '₺${_asDouble(order['total_amount']).toStringAsFixed(2)} • ${order['payment_method'] ?? '-'}'),
            if (status == 'Alındı' || status == 'Hazırlanıyor') ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (status == 'Alındı')
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _prepareOrder(order),
                      icon: const Icon(Icons.inventory_outlined),
                      label: const Text('Hazırlamaya başla'),
                    ),
                  FilledButton.icon(
                    onPressed: busy ? null : () => _chooseCourier(order),
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('Kuryeye ata'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stockTab() {
    final query = _productQuery.toLowerCase();
    final visible = _products
        .where((item) =>
            (item['name']?.toString().toLowerCase() ?? '').contains(query))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) => setState(() => _productQuery = value.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Ürün ara',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('Bu şubeye ait ürün bulunmuyor.'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final product = visible[index];
                      final stock = _asInt(product['stock']);
                      return ListTile(
                        leading: CircleAvatar(child: Text('$stock')),
                        title: Text(product['name']?.toString() ?? 'Ürün'),
                        subtitle: Text(
                            '${product['status'] ?? '-'} • ₺${_asDouble(product['base_price']).toStringAsFixed(2)}'),
                        trailing: IconButton(
                          tooltip: 'Stok güncelle',
                          onPressed: () => _editStock(product),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _couriersTab() {
    if (_couriers.isEmpty) {
      return _EmptyState(
          message: 'Bu şubeye atanımış aktif kurye yok.', onRetry: _loadData);
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _couriers.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final courier = _couriers[index];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
            title: Text(courier['name']?.toString() ?? 'Kurye'),
            subtitle: Text(
                courier['vehicle_type']?.toString() ?? 'Araç belirtilmemiş'),
            trailing: Text(courier['status']?.toString() ?? '-'),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _EmptyState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline,
                  size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Yenile')),
            ],
          ),
        ),
      );
}
