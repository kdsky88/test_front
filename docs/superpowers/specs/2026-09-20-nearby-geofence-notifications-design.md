# 저장 여행 장소 지오펜스 알림 — 설계

- **날짜**: 2026-09-20
- **상태**: 승인됨 (구현 계획 대기)
- **범위**: `test_front` (Flutter) 전용 — **백엔드 무변경**
- **학습 목표**: 지오펜싱, 백그라운드 위치 권한 모델 (FCM은 범위 밖 — 후속 서버발신 알림에서 별도)

## 목표 / 비목표

**목표**: 여행 중, 사용자가 여행 일정에 저장해 둔 장소 근처에 오면 로컬 알림("계획한 {장소} 근처예요")을 띄운다. 앱이 꺼져 있어도 동작.

**비목표 (YAGNI)**:
- 이동 중 새 장소 발견(위치 폴링 + `/places/nearby`) — 이번엔 안 함.
- 알림 탭 시 그 장소 지도로 딥링크 — 후순위. MVP는 앱 열기.
- iOS 실검증 — 코드는 크로스플랫폼이나 안드로이드만 검증.
- 커스텀 사운드, 알림 그룹핑.

## 접근 요약

`native_geofence ^1.3.1` 패키지 사용. 실제 OS 지오펜싱(안드로이드 `GeofencingClient` / iOS `CLRegion`)을 감싸므로 **상시 포그라운드 서비스 없이** 배터리 효율적으로 동작하고, OS가 앱을 깨운다. `geolocator`(권한 체크)·`flutter_local_notifications`(알림 발사)는 기존 것 재사용.

- 패키지 요구: Android API 23+ (현재 minSdk **24** — 충족, 변경 불필요), iOS 14+.
- 라이선스 MIT.

## 아키텍처

핵심 제약: **트리거 콜백은 새 isolate(`@pragma('vm:entry-point')` top-level 함수)에서 실행된다.** 이 isolate는 앱 상태·Riverpod·인증된 API 클라이언트에 접근 못 한다. 따라서 알림에 필요한 모든 것(장소 이름, 쿨다운 타임스탬프)은 **지오펜스 ID에 인코딩되거나 SharedPreferences에서 읽을 수 있어야** 한다.

`services/geofence_service.dart`를 두 책임으로 분리:

### 등록 측 (메인 isolate — 여행/일정 데이터 접근 가능)
1. 진행 중 여행의 저장 장소로 지오펜스 목록 계산.
2. `native_geofence`에 지오펜스 등록/갱신.
3. **`{geofenceId → placeName}` 맵을 SharedPreferences에 기록** (콜백이 읽을 이름 사전).
4. 이전 등록분과 diff — 없어진 장소는 `removeGeofenceById`, 새 장소는 추가.

### 콜백 측 (백그라운드 isolate — SharedPreferences만 접근)
1. 트리거된 지오펜스 ID 수신 (`native_geofence` 콜백 파라미터).
2. SharedPreferences에서 id→placeName 맵 + 장소별 마지막 알림 타임스탬프 로드.
3. 쿨다운(기본 6시간) 내면 skip.
4. 아니면: `flutter_local_notifications` 플러그인을 **이 isolate에서 재초기화**(별 isolate라 앱 init이 안 통함) → `nearby_places` 채널로 `.show()` → 타임스탬프 갱신.

### 순수 로직 (테스트 대상, isolate 무관)
- `geofencesForActiveTrip(trips, todos, now)` → `(지오펜스 목록, id→placeName 맵)` 둘 다 반환. 필터: `start ≤ now ≤ end`인 여행 && `lat/lon` 있는 todo.
- `shouldNotify(placeId, lastNotifiedAt, now, cooldown)` → bool.

## 데이터 흐름

```
앱 시작 / 여행·일정 변경
  → (nearbyEnabled && 진행중 여행 있음?)
     → geofencesForActiveTrip() → 등록 측: OS에 등록 + id→name 맵 저장
  → 없으면: removeAllGeofences + 맵 클리어

[앱 꺼짐] 사용자가 장소 근처 진입/체류
  → OS가 콜백 isolate 깨움 → shouldNotify? → 로컬 알림 발사
```

## 트리거 튜닝 (design-prefs: 값 조절 놉 남기기)

- **트리거 = DWELL(체류)** 기본. ENTER는 그냥 지나가도 오발(150m 반경). DWELL = "N초 이상 근처 머묾"이라 UX 나음. (`loiteringDelay` 예: 60초)
- **반경**: 상수 `_kRadiusMeters = 150` (도심 POI 기준, 조절 가능).
- **쿨다운**: 상수 `_kCooldown = Duration(hours: 6)` (같은 장소 재진입 스팸 방지).

## 권한 · 플랫폼

- **매니페스트 추가**: `ACCESS_BACKGROUND_LOCATION`. (`ACCESS_FINE/COARSE_LOCATION`, `RECEIVE_BOOT_COMPLETED`는 이미 있음 — 후자는 재부팅 후 지오펜스 재등록에 필요.)
- **안드로이드 11+ 백그라운드 위치는 원샷 다이얼로그가 아님.** `ACCESS_BACKGROUND_LOCATION`은 런타임 프롬프트로 못 받음 — 사용자가 시스템 설정에서 "항상 허용"을 직접 골라야 함.
  - `location_perm.dart`에 `ensureBackgroundLocation()` 추가. **계약**: "whileInUse 보장 → 그 다음 앱 설정 딥링크 + 안내"이지 "요청하면 always 받음"이 **아님**. 반환은 현재 백그라운드 권한 상태(승격 여부는 사용자 손).
  - 토글 켤 때: whileInUse 요청 → 안내 다이얼로그("정확히 근처에서 알리려면 '항상 허용'이 필요해요") → 설정 열기.
- **플랫폼 스코프**: 안드로이드 우선(APK 배포 대상). iOS는 `NSLocationAlwaysAndWhenInUseUsageDescription`를 `Info.plist`에 추가해야 빌드가 안 깨짐(미검증이라도 명시) + region 20개 상한(진행중-여행-스코프라 안전). 웹은 `kIsWeb` 가드로 no-op.

## 설정 (옵트인)

- 백그라운드 위치는 민감 → **기본 OFF**.
- `NotificationPrefs`에 `nearbyEnabled` (SharedPreferences) 추가.
- 더보기/설정 화면에 스위치. 켜면 권한 플로우 + 등록, 끄면 `removeAllGeofences` + 맵 클리어.

## 파일

**신규**
- `lib/services/geofence_service.dart` — 등록 측 + 콜백 top-level 함수 + 순수 로직.

**수정**
- `lib/services/location_perm.dart` — `ensureBackgroundLocation()` 추가.
- `lib/services/notification_prefs.dart` — `nearbyEnabled` 필드/로드/세터.
- `lib/main.dart` — 시작 시 (enabled면) 지오펜스 등록.
- 설정/더보기 화면 — 스위치 + 권한 안내.
- `android/app/src/main/AndroidManifest.xml` — `ACCESS_BACKGROUND_LOCATION`.
- `ios/Runner/Info.plist` — `NSLocationAlwaysAndWhenInUseUsageDescription`.
- `pubspec.yaml` — `native_geofence`, 빌드번호 up.

## 테스트

- **단위(헤드리스 가능)**: `geofencesForActiveTrip`(진행중 여행 필터·lat/lon 필터·맵 정확성), `shouldNotify`(쿨다운 경계). 프레임워크 없이 `flutter_test` 기존 방식.
- **실기기(헤드리스 불가)**: 권한 플로우, 실제 지오펜스 트리거, 앱-꺼짐 알림 → **사용자가 폰으로 확인**(정직히 밝힘).

## 구현 전 확인할 것 (verify-at-impl)

1. `native_geofence` 콜백 파라미터가 트리거된 지오펜스 **ID**를 어떻게 주는지(ID 문자열? payload 필드?) — id→name 조회 설계를 그 실제 형태에 맞춤.
2. 백그라운드 isolate에서 `flutter_local_notifications` 재초기화 패턴(채널 재생성 필요 여부).
3. `native_geofence`의 DWELL/loitering 파라미터명·단위.
