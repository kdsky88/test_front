import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/todo.dart'; // ApiException
import '../services/location_perm.dart';
import '../services/places_api.dart';

/// 지도 피커가 돌려주는 선택 결과.
class PickedLocation {
  final double lat;
  final double lng;
  final String? name;
  const PickedLocation({required this.lat, required this.lng, this.name});
}

/// 검색 결과를 지도에 꽂기 위한 형태.
class _Hit {
  final double lat;
  final double lon;
  final String name;
  final String? subtitle;
  const _Hit({required this.lat, required this.lon, required this.name, this.subtitle});
}

/// 구글맵에서 위치를 고른다: 주소/관광지/맛집 검색(구글 Places) 또는 지도 탭.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialName,
    this.initialQuery,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialName;

  /// 여행 목적지 등. 있으면 열자마자 그 지역의 관광지를 자동 검색.
  final String? initialQuery;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _seoul = LatLng(37.5665, 126.9780);

  GoogleMapController? _mapController;
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _mode = 'address'; // 'address' | 'attraction' | 'food'
  List<_Hit> _results = const [];
  String? _searchError;

  LatLng? _selected;
  String? _placeName;
  bool _myLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
    }
    _placeName = widget.initialName;
    ensureLocationPermission().then((ok) {
      if (ok && mounted) setState(() => _myLocation = true);
    });
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      // 여행 목적지가 있으면 관광지로 시작.
      _searchCtrl.text = q;
      _mode = 'attraction';
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch(q));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  bool get _isRecommend => _mode != 'address';

  void _onSearchChanged(String value) {
    // 모두 구글 Places(과금) → 라이브 검색 없이 제출 때만. 비면 결과만 정리.
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searchError = null;
      });
    }
  }

  void _onModeChanged(String mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _results = const [];
      _searchError = null;
    });
    if (_searchCtrl.text.trim().isNotEmpty) _runSearch(_searchCtrl.text);
  }

  Future<void> _runSearch(String value) async {
    final q = value.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final places = await PlacesApi.recommend(region: q, type: _mode);
      final hits = places
          .map((p) => _Hit(
                lat: p.latitude,
                lon: p.longitude,
                name: p.name,
                subtitle: [p.category, p.address]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(' · '),
              ))
          .toList();
      if (mounted) setState(() => _results = hits);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _results = const [];
          _searchError = e.error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = const [];
          _searchError = '검색에 실패했어요';
        });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickHit(_Hit h) {
    final p = LatLng(h.lat, h.lon);
    setState(() {
      _selected = p;
      _placeName = h.name;
      _results = const [];
      _searchCtrl.text = h.name;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(p, 15));
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

  String get _hint => _isRecommend ? '지역 입력 (예: 후쿠오카)' : '장소 검색 (예: 성산일출봉)';

  IconData get _hitIcon => switch (_mode) {
        'attraction' => Icons.photo_camera_outlined,
        'food' => Icons.restaurant_outlined,
        _ => Icons.place_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('장소 선택')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selected ?? _seoul,
              zoom: _selected != null ? 15 : 11,
            ),
            onMapCreated: (c) => _mapController = c,
            onTap: _onMapTap,
            markers: _selected == null
                ? const {}
                : {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selected!,
                      infoWindow: InfoWindow(title: _placeName ?? '선택한 위치'),
                    ),
                  },
            myLocationEnabled: _myLocation,
            myLocationButtonEnabled: _myLocation,
            // 상단 검색 UI와 안 겹치게 내 위치 버튼을 아래로.
            padding: const EdgeInsets.only(top: 116),
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          // 검색창 + 모드 토글 + 결과
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
                    onSubmitted: (v) => _runSearch(v),
                    decoration: InputDecoration(
                      hintText: _hint,
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
                                    _searchError = null;
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
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: 'address', label: Text('주소'), icon: Icon(Icons.place_outlined, size: 18)),
                    ButtonSegment(value: 'attraction', label: Text('관광지'), icon: Icon(Icons.photo_camera_outlined, size: 18)),
                    ButtonSegment(value: 'food', label: Text('맛집'), icon: Icon(Icons.restaurant_outlined, size: 18)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _onModeChanged(s.first),
                ),
                if (_searchError != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_searchError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                  ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 280),
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
                        final h = _results[i];
                        return ListTile(
                          leading: Icon(_hitIcon, size: 22, color: theme.colorScheme.primary),
                          title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: h.subtitle != null && h.subtitle!.isNotEmpty
                              ? Text(h.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          onTap: () => _pickHit(h),
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
                      ? '검색해서 고르거나 지도를 눌러 위치를 찍으세요'
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
