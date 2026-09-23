# 배포 가이드 (test_front)

Flutter 웹(PWA)과 Android APK를 Firebase로 배포한다. 아래 명령은 `test_front/`에서 실행한다. iOS 배포는 구성되지 않았다.

- 백엔드: `https://test-backend-83yt.onrender.com`
- Firebase 프로젝트: `test-todo-app-f4c9a`
- 웹: https://test-todo-app-f4c9a.web.app

## 배포 전 검증

```bash
flutter pub get
flutter analyze
flutter test
```

`.github/workflows/ci.yml`은 Flutter 3.44.1 / Dart 3.12.1로 분석, 테스트, 웹 빌드를 실행한다. 실제 Firebase 배포와 APK 배포는 수동이다. CI 웹 빌드는 지도 키를 주입하지 않으므로 지도 동작은 배포 환경에서 별도 확인한다.

이번 변경은 계정별 캐시, 로그아웃 시 캐시·화면 상태 초기화, 늦게 도착한 인증 응답 무시, 조회 요청만 네트워크 재시도하는 처리를 포함한다. **POST/PATCH/DELETE는 네트워크 오류만으로 자동 재전송하지 않는다.** 저장 중 응답이 유실되면 목록을 새로 조회해 반영 여부를 확인한 뒤 다시 저장한다. `401` 인증 갱신 후 재전송은 한 번 허용한다.

앱 시작 시 이전 공용 오프라인 캐시를 제거하므로 업데이트 직후에는 온라인에서 여행 목록을 한 번 조회해야 한다. 백엔드 V9 이전 토큰은 버전 0으로 호환되며, 비밀번호 변경·재설정으로 인증 버전이 증가하면 기존 세션이 폐기된다. 프론트를 먼저 배포하고 백엔드 배포 후 아래 항목을 확인한다.

- 계정 A 로그아웃 → B 로그인 → 통신 실패 시 A의 여행·달력·일정이 표시되지 않는지.
- 토큰 갱신 중 로그아웃하거나 계정을 바꿔도 이전 계정으로 복귀하지 않는지.
- 비밀번호 변경 후 로그인 화면으로 이동하고, 이전 재설정 링크를 재사용할 수 없는지.
- 여행 상세의 로딩/오류/오프라인 표시와 경비 입력 경계값이 정상인지.

## 지도와 장소 검색 설정

현재 지도는 **Google Maps**(`google_maps_flutter`), 장소 검색은 백엔드의 **Google Places 프록시**다. 이전 Nominatim/OSM 배포 설명은 적용되지 않는다.

- 웹: `web/index.html`의 `__MAPS_WEB_KEY__` 자리표시자를 빌드 결과에서 교체한다. 웹용 키에는 배포 도메인에 맞는 HTTP referrer 제한을 설정한다.
- Android: `android/key.properties`의 `mapsApiKey` 또는 `ANDROID_MAPS_API_KEY`로 주입한다. 키 제한은 앱 패키지와 서명 인증서에 맞춘다.
- 서버 Places 키 `GOOGLE_PLACES_KEY`는 Render에만 설정한다.

## 웹: Firebase Hosting

`firebase login` 후 다음을 실행한다. 웹 빌드에는 Android의 API URL 강제 검사기가 적용되지 않으므로 URL을 반드시 명시한다.

```bash
flutter build web --dart-define=API_BASE_URL=https://test-backend-83yt.onrender.com
# MAPS_WEB_KEY 환경변수를 설정한 터미널에서 실행(키를 명령 출력에 노출하지 않음).
python3 - <<'PYKEY'
import os
from pathlib import Path
key = os.environ['MAPS_WEB_KEY']
if not key or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in key):
    raise SystemExit('Invalid MAPS_WEB_KEY')
page = Path('build/web/index.html')
text = page.read_text()
if '__MAPS_WEB_KEY__' not in text:
    raise SystemExit('Map key placeholder missing; rebuild first')
page.write_text(text.replace('__MAPS_WEB_KEY__', key))
PYKEY
npx firebase-tools deploy --only hosting --project test-todo-app-f4c9a
```

`firebase.json`은 `build/web`을 배포하고 SPA rewrite를 적용한다. 배포 후 브라우저/PWA를 다시 열어 실제 버전, 로그인, 지도, 장소 검색을 확인한다. 소스 HTML에 키를 직접 저장하지 않는다.

## Android: Firebase App Distribution

1. `pubspec.yaml`의 `version` 빌드번호 `+NN`을 올린다.
2. 로컬 `android/key.properties`와 서명 키스토어, 지도 키를 준비한다. 파일 경로는 `storeFile` 설정에 맞춘다. 서명 파일과 비밀번호는 커밋하지 않는다.
3. 릴리스 APK를 빌드하고 실제 기기에서 지도·검색·로그인·근처 알림을 확인한다.

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://test-backend-83yt.onrender.com
npx firebase-tools appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:183473872894:android:91048b780912ed08746aaf \
  --project test-todo-app-f4c9a \
  --groups testers \
  --release-notes "계정 데이터 격리, 인증 안정성 및 요청 재시도 개선"
```

Android 릴리스는 HTTPS API URL과 서명 설정이 없으면 실패한다. 빌드 성공만으로 지도 키 제한이나 운영 API 연결을 검증할 수 없으므로 실제 APK 확인이 필요하다.

## UI/UX 변경 확인

- 목적지만 입력해 날짜 미정 여행을 만들고, 자동 이름과 상세 화면 이동을 확인한다.
- ‘일정 추가’는 입력 폼, ‘날짜별 일정 편집’은 달력으로 이동해야 한다.
- 하루 코스 일부 저장 실패 시 실제 저장 건수와 실패 항목을 표시하며, 재시도는 이미 성공한 항목을 제외한다. 응답 유실 시에는 목록에서 저장 여부를 먼저 확인한다.
- 여행 삭제 확인창에 경비 기록 삭제 및 복구 불가 안내가 표시되는지 확인한다.
- 오프라인 캐시의 마지막 저장 시각, 다시 연결, 쓰기 작업 제한을 확인한다.
- 여행 기간 중 오늘 일정·다음 장소 길찾기가 상단에 표시되는지 확인한다.
- 휴대폰 큰 글자 설정에서 폼·달력·오프라인 배너가 잘리지 않는지, 화면 읽기에서 달력 선택 상태와 하단 탭을 구분하는지 확인한다.
- 첫 시작 안내는 건너뛸 수 있고, 재방문 및 모션 감소 설정에서는 생략되는지 확인한다.

## 디자인 확인

공통 스타일은 `lib/theme.dart`, 여행 커버·카드는 `CoverImage`와 `TravelCard`에서 관리한다. 크림색 배경, 짙은 녹색 본문, 코럴 주요 버튼을 사용하며 다크 모드는 별도 색상을 적용한다.

- 760px 미만에서 여행 카드는 한 열, 그 이상에서는 두 열로 표시한다.
- 사진이 없거나 로딩에 실패하면 등고선 배경과 읽기 쉬운 어두운 그라데이션이 표시되어야 한다.
- 모바일·넓은 화면·다크 모드·200% 글자 설정에서 제목, 상태, 날짜, 메뉴 위치를 확인한다.
