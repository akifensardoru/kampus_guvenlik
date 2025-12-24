import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Provider ekledik

// Gerekli dosyaları import ettiğinden emin ol
import '../app_settings.dart';
import 'add_report_screen.dart';
import 'report_detail_screen.dart';
import 'map_screen.dart';
import 'admin_panel_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'about_us_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isAdmin = false;
  String _searchText = "";
  String _selectedStatus = "Tümü";

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    User? currentUser = _auth.currentUser;
    if (mounted) setState(() => _isAdmin = false);

    if (currentUser != null) {
      if (currentUser.email == "akifensar.dr@gmail.com") {
        if (mounted) setState(() => _isAdmin = true);
        return;
      }
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
          if (data?['role'] == 'admin') {
            if (mounted) setState(() => _isAdmin = true);
          }
        }
      } catch (e) {
        debugPrint("Yetki kontrolü hatası: $e");
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Açık': return Colors.red;
      case 'İnceleniyor': return Colors.orange;
      case 'Çözüldü': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Güvenlik': return Icons.security;
      case 'Sağlık': return Icons.local_hospital;
      case 'Yangın': return Icons.fire_extinguisher;
      case 'Teknik': return Icons.build;
      case 'Çevre': return Icons.eco;
      case 'Kayıp-Buluntu': return Icons.find_in_page;
      default: return Icons.info;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Güvenlik': return Colors.blue.shade700;
      case 'Sağlık': return Colors.red.shade600;
      case 'Yangın': return Colors.orange.shade800;
      case 'Teknik': return Colors.blueGrey.shade700;
      case 'Çevre': return Colors.green.shade600;
      case 'Kayıp-Buluntu': return Colors.amber.shade800;
      default: return Colors.indigo;
    }
  }

  void _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    // MERKEZİ AYARLARI BURADA DİNLİYORUZ
    final settings = Provider.of<AppSettings>(context);
    final isEn = settings.isEnglish;

    // Dil Sözlüğü
    final t = {
      'title': isEn ? "AtaCampus" : "AtaKampüs",
      'home': isEn ? "Home" : "Ana Sayfa",
      'profile': isEn ? "Profile & Settings" : "Profil ve Ayarlar",
      'about': isEn ? "About Us" : "Hakkımızda",
      'logout': isEn ? "Logout" : "Çıkış Yap",
      'lang_label': isEn ? "Language: EN" : "Dil: TR",
      'theme_label': isEn ? "Dark Mode" : "Koyu Tema",
      'search': isEn ? "Search..." : "Ara...",
      'filter': isEn ? "Filter: " : "Filtre: ",
      'all': isEn ? "All" : "Tümü",
      'open': isEn ? "Open" : "Açık",
      'investigating': isEn ? "Investigating" : "İnceleniyor",
      'resolved': isEn ? "Resolved" : "Çözüldü",
      'new_report': isEn ? "Create Report" : "Bildirim Oluştur",
      'emergency': isEn ? "EMERGENCY" : "ACİL DURUM",
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(t['title']!),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen())),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                String displayName = "Kullanıcı";
                String? photoUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  displayName = data['fullName'] ?? "Kullanıcı";
                  photoUrl = data['photoUrl'];
                }
                return UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Colors.blue),
                  accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  accountEmail: Text(user?.email ?? ""),
                  currentAccountPicture: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                    },
                    child: Hero(
                      tag: 'profile_pic_tag',
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.blue, size: 40) : null,
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text(t['home']!),
              onTap: () => Navigator.pop(context),
            ),

            // --- TEMA VE DİL SWITCHLERİ ---
            SwitchListTile(
              secondary: const Icon(Icons.language),
              title: Text(t['lang_label']!),
              value: settings.isEnglish,
              onChanged: (val) => settings.toggleLanguage(),
            ),
            SwitchListTile(
              secondary: Icon(settings.isDarkMode ? Icons.dark_mode : Icons.light_mode),
              title: Text(t['theme_label']!),
              value: settings.isDarkMode,
              onChanged: (val) => settings.toggleTheme(),
            ),
            // ------------------------------

            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                title: Text(isEn ? "Admin Panel" : "Admin Paneli"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
                },
              ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: Text(t['profile']!),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.purple),
              title: Text(t['about']!),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: Text(t['logout']!),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('emergency_alerts').where('isActive', isEqualTo: true).orderBy('createdAt', descending: true).limit(1).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
              HapticFeedback.heavyImpact();
              var alert = snapshot.data!.docs.first;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['emergency']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(alert['content'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Container(
            padding: const EdgeInsets.all(10),
            color: settings.isDarkMode ? Colors.black26 : Colors.blue.shade50,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: t['search'],
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: settings.isDarkMode ? Colors.grey[800] : Colors.white,
                  ),
                  onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(t['filter']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      _buildFilterChip(t['all']!, "Tümü"),
                      _buildFilterChip(t['open']!, "Açık"),
                      _buildFilterChip(t['investigating']!, "İnceleniyor"),
                      _buildFilterChip(t['resolved']!, "Çözüldü"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('reports').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['title'] ?? '').toString().toLowerCase().contains(_searchText) &&
                      (_selectedStatus == "Tümü" || data['status'] == _selectedStatus);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    String dateText = "";
                    if (data['createdAt'] != null) {
                      final date = (data['createdAt'] as Timestamp).toDate();
                      dateText = "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                    }
                    final String reportType = data['type'] ?? 'Diğer';
                    final categoryColor = _getTypeColor(reportType);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReportDetailScreen(reportId: filteredDocs[index].id, data: data))),
                        leading: CircleAvatar(
                          backgroundColor: categoryColor.withValues(alpha: 0.1),
                          child: Icon(_getTypeIcon(reportType), color: categoryColor),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(reportType, style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(dateText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(data['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(data['status'] ?? 'Açık').withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(data['status'] ?? 'Açık', style: TextStyle(color: _getStatusColor(data['status'] ?? 'Açık'), fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddReportScreen())),
        icon: const Icon(Icons.add),
        label: Text(t['new_report']!),
      ),
    );
  }

  Widget _buildFilterChip(String label, String statusValue) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedStatus == statusValue,
        onSelected: (val) => setState(() => _selectedStatus = statusValue),
      ),
    );
  }
}