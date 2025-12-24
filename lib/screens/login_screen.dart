import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool isLoading = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedDept;

  final List<String> _departments = [
    'Mühendislik Fakültesi',
    'Tıp Fakültesi',
    'Mimarlık ve Tasarım Fak.',
    'Hukuk Fakültesi',
    'Eğitim Fakültesi',
    'İlahiyat Fakültesi',
    'Fen Fakültesi',
    'Spor Bilimleri Fak.',
    'Diğer'
  ];

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Şifre Sıfırlama Fonksiyonu
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen önce e-posta adresinizi giriniz.")),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Bilgi"),
          content: const Text("Şifre sıfırlama bağlantısı e-posta adresinize gönderildi. Lütfen gelen kutunuzu kontrol ediniz."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tamam"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: ${e.toString()}")),
      );
    }
  }

  bool _isEmailValid(String email) {
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // --- FORM GÖNDERME VE GİRİŞ İŞLEMİ ---
  Future<void> _submitForm() async {
    TextInput.finishAutofillContext();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty || !_isEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen geçerli bir e-posta adresi giriniz.")),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen şifrenizi giriniz.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isLogin) {
        // --- GİRİŞ YAPMA KISMI ---
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Giriş Başarılı!")),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );

      } else {
        // --- KAYIT OLMA KISMI ---
        if (_nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lütfen adınızı giriniz.")),
          );
          setState(() { isLoading = false; });
          return;
        }

        if (phone.isEmpty || phone.length < 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lütfen geçerli bir telefon numarası giriniz.")),
          );
          setState(() { isLoading = false; });
          return;
        }

        if (_selectedDept == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lütfen biriminizi seçiniz.")),
          );
          setState(() { isLoading = false; });
          return;
        }

        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': email,
            'fullName': _nameController.text.trim(),
            'phoneNumber': phone,
            'department': _selectedDept,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kayıt Başarılı! Giriş yapabilirsiniz.")),
        );

        setState(() {
          isLogin = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: ${e.message}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? "Giriş Yap" : "Kayıt Ol"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: AutofillGroup(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- BURASI DEĞİŞTİ ---
                // Eski: const Icon(Icons.security, size: 100, color: Colors.blue),
                // Yeni: Log0 buraya eklendi
                Image.asset(
                  'assets/images/AtaKampus.png',
                  height: 150,
                  width: 150,
                ),
                // -----------------------

                const SizedBox(height: 30),

                if (!isLogin) ...[
                  TextField(
                    controller: _nameController,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: "Ad Soyad",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Telefon Numarası (Örn: 05xxxxxxxxx)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Birim Seçiniz",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    items: _departments.map((String dept) {
                      return DropdownMenuItem<String>(
                        value: dept,
                        child: Text(dept),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDept = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                ],

                TextField(
                  controller: _emailController,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "E-posta",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: _passwordController,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _submitForm,
                  decoration: InputDecoration(
                    labelText: "Şifre",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                ),

                if (isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text("Şifremi Unuttum?"),
                    ),
                  ),

                const SizedBox(height: 25),

                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isLogin ? "Giriş Yap" : "Kayıt Ol"),
                ),

                const SizedBox(height: 15),

                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: Text(isLogin
                      ? "Hesabın yok mu? Kayıt Ol"
                      : "Zaten hesabın var mı? Giriş Yap"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}