import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/customer_profile_utils.dart';

class AuthPage extends StatefulWidget {
  final String defaultRole;
  final Function(Map<String, dynamic> user)? onLoginSuccess;
  final VoidCallback? onClose;
  final ValueChanged<int>? onNavigate;

  const AuthPage({
    super.key,
    this.defaultRole = 'Customer',
    this.onLoginSuccess,
    this.onClose,
    this.onNavigate,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const bool _staffLoginEnabled = bool.fromEnvironment(
    'ENABLE_STAFF_LOGIN',
    defaultValue: false,
  );

  late String _selectedRole;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _privacyAcknowledged = false;
  bool _smsConsent = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.defaultRole;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _normalizedPhone() {
    var digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('90')) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != 10 || !digits.startsWith('5')) return null;
    return '+90$digits';
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://temasan.com/kvkk');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('KVKK sayfası açılamadı.')),
    );
  }

  Future<void> _sendOtp() async {
    final normalizedPhone = _normalizedPhone();
    if (normalizedPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Geçerli bir cep telefonu numarası girin (05XX XXX XX XX).'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_selectedRole == 'Customer' && !_privacyAcknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devam etmek için KVKK aydınlatma metnini okuyun.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.sendOtp(
        normalizedPhone,
        role: _selectedRole,
        privacyAcknowledged: _privacyAcknowledged,
        smsConsent: _smsConsent,
      );

      if (!mounted) return;
      _openOtpModal(normalizedPhone);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _appendPhoneDigit(String digit) {
    final current = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (current.length >= 11) return;
    setState(() {
      _phoneController.text = '$current$digit';
    });
  }

  void _backspacePhone() {
    final current = _phoneController.text;
    if (current.isEmpty) return;
    setState(() {
      _phoneController.text = current.substring(0, current.length - 1);
    });
  }

  void _clearPhone() {
    setState(() {
      _phoneController.clear();
    });
  }

  Widget _buildKeypad({
    required ValueChanged<String> onDigit,
    required VoidCallback onBackspace,
    required VoidCallback onClear,
  }) {
    Widget keyTile(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFECE9E2)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: child ??
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            keyTile('1', onTap: () => onDigit('1')),
            keyTile('2', onTap: () => onDigit('2')),
            keyTile('3', onTap: () => onDigit('3')),
          ],
        ),
        Row(
          children: [
            keyTile('4', onTap: () => onDigit('4')),
            keyTile('5', onTap: () => onDigit('5')),
            keyTile('6', onTap: () => onDigit('6')),
          ],
        ),
        Row(
          children: [
            keyTile('7', onTap: () => onDigit('7')),
            keyTile('8', onTap: () => onDigit('8')),
            keyTile('9', onTap: () => onDigit('9')),
          ],
        ),
        Row(
          children: [
            keyTile(
              'Temizle',
              onTap: onClear,
              child: const Text(
                'Temizle',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            keyTile('0', onTap: () => onDigit('0')),
            keyTile(
              'Sil',
              onTap: onBackspace,
              child: const Icon(
                Icons.backspace_outlined,
                size: 20,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openOtpModal(String normalizedPhone) {
    final otpController = TextEditingController();
    bool verifying = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF8F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            Future<void> verify() async {
              final code = otpController.text.trim();
              if (code.length != 6) {
                setModalState(
                    () => errorText = 'Lütfen 6 haneli doğrulama kodunu girin.');
                return;
              }

              setModalState(() {
                verifying = true;
                errorText = null;
              });

              try {
                final data = await ApiService.verifyOtp(
                  normalizedPhone,
                  code,
                  expectedRole: _selectedRole,
                );
                if (data['token'] == null || data['user'] == null) {
                  throw const ApiException('Geçerli oturum bilgisi alınamadı.');
                }

                final serverUser = Map<String, dynamic>.from(
                  data['user'] as Map,
                );
                final String userName =
                    serverUser['name']?.toString().trim().isNotEmpty == true
                        ? serverUser['name'].toString()
                        : (_nameController.text.trim().isNotEmpty
                            ? _nameController.text.trim()
                            : 'Tema Müşteri');
                final userObj = {
                  ...serverUser,
                  'name': userName,
                  'phone': serverUser['phone'] ?? normalizedPhone,
                  'user_barcode': serverUser['user_barcode'] ??
                      temaAvantajCardNumber(normalizedPhone),
                  'sms_consent': serverUser['sms_consent'] ?? _smsConsent,
                };
                await ApiService.saveAuthSession(
                  data['token'].toString(),
                  userObj,
                );

                if (modalCtx.mounted) Navigator.pop(modalCtx);
                if (!mounted) return;
                widget.onLoginSuccess?.call(userObj);
              } catch (e) {
                setModalState(() {
                  errorText = e.toString().replaceAll('ApiException: ', '');
                });
              } finally {
                if (modalCtx.mounted) {
                  setModalState(() => verifying = false);
                }
              }
            }

            final currentDigits = otpController.text;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
                left: 18,
                right: 18,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Doğrulama Kodu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.sms_outlined,
                              color: Color(0xFFFCA5A5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Telefon Numaranızı Doğrulayın',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$normalizedPhone numarasına gönderilen 6 haneli kodu girin',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 6 Haneli Görsel Kutular
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (idx) {
                        final char = idx < currentDigits.length
                            ? currentDigits[idx]
                            : '';
                        final isFocused = idx == currentDigits.length;
                        return Expanded(
                          child: Container(
                            height: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isFocused
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFE2E8F0),
                                width: isFocused ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                char,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      onChanged: (_) => setModalState(() {}),
                      onSubmitted: (_) => verify(),
                      decoration: InputDecoration(
                        hintText: 'Kodu klavyeden yazabilir veya aşağıdan tuşlayabilirsiniz',
                        hintStyle: const TextStyle(fontSize: 11.5),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        onPressed: verifying ? null : verify,
                        child: verifying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Doğrula ve Giriş Yap',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildKeypad(
                      onDigit: (d) {
                        if (otpController.text.length >= 6) return;
                        setModalState(() {
                          otpController.text = '${otpController.text}$d';
                        });
                      },
                      onBackspace: () {
                        if (otpController.text.isEmpty) return;
                        setModalState(() {
                          otpController.text = otpController.text
                              .substring(0, otpController.text.length - 1);
                        });
                      },
                      onClear: () {
                        setModalState(() => otpController.clear());
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(otpController.dispose);
  }

  void _onNavTap(int index) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
    } else if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  Widget _buildFloatingNavbar(BuildContext context) {
    final navItems = [
      {'id': 0, 'icon': Icons.home_rounded, 'label': 'Ana Sayfa'},
      {'id': 1, 'icon': Icons.store_rounded, 'label': 'Şubeler'},
      {'id': 2, 'icon': Icons.shopping_bag_outlined, 'label': 'Sepetim'},
      {'id': 3, 'icon': Icons.auto_awesome_rounded, 'label': 'Sizin İçin'},
      {'id': 4, 'icon': Icons.person_rounded, 'label': 'Hesabım'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECE9E2))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: navItems.map((item) {
              final int id = item['id'] as int;
              final bool isSelected = id == 4;
              final IconData icon = item['icon'] as IconData;
              final String label = item['label'] as String;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: isSelected
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF3F1EC),
                  borderRadius: BorderRadius.circular(100),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => _onNavTap(id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF334155),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      bottomNavigationBar: _buildFloatingNavbar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Bar: Geri Butonu + Resmi TEMA Logosu + Rozet
              Row(
                children: [
                  if (widget.onClose != null || widget.onNavigate != null) ...[
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _onNavTap(0),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFECE9E2)),
                          ),
                          child: const Icon(Icons.chevron_left_rounded,
                              color: Color(0xFF0F172A), size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 34,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                          'TEMA MARKET',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded,
                            color: Color(0xFFDC2626), size: 15),
                        SizedBox(width: 5),
                        Text(
                          'Üye Girişi',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Telefon Numaranızı Girin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              // Fotoğraftaki koyu bilgi kartı (TEMA renkleriyle)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0F172A),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telefon Doğrulama',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Devam etmek için cep telefonu numaranızı girin; Tema Avantaj Kartınızla puan kazanın.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_staffLoginEnabled) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Giriş Yapılacak Rol',
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Customer',
                        child: Text('🛒 Müşteri Hesabı',
                            overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'Merchant',
                        child: Text('🏢 Bayi / Şube Yöneticisi',
                            overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'Courier',
                        child: Text('🛵 Kurye Teslimat Personeli',
                            overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'SuperAdmin',
                        child: Text('👑 Genel Yönetici Konsolu',
                            overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Cep Telefonu',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
                decoration: InputDecoration(
                  hintText: '5XX XXX XX XX',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F1EC),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            '+90',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                onSubmitted: (_) => _sendOtp(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad (Kart ve Profil İçin - İsteğe Bağlı)',
                  prefixIcon: Icon(Icons.badge_outlined),
                  fillColor: Colors.white,
                ),
              ),
              if (_selectedRole == 'Customer') ...[
                const SizedBox(height: 6),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _privacyAcknowledged,
                  onChanged: (value) => setState(
                    () => _privacyAcknowledged = value ?? false,
                  ),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'KVKK aydınlatma metnini okudum. ',
                        style: TextStyle(fontSize: 12),
                      ),
                      GestureDetector(
                        onTap: _openPrivacyPolicy,
                        child: const Text(
                          'Metni görüntüle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _smsConsent,
                  onChanged: (value) =>
                      setState(() => _smsConsent = value ?? false),
                  title: const Text(
                    'Kampanya ve fırsatlar için SMS almak istiyorum (isteğe bağlı).',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                  ),
                  onPressed: _isLoading ? null : _sendOtp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SMS Kodu Gönder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              // Fotoğraftaki doğrudan rakam tuş takımı
              _buildKeypad(
                onDigit: _appendPhoneDigit,
                onBackspace: _backspacePhone,
                onClear: _clearPhone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
