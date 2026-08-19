import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import '../models/todo.dart'; // ApiException
import '../services/map_links.dart';
import '../services/places_api.dart';
import '../widgets/empty_state.dart';

/// 내 주변 지금 추천 — 현재 위치(GPS) 기준 관광지/맛집. 카드 탭 → 길찾기.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  String _type = 'attraction';
  Position? _pos;
  List<Place>? _places;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _pos ??= await _getPosition();
      if (_pos == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final places = await PlacesApi.nearby(lat: _pos!.latitude, lng: _pos!.longitude, type: _type);
      if (!mounted) return;
      setState(() {
        _places = places;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error ??= '불러오지 못했어요';
        _loading = false;
      });
    }
  }

  Future<Position?> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _error = '위치 서비스가 꺼져 있어요. 켜고 다시 시도해주세요.';
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      _error = '위치 권한이 필요해요.';
      return null;
    }
    return Geolocator.getCurrentPosition();
  }

  void _onType(String t) {
    if (t == _type) return;
    setState(() => _type = t);
    _load();
  }

  String _distLabel(Place p) {
    final pos = _pos;
    if (pos == null) return '';
    final m = Geolocator.distanceBetween(pos.latitude, pos.longitude, p.latitude, p.longitude);
    return m >= 1000 ? '${(m / 1000).toStringAsFixed(1)}km' : '${m.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 주변')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'attraction', label: Text('관광지'), icon: Icon(Icons.photo_camera_outlined, size: 18)),
                ButtonSegment(value: 'food', label: Text('맛집'), icon: Icon(Icons.restaurant_outlined, size: 18)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _onType(s.first),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        emoji: '📍',
        title: '위치를 확인할 수 없어요',
        subtitle: _error,
        action: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('다시 시도')),
      );
    }
    final places = _places;
    if (places == null || places.isEmpty) {
      return const EmptyState(emoji: '🔍', title: '주변에 결과가 없어요', subtitle: '관광지/맛집을 바꿔보세요.');
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = places[i];
        return Card(
          child: InkWell(
            onTap: () => openInGoogleMaps(lat: p.latitude, lng: p.longitude, directions: true),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (p.category != null) ...[
                          const SizedBox(height: 2),
                          Text(p.category!, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                        if (p.address != null) ...[
                          const SizedBox(height: 2),
                          Text(p.address!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_distLabel(p), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                      const SizedBox(height: 2),
                      Icon(Icons.directions, color: theme.colorScheme.primary, size: 22),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
