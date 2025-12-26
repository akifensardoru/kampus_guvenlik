import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'login_screen.dart';
import 'report_detail_screen.dart'; // Detay sayfasına gitmek için import ekledik

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  File? _localImage;
  bool _isUploading = false;

  final Map<String, bool> _defaultSettings = {
    'Güvenlik': true,
    'Sağlık': true,
    'Yangın': true,
    'Teknik': false,
    'Çevre': true,
    'Kayıp-Buluntu': true,
    'Diğer': true,
  };

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Fotoğraf Çek'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _localImage = File(pickedFile.path);
        _isUploading = true;
      });

      try {
        await _uploadProfileImage(_localImage!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profil fotoğrafı güncellendi!")),
          );
        }
      } catch (e) {
        debugPrint("Yükleme hatası: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
    await ref.putFile(imageFile);
    String downloadUrl = await ref.getDownloadURL();
    await _firestore.collection('users').doc(user.uid).update({
      'photoUrl': downloadUrl,
    });
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'notificationSettings': {
        key: value
      }
    }, SetOptions(merge: true));
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

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        Map<String, dynamic>? userData = snapshot.data?.data() as Map<String, dynamic>?;
        String? cloudPhotoUrl = userData?['photoUrl'];
        String userName = userData?['fullName'] ?? "Kullanıcı";
        String userDept = userData?['department'] ?? "Birim Yok";
        String userRole = userData?['role'] ?? "user";

        Map<String, dynamic> currentSettings = Map.from(_defaultSettings);
        if (userData != null && userData.containsKey('notificationSettings')) {
          currentSettings = Map<String, dynamic>.from(userData['notificationSettings']);
          _defaultSettings.forEach((key, value) {
            if (!currentSettings.containsKey(key)) {
              currentSettings[key] = value;
            }
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Profil ve Ayarlar")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'profile_pic_tag',
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _localImage != null
                              ? FileImage(_localImage!) as ImageProvider
                              : (cloudPhotoUrl != null && cloudPhotoUrl.isNotEmpty
                              ? NetworkImage(cloudPhotoUrl)
                              : null),
                          child: (_localImage == null && (cloudPhotoUrl == null || cloudPhotoUrl.isEmpty))
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                      ),
                      if (_isUploading)
                        const Positioned.fill(child: CircularProgressIndicator(color: Colors.blue)),
                      Positioned(
                        bottom: 0, right: 0,
                        child: InkWell(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                Text(userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text("Rol: $userRole | $userDept",
                      style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w500, fontSize: 12)),
                ),

                const Divider(height: 30),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Bildirim Tercihleri", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                ..._defaultSettings.keys.map((String key) {
                  bool isSwitched = currentSettings[key] ?? false;
                  return CheckboxListTile(
                    title: Text(key),
                    value: isSwitched,
                    activeColor: Colors.blue,
                    onChanged: (bool? value) {
                      _updateNotificationSetting(key, value ?? false);
                    },
                  );
                }),

                const Divider(height: 30),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.bookmark, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Takip Ettiğim Bildirimler", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('reports').where('followers', arrayContains: user?.uid).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        child: const Text("Henüz takip ettiğiniz bir bildirim yok.", style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index]; // Dokümanı aldık
                        var data = doc.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () {
                              // TIKLAMA ÖZELLİĞİ EKLENDİ
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReportDetailScreen(
                                    reportId: doc.id,
                                    data: data,
                                  ),
                                ),
                              );
                            },
                            leading: const Icon(Icons.circle, size: 12, color: Colors.blue),
                            title: Text(data['title'] ?? 'Başlıksız'),
                            subtitle: Text("Durum: ${data['status'] ?? 'Belirsiz'}"),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text("Çıkış Yap"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}