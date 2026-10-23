import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place.dart';
import '../services/map_links.dart';

/// 즉흥 장소 추천 시트: 한 곳을 보여주고 '다른 거'로 다시 뽑는다.
/// [recos]는 타입('attraction'|'food')별 추천 목록(실패 시 null).
class SurprisePlaceSheet extends StatefulWidget {
  const SurprisePlaceSheet({
    super.key,
    required this.initial,
    required this.recos,
    required this.rng,
    required this.onAdd,
  });

  final Place initial;
  final Future<List<Place>?> Function(String type) recos;
  final Random rng;
  final ValueChanged<Place> onAdd;

  @override
  State<SurprisePlaceSheet> createState() => _SurprisePlaceSheetState();
}

class _SurprisePlaceSheetState extends State<SurprisePlaceSheet> {
  late Place _current = widget.initial;
  GoogleMapController? _mapCtrl;

  Future<void> _reroll() async {
    HapticFeedback.selectionClick();
    final type = widget.rng.nextBool() ? 'attraction' : 'food';
    final places = await widget.recos(type) ?? const [];
    if (places.isEmpty || !mounted) return;
    setState(() => _current = places[widget.rng.nextInt(places.length)]);
    _mapCtrl?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_current.latitude, _current.longitude), 15));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _current;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎲 장소 추천',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(current.name,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (current.category != null)
                  Text(current.category!,
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                if (current.rating != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 15, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(current.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ],
            ),
            if (current.description != null) ...[
              const SizedBox(height: 8),
              Text(current.description!,
                  style: TextStyle(fontSize: 13.5, height: 1.35, color: theme.colorScheme.onSurface)),
            ],
            if (current.address != null) ...[
              const SizedBox(height: 8),
              Text(current.address!,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            // 위치 미리보기(핀). 팬/줌은 시트와 안 싸우게 끄고, 탭하면 구글 지도로.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 150,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(current.latitude, current.longitude),
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('surprise'),
                      position: LatLng(current.latitude, current.longitude),
                    ),
                  },
                  onMapCreated: (c) => _mapCtrl = c,
                  onTap: (_) => openInGoogleMaps(lat: current.latitude, lng: current.longitude),
                  zoomGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => widget.onAdd(current),
                    icon: const Icon(Icons.add),
                    label: const Text('일정으로 추가'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => openInGoogleMaps(
                      lat: current.latitude, lng: current.longitude, directions: true),
                  icon: const Icon(Icons.directions),
                  label: const Text('길찾기'),
                ),
              ],
            ),
            Center(
              child: TextButton.icon(
                onPressed: _reroll,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('다른 거'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
