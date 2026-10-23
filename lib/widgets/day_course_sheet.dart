import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place.dart';
import '../services/map_links.dart';
import 'trip_overview.dart';

/// 하루 코스 시트: 슬롯(아침/점심/저녁)별 장소를 지도 동선과 목록으로.
/// [rebuild]는 '다시'를 누를 때 새 코스를 만든다. [initial]은 비어 있지 않아야 한다.
class DayCourseSheet extends StatefulWidget {
  const DayCourseSheet({
    super.key,
    required this.initial,
    required this.rebuild,
    required this.onAdd,
  });

  final List<(String, Place)> initial;
  final List<(String, Place)> Function() rebuild;
  final ValueChanged<List<(String, Place)>> onAdd;

  // 슬롯별 핀 색: 아침=하늘, 점심=주황, 저녁=보라.
  static double slotHue(String slot) => switch (slot) {
        '점심' => BitmapDescriptor.hueOrange,
        '저녁' => BitmapDescriptor.hueViolet,
        _ => BitmapDescriptor.hueAzure,
      };

  // 목록에서도 어느 핀인지 알아보게, 위 hue와 같은 색을 목록 아이콘에 쓴다
  // (구글 기본 마커 = HSV(hue,1,1)).
  static Color slotColor(String slot) => HSVColor.fromAHSV(1, slotHue(slot), 1, 1).toColor();

  @override
  State<DayCourseSheet> createState() => _DayCourseSheetState();
}

class _DayCourseSheetState extends State<DayCourseSheet> {
  late List<(String, Place)> _stops = widget.initial;
  GoogleMapController? _map;

  static List<LatLng> _pointsOf(List<(String, Place)> list) =>
      [for (final (_, p) in list) LatLng(p.latitude, p.longitude)];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stops = _stops;
    final points = _pointsOf(stops);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🗺️ 하루 코스',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                // 동선 미리보기: 순서대로 선으로 잇고 슬롯 색 핀(탭하면 장소 이름).
                // 확대·이동 가능 — EagerGestureRecognizer로 시트 스크롤에 안 먹히게.
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 260,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(target: points.first, zoom: 14),
                      markers: {
                        for (var i = 0; i < stops.length; i++)
                          Marker(
                            markerId: MarkerId('course$i'),
                            position: points[i],
                            icon: BitmapDescriptor.defaultMarkerWithHue(DayCourseSheet.slotHue(stops[i].$1)),
                            infoWindow: InfoWindow(title: stops[i].$2.name, snippet: stops[i].$1),
                          ),
                      },
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('course'),
                          color: theme.colorScheme.primary,
                          width: 4,
                          points: points,
                        ),
                      },
                      onMapCreated: (c) {
                        _map = c;
                        fitMapBounds(c, points);
                      },
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final (slot, p) in stops) _stopRow(theme, slot, p),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => widget.onAdd(_stops),
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('전체 일정에 담기'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _stops = widget.rebuild());
                        final c = _map;
                        if (c != null) fitMapBounds(c, _pointsOf(_stops));
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stopRow(ThemeData theme, String slot, Place p) => InkWell(
        onTap: () => openInGoogleMaps(lat: p.latitude, lng: p.longitude, directions: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.place, size: 18, color: DayCourseSheet.slotColor(slot)),
              const SizedBox(width: 6),
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(slot,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (p.category != null)
                      Text(p.category!,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.directions, size: 20, color: theme.colorScheme.primary),
            ],
          ),
        ),
      );
}
