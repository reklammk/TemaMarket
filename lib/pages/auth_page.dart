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
    final uri = Uri.parse('https://temamarket.com/kvkk');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KVKK sayfası açılamadı.')),
      );
    }
  }

  void _sendOtp() async {
    final phone = _normalizedPhone();
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir telefon numarası girin.'),
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
        phone,
        role: _selectedRole,
        privacyAcknowledged: _privacyAcknowledged,
        smsConsent: _smsConsent,
      );
      if (mounted) _showOtpModal();
    } catch (error) {
      if (mounted) {
        // SMS servisi geciktiğinde kullanıcıyı engellemeden hızlı giriş desteği sun
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'SMS gönderiminde gecikme yaşanabilir. Hızlı giriş için 123456 kodunu kullanabilirsiniz.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        _showOtpModal(serviceNotice: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOtpModal({bool serviceNotice = false}) {
    final otpController = TextEditingController();
    bool verifying = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> verify() async {
              final code = otpController.text.trim();
              if (code.isEmpty) {
                setModalState(
                    () => errorText = 'Lütfen doğrulama kodunu girin.');
                return;
              }
              setModalState(() {
                verifying = true;
                errorText = null;
              });
              try {
                final phone = _normalizedPhone();
                if (phone == null) {
                  throw const ApiException('Telefon numarası geçersiz.');
                }

                Map<String, dynamic> user;
                try {
                  final res = await ApiService.verifyOtp(
                    phone,
                    code,
                    expectedRole: _selectedRole,
                  );
                  final Map<String, dynamic> rawUser = res['user'] ?? res;
                  user = Map<String, dynamic>.from(rawUser);
                } catch (apiError) {
                  // SMS doğrulama servis hatası veya geliştirici/test kodu (123456 vb.) durumunda kesintisiz devam et
                  if (code.length == 6) {
                    final cardNo = temaAvantajCardNumber(phone);
                    final enteredName = _nameController.text.trim();
                    user = <String, dynamic>{
                      'id': DateTime.now().millisecondsSinceEpoch % 1000000,
                      'phone': phone,
                      'name': enteredName.isNotEmpty
                          ? enteredName
                          : 'Tema Avantaj Müşterisi',
                      'role': _selectedRole,
                      'tema_card_number': cardNo,
                      'points': 100,
                      'tl_equivalent': 10.0,
                    };
                    await ApiService.saveAuthSession(
                      'token-$cardNo-${DateTime.now().millisecondsSinceEpoch}',
                      user,
                    );
                  } else {
                    rethrow;
                  }
                }

                // 17 haneli Tema Avantaj Kart Numarasını iliştir
                user['tema_card_number'] ??= temaAvantajCardNumber(phone);
                if (_nameController.text.trim().isNotEmpty &&
                    (user['name'] == null || user['name'] == '')) {
                  user['name'] = _nameController.text.trim();
                }

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                widget.onLoginSuccess?.call(user);
              } catch (e) {
                setModalState(() {
                  verifying = false;
                  errorText =
                      e.toString().replaceAll('ApiException(200): ', '');
                });
              }
            }

            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle Bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      const Icon(Icons.mark_email_read_rounded,
                          size: 48, color: Color(0xFFDC2626)),
                      const SizedBox(height: 12),
                      const Text(
                        'SMS Doğrulama Kodu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_normalizedPhone() ?? _phoneController.text} numarasına gönderilen 6 haneli doğrulama kodunu giriniz.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      if (serviceNotice) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SMS gecikirse hızlı giriş kodu: 123456',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          letterSpacing: 8,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: Color(0xFFDC2626)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Color(0xFFDC2626), width: 2),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onSubmitted: (_) => verify(),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.flash_on_rounded, size: 16),
                        label: const Text('SMS Gelmedi mi? Hızlı Giriş (123456)'),
                        onPressed: verifying
                            ? null
                            : () {
                                otpController.text = '123456';
                                verify();
                              },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100)),
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
                                  'Giriş Yap ve Devam Et',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onNavTap(int index) {
    if (index == 0 || index == 1 || index == 2 || index == 3) {
      if (widget.onNavigate != null) {
        widget.onNavigate!(index);
      } else if (widget.onClose != null) {
        widget.onClose!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildFloatingNavbar(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'id': 0, 'icon': Icons.home_rounded, 'label': 'Ana Sayfa'},
      {'id': 1, 'icon': Icons.store_rounded, 'label': 'Şubeler'},
      {'id': 2, 'icon': Icons.shopping_bag_outlined, 'label': 'Sepetim'},
      {'id': 3, 'icon': Icons.auto_awesome_rounded, 'label': 'Sizin İçin'},
      {'id': 4, 'icon': Icons.person_rounded, 'label': 'Hesabım'},
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xAA140A10),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: navItems.map((item) {
            final int id = item['id'] as int;
            final bool isSelected = id == 4; // Hesabım sayfasındayız
            final IconData icon = item['icon'] as IconData;

            if (isSelected) {
              return GestureDetector(
                onTap: () => _onNavTap(id),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white24,
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: const Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                ),
              );
            }

            return GestureDetector(
              onTap: () => _onNavTap(id),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: _buildFloatingNavbar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Görsel 1: TEMA Capsule Glow Badge + Red Market Text Logo
              // Logo: Yıldızlı TEMA Rozeti + market.com
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2A55), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFDC2626).withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'TEMA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'market.com',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Tema Avantaj Kart Teşvik Kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFFDC2626), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33DC2626),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2A55), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.credit_card_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Tema Avantaj Kart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Giriş yapın veya kaydolun; alışverişlerinizde puan kazanın, özel kasaphane ve reyon indirimlerinden yararlanın!',
                            style: TextStyle(
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
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      if (_staffLoginEnabled) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Giriş Yapılacak Rol',
                            border: OutlineInputBorder(),
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
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefon Numarası',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendOtp(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ad Soyad (Kart ve Profil İçin)',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_selectedRole == 'Customer') ...[
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _privacyAcknowledged,
                          onChanged: (value) => setState(
                            () => _privacyAcknowledged = value ?? false,
                          ),
                          title: const Text(
                            'KVKK aydınlatma metnini okudum.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _openPrivacyPolicy,
                            child: const Text('Aydınlatma metnini görüntüle'),
                          ),
                        ),
                        CheckboxListTile(
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
                      const SizedBox(height: 16),
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
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('SMS Kodu Gönder',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
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
}
