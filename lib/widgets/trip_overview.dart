import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/todo.dart';
import '../services/weather_api.dart';
import '../theme.dart';

// 여행 상세 '지도 · 날씨 · 여행 기록' 묶음의 조각들.

final _dayFmt = DateFormat('M/d (E)', 'ko');

/// 핀이 여러 개면 다 보이게 카메라 맞춤(지도 레이아웃 후 호출).
void fitMapBounds(GoogleMapController controller, List<LatLng> points) {
  if (points.length < 2) return;
  var minLat = points.first.latitude, maxLat = minLat;
  var minLng = points.first.longitude, maxLng = minLng;
  for (final p in points) {
    minLat = p.latitude < minLat ? p.latitude : minLat;
    maxLat = p.latitude > maxLat ? p.latitude : maxLat;
    minLng = p.longitude < minLng ? p.longitude : minLng;
    maxLng = p.longitude > maxLng ? p.longitude : maxLng;
  }
  final bounds = LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
  });
}

/// 목적지 날씨 가로 스트립(여행 기간, 예보 범위 내). 없으면 빈 칸.
class TripWeatherStrip extends StatelessWidget {
  const TripWeatherStrip({super.key, required this.weather});

  final List<DailyWeather>? weather;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    if (w == null || w.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: w.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = w[i];
          return Container(
            width: 74,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_dayFmt.format(d.date),
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(d.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text('${d.tMax.round()}° / ${d.tMin.round()}°',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 여행 기록 진행바: 방문(완료) N / 전체 M 장소. 장소가 없으면 빈 칸.
class TripRecordBar extends StatelessWidget {
  const TripRecordBar({super.key, required this.visited, required this.total});

  final int visited;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final done = visited == total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done ? Icons.emoji_events : Icons.flag_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('여행 기록',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(done ? '완주! $visited곳 다 돌았어요 🎉' : '방문 $visited / $total 곳',
                  style: TextStyle(
                      color: done ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: visited / total,
              minHeight: 7,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

/// 여행 전체 지도(구글맵): 위치가 있는 일정을 핀으로. 인라인에서도 확대/이동 되고, 전체화면 버튼 제공.
/// [located]는 비어 있지 않아야 한다.
class TripMapCard extends StatelessWidget {
  const TripMapCard({
    super.key,
    required this.located,
    required this.onPinTap,
    required this.onFullscreen,
  });

  final List<Todo> located;
  final ValueChanged<Todo> onPinTap;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      for (final t in located)
        Marker(
          markerId: MarkerId(t.id),
          position: LatLng(t.latitude!, t.longitude!),
          infoWindow: InfoWindow(title: t.placeName ?? t.title),
          onTap: () => onPinTap(t),
        ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(located.first.latitude!, located.first.longitude!),
                  zoom: 12,
                ),
                markers: markers,
                onMapCreated: (controller) => fitMapBounds(controller,
                    [for (final t in located) LatLng(t.latitude!, t.longitude!)]),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                // 리스트 안에서도 지도가 드래그/줌 제스처를 잡도록(스크롤에 안 먹힘).
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: '전체화면 지도',
                    onPressed: onFullscreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
