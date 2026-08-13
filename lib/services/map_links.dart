import 'package:url_launcher/url_launcher.dart';

/// 구글 지도 앱(없으면 웹)으로 열기. directions=true면 그 좌표로 길찾기.
Future<bool> openInGoogleMaps({
  required double lat,
  required double lng,
  bool directions = false,
}) async {
  final uri = Uri.parse(directions
      ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
      : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
