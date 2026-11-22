import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ==========================================
// KONFIGURASI URL SERVER API
// ==========================================
// Catatan saat build APK Android:
// - Chrome / Desktop lokal : http://127.0.0.1:5000
// - Android Emulator       : http://10.0.2.2:5000
// - HP Android (1 Wi-Fi)   : http://192.168.x.x:5000 (IP Laptop)
// - Server Online (Deploy) : https://domain-api-kamu.com
const String apiBaseUrl = 'http://127.0.0.1:5000';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Admin Seller Center',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF),
          primary: const Color(0xFF1E40AF),
          secondary: const Color(0xFF3B82F6),
          surface: const Color(0xFFF4F6FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.8),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// HELPER: FORMAT RUPIAH & PERSENTASE
// ==========================================
class FormatUangIndonesia extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    String angkaSaja = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (angkaSaja.isEmpty) return newValue.copyWith(text: '');

    String hasilFormat = '';
    int hitung = 0;
    for (int i = angkaSaja.length - 1; i >= 0; i--) {
      if (hitung == 3) {
        hasilFormat = '.$hasilFormat';
        hitung = 0;
      }
      hasilFormat = angkaSaja[i] + hasilFormat;
      hitung++;
    }

    return TextEditingValue(
      text: hasilFormat,
      selection: TextSelection.collapsed(offset: hasilFormat.length),
    );
  }
}

String formatRupiahAngka(num angka) {
  String str = angka.toInt().toString();
  String hasil = '';
  int hitung = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (hitung == 3) {
      hasil = '.$hasil';
      hitung = 0;
    }
    hasil = str[i] + hasil;
    hitung++;
  }
  return 'Rp $hasil';
}

String formatPersenIndo(double nilai) {
  return '${nilai.toStringAsFixed(2).replaceAll('.', ',')}%';
}

const Map<String, String> _kategoriEnKeId = {
  'Computing': 'Komputer & IT',
  "Men's Fashion": 'Pakaian Pria',
  "Women's Fashion": 'Pakaian Wanita',
  'Beauty & Grooming': 'Kecantikan & Perawatan',
  'Soghaat': 'Oleh-oleh & Camilan',
  'Mobiles & Tablets': 'HP & Tablet',
  'Appliances': 'Peralatan Rumah Tangga',
  'Entertainment': 'Hiburan',
  'Health & Sports': 'Kesehatan & Olahraga',
  'Home & Living': 'Rumah & Dekorasi',
  'Kids & Baby': 'Anak & Bayi',
  'Books': 'Buku',
  'School & Education': 'Sekolah & Edukasi',
  'Superstore': 'Superstore',
  'Others': 'Lainnya',
};

String terjemahkanKategoriKeIndonesia(String raw) {
  return _kategoriEnKeId[raw] ?? raw;
}

IconData iconUntukKategori(String kategori) {
  final k = kategori.toLowerCase();
  if (k.contains('komputer') || k.contains('computing')) return Icons.laptop_mac;
  if (k.contains('pria') || k.contains("men's")) return Icons.checkroom;
  if (k.contains('wanita') || k.contains("women's")) return Icons.shopping_bag;
  if (k.contains('kecantikan') || k.contains('beauty')) return Icons.spa;
  if (k.contains('camilan') || k.contains('soghaat')) return Icons.fastfood;
  if (k.contains('hp') || k.contains('mobile')) return Icons.smartphone;
  return Icons.inventory_2_outlined;
}

// ==========================================
// HALAMAN 1: LOGIN MODERN (MOBILE STYLE)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  Future<void> _prosesLogin() async {
    final inputUser = _emailController.text.trim().toLowerCase();
    final inputPass = _passController.text.trim();

    if (inputUser.isEmpty || inputPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email dan Password wajib diisi!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade800,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? pesanError;
    String? emailLogin;

    try {
      // Cek email & password ke server (tabel users di MySQL)
      final res = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': inputUser, 'password': inputPass}),
      );
      final dataJson = jsonDecode(res.body);

      if (res.statusCode == 200 && dataJson['status'] == 'sukses') {
        emailLogin = dataJson['email']?.toString() ?? inputUser;
      } else {
        pesanError = dataJson['pesan_error']?.toString() ??
            'Email atau password salah!';
      }
    } catch (e) {
      pesanError =
          'Gagal terhubung ke server. Pastikan server Flask sudah menyala.';
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (emailLogin != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainShellScreen(userEmail: emailLogin!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pesanError ?? 'Login gagal'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER GRADASI MELENGKUNG
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 68, 24, 56),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selamat Datang',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Admin Seller Center • Prediksi Risiko Pembatalan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // KARTU FORM LOGIN
            Transform.translate(
              offset: const Offset(0, -28),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Masuk ke Akun Toko',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kelola pesanan dan pantau risiko pembatalan real-time',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'admin@seller.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _prosesLogin(),
                        decoration: InputDecoration(
                          hintText: 'Masukkan password',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: const Color(0xFF1E40AF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  onChanged: (val) => setState(
                                      () => _rememberMe = val ?? true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Ingat saya',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Bantuan Akun Demo'),
                                  content: const Text(
                                    'Gunakan akun berikut untuk masuk:\n\n'
                                    '• Email: admin@seller.com\n'
                                    '• Password: admin',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Tutup'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text(
                              'Lupa password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _prosesLogin,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // INFO AKUN DEMO DI BAWAH
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'Demo Login: admin@seller.com  •  Pass: admin',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E40AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MAIN SHELL: BOTTOM NAVIGATION BAR (3 TAB)
// ==========================================
class MainShellScreen extends StatefulWidget {
  final String userEmail;

  const MainShellScreen({super.key, required this.userEmail});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Filter & search untuk tab Riwayat
  String _selectedFilter = 'Semua';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ambilRiwayatPesanan();
  }

  Future<void> _ambilRiwayatPesanan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final url = Uri.parse('$apiBaseUrl/orders');
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final dataJson = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          _orders = dataJson['data'] ?? [];
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server merespons error ${res.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal terhubung ke server ($apiBaseUrl)';
      });
    }
  }

  Future<void> _bukaFormInput() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FormulirInputScreen()),
    );
    _ambilRiwayatPesanan();
  }

  void _konfirmasiLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Aplikasi?'),
        content: const Text('Anda akan kembali ke halaman login admin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildBerandaTab(),
      _buildRiwayatTab(),
      _buildProfilTab(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      floatingActionButton: _selectedIndex != 2
          ? FloatingActionButton.extended(
              onPressed: _bukaFormInput,
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Cek Risiko',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDBEAFE),
        elevation: 3,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1E40AF)),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF1E40AF)),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF1E40AF)),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: BERANDA (DASHBOARD MOBILE)
  // ==========================================
  Widget _buildBerandaTab() {
    final int totalPesanan = _orders.length;
    final int risikoTinggi = _orders
        .where((o) => ((o['prediksi_risiko'] as num?)?.toDouble() ?? 0) >= 50.0)
        .length;
    final int aman = totalPesanan - risikoTinggi;
    final double rasioAman = totalPesanan == 0 ? 0.0 : aman / totalPesanan;
    final recentOrders = _orders.take(5).toList();

    return RefreshIndicator(
      onRefresh: _ambilRiwayatPesanan,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER GRADASI TOKO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 36),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, Admin Toko 👋',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Admin Seller Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _ambilRiwayatPesanan,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                        ),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'Segarkan',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // KARTU RINGKASAN MELAYANG
            Transform.translate(
              offset: const Offset(0, -22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ringkasan Risiko Toko',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${(rasioAman * 100).toStringAsFixed(0)}% Aman',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3 METRIK UTAMA
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniMetric(
                              'Total',
                              '$totalPesanan',
                              const Color(0xFF1E40AF),
                              const Color(0xFFEFF6FF),
                              Icons.shopping_cart_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniMetric(
                              'Berisiko',
                              '$risikoTinggi',
                              const Color(0xFFDC2626),
                              const Color(0xFFFEF2F2),
                              Icons.warning_amber_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniMetric(
                              'Aman',
                              '$aman',
                              const Color(0xFF059669),
                              const Color(0xFFECFDF5),
                              Icons.verified_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // PROGRESS BAR RASIO
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: totalPesanan == 0 ? 0 : rasioAman,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFFEE2E2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF10B981)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Aman ($aman)',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF059669)),
                          ),
                          Text(
                            'Risiko Tinggi ($risikoTinggi)',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BANNER AKSI CEPAT AI
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: InkWell(
                onTap: _bukaFormInput,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: Color(0xFF60A5FA),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Analisis Pesanan Baru',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Prediksi peluang batal & rekomendasi metode bayar',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ),

            // HEADER PESANAN TERBARU
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pesanan Terbaru',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
            ),

            // LIST PESANAN TERBARU
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              child: _buildOrderListContent(recentOrders),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(
      String label, String value, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: RIWAYAT PESANAN + FILTER & CARI
  // ==========================================
  Widget _buildRiwayatTab() {
    final filters = [
      'Semua',
      'Risiko Tinggi',
      'Aman',
      'COD',
      'Online',
      'Internal Credit',
    ];

    final filteredOrders = _orders.where((item) {
      final risiko = (item['prediksi_risiko'] as num?)?.toDouble() ?? 0.0;
      final kategoriRaw = (item['kategori'] ?? '').toString();
      final kategoriId =
          terjemahkanKategoriKeIndonesia(kategoriRaw).toLowerCase();
      final metode = (item['metode_pembayaran'] ?? '').toString();
      final tanggal = (item['tanggal_pesanan'] ?? '').toString().toLowerCase();

      // Filter chip
      bool matchFilter = true;
      if (_selectedFilter == 'Risiko Tinggi') {
        matchFilter = risiko >= 50.0;
      } else if (_selectedFilter == 'Aman') {
        matchFilter = risiko < 50.0;
      } else if (_selectedFilter != 'Semua') {
        matchFilter = metode.toLowerCase() == _selectedFilter.toLowerCase();
      }

      // Filter pencarian
      final q = _searchQuery.trim().toLowerCase();
      final matchSearch = q.isEmpty ||
          kategoriId.contains(q) ||
          kategoriRaw.toLowerCase().contains(q) ||
          metode.toLowerCase().contains(q) ||
          tanggal.contains(q);

      return matchFilter && matchSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Riwayat Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _ambilRiwayatPesanan,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _ambilRiwayatPesanan,
        child: Column(
          children: [
            // SEARCH BAR + FILTER CHIPS
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Cari kategori, metode, atau tanggal...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final f = filters[index];
                        final isSelected = _selectedFilter == f;
                        return ChoiceChip(
                          label: Text(f),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedFilter = f),
                          selectedColor: const Color(0xFF1E40AF),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF334155),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // JUMLAH HASIL
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menampilkan ${filteredOrders.length} transaksi',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedFilter != 'Semua')
                    GestureDetector(
                      onTap: () => setState(() => _selectedFilter = 'Semua'),
                      child: const Text(
                        'Reset Filter',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // LIST DATA
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                child: _buildOrderListContent(filteredOrders),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListContent(List<dynamic> items) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _ambilRiwayatPesanan,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Muat Ulang'),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'Tidak ada data pesanan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tambahkan pesanan baru lewat tombol Cek Risiko.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final double risiko =
            (item['prediksi_risiko'] as num?)?.toDouble() ?? 0.0;
        final bool isTinggi = risiko >= 50.0;
        final Color warnaStatus =
            isTinggi ? const Color(0xFFDC2626) : const Color(0xFF059669);
        final Color bgStatus =
            isTinggi ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
        final String kategoriRaw = item['kategori']?.toString() ?? '-';
        final String kategori = terjemahkanKategoriKeIndonesia(kategoriRaw);
        final String metode = item['metode_pembayaran']?.toString() ?? '-';
        final String tanggal = item['tanggal_pesanan']?.toString() ?? '-';
        final num totalHarga = item['total_harga'] as num? ?? 0;
        final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;

        final int? orderId = (item['id'] as num?)?.toInt();

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _tampilkanDetailPesanan(item),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: bgStatus,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconUntukKategori(kategori),
                      color: warnaStatus,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                kategori,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                metode,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$tanggal  •  $qty pcs',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatRupiahAngka(totalHarga),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: bgStatus,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: warnaStatus.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatPersenIndo(risiko),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: warnaStatus,
                          ),
                        ),
                        Text(
                          isTinggi ? 'Risiko Tinggi' : 'Aman',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: warnaStatus,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (orderId != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFF94A3B8), size: 20),
                      tooltip: 'Hapus Riwayat',
                      onPressed: () => _konfirmasiHapusPesanan(orderId, kategori),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _tampilkanDetailPesanan(Map<String, dynamic> item) {
    final int? orderId = (item['id'] as num?)?.toInt();
    final String kategori =
        terjemahkanKategoriKeIndonesia(item['kategori']?.toString() ?? '-');
    final String metode = item['metode_pembayaran']?.toString() ?? '-';
    final String tanggal = item['tanggal_pesanan']?.toString() ?? '-';
    final num hargaSatuan = item['harga_satuan'] as num? ?? 0;
    final int qty = (item['jumlah'] as num?)?.toInt() ?? 1;
    final num totalHarga = item['total_harga'] as num? ?? 0;
    final double risiko = (item['prediksi_risiko'] as num?)?.toDouble() ?? 0.0;
    final bool isTinggi = risiko >= 50.0;
    final Color warnaStatus =
        isTinggi ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final Color bgStatus =
        isTinggi ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderId != null
                      ? 'Detail Pesanan #$orderId'
                      : 'Detail Pesanan',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: bgStatus,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isTinggi ? 'Risiko Tinggi' : 'Aman',
                    style: TextStyle(
                      color: warnaStatus,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgStatus,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: warnaStatus.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Skor Prediksi Risiko Batal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Text(
                    formatPersenIndo(risiko),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: warnaStatus,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Tanggal Pesanan', tanggal),
            const Divider(height: 18),
            _buildDetailRow('Kategori Barang', kategori),
            const Divider(height: 18),
            _buildDetailRow('Metode Pembayaran', metode),
            const Divider(height: 18),
            _buildDetailRow('Harga Baris Produk', formatRupiahAngka(hargaSatuan)),
            const Divider(height: 18),
            _buildDetailRow('Jumlah Barang', '$qty pcs'),
            const Divider(height: 18),
            _buildDetailRow('Total Transaksi', formatRupiahAngka(totalHarga),
                isBold: true),
            const SizedBox(height: 22),
            Row(
              children: [
                if (orderId != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _konfirmasiHapusPesanan(orderId, kategori);
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Hapus',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _konfirmasiHapusPesanan(int orderId, String kategori) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Riwayat Pesanan?'),
        content: Text(
          'Pesanan #$orderId ($kategori) akan dihapus permanen dari database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () {
              Navigator.pop(ctx);
              _hapusPesanan(orderId);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusPesanan(int orderId) async {
    try {
      final url = Uri.parse('$apiBaseUrl/orders/$orderId');
      final res = await http.delete(url);
      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Riwayat pesanan #$orderId berhasil dihapus.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF059669),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _ambilRiwayatPesanan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menghapus (Error ${res.statusCode}). Pastikan endpoint DELETE /orders di app_api.py sudah ditambahkan.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal terhubung ke server saat menghapus data.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ==========================================
  // TAB 3: PROFIL & PENGATURAN
  // ==========================================
  Widget _buildProfilTab() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profil & Info Sistem',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // KARTU PROFIL ADMIN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFDBEAFE),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 30,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userEmail,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '● Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // KARTU INFO SISTEM AI & SERVER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Model & Server',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildInfoRow(
                      Icons.memory, 'Model Prediksi', 'XGBoost 3-Class'),
                  const Divider(height: 20),
                  _buildInfoRow(Icons.auto_fix_high, 'Metode Rekomendasi',
                      'Bounded Counterfactual'),
                  const Divider(height: 20),
                  _buildInfoRow(
                      Icons.speed, 'Ambang Risiko Tinggi', '≥ 50,00%'),
                  const Divider(height: 20),
                  _buildInfoRow(Icons.dns_outlined, 'Endpoint API', apiBaseUrl),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // DISCLAIMER PENELITIAN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1E40AF), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aplikasi ini merupakan demonstrasi penelitian. Model dilatih dan diuji menggunakan dataset transaksi Pakistan, serta belum divalidasi untuk transaksi Indonesia.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF1E3A8A),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // TOMBOL LOGOUT
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _konfirmasiLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// HALAMAN 3: FORMULIR INPUT DATA PESANAN
// ==========================================
class FormulirInputScreen extends StatefulWidget {
  const FormulirInputScreen({super.key});

  @override
  State<FormulirInputScreen> createState() => _FormulirInputScreenState();
}

class _FormulirInputScreenState extends State<FormulirInputScreen> {
  final _tanggalController = TextEditingController();
  final _priceController = TextEditingController();
  final _jumlahController = TextEditingController();
  final _grandTotalController = TextEditingController();

  String? _kategori;
  String? _metodePembayaran;
  DateTime? _tanggalPesanan;

  bool _isError = false;
  String _errorMessage = '';

  static const List<String> _daftarKategori = [
    'Komputer & IT',
    'Pakaian Pria',
    'Pakaian Wanita',
    'Kecantikan & Perawatan',
    'Oleh-oleh & Camilan',
  ];

  @override
  void initState() {
    super.initState();
    // Default ke hari ini agar praktis
    final now = DateTime.now();
    _tanggalPesanan = now;
    _tanggalController.text =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pilihTanggal() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tanggalPesanan ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _tanggalPesanan = picked;
        _tanggalController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _prosesPrediksiAI() async {
    if (_metodePembayaran == null ||
        _kategori == null ||
        _tanggalPesanan == null ||
        _priceController.text.isEmpty ||
        _jumlahController.text.isEmpty ||
        _grandTotalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Harap lengkapi semua data formulir pesanan!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade800,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Memproses prediksi risiko...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      double priceVal =
          double.tryParse(_priceController.text.replaceAll('.', '')) ?? 0;
      int qtyVal =
          int.tryParse(_jumlahController.text.replaceAll('.', '')) ?? 1;
      double grandTotalVal =
          double.tryParse(_grandTotalController.text.replaceAll('.', '')) ?? 0;

      int orderYear = _tanggalPesanan!.year;
      int orderMonth = _tanggalPesanan!.month;
      int orderDay = _tanggalPesanan!.day;
      int orderDayOfWeek = _tanggalPesanan!.weekday - 1;

      final url = Uri.parse('$apiBaseUrl/predict');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'price': priceVal,
          'qty_ordered': qtyVal,
          'grand_total': grandTotalVal,
          'order_year': orderYear,
          'order_month': orderMonth,
          'order_day': orderDay,
          'order_dayofweek': orderDayOfWeek,
          'category_name_1': _kategori,
          'payment_method_class': _metodePembayaran,
          'tanggal_pesanan': _tanggalController.text,
          'kategori': _kategori,
          'harga_satuan': priceVal,
          'jumlah': qtyVal,
          'total_harga': grandTotalVal,
          'metode_pembayaran': _metodePembayaran,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataJson = jsonDecode(response.body);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HasilPrediksiScreen(
              hasilApi: dataJson,
              metodeAwalFallback: _metodePembayaran!,
            ),
          ),
        );
      } else {
        setState(() {
          _isError = true;
          _errorMessage =
              "Server merespons dengan kode error ${response.statusCode}.\n${response.body}";
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      setState(() {
        _isError = true;
        _errorMessage =
            "Gagal terhubung ke server.\nPastikan server Python (Flask) menyala di $apiBaseUrl.";
      });
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _priceController.dispose();
    _jumlahController.dispose();
    _grandTotalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Input Data Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isError ? _buildErrorScreen() : _buildFormScreen(),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 84, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Koneksi Terputus!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => setState(() => _isError = false),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BAGIAN 1: INFORMASI PESANAN
          _buildSectionCard(
            title: 'Detail Pesanan',
            icon: Icons.shopping_bag_outlined,
            children: [
              const Text(
                'Tanggal Pesanan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tanggalController,
                readOnly: true,
                onTap: _pilihTanggal,
                decoration: const InputDecoration(
                  hintText: 'Pilih tanggal pesanan',
                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kategori Barang',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _kategori,
                decoration: const InputDecoration(
                  hintText: 'Pilih kategori barang',
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                ),
                items: _daftarKategori.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() => _kategori = newValue),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // BAGIAN 2: RINCIAN NOMINAL
          _buildSectionCard(
            title: 'Rincian Harga & Kuantitas',
            icon: Icons.payments_outlined,
            children: [
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FormatUangIndonesia()],
                decoration: const InputDecoration(
                  labelText: 'Harga Baris Produk / Price',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _jumlahController,
                keyboardType: TextInputType.number,
                inputFormatters: [FormatUangIndonesia()],
                decoration: const InputDecoration(
                  labelText: 'Jumlah Barang (qty_ordered)',
                  prefixIcon: Icon(Icons.numbers, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _grandTotalController,
                keyboardType: TextInputType.number,
                inputFormatters: [FormatUangIndonesia()],
                decoration: const InputDecoration(
                  labelText: 'Total Transaksi / Grand Total',
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // BAGIAN 3: PILIHAN METODE PEMBAYARAN (CARD STYLE)
          _buildSectionCard(
            title: 'Metode Pembayaran Awal',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentOptionCard(
                      'COD',
                      Icons.local_shipping_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPaymentOptionCard(
                      'Online',
                      Icons.credit_card_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPaymentOptionCard(
                      'Internal Credit',
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),

          // TOMBOL ANALISIS AI
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _prosesPrediksiAI,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text(
                'Cek Prediksi Risiko',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1E40AF)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOptionCard(String label, IconData icon) {
    final isSelected = _metodePembayaran == label;
    return InkWell(
      onTap: () => setState(() => _metodePembayaran = label),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1E40AF) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color:
                  isSelected ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HALAMAN 4: DETAIL ANALISIS AI (MOBILE HERO)
// ==========================================
class HasilPrediksiScreen extends StatelessWidget {
  final Map<String, dynamic> hasilApi;
  final String metodeAwalFallback;

  const HasilPrediksiScreen({
    super.key,
    required this.hasilApi,
    required this.metodeAwalFallback,
  });

  @override
  Widget build(BuildContext context) {
    final String metodeAwal =
        (hasilApi['metode_awal'] ?? metodeAwalFallback).toString();
    final double threshold =
        (hasilApi['threshold'] as num?)?.toDouble() ?? 0.50;
    final double probAwal = (hasilApi['probabilitas_awal'] as num?) != null
        ? (hasilApi['probabilitas_awal'] as num).toDouble()
        : ((hasilApi['risiko_awal_persen'] as num?)?.toDouble() ?? 0.0) / 100.0;
    final double risikoAwalPersen =
        (hasilApi['risiko_awal_persen'] as num?)?.toDouble() ??
            (probAwal * 100.0);

    final bool isHighRisk = probAwal >= threshold;
    final String labelRisiko =
        isHighRisk ? 'Risiko Tinggi' : 'Aman (Di Bawah Ambang)';
    final Color warnaRisiko =
        isHighRisk ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final Color bgRisiko =
        isHighRisk ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);

    final bool rekomendasiValid = hasilApi['rekomendasi_valid'] == true;
    final String? metodeRekomendasi =
        hasilApi['metode_rekomendasi']?.toString();
    final double? risikoAkhirPersen =
        (hasilApi['risiko_akhir_persen'] as num?)?.toDouble();
    final List<dynamic> evaluasiAlternatif =
        (hasilApi['evaluasi_alternatif'] as List<dynamic>?) ?? [];

    final bool adaInternalCredit = metodeRekomendasi == 'Internal Credit' ||
        evaluasiAlternatif
            .any((item) => item['metode']?.toString() == 'Internal Credit');

    final String pesanPelanggan =
        'Halo Kak, pesanan Anda dengan metode pembayaran $metodeAwal teridentifikasi memiliki risiko pembatalan tinggi (${formatPersenIndo(risikoAwalPersen)}). Agar pesanan dapat diproses lebih cepat dan aman, apakah Anda bersedia mengganti metode pembayaran menjadi $metodeRekomendasi?';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hasil Analisis Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // HERO CARD SKOR RISIKO DENGAN GAUGE LINGKARAN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: warnaRisiko.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: warnaRisiko.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: bgRisiko,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHighRisk
                              ? Icons.warning_rounded
                              : Icons.verified_rounded,
                          color: warnaRisiko,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          labelRisiko,
                          style: TextStyle(
                            color: warnaRisiko,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // CIRCULAR GAUGE
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: probAwal.clamp(0.0, 1.0),
                            strokeWidth: 12,
                            strokeCap: StrokeCap.round,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(warnaRisiko),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatPersenIndo(risikoAwalPersen),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: warnaRisiko,
                              ),
                            ),
                            const Text(
                              'Risiko Batal',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Metode Awal: $metodeAwal  •  Ambang Batas: ${(threshold * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // KARTU REKOMENDASI BOUNDED COUNTERFACTUAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.recommend_outlined,
                          color: Color(0xFF1E40AF), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Rekomendasi Bounded Counterfactual',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isHighRisk) ...[
                    if (rekomendasiValid &&
                        metodeRekomendasi != null &&
                        risikoAkhirPersen != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF6EE7B7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Alternatif Terbaik Ditemukan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  metodeAwal,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.arrow_forward_rounded,
                                      size: 16, color: Color(0xFF059669)),
                                ),
                                Text(
                                  metodeRekomendasi,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Risiko turun menjadi ${formatPersenIndo(risikoAkhirPersen)} (Memenuhi ambang < ${(threshold * 100).toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFDC2626)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tidak ditemukan alternatif metode pembayaran yang menurunkan risiko di bawah 50%.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (evaluasiAlternatif.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Simulasi Alternatif Metode Pembayaran:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...evaluasiAlternatif.map((item) {
                        final String namaAlt =
                            item['metode']?.toString() ?? '-';
                        final double probAlt =
                            (item['probabilitas'] as num?)?.toDouble() ?? 0.0;
                        final double persenAlt =
                            (item['risiko_persen'] as num?)?.toDouble() ??
                                (probAlt * 100.0);
                        final bool memenuhi = probAlt < threshold;
                        final bool isSelected =
                            rekomendasiValid && namaAlt == metodeRekomendasi;
                        final Color c = memenuhi
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        namaAlt,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Terpilih',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    formatPersenIndo(persenAlt),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: c,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: probAlt.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(c),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    if (adaInternalCredit) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'Catatan: Internal Credit merupakan alternatif simulasi model karena belum tentu tersedia bagi semua pelanggan.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF92400E),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF6EE7B7)),
                      ),
                      child: const Text(
                        'Probabilitas pembatalan berada di bawah ambang risiko tinggi (50%). Pesanan aman untuk langsung diproses tanpa perubahan metode pembayaran.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF065F46),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // TINDAK LANJUT ADMIN + TOMBOL SALIN PESAN
            if (isHighRisk) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.support_agent_rounded,
                            color: Color(0xFF1E40AF), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tindak Lanjut Admin',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (rekomendasiValid && metodeRekomendasi != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '"$pesanPelanggan"',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: pesanPelanggan));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Pesan tindak lanjut berhasil disalin!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF059669),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Salin Pesan untuk Pelanggan'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Seluruh alternatif masih berisiko ≥ 50%. Admin disarankan melakukan verifikasi manual (telepon/chat konfirmasi alamat & keseriusan) sebelum mengirim barang.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // TOMBOL KEMBALI KE DASHBOARD
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context); // tutup hasil
                  Navigator.pop(context); // tutup form -> kembali ke dashboard
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Selesai & Kembali ke Beranda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
