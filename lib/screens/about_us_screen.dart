import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Mail göndermek için

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  // --- EKİP LİSTESİ ---
  final List<Map<String, dynamic>> _teamMembers = const [
    {
      'name': 'Akif Ensar Doru',
      'role': 'Geliştirici',
      'icon': Icons.code,
      'color': Colors.blue
    },
    {
      'name': 'Ahmet Tolga Samıkıran',
      'role': 'Geliştirici',
      'icon': Icons.code,
      'color': Colors.cyan
    },

  ];

  // --- MAİL GÖNDERME FONKSİYONU ---
  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'akifensar.dr@gmail.com',
      query: 'subject=AtaKampüs Geri Bildirim&body=Merhaba, uygulama hakkında şöyle bir geri bildirimim var...',
    );

    if (!await launchUrl(emailUri)) {
      debugPrint("Mail uygulaması açılamadı.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hakkımızda"),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. UYGULAMA TANITIMI ---
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security, size: 60, color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "AtaKampüs",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Versiyon 1.0.0",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "AtaKampüs, üniversite içerisindeki güvenlik, sağlık ve teknik sorunların hızlıca raporlanmasını ve çözülmesini sağlayan modern bir kampüs yönetim sistemidir. Güvenli ve sorunsuz bir eğitim hayatı için yanınızdayız.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text("Ekibimiz", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // --- 2. EKİP KARTLARI (GRID TASARIM) ---
            GridView.builder(
              shrinkWrap: true, // Scroll hatasını önler
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Yan yana 2 kutu
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85, // Kartların boy/en oranı
              ),
              itemCount: _teamMembers.length,
              itemBuilder: (context, index) {
                final member = _teamMembers[index];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        // DÜZELTİLDİ: withOpacity yerine withValues kullanıldı
                        backgroundColor: (member['color'] as Color).withValues(alpha: 0.2),
                        child: Icon(member['icon'], color: member['color'], size: 30),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        member['name'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        member['role'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // --- 3. İLETİŞİM VE GERİ BİLDİRİM ---
            const Text("İletişim", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: const Icon(Icons.mail, color: Colors.blue),
                title: const Text("Sorun ve Geri Bildirim"),
                subtitle: const Text("akifensar.dr@gmail.com"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                onTap: _sendEmail, // Tıklayınca mail atar
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}