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
