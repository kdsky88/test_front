import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/location_perm.dart';

final _timeFmt = DateFormat('HH:mm');
final _dayFmt = DateFormat('M/d (E)', 'ko');

/// 두 장소 사이 이동 추정(직선거리 기반, 실제 경로 아님).
/// 거리로 교통수단을 어림잡고 평균 속도로 소요시간을 추정한다.
class _Leg {
  final IconData icon;
  final String mode;
  final String detail; // "약 12분 · 0.9km"

  const _Leg(this.icon, this.mode, this.detail);

  factory _Leg.between(Todo a, Todo b) {
    final m = Geolocator.distanceBetween(
        a.latitude!, a.longitude!, b.latitude!, b.longitude!);
    // ponytail: 직선거리 휴리스틱. 도보 4.5km/h, 대중교통 18km/h, 차량 32km/h(도심 평균).
    final IconData icon;
    final String mode;
    final double kmh;
    if (m < 900) {
      icon = Icons.directions_walk;
      mode = '도보';
      kmh = 4.5;
    } else if (m < 6000) {
      icon = Icons.directions_transit;
      mode = '대중교통';
      kmh = 18;
    } else {
      icon = Icons.directions_car;
      mode = '차량';
      kmh = 32;
    }
    final min = (m / 1000 / kmh * 60).round().clamp(1, 999);
    final dist = m >= 1000 ? '${(m / 1000).toStringAsFixed(1)}km' : '${m.round()}m';
    return _Leg(icon, mode, '약 $min분 · $dist');
  }
}

// 두 시각이 다른 날인지(날짜 구분용).
bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null && b == null;
  final la = a.toLocal(), lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// 여행 미리보기: 시간순 장소를 프레젠테이션처럼 한 곳씩 넘겨보며 지도 카메라가 따라 이동.
/// 경로선(Polyline)으로 전체 동선을, 마커로 각 정지점을 표시한다.
class TripPreviewScreen extends StatefulWidget {
  const TripPreviewScreen({super.key, required this.title, required this.stops});

  final String title;

  /// 위치가 있는 일정을 시간순으로 정렬해서 넘길 것.
  final List<Todo> stops;

  @override
  State<TripPreviewScreen> createState() => _TripPreviewScreenState();
}

class _TripPreviewScreenState extends State<TripPreviewScreen> {
  GoogleMapController? _map;
  int _i = 0;
  Timer? _autoplay;

  Todo get _cur => widget.stops[_i];
  bool get _isFirst => _i == 0;
  bool get _isLast => _i == widget.stops.length - 1;
  bool _myLocation = false;

  @override
  void initState() {
    super.initState();
    ensureLocationPermission().then((ok) {
      if (ok && mounted) setState(() => _myLocation = true);
    });
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _moveCamera() {
    _map?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(_cur.latitude!, _cur.longitude!),
      15,
    ));
  }

  void _goTo(int i) {
    if (i < 0 || i >= widget.stops.length) return;
    HapticFeedback.selectionClick();
    setState(() => _i = i);
    _moveCamera();
  }

  void _toggleAutoplay() {
    if (_autoplay != null) {
      _autoplay!.cancel();
      setState(() => _autoplay = null);
      return;
    }
    setState(() {
      _autoplay = Timer.periodic(const Duration(seconds: 3), (t) {
        if (_isLast) {
          t.cancel();
          if (mounted) setState(() => _autoplay = null);
        } else {
          _goTo(_i + 1);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stops = widget.stops;
    final markers = <Marker>{
      for (int k = 0; k < stops.length; k++)
        Marker(
          markerId: MarkerId(stops[k].id),
          position: LatLng(stops[k].latitude!, stops[k].longitude!),
          // 현재=빨강, 방문(완료)=초록, 나머지=하늘색.
          icon: k == _i
              ? BitmapDescriptor.defaultMarker
              : BitmapDescriptor.defaultMarkerWithHue(
                  stops[k].completed ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure),
          onTap: () => _goTo(k),
        ),
    };
    final route = Polyline(
      polylineId: const PolylineId('route'),
      color: theme.colorScheme.primary,
      width: 4,
      points: [for (final s in stops) LatLng(s.latitude!, s.longitude!)],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} 미리보기'),
        actions: [
          IconButton(
            icon: Icon(_autoplay != null ? Icons.pause_circle : Icons.play_circle),
            tooltip: _autoplay != null ? '멈춤' : '자동 재생',
            onPressed: _toggleAutoplay,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_cur.latitude!, _cur.longitude!),
              zoom: 15,
            ),
            markers: markers,
            polylines: {route},
            onMapCreated: (c) => _map = c,
            myLocationEnabled: _myLocation,
            myLocationButtonEnabled: _myLocation,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          // 하단 카드 + 넘기기 컨트롤.
          Align(
            alignment: Alignment.bottomCenter,
            child: _controlCard(theme),
          ),
        ],
      ),
    );
  }

  Widget _controlCard(ThemeData theme) {
    final when = _cur.startAt ?? _cur.dueAt;
    final total = widget.stops.length;
    // 이전 정지점 기준: 날짜가 바뀌면 Day 구분, 아니면 이동 교통수단 추정.
    final prev = _i > 0 ? widget.stops[_i - 1] : null;
    final prevWhen = prev == null ? null : (prev.startAt ?? prev.dueAt);
    final newDay = prev != null && !_sameDay(prevWhen, when);
    final leg = (prev != null && !newDay) ? _Leg.between(prev, _cur) : null;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜가 바뀌면 Day 구분 배너.
            if (newDay && when != null) ...[
              Row(
                children: [
                  Icon(Icons.event, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('${_dayFmt.format(when.toLocal())} 시작',
                      style: TextStyle(
                          color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
            ],
            // 이동 교통수단 추정(같은 날, 이전 정지점 있을 때).
            if (leg != null) ...[
              Row(
                children: [
                  Icon(leg.icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('${leg.mode}  ${leg.detail}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5)),
                  const SizedBox(width: 6),
                  Text('(예상)', style: TextStyle(color: theme.colorScheme.outline, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    when != null
                        ? '${_dayFmt.format(when.toLocal())}  ${_timeFmt.format(when.toLocal())}'
                        : '시간 미정',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                const Spacer(),
                Text('${_i + 1} / $total',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _cur.placeName ?? _cur.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (_cur.placeName != null && _cur.placeName != _cur.title) ...[
              const SizedBox(height: 2),
              Text(_cur.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isFirst ? null : () => _goTo(_i - 1),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLast ? null : () => _goTo(_i + 1),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('다음'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
