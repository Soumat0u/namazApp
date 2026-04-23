import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';

/// Giriş/Kayıt ekranı.
/// Varsayılan: Email/Şifre — Alternatif: Google ile Giriş
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLogin = true; // true=Giriş Yap, false=Kayıt Ol
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorText = null;
    });
  }

  Future<void> _emailIleDevamEt() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();
    final rawUsername = _usernameController.text.trim();
    final username = rawUsername.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');

    // Validasyon
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Geçerli bir e-posta adresi girin.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorText = 'Şifre en az 6 karakter olmalı.');
      return;
    }
    if (!_isLogin && displayName.length < 2) {
      setState(() => _errorText = 'Ad soyad en az 2 karakter olmalı.');
      return;
    }
    if (!_isLogin && username.isEmpty) {
      setState(() => _errorText = 'Geçerli bir kullanıcı adı girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final provider = context.read<NamazProvider>();
    String? error;

    if (_isLogin) {
      error = await provider.emailIleGirisYap(email: email, password: password);
    } else {
      error = await provider.emailIleKayitOl(email: email, password: password, displayName: displayName, username: username);
    }

    if (error != null && mounted) {
      setState(() {
        _errorText = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _googleIleGiris() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final provider = context.read<NamazProvider>();
    final error = await provider.googleIleGirisYap();

    if (error == 'google_username_taken') {
      setState(() { _isLoading = false; });
      _showUsernameModal(context, provider);
    } else if (error != null && mounted) {
      setState(() {
        _errorText = error;
        _isLoading = false;
      });
    }
  }

  void _showUsernameModal(BuildContext ctx, NamazProvider provider) {
    final TextEditingController unController = TextEditingController();
    bool isSaving = false;
    String? modalError;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final r = this.context.renkler;
          return Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: r.arkaPlanRengi,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Kullanıcı Adı Seç", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  "Meclisimizde seçtiğiniz Google ismiyle bir kardeşimiz zaten mevcut. Lütfen kendinize has bir kullanıcı adı belirleyin.",
                  style: TextStyle(color: r.yaziRengi.withOpacity(0.6), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: unController,
                  hint: "@kullaniciadi",
                  icon: Icons.alternate_email_rounded,
                  r: r,
                ),
                if (modalError != null) ...[
                  const SizedBox(height: 8),
                  Text(modalError!, style: TextStyle(color: r.kirmizi, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      final raw = unController.text.trim();
                      final un = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
                      if (un.isEmpty) {
                        setModalState(() => modalError = "Geçerli bir kullanıcı adı girin.");
                        return;
                      }
                      setModalState(() { isSaving = true; modalError = null; });
                      
                      // TODO: FirebaseAuth üzerinden displayName çekeceğiz. AuthScreen Provider biliyor.
                      // Basitlik için default atayalım, Provider içinde halledilecek.
                      final err = await provider.completeGoogleRegistration(
                        username: un, 
                        displayName: unController.text.trim().isEmpty ? "Google Kullanıcı" : raw, // temporary fallback
                      );
                      
                      if (err != null) {
                        setModalState(() { isSaving = false; modalError = err; });
                      } else {
                        Navigator.pop(bCtx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: r.anaRenk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Tamamla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(28)),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ☪ Logo
                    Container(
                      width: Responsive.w(80),
                      height: Responsive.w(80),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [r.anaRenk, r.anaRenk.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: r.anaRenk.withOpacity(0.25),
                            blurRadius: 25,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.mosque_rounded, color: Colors.white, size: Responsive.w(40)),
                    ),

                    SizedBox(height: Responsive.h(24)),

                    // Başlık
                    Text(
                      _isLogin ? "Hoş Geldin" : "Manevi Meclise\nKatıl",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: r.yaziRengi,
                        fontWeight: FontWeight.w900,
                        fontSize: Responsive.sp(24),
                        height: 1.2,
                      ),
                    ),

                    SizedBox(height: Responsive.h(8)),

                    Text(
                      _isLogin 
                          ? "Hesabına giriş yap veya bir hesap oluştur." 
                          : "Bir hesap oluştur, manevi yolculuğuna başla.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: r.yaziRengi.withOpacity(0.5), fontSize: Responsive.sp(13), height: 1.4),
                    ),

                    SizedBox(height: Responsive.h(32)),

                    // İsim & Kullanıcı Adı (sadece kayıt modunda)
                    if (!_isLogin) ...[
                      _buildTextField(
                        controller: _displayNameController,
                        hint: "Ad Soyad / Görünen İsim",
                        icon: Icons.person_outline_rounded,
                        r: r,
                      ),
                      SizedBox(height: Responsive.h(12)),
                      _buildTextField(
                        controller: _usernameController,
                        hint: "Kullanıcı Adı (@bosluksuz)",
                        icon: Icons.alternate_email_rounded,
                        r: r,
                      ),
                      SizedBox(height: Responsive.h(12)),
                    ],

                    // Email
                    _buildTextField(
                      controller: _emailController,
                      hint: "E-posta adresi",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      r: r,
                    ),

                    SizedBox(height: Responsive.h(12)),

                    // Şifre
                    _buildTextField(
                      controller: _passwordController,
                      hint: "Şifre",
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      r: r,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: r.pasifRenk,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),

                    SizedBox(height: Responsive.h(8)),

                    // Hata mesajı
                    if (_errorText != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(Responsive.w(12)),
                        decoration: BoxDecoration(
                          color: r.kirmizi.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: r.kirmizi, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: TextStyle(color: r.kirmizi, fontSize: Responsive.sp(12), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: Responsive.h(20)),

                    // Ana Buton — Giriş / Kayıt
                    SizedBox(
                      width: double.infinity,
                      height: Responsive.h(52),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _emailIleDevamEt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: r.anaRenk,
                          disabledBackgroundColor: r.anaRenk.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text(
                                _isLogin ? "Giriş Yap" : "Hesap Oluştur",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: Responsive.sp(15)),
                              ),
                      ),
                    ),

                    SizedBox(height: Responsive.h(16)),

                    // Ayırıcı
                    Row(
                      children: [
                        Expanded(child: Divider(color: r.pasifRenk.withOpacity(0.3))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                          child: Text("veya", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
                        ),
                        Expanded(child: Divider(color: r.pasifRenk.withOpacity(0.3))),
                      ],
                    ),

                    SizedBox(height: Responsive.h(16)),

                    // Google Giriş Butonu
                    SizedBox(
                      width: double.infinity,
                      height: Responsive.h(52),
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _googleIleGiris,
                        icon: Image.network(
                          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata_rounded, size: 24, color: r.yaziRengi),
                        ),
                        label: Text(
                          "Google ile Giriş Yap",
                          style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w700, fontSize: Responsive.sp(14)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: r.pasifRenk.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),

                    SizedBox(height: Responsive.h(24)),

                    // Mod Değiştir
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLogin ? "Hesabın yok mu? " : "Zaten hesabın var mı? ",
                          style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(13)),
                        ),
                        GestureDetector(
                          onTap: _toggleMode,
                          child: Text(
                            _isLogin ? "Kayıt Ol" : "Giriş Yap",
                            style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w800, fontSize: Responsive.sp(13)),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.h(16)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required AppThemeColors r,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w600, fontSize: Responsive.sp(14)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: r.pasifRenk, fontWeight: FontWeight.w400, fontSize: Responsive.sp(13)),
          prefixIcon: Icon(icon, color: r.pasifRenk, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(16)),
        ),
      ),
    );
  }
}
