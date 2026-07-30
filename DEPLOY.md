# 배포 가이드 (test_front)

Flutter 앱을 **3채널**로 배포한다. 백엔드는 별도 레포(`test_backend`, Render) 참고.

- **prod 백엔드 URL**: `https://test-backend-83yt.onrender.com`
- **Firebase 프로젝트**: `test-todo-app-f4c9a` (로그인: kdsky88@gmail.com, `firebase login` 필요)
- 릴리스 빌드는 `--dart-define=API_BASE_URL=https://...`를 **강제**한다(android/app/build.gradle.kts 가드). 빼면 빌드 실패.

## 1. 웹 (Firebase Hosting → PWA)

라이브: https://test-todo-app-f4c9a.web.app

```bash
flutter build web --dart-define=API_BASE_URL=https://test-backend-83yt.onrender.com
npx firebase-tools deploy --only hosting --project test-todo-app-f4c9a
```

- 설정: `firebase.json`(`public: build/web`, SPA rewrite).
- 홈화면에 "추가"하면 PWA로 설치됨 → 배포 후 앱 재실행 시 서비스워커가 자동 갱신(한 번 늦게 반영).

## 2. 폰 (Firebase App Distribution → 네이티브 APK)

폰의 **App Tester** 앱에 "새 버전 다운로드" 알림이 뜬다.

```bash
# 1) pubspec.yaml의 version 빌드번호(+NN)를 반드시 올린다 (안 올리면 폰에서 같은 버전이라 설치 애매)
#    예: version: 1.8.5+23  →  1.8.6+24

# 2) 서명된 릴리스 APK 빌드
flutter build apk --release --dart-define=API_BASE_URL=https://test-backend-83yt.onrender.com

# 3) testers 그룹에 배포
npx firebase-tools appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:183473872894:android:91048b780912ed08746aaf \
  --project test-todo-app-f4c9a \
  --groups testers \
  --release-notes "변경 요약"
```

- **App ID(안드로이드)**: `1:183473872894:android:91048b780912ed08746aaf`
- **테스터 그룹**: `testers`
- **서명**: `android/key.properties` + `android/app/upload-keystore.jks` (둘 다 gitignore, 로컬에 있어야 릴리스 서명됨). 없으면 릴리스 빌드 실패.

## 외부 API — OSM Nominatim (장소 검색, `lib/services/geocoding_api.dart`)

무료·API 키 불필요지만 사용 정책이 있고, 어기면 **런타임에 403 / IP 차단**된다(빌드는 통과하므로 analyze로 안 잡힘).

- **User-Agent 필수**: 일반/빈 UA는 403. 현재 값 `test-todo-app/1.0 (kdsky88@gmail.com)`.
  - ⚠️ **APK 전용 함정**: 웹은 브라우저가 UA를 대신 채워 통과하지만, **네이티브(APK)는 Dart 기본 UA가 차단**된다. 그래서 웹에서 테스트하면 멀쩡해 보여도 폰에서 검색이 안 될 수 있음 → 반드시 **APK로 검색을 테스트**할 것.
- **초당 1회 제한**: 키 입력마다 호출 금지 → 검색은 디바운스(현재 ~600ms).
- **응답 형태**(파서 주의): 배열이며 `lat`/`lon`은 **문자열**(double 파싱), 필드명은 `lng`가 아니라 **`lon`**, 이름은 `display_name`.
- 엔드포인트: `https://nominatim.openstreetmap.org/search?q=...&format=json&limit=5`
- 대량/상용으로 커지면: 무료 정책 한계를 넘으니 자체 Nominatim 호스팅 또는 유료 지오코딩(Google/Mapbox) 키로 전환.

## 참고

- CORS: 백엔드가 `https://test-todo-app-f4c9a.web.app` 오리진을 이미 허용(프리플라이트 통과).
- 배포 자동화(CI) 없음 — 위 명령을 수동 실행한다.
- `iOS`는 미설정(App Distribution엔 안드로이드 앱만 등록됨).
- 지도 타일: OSM 공개 타일 서버 사용(`flutter_map` + `TileLayer.userAgentPackageName` 설정). 대량이면 유료 타일 제공자로.
