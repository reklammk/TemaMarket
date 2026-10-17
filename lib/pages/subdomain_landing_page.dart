import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../widgets/tema_logo_painter.dart';

/// Subdomain üzerinde çalışan dinamik sayfa (örn: kasap.temamarket.com, sarkuteri.temamarket.com)
class SubdomainLandingPage extends StatefulWidget {
  final String subdomainSlug;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onBackToMain;
  final VoidCallback? onOpenSanalMarket;

  const SubdomainLandingPage({
    super.key,
    required this.subdomainSlug,
    this.initialData,
    this.onBackToMain,
    this.onOpenSanalMarket,
  });

  @override
  State<SubdomainLandingPage> createState() => _SubdomainLandingPageState();
}

class _SubdomainLandingPageState extends State<SubdomainLandingPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _pageData;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _trackingRecords = [];

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? selected;
      if (widget.initialData != null) {
        selected = widget.initialData;
      } else {
        final pages = await ApiService.fetchSubdomainPages();
        for (final p in pages) {
          if (p is Map &&
              p['subdomain']?.toString().toLowerCase() ==
                  widget.subdomainSlug.toLowerCase()) {
            selected = Map<String, dynamic>.from(p);
            break;
          }
        }
      }

      // Varsayılan eşleşme bulunamazsa ilk varsayılanı kullan
      selected ??= ApiService.defaultSubdomainPages.firstWhere(
        (p) =>
            p['subdomain']?.toString().toLowerCase() ==
            widget.subdomainSlug.toLowerCase(),
        orElse: () => ApiService.defaultSubdomainPages.first,
      );

      final category = selected['category']?.toString();

      // Kategoriye ait ürünleri ve varsa kasaphane takip kayıtlarını çek
      final futures = <Future<dynamic>>[
        ApiService.fetchProducts(category: category),
      ];

      if (widget.subdomainSlug.toLowerCase().contains('kasap')) {
        futures.add(ApiService.fetchKasaphaneTracking());
      }

      final results = await Future.wait(futures);

      final rawProducts = results[0] as List<dynamic>;
      final products = rawProducts
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      List<Map<String, dynamic>> tracking = [];
      if (results.length > 1) {
        final rawTracking = results[1] as List<dynamic>;
        tracking = rawTracking
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _pageData = selected;
        _products = products;
        _trackingRecords = tracking;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _parseColor(String? hexString, Color defaultColor) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    try {
      final hex = hexString.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName) {
      case 'set_meal':
        return Icons.set_meal_rounded;
      case 'egg_alt':
        return Icons.egg_alt_rounded;
      case 'local_drink':
        return Icons.local_drink_rounded;
      case 'bakery_dining':
        return Icons.bakery_dining_rounded;
      case 'grain':
        return Icons.grain_rounded;
      case 'apartment':
        return Icons.apartment_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFDC2626)),
              SizedBox(height: 16),
              Text('Sayfa hazırlanıyor...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final data = _pageData ?? {};
    final title = data['title']?.toString() ?? 'Tema Sayfası';
    final subdomain = data['subdomain']?.toString() ?? widget.subdomainSlug;
    final domain = data['domain']?.toString() ?? '$subdomain.temamarket.com';
    final slogan = data['slogan']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final heroImage = data['hero_image']?.toString() ?? '';
    final customInfo = data['custom_info']?.toString() ?? '';
    final brandColor = _parseColor(data['color_hex']?.toString(), const Color(0xFFDC2626));
    final icon = _parseIcon(data['icon_name']?.toString());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: widget.onBackToMain != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'temamarket.com Ana Sayfasına Dön',
                onPressed: widget.onBackToMain,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HeaderTemaLogo(isSanalMarket: false),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: brandColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                domain,
                style: TextStyle(
                  color: brandColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: widget.onOpenSanalMarket ?? widget.onBackToMain,
            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
            label: const Text('Sanal Market'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ── Hero Banner ──
            _buildHeroBanner(title, slogan, description, heroImage, brandColor, icon, domain),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bilgi / Rozet Şeridi ──
                  if (customInfo.isNotEmpty) ...[
                    _buildInfoStrip(customInfo, brandColor),
                    const SizedBox(height: 20),
                  ],

                  // ── Kasaphane Canlı Sevk Takibi Bölümü (Eğer kasap subdomain ise) ──
                  if (_trackingRecords.isNotEmpty) ...[
                    _buildTrackingSection(brandColor),
                    const SizedBox(height: 24),
                  ],

                  // ── Reyon Ürünleri ──
                  _buildProductsSection(brandColor),
                  const SizedBox(height: 24),

                  // ── Kurumsal Çağrı & İletişim Kartı ──
                  _buildContactCard(brandColor, domain),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(
    String title,
    String slogan,
    String description,
    String heroImage,
    Color brandColor,
    IconData icon,
    String domain,
  ) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        image: heroImage.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(heroImage),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.65),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white30),
                ),
                child: Text(
                  '🌐 $domain',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          if (slogan.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              slogan,
              style: TextStyle(
                color: Colors.amber.shade300,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                label: const Text('Ürünleri İncele & Sipariş Ver', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: widget.onOpenSanalMarket ?? widget.onBackToMain,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.home_outlined, size: 20),
                label: const Text('temamarket.com Ana Sayfası'),
                onPressed: widget.onBackToMain,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStrip(String customInfo, Color brandColor) {
    final items = customInfo.split('•').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        alignment: WrapAlignment.spaceAround,
        children: items
            .map(
              (item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: brandColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    item,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTrackingSection(Color brandColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_outlined, color: brandColor, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Canlı Çiftlik & Sevk Takibi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Veteriner hekimlerimizce denetlenen kesim ve soğuk hava zinciriyle şubelerimize sevk edilen partilerimiz.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        ..._trackingRecords.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
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
                    const Divider(height: 14),
                    _subdomainDetailRow('Kesim Tarihi:', item['slaughter_date']?.toString() ?? '-'),
                    _subdomainDetailRow('Veteriner Onay No:', item['vet_report_no']?.toString() ?? '-'),
                    _subdomainDetailRow('Sevk Şubeleri:', item['branches']?.toString() ?? 'Tüm Şubeler'),
                    if (item['notes']?.toString().isNotEmpty == true)
                      _subdomainDetailRow('Notlar:', item['notes']?.toString() ?? ''),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildProductsSection(Color brandColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: brandColor, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Öne Çıkan Ürünlerimiz',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            if (widget.onOpenSanalMarket != null)
              TextButton(
                onPressed: widget.onOpenSanalMarket,
                child: const Text('Tümünü Gör'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_products.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'Bu reyon için listelenen taze ürünler Sanal Market reyonlarında güncelleniyor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
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
                  mainAxisExtent: 260,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _products.take(8).length,
                itemBuilder: (_, index) {
                  final prod = _products[index];
                  final name = prod['name']?.toString() ?? 'Ürün';
                  final price = double.tryParse(prod['base_price']?.toString() ?? '') ?? 0.0;
                  final image = prod['image']?.toString() ?? '';

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: const Color(0xFFF1F5F9),
                            child: image.isNotEmpty
                                ? Image.network(
                                    image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.image_outlined, size: 36, color: Colors.grey),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_outlined, size: 36, color: Colors.grey),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₺${price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: brandColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                height: 30,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: widget.onOpenSanalMarket ?? widget.onBackToMain,
                                  child: const Text('Sipariş Ver', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildContactCard(Color brandColor, String domain) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.headset_mic_outlined, color: brandColor, size: 22),
              const SizedBox(width: 8),
              Text(
                '$domain İletişim & Destek',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Sorularınız, toptan siparişleriniz veya şube teslimat detayları için müşteri temsilcimizle görüşebilirsiniz.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('0850 300 00 00'),
                  onPressed: () => launchUrl(Uri.parse('tel:08503000000')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('WhatsApp'),
                  onPressed: () => launchUrl(Uri.parse('https://wa.me/905300000000')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subdomainDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
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
