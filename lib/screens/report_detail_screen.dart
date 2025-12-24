import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const ReportDetailScreen({super.key, required this.reportId, required this.data});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late String _currentStatus;
  bool _isLoading = false;
  bool _isFollowing = false;
  bool _isAdmin = false;
  final _auth = FirebaseAuth.instance;
  final List<String> _statuses = ['Açık', 'İnceleniyor', 'Çözüldü'];
  List<String> _imageUrls = [];
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.data['status'] ?? 'Açık';

    if (widget.data['imageUrls'] != null) {
      _imageUrls = List<String>.from(widget.data['imageUrls']);
    } else if (widget.data['imageUrl'] != null) {
      _imageUrls = [widget.data['imageUrl']];
    }

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _isFollowing = (widget.data['followers'] ?? []).contains(uid);
      if (_auth.currentUser?.email == 'admin@kampusguvenlik.com' ||
          _auth.currentUser?.email == 'akifensar.dr@gmail.com') {
        _isAdmin = true;
      }
    }
  }

  // --- TÜRÜNE GÖRE RENK BELİRLEME ---
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

  Future<void> _toggleFollow() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final docRef = FirebaseFirestore.instance.collection('reports').doc(widget.reportId);

    try {
      if (_isFollowing) {
        await docRef.update({'followers': FieldValue.arrayRemove([uid])});
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text("Takip bırakıldı.")));
      } else {
        await docRef.update({'followers': FieldValue.arrayUnion([uid])});
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text("Bildirim takip ediliyor.")));
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({'status': newStatus});
      if (!mounted) return;
      setState(() => _currentStatus = newStatus);
      messenger.showSnackBar(SnackBar(content: Text("Durum: $newStatus")));
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Açık': return Colors.red;
      case 'İnceleniyor': return Colors.orange;
      case 'Çözüldü': return Colors.green;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    GeoPoint? gp = widget.data['location'];
    LatLng loc = gp != null ? LatLng(gp.latitude, gp.longitude) : const LatLng(39.9043, 41.2679);

    String fullDate = "Tarih Yok";
    if (widget.data['createdAt'] != null) {
      final d = (widget.data['createdAt'] as Timestamp).toDate();
      fullDate = "${d.day}/${d.month}/${d.year} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
    }

    final String reportType = widget.data['type'] ?? 'Diğer';
    final Color typeColor = _getTypeColor(reportType);

    return Scaffold(
      appBar: AppBar(title: const Text("Bildirim Detayı")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageUrls.isNotEmpty)
              Column(
                children: [
                  SizedBox(
                      height: 250,
                      child: PageView.builder(
                          itemCount: _imageUrls.length,
                          onPageChanged: (i) => setState(() => _currentImageIndex = i),
                          itemBuilder: (c, i) => GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => FullScreenImageViewer(imageUrl: _imageUrls[i]))),
                              child: Hero(tag: _imageUrls[i], child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_imageUrls[i], fit: BoxFit.cover)))
                          )
                      )
                  ),
                  if (_imageUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text("${_currentImageIndex + 1} / ${_imageUrls.length}", style: const TextStyle(color: Colors.grey)),
                    ),
                ],
              ),
            const SizedBox(height: 20),

            // --- BAŞLIK VE TÜR ETİKETİ ---
            Row(
              children: [
                Expanded(
                  child: Text(
                      widget.data['title'] ?? '',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: typeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    reportType.toUpperCase(),
                    style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("Yayınlanma: $fullDate", style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const Divider(height: 30),
            Text(widget.data['description'] ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(height: 180, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: GoogleMap(initialCameraPosition: CameraPosition(target: loc, zoom: 15), markers: {Marker(markerId: const MarkerId("m"), position: loc)}, liteModeEnabled: true))),
            const SizedBox(height: 20),

            // Takip Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _toggleFollow,
                icon: Icon(_isFollowing ? Icons.notifications_off : Icons.notifications_active),
                label: Text(_isFollowing ? "TAKİBİ BIRAK" : "TAKİP ET"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            if (_isAdmin) ...[
              const Divider(height: 40),
              const Text("Yönetici İşlemleri", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                  value: _currentStatus,
                  isExpanded: true,
                  items: _statuses.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: TextStyle(color: _getStatusColor(s), fontWeight: FontWeight.bold))
                  )).toList(),
                  onChanged: (v) { if (v != null) _updateStatus(v); }
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});
  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _isDownloading = false;

  Future<void> _saveImage() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDownloading = true);
    try {
      final resp = await Dio().get(widget.imageUrl, options: Options(responseType: ResponseType.bytes));
      final f = File('${Directory.systemTemp.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await f.writeAsBytes(resp.data);
      await Gal.putImage(f.path);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text("Galeriye Kaydedildi! ✅")));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black.withValues(alpha: 0.5), iconTheme: const IconThemeData(color: Colors.white), actions: [
        _isDownloading
            ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white))
            : IconButton(icon: const Icon(Icons.download), onPressed: _saveImage)
      ]),
      body: InteractiveViewer(child: Center(child: Hero(tag: widget.imageUrl, child: Image.network(widget.imageUrl)))),
    );
  }
}