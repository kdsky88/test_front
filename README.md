# P의 여행 플래너 — 프론트엔드 (Flutter)

MBTI **P유형(즉흥형)을 위한 여행앱**. 계획을 빡빡하게 강요하지 않고, **지역만 정하면 관광지·맛집을 추천**해
발견 중심으로 여행을 채워준다. 웹(PWA)과 안드로이드(APK)로 동시 배포.

> 🤖 이 프로젝트는 **AI 코딩 에이전트(Claude Code)와 대화하며** 만든 실배포 앱이다 —
> 아이디어부터 구현·디버깅·배포까지 어디까지 가능한지 실험한 결과물.

- **라이브(웹)**: https://test-todo-app-f4c9a.web.app
- **백엔드 레포**: https://github.com/kdsky88/test_backend
- **버전**: `1.49.2+84`

---

## 화면 구성 (하단 3탭)

| 탭 | 내용 |
|----|------|
| 🧳 **여행** | 여행 만들기/수정, 지도 장소 검색, 관광지·맛집 추천, 하루 코스·아무거나·미리보기, 경비·환율·내 주변 |
| 📅 **달력** | 날짜별 일정, 좌우 스와이프 월 이동 |
| ☰ **더보기** | 할 일 목록, 통계, 알림·생체잠금 설정, 로그아웃 |

## 주요 기능

- 🗺️ **지도 장소 검색** — 주소·관광지·맛집 3모드 (Google Maps)
- 📍 **관광지·맛집 추천** — 지역 기반 (백엔드가 Google Places 프록시)
- 🗺️ **하루 코스 / 🎲 아무거나** — 시간대별 코스·랜덤 추천 → 일정 담기·길찾기
- 🎬 **여행 미리보기** — 위치 일정 시간순 재생, 경로선·교통수단·소요시간 추정
- 🧾 **경비 기록 / 💱 환율 계산기** — 통화별 합계 · 166통화
- 🧭 **내 주변** — GPS 현위치 기반 검색 → 길찾기
- ☀️ **목적지 날씨** — open-meteo 예보
- 📶 **오프라인 접근** — 저장된 여행·일정 캐시 조회
- 🖼️ **여행 커버 사진** — 목적지 대표 이미지 (Wikipedia, 키 불필요)
- ↔️ **스와이프 삭제** — 낙관적 제거 + 실행취소
- 🔑 로그인 · 🧬 생체 잠금 · 비밀번호 재설정

## 기술 스택

- **Flutter (Dart)** — Material 3, 코럴 테마 디자인 시스템 (`lib/theme.dart`)
- `google_maps_flutter` · `geolocator` · `url_launcher`
- `shared_preferences` (토큰·설정·오프라인 캐시) · `local_auth` (생체 잠금)
- `flutter_local_notifications` · `timezone` · `share_plus` · `http` · `intl`

---

## 실행 방법

```bash
flutter pub get

# 백엔드 URL은 dart-define으로 주입 (릴리스 빌드는 필수)
flutter run --dart-define=API_BASE_URL=https://test-backend-83yt.onrender.com
```

### 지도 키 설정 (지도 기능을 쓰려면)

- **Android**: `android/key.properties`에 `mapsApiKey`(+ 서명 keystore) — gitignore, 로컬 필수
- **Web**: `web/index.html`의 `__MAPS_WEB_KEY__` 플레이스홀더에 빌드 직전 실키 주입 → 배포 후 복원(공개 레포 미커밋)

자세한 배포 절차는 **[`DEPLOY.md`](DEPLOY.md)** 참고 (웹 = Firebase Hosting, 폰 = App Distribution).

## 테스트

```bash
flutter test        # 36개 통과 (하루코스 순수함수·오프라인 캐시·Trip 모델·smoke)
flutter analyze
```

## 프로젝트 구조

```
lib/
├── main.dart               # 앱 진입 · 하단 탭 · 인증/스플래시/잠금 게이트
├── theme.dart              # 코럴 디자인 시스템
├── models/                 # Trip · Todo · Place 등
├── services/               # api_config · trip_api · places_api · offline_cache · day_course …
├── state/                  # todo_notifier · calendar_notifier
├── screens/                # trips · trip_detail · trip_calendar · location_picker · nearby …
└── widgets/                # todo_form_dialog · cover_image · offline_banner · empty_state …
```

## 배포

CI 없이 수동. 매 변경마다 커밋 → **웹(Firebase Hosting) + APK(App Distribution)** 동시 배포, 빌드 번호를 올린다.
빌드 산출물의 백엔드 URL을 검증 후 배포. 상세는 [`DEPLOY.md`](DEPLOY.md).
