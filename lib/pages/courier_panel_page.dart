import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────
//  Veri modeli
// ─────────────────────────────────────────────
class DeliveryOrder {
  final String orderNo;
  final String customer;
  final String phone;
  final String address;
  final String items;
  final double amount;
  final String paymentType; // 'softpos' | 'online' | 'cash'
  final LatLng location;
  String status; // 'pending' | 'on_way' | 'delivered'

  DeliveryOrder({
    required this.orderNo,
    required this.customer,
    required this.phone,
    required this.address,
    required this.items,
    required this.amount,
    required this.paymentType,
    required this.location,
    this.status = 'pending',
  });
}

// ─────────────────────────────────────────────
//  Ana widget
// ─────────────────────────────────────────────
class CourierPanelPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback? onBackToStore;

  const CourierPanelPage({super.key, this.user, this.onBackToStore});

  @override
  State<CourierPanelPage> createState() => _CourierPanelPageState();
}

class _CourierPanelPageState extends State<CourierPanelPage>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  DeliveryOrder? _selectedOrder;
  late TabController _tabController;
  final MapController _mapController = MapController();

  // Erzurum / Aziziye merkez koordinatları
  static const LatLng _center = LatLng(39.9057, 41.2689);

  final List<DeliveryOrder> _orders = [
    DeliveryOrder(
      orderNo: '#TEM-84920',
      customer: 'Zeynep Yılmaz',
      phone: '+90 532 100 2233',
      address: 'Gezköy OSB Mah. 3. Sanayi Cad. No:5 Aziziye / Erzurum',
      items: '2x Dana Kasap Sucuk, 1x Kaşar Peyniri',
      amount: 499.00,
      paymentType: 'softpos',
      location: const LatLng(39.9120, 41.2750),
      status: 'on_way',
    ),
    DeliveryOrder(
      orderNo: '#TEM-84921',
      customer: 'Mehmet Demir',
      phone: '+90 542 200 3344',
      address: 'Cumhuriyet Mah. Atatürk Cad. No:12 Yakutiye / Erzurum',
      items: '1x Hakiki Bal Petek 500g, 3x Amasya Elması',
      amount: 384.70,
      paymentType: 'online',
      location: const LatLng(39.9010, 41.2620),
      status: 'pending',
    ),
    DeliveryOrder(
      orderNo: '#TEM-84922',
      customer: 'Fatma Kaya',
      phone: '+90 505 300 4455',
      address: 'Dadaşkent Mah. Köprübaşı Sok. No:8 Palandöken / Erzurum',
      items: '1x Köy Tereyağı 1kg, 1x Civil Peyniri 500g',
      amount: 560.00,
      paymentType: 'softpos',
      location: const LatLng(39.8940, 41.2580),
      status: 'pending',
    ),
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

  // ── Renk yardımcıları ────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s) {
      case 'on_way':    return const Color(0xFF2563EB);
      case 'delivered': return const Color(0xFF16A34A);
      default:          return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'on_way':    return 'Yolda';
      case 'delivered': return 'Teslim Edildi';
      default:          return 'Bekliyor';
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'on_way':    return Icons.delivery_dining;
      case 'delivered': return Icons.check_circle;
      default:          return Icons.hourglass_bottom;
    }
  }

  Color _paymentColor(String p) {
    switch (p) {
      case 'softpos': return const Color(0xFF7C3AED);
      case 'online':  return const Color(0xFF16A34A);
      default:        return const Color(0xFF64748B);
    }
  }

  String _paymentLabel(String p) {
    switch (p) {
      case 'softpos': return 'Kapıda SoftPOS';
      case 'online':  return 'Online Ödendi';
      default:        return 'Kapıda Nakit';
    }
  }

  // ── Yol tarifi aç ───────────────────────────────────────────────────────
  Future<void> _openNavigation(DeliveryOrder order) async {
    final lat = order.location.latitude;
    final lng = order.location.longitude;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── SoftPOS ödeme ekranı ────────────────────────────────────────────────
  void _showSoftPOS(DeliveryOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SoftPOSSheet(order: order, onSuccess: () {
        Navigator.pop(context);
        setState(() => order.status = 'delivered');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${order.orderNo} teslim edildi ve ₺${order.amount.toStringAsFixed(2)} tahsil edildi.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }),
    );
  }

  // ── Sipariş popup ────────────────────────────────────────────────────────
  void _showOrderPopup(DeliveryOrder order) {
    setState(() => _selectedOrder = order);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderPopupSheet(
        order: order,
        onNavigate: () { Navigator.pop(context); _openNavigation(order); },
        onDeliver: () {
          Navigator.pop(context);
          if (order.paymentType == 'softpos' && order.status != 'delivered') {
            _showSoftPOS(order);
          } else {
            setState(() => order.status = 'delivered');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${order.orderNo} teslim edildi.'), backgroundColor: const Color(0xFF16A34A)),
            );
          }
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pending   = _orders.where((o) => o.status != 'delivered').length;
    final delivered = _orders.where((o) => o.status == 'delivered').length;

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
            const Text('Kurye Paneli', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 16)),
          ],
        ),
        actions: [
          // Online/Offline toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(_isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isOnline ? const Color(0xFF16A34A) : Colors.grey)),
                Switch(
                  value: _isOnline,
                  activeColor: const Color(0xFF16A34A),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() => _isOnline = v),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.home_outlined, color: Color(0xFF0F172A)), onPressed: widget.onBackToStore),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFDC2626),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFDC2626),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.map_outlined, size: 18), text: 'Harita ($pending)'),
            Tab(icon: const Icon(Icons.list_alt_outlined, size: 18), text: 'Teslimatlar'),
          ],
        ),
      ),

      // ── Stats bar ──
      body: Column(
        children: [
          // Özet şeridi
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(icon: Icons.pending_actions, label: 'Bekleyen', value: '$pending', color: const Color(0xFFF59E0B)),
                _StatChip(icon: Icons.delivery_dining, label: 'Yolda', value: '${_orders.where((o) => o.status == "on_way").length}', color: const Color(0xFF2563EB)),
                _StatChip(icon: Icons.check_circle_outline, label: 'Teslim', value: '$delivered', color: const Color(0xFF16A34A)),
                _StatChip(icon: Icons.payments_outlined, label: 'Ciro', value: '₺${_orders.where((o) => o.status == "delivered").fold(0.0, (s, o) => s + o.amount).toStringAsFixed(0)}', color: const Color(0xFFDC2626)),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMapTab(),
                _buildListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HARITA SEKMESİ ────────────────────────────────────────────────────
  Widget _buildMapTab() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 13.5,
        onTap: (_, __) => setState(() => _selectedOrder = null),
      ),
      children: [
        // OpenStreetMap tile katmanı (API key gerektirmez)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.temasan.sanalmarket',
        ),

        // Sipariş işaretçileri
        MarkerLayer(
          markers: _orders.map((order) {
            final isSelected = _selectedOrder?.orderNo == order.orderNo;
            final isDelivered = order.status == 'delivered';
            return Marker(
              point: order.location,
              width: isSelected ? 64 : 48,
              height: isSelected ? 64 : 48,
              child: GestureDetector(
                onTap: () => _showOrderPopup(order),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isDelivered
                        ? const Color(0xFF16A34A)
                        : isSelected
                            ? const Color(0xFFDC2626)
                            : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDelivered
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDelivered
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626))
                            .withValues(alpha: 0.4),
                        blurRadius: isSelected ? 16 : 8,
                        spreadRadius: isSelected ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _statusIcon(order.status),
                    color: isDelivered || isSelected ? Colors.white : const Color(0xFFDC2626),
                    size: isSelected ? 32 : 22,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Kurye konumu (merkez pin)
        MarkerLayer(
          markers: [
            Marker(
              point: _center,
              width: 52,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.5), blurRadius: 12)],
                ),
                child: const Icon(Icons.delivery_dining, color: Colors.white, size: 26),
              ),
            ),
          ],
        ),

        // Kılavuz metni
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text('Sipariş ikonuna tıkla → Teslimat Detayı', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),

        // Zoom butonları
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Color(0xFF0F172A)),
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Color(0xFF0F172A)),
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'center',
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.my_location, color: Colors.white),
                  onPressed: () => _mapController.move(_center, 13.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── LİSTE SEKMESİ ────────────────────────────────────────────────────
  Widget _buildListTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final o = _orders[i];
        return _OrderCard(
          order: o,
          onNavigate: () => _openNavigation(o),
          onDeliver: () {
            if (o.paymentType == 'softpos' && o.status != 'delivered') {
              _showSoftPOS(o);
            } else {
              setState(() => o.status = 'delivered');
            }
          },
          statusColor: _statusColor(o.status),
          statusLabel: _statusLabel(o.status),
          paymentColor: _paymentColor(o.paymentType),
          paymentLabel: _paymentLabel(o.paymentType),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sipariş Popup BottomSheet
// ─────────────────────────────────────────────────────────────────────────────
class _OrderPopupSheet extends StatelessWidget {
  final DeliveryOrder order;
  final VoidCallback onNavigate;
  final VoidCallback onDeliver;

  const _OrderPopupSheet({required this.order, required this.onNavigate, required this.onDeliver});

  @override
  Widget build(BuildContext context) {
    final bool needsPayment = order.paymentType == 'softpos' && order.status != 'delivered';
    final bool isDelivered  = order.status == 'delivered';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(100))),
          ),
          const SizedBox(height: 20),

          // Başlık
          Row(
            children: [
              Text(order.orderNo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
              const Spacer(),
              _StatusPill(label: order.status == 'delivered' ? 'Teslim Edildi' : order.status == 'on_way' ? 'Yolda' : 'Bekliyor',
                          color: order.status == 'delivered' ? const Color(0xFF16A34A) : order.status == 'on_way' ? const Color(0xFF2563EB) : const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 16),

          // Bilgi satırları
          _InfoRow(icon: Icons.person_outline, label: order.customer),
          _InfoRow(icon: Icons.phone_outlined, label: order.phone),
          _InfoRow(icon: Icons.location_on_outlined, label: order.address),
          _InfoRow(icon: Icons.shopping_bag_outlined, label: order.items),
          _InfoRow(
            icon: Icons.payment_outlined,
            label: order.paymentType == 'softpos'
                ? 'Kapıda SoftPOS (NFC) — ₺${order.amount.toStringAsFixed(2)}'
                : order.paymentType == 'online'
                    ? 'Online Ödendi — ₺${order.amount.toStringAsFixed(2)}'
                    : 'Nakit — ₺${order.amount.toStringAsFixed(2)}',
            color: order.paymentType == 'softpos' ? const Color(0xFF7C3AED) : const Color(0xFF16A34A),
          ),

          const SizedBox(height: 24),

          // Butonlar
          Row(
            children: [
              // Yol Tarifi
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Yol Tarifi', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onNavigate,
                ),
              ),
              const SizedBox(width: 12),

              // Teslim Et / SoftPOS
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: Icon(needsPayment ? Icons.point_of_sale : Icons.check_circle_outline, size: 18, color: Colors.white),
                  label: Text(
                    isDelivered
                        ? 'Teslim Edildi'
                        : needsPayment
                            ? 'Teslim Et & SoftPOS Öde'
                            : 'Teslim Et',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDelivered
                        ? const Color(0xFF64748B)
                        : needsPayment
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isDelivered ? null : onDeliver,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SoftPOS BottomSheet
// ─────────────────────────────────────────────────────────────────────────────
class _SoftPOSSheet extends StatefulWidget {
  final DeliveryOrder order;
  final VoidCallback onSuccess;

  const _SoftPOSSheet({required this.order, required this.onSuccess});

  @override
  State<_SoftPOSSheet> createState() => _SoftPOSSheetState();
}

class _SoftPOSSheetState extends State<_SoftPOSSheet>
    with SingleTickerProviderStateMixin {
  // Aşamalar: 'idle' → 'waiting' → 'success' → 'done'
  String _phase = 'idle';
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startNFC() async {
    setState(() => _phase = 'waiting');
    // Simülasyon: 2,5 saniye kart bekleme
    await Future.delayed(const Duration(milliseconds: 2500));
    setState(() => _phase = 'success');
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(100))),
          ),
          const SizedBox(height: 24),

          // Başlık
          const Row(
            children: [
              Icon(Icons.point_of_sale, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TEMA SoftPOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1)),
                  Text('NFC ile Temassız Ödeme', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Tutar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Text('Tahsil Edilecek Tutar', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '₺${widget.order.amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(widget.order.orderNo, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // NFC alanı
          if (_phase == 'idle') ...[
            const Text('Kartı veya telefonu cihaza yaklaştırın', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            // Büyük NFC ikonu
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.contactless, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.nfc, color: Color(0xFF7C3AED)),
                label: const Text('NFC Okumayı Başlat', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                onPressed: _startNFC,
              ),
            ),
          ] else if (_phase == 'waiting') ...[
            const Text('Kart veya telefonu bekliyorum...', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: 4)],
                ),
                child: const Icon(Icons.contactless, color: Colors.white, size: 64),
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ] else if (_phase == 'success') ...[
            const SizedBox(height: 10),
            Container(
              width: 120, height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 20),
            const Text('Ödeme Başarılı!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const Text('Teslimat tamamlandı.', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Yardımcı widget'lar
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, color: color ?? const Color(0xFF334155), fontWeight: color != null ? FontWeight.w700 : FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final VoidCallback onNavigate;
  final VoidCallback onDeliver;
  final Color statusColor;
  final String statusLabel;
  final Color paymentColor;
  final String paymentLabel;

  const _OrderCard({
    required this.order,
    required this.onNavigate,
    required this.onDeliver,
    required this.statusColor,
    required this.statusLabel,
    required this.paymentColor,
    required this.paymentLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDelivered = order.status == 'delivered';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(order.orderNo, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFFDC2626))),
                const Spacer(),
                _StatusPill(label: statusLabel, color: statusColor),
              ],
            ),
            const Divider(height: 16),
            _InfoRow(icon: Icons.person_outline, label: order.customer),
            _InfoRow(icon: Icons.location_on_outlined, label: order.address),
            _InfoRow(icon: Icons.shopping_bag_outlined, label: order.items),
            _InfoRow(icon: Icons.payment_outlined, label: '$paymentLabel — ₺${order.amount.toStringAsFixed(2)}', color: paymentColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.navigation_outlined, size: 16),
                    label: const Text('Yol Tarifi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onNavigate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      isDelivered ? Icons.check_circle : order.paymentType == 'softpos' ? Icons.point_of_sale : Icons.check_circle_outline,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      isDelivered ? 'Teslim Edildi' : order.paymentType == 'softpos' ? 'Teslim Et & SoftPOS' : 'Teslim Et',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDelivered
                          ? const Color(0xFF64748B)
                          : order.paymentType == 'softpos'
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: isDelivered ? null : onDeliver,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
