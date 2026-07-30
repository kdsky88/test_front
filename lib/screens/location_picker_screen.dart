import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geocoding_api.dart';

/// 지도 피커가 돌려주는 선택 결과.
class PickedLocation {
  final double lat;
  final double lng;
  final String? name;
  const PickedLocation({required this.lat, required this.lng, this.name});
}

/// 지도에서 위치를 고른다: 검색(무료 Nominatim) 또는 지도 탭으로 핀.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial, this.initialName});

  final LatLng? initial;
  final String? initialName;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _seoul = LatLng(37.5665, 126.9780);

  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<GeocodeResult> _results = const [];

  LatLng? _selected;
  String? _placeName;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _placeName = widget.initialName;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // 정책상 초당 1회 → 600ms 디바운스.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    setState(() => _searching = true);
    try {
      final results = await GeocodingApi.search(value);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickResult(GeocodeResult r) {
    final p = LatLng(r.lat, r.lon);
    setState(() {
      _selected = p;
      _placeName = r.shortName;
      _results = const [];
      _searchCtrl.text = r.shortName;
    });
    _mapController.move(p, 15);
    FocusScope.of(context).unfocus();
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selected = point;
      _results = const [];
      // 직접 찍은 지점은 이름 미상 → 검색으로 넣은 이름이 있으면 유지, 없으면 null.
    });
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.of(context).pop(PickedLocation(
      lat: _selected!.latitude,
      lng: _selected!.longitude,
      name: _placeName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('장소 선택')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected ?? widget.initial ?? _seoul,
              initialZoom: _selected != null ? 15 : 11,
              onTap: (tapPosition, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.openclaw.todo_app',
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on, size: 44, color: theme.colorScheme.error),
                    ),
                  ],
                ),
            ],
          ),
          // 검색창 + 결과
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: (v) {
                      _debounce?.cancel();
                      _runSearch(v);
                    },
                    decoration: InputDecoration(
                      hintText: '장소 검색 (예: 성산일출봉)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : (_searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() {
                                    _searchCtrl.clear();
                                    _results = const [];
                                  }),
                                )
                              : null),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      isDense: true,
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, size: 20),
                          title: Text(r.shortName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(r.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _pickResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selected == null
                      ? '지도를 눌러 위치를 찍거나 검색하세요'
                      : (_placeName ?? '선택한 위치 (${_selected!.latitude.toStringAsFixed(4)}, ${_selected!.longitude.toStringAsFixed(4)})'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _selected == null ? null : _confirm,
                icon: const Icon(Icons.check),
                label: const Text('이 위치'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
