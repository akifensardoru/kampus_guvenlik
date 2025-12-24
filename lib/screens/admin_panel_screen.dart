import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _firestore = FirebaseFirestore.instance;

  // --- ARAMA VE FİLTRELEME DEĞİŞKENLERİ ---
  String _searchText = "";
  String _selectedStatus = "Tümü";

  void _updateStatus(String docId, String newStatus) {
    _firestore.collection('reports').doc(docId).update({'status': newStatus});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Durum '$newStatus' olarak güncellendi.")));
  }

  void _editDescription(String docId, String currentDesc) {
    TextEditingController descController = TextEditingController(text: currentDesc);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Açıklamayı Düzenle"),
        content: TextField(
          controller: descController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Yeni Açıklama"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              _firestore.collection('reports').doc(docId).update({'description': descController.text});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Açıklama düzenlendi.")));
            },
            child: const Text("Kaydet"),
          )
        ],
      ),
    );
  }

  void _deleteReport(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Bildirimi Sil"),
        content: const Text("Bu uygunsuz bildirimi kalıcı olarak silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              _firestore.collection('reports').doc(docId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bildirim silindi.")));
            },
            child: const Text("SİL"),
          )
        ],
      ),
    );
  }

  void _sendEmergencyAlert() {
    TextEditingController titleController = TextEditingController();
    TextEditingController contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text("ACİL DURUM")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Başlık", border: OutlineInputBorder(), prefixIcon: Icon(Icons.title))),
            const SizedBox(height: 10),
            TextField(controller: contentController, maxLines: 3, decoration: const InputDecoration(labelText: "Açıklama", border: OutlineInputBorder(), prefixIcon: Icon(Icons.message))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                _firestore.collection('emergency_alerts').add({
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'isActive': true,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🚨 Acil durum mesajı gönderildi!")));
              }
            },
            child: const Text("YAYINLA"),
          )
        ],
      ),
    );
  }

  void _deleteActiveAlert(String docId) {
    _firestore.collection('emergency_alerts').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acil durum yayından kaldırıldı.")));
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Açık': return Colors.red;
      case 'İnceleniyor': return Colors.orange;
      case 'Çözüldü': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Yönetim Paneli"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- ACİL DURUM YÖNETİMİ ---
          Container(
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.campaign),
                    label: const Text("ACİL DURUM YAYINLA"),
                    onPressed: _sendEmergencyAlert,
                  ),
                ),
                // Aktif Uyarıları izleme StreamBuilder (Basitleştirildi)
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('emergency_alerts').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                    return Column(children: snapshot.data!.docs.map((doc) => Card(child: ListTile(title: Text(doc['title']), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => _deleteActiveAlert(doc.id))))).toList());
                  },
                )
              ],
            ),
          ),

          // --- YENİ: ARAMA VE FİLTRELEME ÇUBUĞU ---
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: "Bildirim başlığında ara...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ["Tümü", "Açık", "İnceleniyor", "Çözüldü"].map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _selectedStatus == s,
                        onSelected: (val) => setState(() => _selectedStatus = s),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- BİLDİRİM LİSTESİ ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('reports').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // Filtreleme mantığını buraya uyguluyoruz
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  bool matchesSearch = (data['title'] ?? '').toString().toLowerCase().contains(_searchText);
                  bool matchesStatus = _selectedStatus == "Tümü" || data['status'] == _selectedStatus;
                  return matchesSearch && matchesStatus;
                }).toList();

                if (filteredDocs.isEmpty) return const Center(child: Text("Sonuç bulunamadı."));

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ExpansionTile(
                        leading: CircleAvatar(backgroundColor: _getStatusColor(data['status']), child: const Icon(Icons.assignment, color: Colors.white, size: 20)),
                        title: Text(data['title'] ?? 'Başlıksız', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Durum: ${data['status']}"),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text("Açıklama: ${data['description']}")),
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editDescription(doc.id, data['description'] ?? ''))
                                  ],
                                ),
                                const Divider(),
                                const Text("Durumu Güncelle:", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatusBtn(doc.id, "Açık", Colors.red),
                                    _buildStatusBtn(doc.id, "İnceleniyor", Colors.orange),
                                    _buildStatusBtn(doc.id, "Çözüldü", Colors.green),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(icon: const Icon(Icons.delete_forever), label: const Text("Bildirimi Kalıcı Olarak Sil"), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), onPressed: () => _deleteReport(doc.id)),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBtn(String docId, String status, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color.withValues(alpha: 0.1), foregroundColor: color, elevation: 0),
      onPressed: () => _updateStatus(docId, status),
      child: Text(status),
    );
  }
}