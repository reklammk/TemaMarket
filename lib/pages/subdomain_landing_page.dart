import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../widgets/tema_logo_painter.dart';

/// Subdomain üzerinde çalışan dinamik ve sürükle-bırak editörle özelleştirilebilir sayfa
/// (örn: kasap.temasan.com, sarkuteri.temasan.com, mandira.temasan.com)
class SubdomainLandingPage extends StatefulWidget {
  final String subdomainSlug;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onBackToMain;
  final VoidCallback? onOpenSanalMarket;

  /// Yönetici görsel editörü içinde canlı önizleme ve sürükle-bırak modunda mı?
  final bool isEditorMode;
  final String? selectedSectionId;
  final String? selectedElementId;
  final ValueChanged<String>? onSelectSection;
  final ValueChanged<String>? onSelectElement;
  final void Function(int oldIndex, int newIndex)? onReorderSections;
  final void Function(int targetIndex, Map<String, dynamic> blockData)?
      onDropNewBlock;
  final void Function(String sectionId)? onDeleteSection;
  final void Function(String sectionId)? onToggleSectionVisibility;
  final void Function(String elementKey, Offset delta)? onDragHeroElement;
  final void Function(String elementId, Offset delta)? onDragFloatingElement;
  final void Function(int sectionIndex, Map<String, dynamic> elementData,
      Offset localDropOffset)? onDropFloatingElement;
  final void Function(String elementId)? onDeleteFloatingElement;

  const SubdomainLandingPage({
    super.key,
    required this.subdomainSlug,
    this.initialData,
    this.onBackToMain,
    this.onOpenSanalMarket,
    this.isEditorMode = false,
    this.selectedSectionId,
    this.selectedElementId,
    this.onSelectSection,
    this.onSelectElement,
    this.onReorderSections,
    this.onDropNewBlock,
    this.onDeleteSection,
    this.onToggleSectionVisibility,
    this.onDragHeroElement,
    this.onDragFloatingElement,
    this.onDropFloatingElement,
    this.onDeleteFloatingElement,
  });

  /// Varsayılan sayfa bölümlerini döndürür
  static List<Map<String, dynamic>> defaultSectionsFor(
      Map<String, dynamic> pageData) {
    final raw = pageData['sections'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final sub = (pageData['subdomain']?.toString() ?? '').toLowerCase();
    final hasTracking = sub.contains('kasap');
    return [
      {
        'id': 'sec_hero',
        'type': 'hero_banner',
        'title': 'Hero Kapak & Serbest Sürükleme Alanı',
        'visible': true,
      },
      {
        'id': 'sec_info',
        'type': 'info_strip',
        'title': 'Güvence & Özellik Rozet Şeridi',
        'visible': true,
      },
      if (hasTracking)
        {
          'id': 'sec_tracking',
          'type': 'tracking',
          'title': 'Canlı Çiftlik & Sevk Takibi',
          'visible': true,
        },
      {
        'id': 'sec_products',
        'type': 'products',
        'title': 'Öne Çıkan Reyon Ürünleri',
        'visible': true,
        'columns': 3,
      },
      {
        'id': 'sec_contact',
        'type': 'contact',
        'title': 'İletişim & WhatsApp Destek Kartı',
        'visible': true,
      },
    ];
  }

  @override
  State<SubdomainLandingPage> createState() => _SubdomainLandingPageState();
}

class _SubdomainLandingPageState extends State<SubdomainLandingPage> {
  bool _loading = true;
  Map<String, dynamic>? _pageData;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _trackingRecords = [];
  List<Map<String, dynamic>> _mediaItems = [];

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didUpdateWidget(covariant SubdomainLandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != null) {
      _pageData = widget.initialData;
      final oldCat = oldWidget.initialData?['category']?.toString();
      final newCat = widget.initialData?['category']?.toString();
      if (oldCat != newCat) {
        _loadCategoryProducts(newCat);
      }
    } else if (oldWidget.subdomainSlug != widget.subdomainSlug) {
      _loadPage();
    }
  }

  Future<void> _loadCategoryProducts(String? category) async {
    try {
      final rawProducts = await ApiService.fetchProducts(category: category);
      if (!mounted) return;
      setState(() {
        _products = rawProducts
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
    });

    try {
      Map<String, dynamic>? selected;
      if (widget.initialData != null) {
        selected = Map<String, dynamic>.from(widget.initialData!);
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

      selected ??= Map<String, dynamic>.from(
        ApiService.defaultSubdomainPages.firstWhere(
          (p) =>
              p['subdomain']?.toString().toLowerCase() ==
              widget.subdomainSlug.toLowerCase(),
          orElse: () => ApiService.defaultSubdomainPages.first,
        ),
      );

      final category = selected['category']?.toString();

      final results = await Future.wait<dynamic>([
        ApiService.fetchProducts(category: category),
        ApiService.fetchKasaphaneTracking(),
        ApiService.fetchKasaphaneMedia(),
      ]);

      final rawProducts = results[0] as List<dynamic>;
      final products = rawProducts
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final rawTracking = results[1] as List<dynamic>;
      final tracking = rawTracking
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final rawMedia = results[2] as List<dynamic>;
      final media = rawMedia
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _pageData = selected;
        _products = products;
        _trackingRecords = tracking;
        _mediaItems = media;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pageData = widget.initialData ??
            Map<String, dynamic>.from(ApiService.defaultSubdomainPages.first);
        _loading = false;
      });
    }
  }

  Color _parseColor(String? hexString, Color defaultColor) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    try {
      final hex = hexString.replaceAll('#', '').trim();
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
      return defaultColor;
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
      case 'eco':
        return Icons.eco_rounded;
      case 'local_offer':
        return Icons.local_offer_rounded;
      case 'verified':
        return Icons.verified_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }

  Offset _getHeroElementOffset(Map<String, dynamic> data, String key) {
    final positions = data['element_positions'];
    if (positions is Map && positions[key] is Map) {
      final m = positions[key] as Map;
      final dx = (m['dx'] is num) ? (m['dx'] as num).toDouble() : 0.0;
      final dy = (m['dy'] is num) ? (m['dy'] as num).toDouble() : 0.0;
      return Offset(dx, dy);
    }
    return Offset.zero;
  }

  List<Map<String, dynamic>> _getFloatingElements(Map<String, dynamic> data) {
    final raw = data['floating_elements'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _pageData == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFDC2626)),
              SizedBox(height: 16),
              Text('Sayfa hazırlanıyor...',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final data = widget.initialData ?? _pageData ?? {};
    final title = data['title']?.toString() ?? 'Tema Sayfası';
    final subdomain = data['subdomain']?.toString() ?? widget.subdomainSlug;
    final domain = data['domain']?.toString() ?? '$subdomain.temasan.com';
    final brandColor =
        _parseColor(data['color_hex']?.toString(), const Color(0xFFDC2626));
    final sections = SubdomainLandingPage.defaultSectionsFor(data);
    final floatingElements = _getFloatingElements(data);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.isEditorMode,
        leading: (!widget.isEditorMode && widget.onBackToMain != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'temasan.com Ana Sayfasına Dön',
                onPressed: widget.onBackToMain,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HeaderTemaLogo(isSanalMarket: false),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: brandColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  domain,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: brandColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
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
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626)),
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
            if (widget.isEditorMode) _buildDropZone(0, brandColor),
            for (int i = 0; i < sections.length; i++) ...[
              if (sections[i]['visible'] != false || widget.isEditorMode)
                _buildSectionWrapper(
                  context,
                  index: i,
                  totalCount: sections.length,
                  section: sections[i],
                  pageData: data,
                  brandColor: brandColor,
                  title: title,
                  domain: domain,
                  floatingElements: floatingElements
                      .where((el) =>
                          (el['section_id']?.toString() ??
                              sections.first['id']) ==
                          sections[i]['id']?.toString())
                      .toList(),
                ),
              if (widget.isEditorMode) _buildDropZone(i + 1, brandColor),
            ],
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  /// Editör modunda blokların arasına sürükle-bırak hedef alanı
  Widget _buildDropZone(int targetIndex, Color brandColor) {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) =>
          details.data['drag_kind'] == 'new_block' ||
          details.data['drag_kind'] == 'move_section',
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload['drag_kind'] == 'move_section') {
          final fromIdx = payload['from_index'] as int? ?? 0;
          widget.onReorderSections?.call(fromIdx, targetIndex);
        } else if (payload['drag_kind'] == 'new_block') {
          widget.onDropNewBlock?.call(targetIndex, payload);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: isHovering ? 58 : 18,
          margin: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isHovering ? 6 : 2,
          ),
          decoration: BoxDecoration(
            color: isHovering
                ? brandColor.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isHovering
                ? Border.all(color: brandColor, width: 2)
                : Border.all(
                    color: const Color(0xFFCBD5E1).withValues(alpha: 0.5),
                    width: 1,
                  ),
          ),
          child: Center(
            child: isHovering
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle, color: brandColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Bloğu Bu Alana Bırakın',
                        style: TextStyle(
                          color: brandColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : Container(
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSectionWrapper(
    BuildContext context, {
    required int index,
    required int totalCount,
    required Map<String, dynamic> section,
    required Map<String, dynamic> pageData,
    required Color brandColor,
    required String title,
    required String domain,
    required List<Map<String, dynamic>> floatingElements,
  }) {
    final secId = section['id']?.toString() ?? 'sec_$index';
    final secType = section['type']?.toString() ?? 'custom_text';
    final isVisible = section['visible'] != false;
    final isSelected =
        widget.isEditorMode && widget.selectedSectionId == secId;

    Widget content = _buildSectionContent(
      section: section,
      pageData: pageData,
      brandColor: brandColor,
      title: title,
      domain: domain,
    );

    if (secType != 'hero_banner') {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: content,
      );
    }

    // Bölüm üzerine serbest sürüklenebilir elemanlar (floating_elements) eklenebilmesi için Stack + DragTarget
    final stackKey = GlobalKey();
    Widget interactiveArea = DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) =>
          widget.isEditorMode &&
          (details.data['drag_kind'] == 'floating_element' ||
              details.data['drag_kind'] == 'new_block' ||
              details.data['drag_kind'] == 'move_section'),
      onAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload['drag_kind'] == 'floating_element') {
          final box =
              stackKey.currentContext?.findRenderObject() as RenderBox?;
          final localPos = box != null
              ? box.globalToLocal(details.offset)
              : const Offset(40, 40);
          widget.onDropFloatingElement?.call(index, payload, localPos);
        } else if (payload['drag_kind'] == 'move_section') {
          final fromIdx = payload['from_index'] as int? ?? 0;
          if (fromIdx != index) {
            widget.onReorderSections?.call(fromIdx, index);
          }
        } else if (payload['drag_kind'] == 'new_block') {
          widget.onDropNewBlock?.call(index + 1, payload);
        }
      },
      builder: (ctx, candidates, _) {
        final hoveringCanvas = candidates.isNotEmpty;
        return Stack(
          key: stackKey,
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: isVisible ? 1.0 : 0.4,
              child: content,
            ),
            // Bu bölüme ait serbest sürüklenen elemanlar
            ...floatingElements.map((el) => _buildFloatingElementWidget(
                  el,
                  brandColor,
                )),
            if (hoveringCanvas)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.08),
                      border: Border.all(color: brandColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (!widget.isEditorMode) {
      return interactiveArea;
    }

    return GestureDetector(
      onTap: () => widget.onSelectSection?.call(secId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? brandColor
                : const Color(0xFF94A3B8).withValues(alpha: 0.35),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Editör Bölüm Başlığı ve Sürükleme Çubuğu
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? brandColor : const Color(0xFF0F172A),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  // Sürükle-Taşı tutamacı
                  Draggable<Map<String, dynamic>>(
                    data: {
                      'drag_kind': 'move_section',
                      'from_index': index,
                      'section_id': secId,
                    },
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF0F172A),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.drag_indicator,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              section['title']?.toString() ?? 'Bölüm Taşınıyor',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.drag_indicator,
                              color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Sürükle',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${index + 1}. ${section['title'] ?? secType}'
                      '${!isVisible ? ' (Gizli)' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28),
                    icon: const Icon(Icons.arrow_upward,
                        color: Colors.white, size: 16),
                    tooltip: 'Yukarı Taşı',
                    onPressed: index > 0
                        ? () => widget.onReorderSections?.call(index, index - 1)
                        : null,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28),
                    icon: const Icon(Icons.arrow_downward,
                        color: Colors.white, size: 16),
                    tooltip: 'Aşağı Taşı',
                    onPressed: index < totalCount - 1
                        ? () => widget.onReorderSections?.call(index, index + 2)
                        : null,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28),
                    icon: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    tooltip: isVisible ? 'Gizle' : 'Göster',
                    onPressed: () =>
                        widget.onToggleSectionVisibility?.call(secId),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 16),
                    tooltip: 'Bloğu Kaldır',
                    onPressed: () => widget.onDeleteSection?.call(secId),
                  ),
                ],
              ),
            ),
            interactiveArea,
          ],
        ),
      ),
    );
  }

  /// Sayfa üzerinde herhangi bir koordinata (dx, dy) serbestçe sürüklenebilen eleman
  Widget _buildFloatingElementWidget(
    Map<String, dynamic> el,
    Color brandColor,
  ) {
    final elId = el['id']?.toString() ?? '';
    final dx = (el['dx'] is num) ? (el['dx'] as num).toDouble() : 24.0;
    final dy = (el['dy'] is num) ? (el['dy'] as num).toDouble() : 24.0;
    final kind = el['element_type']?.toString() ?? 'badge';
    final text = el['text']?.toString() ?? 'Özel Etiket';
    final subtext = el['subtext']?.toString() ?? '';
    final imageUrl = el['image_url']?.toString() ?? '';
    final bgColor = _parseColor(el['color_hex']?.toString(), brandColor);
    final isSelected =
        widget.isEditorMode && widget.selectedElementId == elId;

    Widget badgeChild;
    switch (kind) {
      case 'button':
        badgeChild = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.bolt_rounded, size: 18),
          label:
              Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
          onPressed: widget.isEditorMode
              ? () => widget.onSelectElement?.call(elId)
              : (widget.onOpenSanalMarket ?? widget.onBackToMain),
        );
        break;
      case 'price_card':
        badgeChild = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bgColor, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF0F172A)),
              ),
              if (subtext.isNotEmpty)
                Text(
                  subtext,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: bgColor),
                ),
            ],
          ),
        );
        break;
      case 'image_box':
        badgeChild = Container(
          width: 140,
          height: 95,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
            image: imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(imageUrl), fit: BoxFit.cover)
                : null,
          ),
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        );
        break;
      case 'text_box':
        badgeChild = Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xE60F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14),
              ),
              if (subtext.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ],
          ),
        );
        break;
      case 'badge':
      default:
        badgeChild = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(100),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
    }

    return Positioned(
      left: dx.clamp(0.0, 900.0),
      top: dy.clamp(0.0, 900.0),
      child: GestureDetector(
        onTap: widget.isEditorMode
            ? () => widget.onSelectElement?.call(elId)
            : null,
        onPanUpdate: widget.isEditorMode
            ? (details) {
                widget.onSelectElement?.call(elId);
                widget.onDragFloatingElement?.call(elId, details.delta);
              }
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: widget.isEditorMode
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? Colors.amber : Colors.white54,
                        width: isSelected ? 2.5 : 1,
                      ),
                    )
                  : null,
              child: badgeChild,
            ),
            if (widget.isEditorMode)
              Positioned(
                right: -10,
                top: -10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.open_with,
                          size: 12, color: Colors.amber),
                    ),
                    if (isSelected && widget.onDeleteFloatingElement != null)
                      GestureDetector(
                        onTap: () =>
                            widget.onDeleteFloatingElement?.call(elId),
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: Colors.white),
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

  Widget _buildSectionContent({
    required Map<String, dynamic> section,
    required Map<String, dynamic> pageData,
    required Color brandColor,
    required String title,
    required String domain,
  }) {
    final type = section['type']?.toString() ?? 'custom_text';
    final slogan = pageData['slogan']?.toString() ?? '';
    final description = pageData['description']?.toString() ?? '';
    final heroImage = pageData['hero_image']?.toString() ?? '';
    final customInfo = pageData['custom_info']?.toString() ?? '';
    final ctaText =
        pageData['cta_text']?.toString() ?? 'Ürünleri İncele & Sipariş Ver';
    final icon = _parseIcon(pageData['icon_name']?.toString());

    switch (type) {
      case 'hero_banner':
        return _buildHeroBanner(
          pageData: pageData,
          title: section['custom_title']?.toString().isNotEmpty == true
              ? section['custom_title'].toString()
              : title,
          slogan: section['custom_subtitle']?.toString().isNotEmpty == true
              ? section['custom_subtitle'].toString()
              : slogan,
          description:
              section['custom_description']?.toString().isNotEmpty == true
                  ? section['custom_description'].toString()
                  : description,
          heroImage: section['image_url']?.toString().isNotEmpty == true
              ? section['image_url'].toString()
              : heroImage,
          brandColor: brandColor,
          icon: icon,
          domain: domain,
          ctaText: ctaText,
        );
      case 'info_strip':
        final infoText =
            section['custom_description']?.toString().isNotEmpty == true
                ? section['custom_description'].toString()
                : (customInfo.isNotEmpty
                    ? customInfo
                    : 'Helal & Güvenilir • Günlük Taze Sevkiyat • Yerli Üretim');
        return _buildInfoStrip(infoText, brandColor);
      case 'tracking':
        return _buildTrackingSection(brandColor, section);
      case 'products':
        return _buildProductsSection(brandColor, section);
      case 'promo_banner':
        return _buildPromoBannerSection(brandColor, section);
      case 'media_showcase':
        return _buildMediaShowcaseSection(brandColor, section);
      case 'free_canvas':
        return _buildFreeCanvasSection(brandColor, section);
      case 'features_grid':
        return _buildFeaturesGridSection(brandColor, section);
      case 'contact':
        return _buildContactCard(brandColor, domain, section);
      case 'custom_text':
      default:
        return _buildCustomTextSection(brandColor, section);
    }
  }

  /// Serbest sürüklenebilir eleman sarmalayıcı (Hero içindeki Başlık, Slogan, Buton vb. için)
  Widget _wrapDraggableHeroElement({
    required Map<String, dynamic> pageData,
    required String elementKey,
    required String label,
    required Widget child,
  }) {
    final offset = _getHeroElementOffset(pageData, elementKey);
    final isSelected =
        widget.isEditorMode && widget.selectedElementId == elementKey;

    if (!widget.isEditorMode) {
      return Transform.translate(offset: offset, child: child);
    }

    return Transform.translate(
      offset: offset,
      child: GestureDetector(
        onTap: () => widget.onSelectElement?.call(elementKey),
        onPanUpdate: (details) {
          widget.onSelectElement?.call(elementKey);
          widget.onDragHeroElement?.call(elementKey, details.delta);
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Colors.amber
                  : Colors.white.withValues(alpha: 0.35),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? Colors.amber.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              Positioned(
                right: -6,
                top: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber
                        : const Color(0xCC0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_with,
                        size: 11,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner({
    required Map<String, dynamic> pageData,
    required String title,
    required String slogan,
    required String description,
    required String heroImage,
    required Color brandColor,
    required IconData icon,
    required String domain,
    required String ctaText,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        image: heroImage.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(heroImage),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.62),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(22, 32, 22, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _wrapDraggableHeroElement(
            pageData: pageData,
            elementKey: 'hero_badge',
            label: 'Rozet (Sürükle)',
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(
                    domain,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _wrapDraggableHeroElement(
            pageData: pageData,
            elementKey: 'hero_title',
            label: 'Başlık (Sürükle)',
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (slogan.isNotEmpty) ...[
            const SizedBox(height: 6),
            _wrapDraggableHeroElement(
              pageData: pageData,
              elementKey: 'hero_slogan',
              label: 'Slogan (Sürükle)',
              child: Text(
                slogan,
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            _wrapDraggableHeroElement(
              pageData: pageData,
              elementKey: 'hero_description',
              label: 'Açıklama (Sürükle)',
              child: ConstrainedBox(
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
            ),
          ],
          const SizedBox(height: 20),
          _wrapDraggableHeroElement(
            pageData: pageData,
            elementKey: 'hero_cta',
            label: 'Butonlar (Sürükle)',
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                  label: Text(ctaText,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: widget.onOpenSanalMarket ?? widget.onBackToMain,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: const Text('temasan.com Ana Sayfası'),
                  onPressed: widget.onBackToMain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStrip(String customInfo, Color brandColor) {
    final items = customInfo
        .split('•')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTrackingSection(
      Color brandColor, Map<String, dynamic> section) {
    final secTitle = section['custom_title']?.toString().isNotEmpty == true
        ? section['custom_title'].toString()
        : 'Canlı Çiftlik & Sevk Takibi';
    final records = _trackingRecords.isNotEmpty
        ? _trackingRecords
        : ApiService.defaultKasaphaneFallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_outlined, color: brandColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                secTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          section['custom_subtitle']?.toString().isNotEmpty == true
              ? section['custom_subtitle'].toString()
              : 'Veteriner hekimlerimizce denetlenen kesim ve soğuk hava zinciriyle şubelerimize sevk edilen partilerimiz.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        ...records.map((item) => Card(
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
                          'Parti No: ${item['batch_no'] ?? item['lot_no'] ?? ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['delivery_status']?.toString() ??
                                item['status']?.toString() ??
                                'Şubelere Sevk Edildi',
                            style: const TextStyle(
                                color: Color(0xFF166534),
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    _subdomainDetailRow(
                      'Kesim Tarihi:',
                      item['slaughter_date']?.toString() ??
                          item['date']?.toString() ??
                          '-',
                    ),
                    _subdomainDetailRow(
                      'Çiftlik / Tesis:',
                      item['farm']?.toString() ?? 'TEMA Besi Çiftliği',
                    ),
                    _subdomainDetailRow(
                      'Veteriner Onay No:',
                      item['vet_report_no']?.toString() ??
                          item['vet_report']?.toString() ??
                          '-',
                    ),
                    _subdomainDetailRow(
                      'Sevk Şubeleri:',
                      item['branches']?.toString() ?? 'Tüm Şubeler',
                    ),
                    if ((item['notes'] ?? item['note'])
                            ?.toString()
                            .isNotEmpty ==
                        true)
                      _subdomainDetailRow(
                        'Notlar:',
                        (item['notes'] ?? item['note'])?.toString() ?? '',
                      ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildProductsSection(
      Color brandColor, Map<String, dynamic> section) {
    final secTitle = section['custom_title']?.toString().isNotEmpty == true
        ? section['custom_title'].toString()
        : 'Öne Çıkan Ürünlerimiz';
    final preferredCols = section['columns'] is num
        ? (section['columns'] as num).toInt()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      color: brandColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      secTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
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
              final columns = preferredCols >= 2 && preferredCols <= 4
                  ? (constraints.maxWidth < 520 ? 2 : preferredCols)
                  : (constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                          ? 3
                          : 2);
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
                  final price = double.tryParse(
                          prod['base_price']?.toString() ?? '') ??
                      0.0;
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
                                      child: Icon(Icons.image_outlined,
                                          size: 36, color: Colors.grey),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_outlined,
                                        size: 36, color: Colors.grey),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13),
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
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: widget.onOpenSanalMarket ??
                                      widget.onBackToMain,
                                  child: const Text(
                                    'Sipariş Ver',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
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

  Widget _buildPromoBannerSection(
      Color brandColor, Map<String, dynamic> section) {
    final promoTitle = section['custom_title']?.toString().isNotEmpty == true
        ? section['custom_title'].toString()
        : 'Haftanın Özel Reyon Kampanyası';
    final promoSub = section['custom_subtitle']?.toString().isNotEmpty == true
        ? section['custom_subtitle'].toString()
        : 'Tema Avantaj Kart sahiplerine özel tüm reyon ürünlerinde anında %20 indirim ve ekstra TemaPuan!';
    final badgeText = section['badge_text']?.toString().isNotEmpty == true
        ? section['badge_text'].toString()
        : '%20 İNDİRİM';
    final imgUrl = section['image_url']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandColor, const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        image: imgUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imgUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.6),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            promoTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            promoSub,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: brandColor,
            ),
            onPressed: widget.onOpenSanalMarket ?? widget.onBackToMain,
            icon: const Icon(Icons.local_offer_outlined, size: 16),
            label: const Text('Fırsatı Yakala'),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaShowcaseSection(
      Color brandColor, Map<String, dynamic> section) {
    final secTitle = section['custom_title']?.toString().isNotEmpty == true
        ? section['custom_title'].toString()
        : 'Tesis & Üretim Görselleri';
    final items = _mediaItems.isNotEmpty
        ? _mediaItems
        : ApiService.defaultKasaphaneMediaFallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library_outlined, color: brandColor, size: 22),
            const SizedBox(width: 8),
            Text(
              secTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, idx) {
              final m = items[idx];
              return Container(
                width: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF0F172A),
                  image: (m['url']?.toString().isNotEmpty == true)
                      ? DecorationImage(
                          image: NetworkImage(m['url'].toString()),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.35),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                padding: const EdgeInsets.all(14),
                alignment: Alignment.bottomLeft,
                child: Row(
                  children: [
                    Icon(
                      m['type'] == 'Video'
                          ? Icons.play_circle_fill
                          : Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m['title']?.toString() ?? 'Görsel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
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

  /// Kullanıcının içine dilediği elemanı sürükleyip istediği koordinata yerleştirebileceği Serbest Tuval (Canvas) alanı
  Widget _buildFreeCanvasSection(
      Color brandColor, Map<String, dynamic> section) {
    final height = section['canvas_height'] is num
        ? (section['canvas_height'] as num).toDouble()
        : 240.0;
    final bgImage = section['image_url']?.toString() ?? '';
    final title = section['custom_title']?.toString() ?? 'Serbest Tasarım Alanı';
    final sub = section['custom_subtitle']?.toString() ??
        'Sol paneldeki "Serbest Sürüklenebilir Elemanlar" kutusundan rozet, metin, görsel veya butonları bu alana sürükleyip istediğiniz noktaya bırakabilirsiniz.';

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isEditorMode
              ? brandColor.withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: widget.isEditorMode ? 1.5 : 1,
        ),
        image: bgImage.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(bgImage),
                fit: BoxFit.cover,
              )
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: bgImage.isNotEmpty ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              sub,
              style: TextStyle(
                fontSize: 12,
                color:
                    bgImage.isNotEmpty ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeaturesGridSection(
      Color brandColor, Map<String, dynamic> section) {
    final secTitle = section['custom_title']?.toString().isNotEmpty == true
        ? section['custom_title'].toString()
        : 'Neden Bizi Tercih Etmelisiniz?';
    final items = [
      (
        Icons.verified_user_outlined,
        '%100 Kalite Güvencesi',
        'Tüm ürünlerimiz günlük kalite ve hijyen kontrolünden geçer.'
      ),
      (
        Icons.ac_unit_rounded,
        'Kesintisiz Soğuk Zincir',
        '+2°C özel frigolu araçlarımızla tazeliği korunarak sevk edilir.'
      ),
      (
        Icons.local_shipping_outlined,
        'Hızlı Şube & Kapı Teslimatı',
        'Erzurum genelinde aynı gün hızlı kurye ve şube teslimatı.'
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          secTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (it) => SizedBox(
                  width: 260,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: brandColor.withValues(alpha: 0.12),
                          child: Icon(it.$1, color: brandColor),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          it.$2,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          it.$3,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCustomTextSection(
      Color brandColor, Map<String, dynamic> section) {
    final t = section['custom_title']?.toString().isNotEmpty == true
        ? section['custom_title'].toString()
        : 'Özel Bilgilendirme & Duyuru';
    final d = section['custom_description']?.toString().isNotEmpty == true
        ? section['custom_description'].toString()
        : 'TEMA Market güvencesiyle yöresel, doğal ve taze ürünlerimizi doğrudan üreticiden sofralarınıza ulaştırıyoruz.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: brandColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF334155), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    Color brandColor,
    String domain,
    Map<String, dynamic> section,
  ) {
    final phone = section['phone']?.toString().isNotEmpty == true
        ? section['phone'].toString()
        : '0 (442) 329 06 08';
    final whatsapp = section['whatsapp']?.toString().isNotEmpty == true
        ? section['whatsapp'].toString()
        : '904423290608';

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
              Expanded(
                child: Text(
                  section['custom_title']?.toString().isNotEmpty == true
                      ? section['custom_title'].toString()
                      : '$domain İletişim & Destek',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            section['custom_description']?.toString().isNotEmpty == true
                ? section['custom_description'].toString()
                : 'Sorularınız, toptan siparişleriniz veya şube teslimat detayları için müşteri temsilcimizle görüşebilirsiniz.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.call, size: 16),
                  label: Text(phone),
                  onPressed: () => launchUrl(
                      Uri.parse('tel:${phone.replaceAll(' ', '')}')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A)),
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('WhatsApp'),
                  onPressed: () =>
                      launchUrl(Uri.parse('https://wa.me/$whatsapp')),
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
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
