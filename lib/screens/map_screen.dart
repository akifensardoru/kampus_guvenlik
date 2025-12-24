import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; // Konum servis kontrolü için eklendi
import 'report_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _centerLocation = LatLng(39.9043, 41.2679);
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  int _lastDocCount = 0;

  @override
  void initState() {
    super.initState();
    _checkLocationSettings(); // Sayfa açıldığında kontrol et
  }

  // --- KONUM SERVİS VE İZİN KONTROLÜ ---
  Future<void> _checkLocationSettings() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Konum servisi (GPS) açık mı?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showLocationDialog(
        "Konum Servisi Kapalı",
        "Haritada konumunuzu görebilmek için lütfen cihazın konum servisini (GPS) açın.",
        true,
      );
      return;
    }

    // 2. Uygulamanın konum izni var mı?
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Konum izni reddedildi.")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _showLocationDialog(
        "Konum İzni Gerekli",
        "Konum iznini kalıcı olarak reddettiniz. Lütfen ayarlardan izin verin.",
        false,
      );
      return;
    }
  }

  // Kullanıcıyı yönlendiren uyarı penceresi
  void _showLocationDialog(String title, String content, bool isService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isService) {
                await Geolocator.openLocationSettings(); // GPS ayarlarını açar
              } else {
                await Geolocator.openAppSettings(); // Uygulama izinlerini açar
              }
            },
            child: const Text("Ayarlara Git"),
          ),
        ],
      ),
    );
  }

  double _getMarkerColor(String type) {
    switch (type) {
      case 'Güvenlik': return BitmapDescriptor.hueRed;
      case 'Sağlık': return BitmapDescriptor.hueBlue;
      case 'Yangın': return BitmapDescriptor.hueOrange;
      case 'Teknik': return BitmapDescriptor.hueYellow;
      case 'Çevre': return BitmapDescriptor.hueGreen;
      default: return BitmapDescriptor.hueAzure;
    }
  }

  void _createMarkers(List<QueryDocumentSnapshot> docs) {
    if (_lastDocCount == docs.length) return;
    _lastDocCount = docs.length;

    Set<Marker> newMarkers = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final GeoPoint? gp = data['location'];

      if (gp != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(gp.latitude, gp.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerColor(data['type'] ?? '')),
            infoWindow: InfoWindow(
              title: data['title'] ?? 'Başlıksız Bildirim',
              snippet: "Detayı Gör",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (context) => ReportDetailScreen(reportId: doc.id, data: data)
                ));
              },
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _markers = newMarkers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kampüs Bildirim Haritası"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      // --- ÖZEL KONUM BUTONU ---
      // Haritanın üzerindeki varsayılan buton bazen stabil çalışmaz,
      // FloatingActionButton ile kontrolü tamamen biz alıyoruz.
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        mini: true,
        onPressed: () async {
          await _checkLocationSettings(); // Butona basınca tekrar kontrol et
          // Eğer her şey tamamsa konuma odaklan
          Position pos = await Geolocator.getCurrentPosition();
          _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
        },
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _createMarkers(snapshot.data!.docs));
          }

          return GoogleMap(
            initialCameraPosition: const CameraPosition(target: _centerLocation, zoom: 14.5),
            markers: _markers,
            mapType: MapType.hybrid,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Kendi butonumuzu eklediğimiz için kapattık
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          );
        },
      ),
    );
  }
}