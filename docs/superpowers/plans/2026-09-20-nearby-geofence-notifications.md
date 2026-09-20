# 저장 여행 장소 지오펜스 알림 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 여행 중, 여행 일정에 저장한 장소 근처에 체류하면 앱이 꺼져 있어도 로컬 알림을 띄운다.

**Architecture:** `native_geofence`(실제 OS 지오펜싱)로 진행 중 여행의 저장 장소에 지오펜스를 등록한다. 트리거 콜백은 별도 isolate에서 실행되므로, 알림에 필요한 장소 이름·쿨다운은 SharedPreferences로만 주고받는다. 순수 로직(어느 장소를 지오펜싱할지, 쿨다운 판정)은 플러그인 무관 파일로 분리해 단위 테스트한다.

**Tech Stack:** Flutter, `native_geofence ^1.3.1`, 기존 `flutter_local_notifications`·`geolocator`·`shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-09-20-nearby-geofence-notifications-design.md`

## Global Constraints

- 백엔드 무변경. 프론트(`test_front`) 전용.
- 안드로이드 우선 검증. 웹은 `kIsWeb` no-op. iOS는 빌드만 안 깨지게(`Info.plist` 키 추가), 실검증은 범위 밖.
- 트리거 = **DWELL**(체류), 반경 **150m**, 쿨다운 **6시간**, loiteringDelay **60초**. 상수로 두고 조절 가능하게.
- 백그라운드 위치는 **옵트인 기본 OFF**. 안드11+ `ACCESS_BACKGROUND_LOCATION`은 런타임 원샷으로 못 받음 — 설정 유도.
- 순수 로직 파일(`geofence_logic.dart`)은 플러그인 import 금지(테스트 격리). 기존 `day_course.dart` 패턴 따름.
- 커밋 메시지는 한국어, 마지막 줄에 `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **verify-at-impl (스펙)**: `GeofenceCallbackParams`의 실제 필드명(`geofences` 리스트 원소의 `.id`, `.event`)을 native_geofence 1.3.1 API 문서로 확인 후 콜백 코드 맞출 것.

---

### Task 1: 순수 로직 (지오펜스 대상 선정 + 쿨다운)

**Files:**
- Create: `lib/services/geofence_logic.dart`
- Test: `test/geofence_logic_test.dart`

**Interfaces:**
- Consumes: `Trip`(id, startDate?, endDate?), `Todo`(id, tripId?, latitude?, longitude?, placeName?, title).
- Produces:
  - `typedef GeofenceSpec = ({String id, double lat, double lon});`
  - `List<Trip> activeTrips(List<Trip> trips, DateTime now)` — start·end 날짜(양끝 포함, 날짜 단위)에 now가 드는 여행.
  - `({List<GeofenceSpec> fences, Map<String, String> names}) geofencesForActiveTrips(List<Trip> trips, List<Todo> todos, DateTime now)`
  - `bool shouldNotify(DateTime? lastAt, DateTime now, Duration cooldown)`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/geofence_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/models/trip.dart';
import 'package:test_front/models/todo.dart';
import 'package:test_front/services/geofence_logic.dart';

Trip trip(String id, DateTime? s, DateTime? e) =>
    Trip(id: id, startDate: s, endDate: e);
Todo todo(String id, String? tripId, {double? lat, double? lon, String? place, String title = 'T'}) =>
    Todo(id: id, title: title, tripId: tripId, latitude: lat, longitude: lon, placeName: place);

void main() {
  final now = DateTime(2026, 9, 20, 14);

  group('activeTrips', () {
    test('now가 여행 기간(양끝 포함)에 들면 active', () {
      final trips = [
        trip('a', DateTime(2026, 9, 20), DateTime(2026, 9, 25)), // 시작일 당일
        trip('b', DateTime(2026, 9, 15), DateTime(2026, 9, 20)), // 종료일 당일
        trip('c', DateTime(2026, 9, 10), DateTime(2026, 9, 19)), // 지남
        trip('d', DateTime(2026, 9, 21), DateTime(2026, 9, 25)), // 미래
        trip('e', null, null),                                    // 날짜 없음
      ];
      expect(activeTrips(trips, now).map((t) => t.id).toSet(), {'a', 'b'});
    });
  });

  group('geofencesForActiveTrips', () {
    test('active 여행 + lat/lon 있는 todo만, 이름은 placeName 우선', () {
      final trips = [trip('a', DateTime(2026, 9, 20), DateTime(2026, 9, 25))];
      final todos = [
        todo('t1', 'a', lat: 35.1, lon: 129.0, place: '해운대'),
        todo('t2', 'a', title: '메모만'),          // 좌표 없음 → 제외
        todo('t3', 'z', lat: 1, lon: 1),           // 비-active 여행 → 제외
        todo('t4', 'a', lat: 37.5, lon: 127.0, title: '광장'), // placeName 없음 → title
      ];
      final r = geofencesForActiveTrips(trips, todos, now);
      expect(r.fences.map((f) => f.id).toSet(), {'t1', 't4'});
      expect(r.names['t1'], '해운대');
      expect(r.names['t4'], '광장');
    });
  });

  group('shouldNotify', () {
    test('마지막 알림 없으면 true', () {
      expect(shouldNotify(null, now, const Duration(hours: 6)), isTrue);
    });
    test('쿨다운 이내면 false, 딱 지나면 true', () {
      expect(shouldNotify(now.subtract(const Duration(hours: 5)), now, const Duration(hours: 6)), isFalse);
      expect(shouldNotify(now.subtract(const Duration(hours: 6)), now, const Duration(hours: 6)), isTrue);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/geofence_logic_test.dart`
Expected: FAIL — `geofence_logic.dart`/함수 미정의 컴파일 에러.

- [ ] **Step 3: 최소 구현**

```dart
// lib/services/geofence_logic.dart
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
```

> 확인: `Trip`/`Todo` 생성자에 위 이름의 named 파라미터가 있는지(현재 있음). 테스트 헬퍼가 컴파일되면 OK.

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/geofence_logic_test.dart`
Expected: PASS (3 group 전부).

- [ ] **Step 5: 커밋**

```bash
git add lib/services/geofence_logic.dart test/geofence_logic_test.dart
git commit -m "feat: 지오펜스 대상 선정·쿨다운 순수 로직

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: 의존성 + 권한 설정

**Files:**
- Modify: `pubspec.yaml` (dependencies에 native_geofence)
- Modify: `android/app/src/main/AndroidManifest.xml` (ACCESS_BACKGROUND_LOCATION)
- Modify: `ios/Runner/Info.plist` (NSLocationAlwaysAndWhenInUseUsageDescription)

**Interfaces:**
- Produces: 빌드 가능한 `native_geofence` import 환경. 이후 Task 4가 사용.

- [ ] **Step 1: pubspec에 의존성 추가**

`pubspec.yaml`의 `dependencies:` 아래(기존 `geolocator:` 근처)에 추가:
```yaml
  native_geofence: ^1.3.1
```

- [ ] **Step 2: 의존성 설치**

Run: `flutter pub get`
Expected: 성공, `native_geofence` 해석됨.

- [ ] **Step 3: 안드로이드 매니페스트 권한 추가**

`android/app/src/main/AndroidManifest.xml`의 기존 위치 권한(`ACCESS_FINE_LOCATION`) 줄 아래에 추가:
```xml
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
```
(`RECEIVE_BOOT_COMPLETED`는 이미 있음 — 재부팅 후 지오펜스 재등록에 필요하므로 유지.)

- [ ] **Step 4: iOS Info.plist 키 추가**

`ios/Runner/Info.plist`의 `<dict>` 안에 추가(빌드 실패 방지, iOS 미검증이라도 필수):
```xml
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>여행 중 저장한 장소 근처에 오면 알려드리기 위해 위치를 사용해요.</string>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>지도와 근처 장소 알림에 위치를 사용해요.</string>
```
> `NSLocationWhenInUseUsageDescription`이 이미 있으면 중복 추가하지 말 것.

- [ ] **Step 5: 정적 분석으로 회귀 없음 확인**

Run: `flutter analyze`
Expected: 신규 에러 없음(기존 경고 수준 유지).

- [ ] **Step 6: 커밋**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore: native_geofence 의존성·배경위치 권한 추가

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: 근처 알림 옵트인 설정값

**Files:**
- Modify: `lib/services/notification_prefs.dart`
- Test: `test/geofence_logic_test.dart` (기존 파일에 pref 라운드트립 테스트 추가)

**Interfaces:**
- Produces: `NotificationPrefs.nearbyEnabled` (bool, 기본 false), `NotificationPrefs.setNearbyEnabled(bool)`, `load()`가 이 값을 채움.

- [ ] **Step 1: 실패하는 테스트 추가**

`test/geofence_logic_test.dart`의 `main()` 안에 group 추가(상단에 import 추가):
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_front/services/notification_prefs.dart';
```
```dart
  group('NotificationPrefs.nearbyEnabled', () {
    test('기본 false, set 후 load하면 유지', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPrefs.load();
      expect(NotificationPrefs.nearbyEnabled, isFalse);
      await NotificationPrefs.setNearbyEnabled(true);
      await NotificationPrefs.load();
      expect(NotificationPrefs.nearbyEnabled, isTrue);
    });
  });
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/geofence_logic_test.dart`
Expected: FAIL — `nearbyEnabled`/`setNearbyEnabled` 미정의.

- [ ] **Step 3: NotificationPrefs 확장**

`lib/services/notification_prefs.dart`에 필드·키·로드·세터 추가(기존 morning 패턴과 동일하게):
```dart
  static bool nearbyEnabled = false;
```
```dart
  static const _kNearby = 'notif_nearby_enabled';
```
`load()` 안에 추가:
```dart
    nearbyEnabled = p.getBool(_kNearby) ?? false;
```
새 세터:
```dart
  static Future<void> setNearbyEnabled(bool v) async {
    nearbyEnabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNearby, v);
  }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/geofence_logic_test.dart`
Expected: PASS(신규 group 포함 전체).

- [ ] **Step 5: 커밋**

```bash
git add lib/services/notification_prefs.dart test/geofence_logic_test.dart
git commit -m "feat: 근처 알림 옵트인 설정값(nearbyEnabled)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: 지오펜스 서비스 (등록 + 콜백 + 동기화)

**Files:**
- Create: `lib/services/geofence_service.dart`

**Interfaces:**
- Consumes: Task 1(`geofencesForActiveTrips`, `activeTrips`, `shouldNotify`, `GeofenceSpec`), Task 3(`NotificationPrefs.nearbyEnabled`), 기존 `TripApi.getTrips`/`getTripTodos`.
- Produces:
  - `Future<void> syncNearbyGeofences()` — enabled면 진행중 여행 장소로 등록, 아니면 전부 해제. main·설정화면이 호출.
  - `Future<void> clearGeofences()`
  - `@pragma('vm:entry-point') Future<void> nearbyGeofenceCallback(GeofenceCallbackParams params)`

- [ ] **Step 1: 서비스 파일 작성**

```dart
// lib/services/geofence_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'geofence_logic.dart';
import 'notification_prefs.dart';
import 'trip_api.dart';

const _kRadiusMeters = 150.0;
const _kLoiteringDelay = Duration(seconds: 60);
const _kCooldown = Duration(hours: 6);
const _kNamesKey = 'geofence_names';     // JSON {id: name}
const _kLastPrefix = 'geofence_last_';   // + id -> epoch millis
const _channelId = 'nearby_places';

/// enabled + 진행중 여행이면 그 여행의 저장 장소로 지오펜스 등록, 아니면 전부 해제.
/// 앱-열림 기반: main·설정 토글에서 호출. 실패는 조용히 무시(앱 방해 X).
Future<void> syncNearbyGeofences() async {
  if (kIsWeb) return; // 웹은 지오펜싱 불가
  try {
    if (!NotificationPrefs.nearbyEnabled) {
      await clearGeofences();
      return;
    }
    final trips = await TripApi.getTrips();
    final now = DateTime.now();
    final active = activeTrips(trips, now);
    final todos = <dynamic>[];
    for (final t in active) {
      todos.addAll(await TripApi.getTripTodos(t.id));
    }
    final result = geofencesForActiveTrips(trips, todos.cast(), now);
    await NativeGeofenceManager.instance.initialize();
    await NativeGeofenceManager.instance.removeAllGeofences();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNamesKey, jsonEncode(result.names));
    for (final f in result.fences) {
      await NativeGeofenceManager.instance.createGeofence(
        Geofence(
          id: f.id,
          location: Location(latitude: f.lat, longitude: f.lon),
          radiusMeters: _kRadiusMeters,
          triggers: const {GeofenceEvent.dwell},
          iosSettings: const IosGeofenceSettings(initialTrigger: false),
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: {},
            loiteringDelay: _kLoiteringDelay,
          ),
        ),
        nearbyGeofenceCallback,
      );
    }
  } catch (_) {
    // 등록 실패는 무시(권한 미승격·네트워크 등)
  }
}

Future<void> clearGeofences() async {
  if (kIsWeb) return;
  try {
    await NativeGeofenceManager.instance.initialize();
    await NativeGeofenceManager.instance.removeAllGeofences();
  } catch (_) {}
}

/// 별도 isolate에서 실행 — 앱 상태 접근 불가. SharedPreferences만 사용.
@pragma('vm:entry-point')
Future<void> nearbyGeofenceCallback(GeofenceCallbackParams params) async {
  // verify-at-impl: params.event / params.geofences / 원소 .id 필드명 확정
  if (params.event != GeofenceEvent.dwell) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final names = (jsonDecode(prefs.getString(_kNamesKey) ?? '{}') as Map)
      .cast<String, String>();
  final now = DateTime.now();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ));
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId, '근처 장소',
      channelDescription: '저장한 여행 장소 근처 알림',
      importance: Importance.high, priority: Priority.high,
    ),
  );
  for (final g in params.geofences) {
    final id = g.id;
    final lastMs = prefs.getInt('$_kLastPrefix$id');
    final lastAt = lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
    if (!shouldNotify(lastAt, now, _kCooldown)) continue;
    final name = names[id] ?? '저장한 장소';
    await plugin.show(id.hashCode & 0x7fffffff, '계획한 $name 근처예요',
        '가는 김에 들러볼까요?', details);
    await prefs.setInt('$_kLastPrefix$id', now.millisecondsSinceEpoch);
  }
}
```

> `todos`를 `dynamic` 리스트로 모아 `.cast()`한 이유: `getTripTodos`가 `List<Todo>`를 반환하므로 `final todos = <Todo>[];`로 두고 `import '../models/todo.dart';` 후 `todos.addAll(...)` 해도 됨 — import 추가하고 `<Todo>[]`로 바꾸는 편이 명확. (둘 중 하나 선택, 컴파일 통과 기준.)

- [ ] **Step 2: 정적 분석 + 콜백 API 실검증**

Run: `flutter analyze lib/services/geofence_service.dart`
Expected: 컴파일 에러 없음. 에러가 나면 `GeofenceCallbackParams`·`ActiveGeofence` 실제 필드명을 native_geofence 1.3.1 문서로 확인해 `params.geofences`/`g.id`/`params.event` 접근을 맞춘다.

- [ ] **Step 3: 커밋**

```bash
git add lib/services/geofence_service.dart
git commit -m "feat: 지오펜스 등록·동기화·트리거 콜백 서비스

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> 실제 트리거·앱꺼짐 알림은 헤드리스 검증 불가 → Task 7 실기기 체크리스트에서 확인.

---

### Task 5: 배경 위치 권한 헬퍼

**Files:**
- Modify: `lib/services/location_perm.dart`

**Interfaces:**
- Consumes: 기존 `ensureLocationPermission()`.
- Produces: `Future<bool> ensureBackgroundLocation()` — 반환은 "현재 배경위치(always) 승격 여부". 승격을 강제하지 않음(안드11+는 설정에서만 가능).

- [ ] **Step 1: 헬퍼 추가**

`lib/services/location_perm.dart`에 추가:
```dart
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
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib/services/location_perm.dart`
Expected: 에러 없음.

- [ ] **Step 3: 커밋**

```bash
git add lib/services/location_perm.dart
git commit -m "feat: 배경 위치 권한 헬퍼(ensureBackgroundLocation)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: 앱 배선 (시작 시 동기화 + 설정 스위치)

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: Task 4(`syncNearbyGeofences`, `clearGeofences`), Task 5(`ensureBackgroundLocation`), Task 3(`NotificationPrefs.nearbyEnabled`/`setNearbyEnabled`).

- [ ] **Step 1: main에서 시작 시 동기화**

`lib/main.dart` 상단에 import 추가:
```dart
import 'services/geofence_service.dart';
```
인증 상태에서 `NotificationService.sync()`를 호출하는 지점(로그인 후·resume 등, 현재 `_isAuthenticated` 분기) 바로 뒤에 추가:
```dart
    syncNearbyGeofences(); // 근처 알림 지오펜스 갱신(옵트인 꺼져있으면 내부에서 해제)
```
> `NotificationService.sync()`와 같은 fire-and-forget 스타일. await 불필요(앱 시작 지연 방지).

- [ ] **Step 2: 설정 화면에 상태·토글 추가**

`lib/screens/settings_screen.dart`:
- State 필드 추가(기존 `_morningOn` 근처):
```dart
  bool _nearbyOn = false;
```
- 설정 로드하는 initState/로더에서 `_nearbyOn = NotificationPrefs.nearbyEnabled;` 채우기(기존 `_morningOn` 초기화와 같은 위치).
- import 추가:
```dart
import 'package:geolocator/geolocator.dart';
import '../services/geofence_service.dart';
import '../services/location_perm.dart';
```
- 토글 핸들러 추가(`_saveMorning` 근처):
```dart
  Future<void> _toggleNearby(bool on) async {
    if (on) {
      final ok = await ensureBackgroundLocation();
      if (!ok && mounted) {
        // 배경 권한 미승격 → 안내 후 설정 열기. 켜기는 진행(승격되면 다음 동기화 때 동작).
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('위치를 "항상 허용"으로'),
            content: const Text('앱이 꺼져 있어도 근처 장소를 알리려면 위치 권한을 "항상 허용"으로 바꿔주세요.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('나중에')),
              TextButton(
                onPressed: () { Navigator.pop(context); Geolocator.openAppSettings(); },
                child: const Text('설정 열기'),
              ),
            ],
          ),
        );
      }
    }
    await NotificationPrefs.setNearbyEnabled(on);
    if (mounted) setState(() => _nearbyOn = on);
    await syncNearbyGeofences();
  }
```
- 알림 섹션(아침 요약 `SwitchListTile` 아래)에 스위치 추가:
```dart
          SwitchListTile(
            secondary: const Icon(Icons.near_me_outlined),
            title: const Text('근처 장소 알림'),
            subtitle: const Text('여행 중 저장한 장소 근처에 오면 알려줘요'),
            value: _nearbyOn,
            onChanged: _toggleNearby,
          ),
```

- [ ] **Step 3: 정적 분석 + 전체 테스트**

Run: `flutter analyze && flutter test`
Expected: 분석 에러 없음, 기존 테스트 + 신규 테스트 전부 PASS.

- [ ] **Step 4: 커밋**

```bash
git add lib/main.dart lib/screens/settings_screen.dart
git commit -m "feat: 근처 알림 시작 시 동기화 + 설정 토글

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: 빌드번호 상향 + 실기기 검증 + 마무리

**Files:**
- Modify: `pubspec.yaml` (version 빌드번호)

**Interfaces:** 없음(릴리스 준비).

- [ ] **Step 1: 빌드번호 올리기**

`pubspec.yaml`의 `version: 1.49.2+84` → 다음 마이너+빌드로(예: `1.50.0+85`). 규칙은 `deploy-runbook` 참고.

- [ ] **Step 2: 릴리스 APK 빌드**

Run: `flutter build apk --release --dart-define=API_BASE_URL=https://test-backend-83yt.onrender.com`
Expected: 성공.

- [ ] **Step 3: 실기기 검증(사용자, 헤드리스 불가)**

체크리스트:
1. 설정 → "근처 장소 알림" ON → 위치 "항상 허용" 안내/승격.
2. 진행 중(오늘이 기간 내) 여행에 좌표 있는 일정이 있는지 확인.
3. 해당 장소 반경 150m 안에서 ~1분 체류 → "계획한 {장소} 근처예요" 알림 수신.
4. 앱을 완전히 종료한 상태에서도 3이 되는지.
5. 같은 장소 재진입 시 6시간 내 재알림 안 오는지(쿨다운).
6. 토글 OFF → 지오펜스 해제(알림 안 옴).

> 실기기 확인은 사용자 몫 — 코드는 여기까지. 결과 보고 후 배포/머지.

- [ ] **Step 4: 커밋**

```bash
git add pubspec.yaml
git commit -m "chore: 근처 알림 빌드번호 상향(1.50.0+85)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: 통합**

`superpowers:finishing-a-development-branch`로 `nearby-geofence` → `main` 머지 여부 결정. 이후 배포(`deploy-runbook`: 웹·APK 둘 다, App Distribution).

---

## Self-Review 결과

- **스펙 커버리지**: 패키지 선택(T2)·진행중여행 장소 필터(T1)·id→name 맵/콜백 isolate(T4)·DWELL·반경·쿨다운(T1/T4)·배경권한 원샷아님(T5)·옵트인 토글(T3/T6)·매니페스트·plist·minSdk(T2, minSdk 24 이미 충족)·순수함수 테스트(T1/T3)·실기기 검증(T7) 모두 태스크 있음.
- **플레이스홀더**: 없음(코드 전부 실제). 단 콜백 필드명은 명시적 verify-at-impl로 표시.
- **타입 일관성**: `GeofenceSpec`·`geofencesForActiveTrips`·`activeTrips`·`shouldNotify`·`nearbyEnabled`/`setNearbyEnabled`·`syncNearbyGeofences`/`clearGeofences`/`nearbyGeofenceCallback`·`ensureBackgroundLocation` 명칭이 태스크 간 일치.
