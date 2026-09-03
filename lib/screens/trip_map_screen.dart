import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/todo.dart';
import '../services/location_perm.dart';
import '../services/map_links.dart';

/// 전체화면 인터랙티브 지도: 여행의 장소들을 핀으로. focusId 있으면 그 장소로 확대.
/// 풀스크린이라 스크롤 충돌 없이 확대·축소·이동 자유.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({
    super.key,
    required this.title,
    required this.located,
    this.focusId,
  });

  final String title;
  final List<Todo> located; // latitude/longitude 있는 것만
  final String? focusId;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  GoogleMapController? _controller;
  bool _myLocation = false;

  @override
  void initState() {
    super.initState();
    ensureLocationPermission().then((ok) {
      if (ok && mounted) setState(() => _myLocation = true);
    });
  }

  Todo? get _focus {
    final id = widget.focusId;
    if (id == null) return null;
    for (final t in widget.located) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onCreated(GoogleMapController c) {
    _controller = c;
    final focus = _focus;
    if (focus != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => c.showMarkerInfoWindow(MarkerId(focus.id)),
      );
      return;
    }
    if (widget.located.length > 1) {
      var minLat = widget.located.first.latitude!, maxLat = minLat;
      var minLng = widget.located.first.longitude!, maxLng = minLng;
      for (final t in widget.located) {
        minLat = t.latitude! < minLat ? t.latitude! : minLat;
        maxLat = t.latitude! > maxLat ? t.latitude! : maxLat;
        minLng = t.longitude! < minLng ? t.longitude! : minLng;
        maxLng = t.longitude! > maxLng ? t.longitude! : maxLng;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          60,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final focus = _focus;
    final target = focus != null
        ? LatLng(focus.latitude!, focus.longitude!)
        : LatLng(widget.located.first.latitude!, widget.located.first.longitude!);
    final markers = <Marker>{
      for (final t in widget.located)
        Marker(
          markerId: MarkerId(t.id),
          position: LatLng(t.latitude!, t.longitude!),
          infoWindow: InfoWindow(title: t.placeName ?? t.title),
        ),
    };
    // 포커스된(또는 유일한) 장소가 있으면 길찾기 버튼.
    final dirTarget = focus ?? (widget.located.length == 1 ? widget.located.first : null);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: dirTarget == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openInGoogleMaps(
                lat: dirTarget.latitude!,
                lng: dirTarget.longitude!,
                directions: true,
              ),
              icon: const Icon(Icons.directions),
              label: const Text('길찾기'),
            ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: target, zoom: focus != null ? 16 : 12),
        markers: markers,
        onMapCreated: _onCreated,
        myLocationEnabled: _myLocation,
        myLocationButtonEnabled: _myLocation,
      ),
    );
  }
}
