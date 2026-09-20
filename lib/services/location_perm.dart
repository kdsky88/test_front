import 'package:geolocator/geolocator.dart';

/// 위치 권한 보장. 지도의 '내 위치' 표시를 켜기 전에 호출.
/// 서비스 꺼짐/거부면 false(그럼 내 위치 기능만 끔).
Future<bool> ensureLocationPermission() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
}

/// 배경 위치 권한 보장 시도. 반환 = 현재 always 권한 여부.
/// 주의: 안드11+는 런타임 다이얼로그로 always를 못 받음 — 호출부가 실패 시
/// Geolocator.openAppSettings()로 사용자를 '항상 허용'으로 유도해야 함.
Future<bool> ensureBackgroundLocation() async {
  try {
    if (!await ensureLocationPermission()) return false; // whileInUse/always 확보
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.whileInUse) {
      p = await Geolocator.requestPermission(); // OS 버전에 따라 배경 승격 유도
    }
    return p == LocationPermission.always;
  } catch (_) {
    return false;
  }
}
