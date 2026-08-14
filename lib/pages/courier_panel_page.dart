import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Kurye ekranı yalnızca sunucunun oturumdaki kuryeye atadığı siparişleri
/// gösterir. Harita ve SoftPOS/NFC gibi gerçek entegrasyonu olmayan işlemler
/// bilinçli olarak bu ekranda sunulmaz.
class CourierPanelPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const CourierPanelPage({super.key, this.user, this.onBackToStore});

  @override
  State<CourierPanelPage> createState() => _CourierPanelPageState();
}

class _CourierPanelPageState extends State<CourierPanelPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await ApiService.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = result
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(Map<String, dynamic> order, String status) async {
    final id = _asInt(order['id']);
    if (id <= 0 || _updating.contains(id)) return;
    setState(() => _updating.add(id));
    try {
      await ApiService.updateOrderStatus(id, status);
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sipariş durumu "$status" olarak güncellendi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  int _asInt(dynamic value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;

  double _asDouble(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final role = widget.user?['role']?.toString();
    if (role != 'Courier') {
      return const Scaffold(
        body: Center(child: Text('Bu sayfaya yalnızca kurye hesabı erişebilir.')),
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
            const Text('Kurye Siparişleri', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              widget.user?['name']?.toString() ?? 'Kurye',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
          if (widget.onBackToStore != null)
            IconButton(
              tooltip: 'Mağazaya dön',
              onPressed: widget.onBackToStore,
              icon: const Icon(Icons.storefront_outlined),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _orders.isEmpty) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        actionLabel: 'Tekrar dene',
        onAction: _loadOrders,
      );
    }
    if (_orders.isEmpty) {
      return _MessageState(
        icon: Icons.delivery_dining_outlined,
        message: 'Size atanmış sipariş bulunmuyor.',
        actionLabel: 'Yenile',
        onAction: _loadOrders,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final id = _asInt(order['id']);
    final status = order['status']?.toString() ?? 'Alındı';
    final items = order['items'] is List ? order['items'] as List : const [];
    final isFinished = status == 'Teslim Edildi' || status == 'İptal Edildi';
    final isUpdating = _updating.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['order_number']?.toString() ?? 'Sipariş #$id',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            const Divider(),
            _detail(Icons.person_outline, order['customer_name']?.toString() ?? '-'),
            _detail(Icons.phone_outlined, order['phone']?.toString() ?? '-'),
            _detail(Icons.location_on_outlined, order['delivery_address']?.toString() ?? '-'),
            _detail(
              Icons.shopping_bag_outlined,
              items.isEmpty
                  ? 'Ürün bilgisi yok'
                  : items.map((item) {
                      if (item is! Map) return item.toString();
                      return '${item['quantity'] ?? 1} x ${item['name'] ?? 'Ürün'}';
                    }).join(', '),
            ),
            _detail(
              Icons.payments_outlined,
              '${order['payment_method'] ?? 'Belirtilmedi'} • ${order['payment_status'] ?? 'Bekliyor'} • ₺${_asDouble(order['total_amount']).toStringAsFixed(2)}',
            ),
            if (!isFinished) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isUpdating
                      ? null
                      : () => _setStatus(
                            order,
                            status == 'Kuryede' ? 'Teslim Edildi' : 'Kuryede',
                          ),
                  icon: isUpdating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(status == 'Kuryede' ? Icons.check_circle_outline : Icons.delivery_dining),
                  label: Text(status == 'Kuryede' ? 'Teslim edildi olarak işaretle' : 'Teslimata başla'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _MessageState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: const Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      );
}
