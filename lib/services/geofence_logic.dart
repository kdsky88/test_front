import '../models/trip.dart';
import '../models/todo.dart';

typedef GeofenceSpec = ({String id, double lat, double lon});

bool _isActive(Trip t, DateTime now) {
  if (t.startDate == null || t.endDate == null) return false;
  final d = DateTime(now.year, now.month, now.day);
  final s = DateTime(t.startDate!.year, t.startDate!.month, t.startDate!.day);
  final e = DateTime(t.endDate!.year, t.endDate!.month, t.endDate!.day);
  return !d.isBefore(s) && !d.isAfter(e);
}

List<Trip> activeTrips(List<Trip> trips, DateTime now) =>
    trips.where((t) => _isActive(t, now)).toList();

({List<GeofenceSpec> fences, Map<String, String> names}) geofencesForActiveTrips(
    List<Trip> trips, List<Todo> todos, DateTime now) {
  final ids = activeTrips(trips, now).map((t) => t.id).toSet();
  final fences = <GeofenceSpec>[];
  final names = <String, String>{};
  for (final t in todos) {
    if (t.tripId == null || !ids.contains(t.tripId)) continue;
    if (t.latitude == null || t.longitude == null) continue;
    fences.add((id: t.id, lat: t.latitude!, lon: t.longitude!));
    names[t.id] = t.placeName ?? t.title;
  }
  return (fences: fences, names: names);
}

bool shouldNotify(DateTime? lastAt, DateTime now, Duration cooldown) =>
    lastAt == null || now.difference(lastAt) >= cooldown;
