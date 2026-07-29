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

## 참고

- CORS: 백엔드가 `https://test-todo-app-f4c9a.web.app` 오리진을 이미 허용(프리플라이트 통과).
- 배포 자동화(CI) 없음 — 위 명령을 수동 실행한다.
- `iOS`는 미설정(App Distribution엔 안드로이드 앱만 등록됨).
