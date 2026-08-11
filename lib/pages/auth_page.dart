import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  final String defaultRole;
  final Function(Map<String, dynamic> user)? onLoginSuccess;

  const AuthPage({super.key, this.defaultRole = 'Customer', this.onLoginSuccess});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late String _selectedRole;
  final TextEditingController _phoneController = TextEditingController(text: '+90 532 100 2233');
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.defaultRole;
  }

  void _sendOtp() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isLoading = false;
      _otpSent = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Doğrulama Kodu SMS Olarak Gönderildi: 123987'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  void _verifyOtp() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    final user = {
      'name': _selectedRole == 'SuperAdmin'
          ? 'Yönetici Temasan'
          : _selectedRole == 'Merchant'
              ? 'Lalapaşa Şube Müdürü'
              : _selectedRole == 'Courier'
                  ? 'Kurye Ahmet Yılmaz'
                  : 'Zeynep Yılmaz',
      'phone': _phoneController.text,
      'role': _selectedRole,
      'points': 450,
    };

    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('TEMASAN SanalMarket & ERP', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('TEMA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
              ),
              const SizedBox(height: 16),
              const Text('Hızlı ve Güvenli SMS Girişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Giriş Yapılacak Rol',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Customer', child: Text('🛒 Müşteri Hesabı')),
                          DropdownMenuItem(value: 'Merchant', child: Text('🏢 Bayi / Şube Yöneticisi')),
                          DropdownMenuItem(value: 'Courier', child: Text('🛵 Kurye Teslimat Personeli')),
                          DropdownMenuItem(value: 'SuperAdmin', child: Text('👑 Genel Yönetici Konsolu')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefon Numarası',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'SMS Doğrulama Kodu (123987)',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          onPressed: _isLoading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(_otpSent ? 'Giriş Yap ve Devam Et' : 'SMS Kodu Gönder', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
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
