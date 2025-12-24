import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedType = 'Güvenlik';
  final List<String> _types = ['Güvenlik', 'Sağlık', 'Yangın', 'Teknik', 'Çevre', 'Kayıp-Buluntu', 'Diğer'];

  bool _isLoading = false;

  // --- DÜZELTİLDİ: 'final' EKLENDİ ---
  // Artık sarı uyarı vermeyecek. Listenin kendisi değişmez, içeriği değişebilir.
  final List<File> _selectedImages = [];

  GeoPoint? _currentLocation;
  String _locationMessage = "Konum seçilmedi";

  // --- FOTOĞRAF SEÇME VE EKLEME ---
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.camera) {
        // Kameradan tek foto çek
        final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (photo != null) {
          setState(() {
            _selectedImages.add(File(photo.path));
          });
        }
      } else {
        // Galeriden ÇOKLU foto seç
        final List<XFile> photos = await picker.pickMultiImage(imageQuality: 80);
        if (photos.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(photos.map((e) => File(e.path)));
          });
        }
      }
    } catch (e) {
      debugPrint("Fotoğraf hatası: $e");
    }
  }

  // --- FOTOĞRAF SİLME (LİSTEDEN ÇIKARMA) ---
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // --- SEÇİM MENÜSÜ ---
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text("Galeriden (Çoklu Seçim)"),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.red),
                title: const Text("Kamera ile Çek"),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Konum izni verilmedi.";
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;
      setState(() {
        _currentLocation = GeoPoint(position.latitude, position.longitude);
        _locationMessage = "Konum: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konum alındı!")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- KAYDETME İŞLEMİ (ÇOKLU YÜKLEME) ---
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen konum bilgisi ekleyin.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Kullanıcı bulunamadı");

      // --- ÇOKLU FOTOĞRAF YÜKLEME DÖNGÜSÜ ---
      List<String> imageUrls = [];

      // Her bir resmi sırayla yükle
      for (var imageFile in _selectedImages) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('report_images')
            .child('${DateTime.now().millisecondsSinceEpoch}_${_selectedImages.indexOf(imageFile)}.jpg');

        await storageRef.putFile(imageFile);
        final url = await storageRef.getDownloadURL();
        imageUrls.add(url);
      }
      // ----------------------------------------

      await FirebaseFirestore.instance.collection('reports').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'type': _selectedType,
        'status': 'Açık',
        'userId': user.uid,
        'userEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'imageUrls': imageUrls, // Resim Listesi
        'location': _currentLocation,
        'followers': [],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bildirim başarıyla oluşturuldu!")));
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Yeni Bildirim")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: "Tür", border: OutlineInputBorder()),
                items: _types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Başlık", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Gerekli" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Açıklama", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Gerekli" : null,
              ),
              const SizedBox(height: 20),

              // --- FOTOĞRAF LİSTESİ GÖRÜNÜMÜ ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Fotoğraflar:", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text("Ekle"),
                  ),
                ],
              ),

              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Silme Butonu (X)
                          Positioned(
                            right: 5,
                            top: 5,
                            child: InkWell(
                              onTap: () => _removeImage(index),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: const Text("Henüz fotoğraf seçilmedi", style: TextStyle(color: Colors.grey)),
                ),
              // ------------------------------------

              const SizedBox(height: 20),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: Text(_locationMessage),
                trailing: ElevatedButton(onPressed: _getCurrentLocation, child: const Text("Konum Al")),
              ),

              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                  child: const Text("BİLDİRİMİ GÖNDER")
              ),
            ],
          ),
        ),
      ),
    );
  }
}