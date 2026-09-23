import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_front/models/trip.dart';
import 'package:test_front/models/todo.dart';
import 'package:test_front/screens/trip_detail_screen.dart';
import 'package:test_front/screens/trips_screen.dart';
import 'package:test_front/widgets/travel_card.dart';
import 'package:test_front/screens/splash_screen.dart';
import 'package:test_front/services/startup_prefs.dart';
import 'package:test_front/state/todo_notifier.dart';
import 'package:test_front/state/trip_detail_notifier.dart';
import 'package:test_front/theme.dart';
import 'package:test_front/widgets/trip_form_dialog.dart';
import 'package:test_front/widgets/offline_banner.dart';
import 'package:test_front/widgets/calendar_date_cell.dart';
import 'package:test_front/widgets/course_save_dialog.dart';

const captureDir = String.fromEnvironment('UX_SCREENSHOTS');
final captureKey = GlobalKey();
Widget app(
  Widget child, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) {
  var theme = AppTheme.build(brightness);
  if (captureDir.isNotEmpty) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'AuditKorean'),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'AuditKorean',
        ),
      ),
    );
  }
  if (captureDir.isNotEmpty) {
    final buttonType = WidgetStatePropertyAll(
      theme.textTheme.labelLarge?.copyWith(fontFamily: 'AuditKorean'),
    );
    theme = theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: theme.filledButtonTheme.style?.copyWith(textStyle: buttonType),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: theme.outlinedButtonTheme.style?.copyWith(textStyle: buttonType),
      ),
      textButtonTheme: TextButtonThemeData(
        style: theme.textButtonTheme.style?.copyWith(textStyle: buttonType),
      ),
      floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
        extendedTextStyle: theme.floatingActionButtonTheme.extendedTextStyle
            ?.copyWith(fontFamily: 'AuditKorean'),
      ),
    );
  }
  return RepaintBoundary(
    key: captureKey,
    child: MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
}

Future<void> capture(WidgetTester tester, String name) async {
  if (captureDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(captureDir).create(recursive: true);
    await File(
      '$captureDir/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
    if (captureDir.isNotEmpty) {
      final loader = FontLoader('AuditKorean')
        ..addFont(
          File(
            '/System/Library/Fonts/AppleSDGothicNeo.ttc',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await icons.load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('destination alone creates a named trip without dates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Trip? result;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Trip>(
                  context: context,
                  builder: (_) => TripFormDialog(
                    save: (title, destination, start, end) async {
                      expect(title, '제주 여행');
                      expect(destination, '제주');
                      expect(start, isNull);
                      expect(end, isNull);
                      return Trip(
                        id: 'new',
                        title: title,
                        destination: destination,
                      );
                    },
                  ),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '제주');
    await tester.pumpAndSettle();
    await capture(tester, 'new-trip');
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();
    expect(result?.id, 'new');
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline banner wraps on narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                OfflineBanner(
                  lastSynced: DateTime(2026, 9, 22, 14, 30),
                  onRetry: () => retries++,
                ),
                CalendarDateCell(
                  date: DateTime(2026, 9, 22),
                  count: 3,
                  selected: true,
                  enabled: true,
                  today: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'offline-large-text');
    await tester.tap(find.text('다시 연결'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('9월 22일, 오늘, 일정 3개'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('course save dialog displays partial success and error', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CourseSaveDialog(
          names: const ['해변', '식당'],
          save: (i) async => i == 1 ? '연결을 확인해주세요.' : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2곳 중 1곳 저장됨'), findsOneWidget);
    expect(find.text('실패한 장소만 재시도'), findsOneWidget);
    await capture(tester, 'partial-save');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active trip opens with today itinerary before travel information',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateUtils.dateOnly(DateTime.now());
      final trip = Trip(
        id: 'active',
        title: '오늘의 여행',
        startDate: now,
        endDate: now,
      );
      final detail = TripDetailNotifier(trip.id, fetch: (_) async => <Todo>[]);
      final notifier = TodoNotifier();
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        app(TripDetailScreen(trip: trip, notifier: notifier, detail: detail)),
      );
      await tester.pumpAndSettle();
      expect(find.text('오늘 일정'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('오늘 일정')).dy,
        lessThan(tester.getTopLeft(find.text('지도 · 날씨 · 여행 기록')).dy),
      );
      expect(
        tester
            .widget<ExpansionTile>(find.byType(ExpansionTile))
            .initiallyExpanded,
        isFalse,
      );
      await capture(tester, 'active-trip');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion skips welcome without waiting', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SplashScreen(onDone: () => finished++),
        ),
      ),
    );
    await tester.pump();
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(finished, 1);
  });

  test('welcome is skipped after first visit', () async {
    await StartupPrefs.load();
    expect(StartupPrefs.showWelcome, isTrue);
    await StartupPrefs.markSeen();
    await StartupPrefs.load();
    expect(StartupPrefs.showWelcome, isFalse);
  });

  testWidgets('large text trip form keeps validation and actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saves = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TripFormDialog(
            save: (title, dest, start, end) async {
              saves++;
              return Trip(id: 'new', title: title);
            },
          ),
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    await tester.ensureVisible(find.text('추천받고 싶은 목적지를 입력해주세요.'));
    await tester.pumpAndSettle();
    await capture(tester, 'new-trip-large-text');
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome can be skipped immediately', (tester) async {
    var finished = 0;
    await tester.pumpWidget(app(SplashScreen(onDone: () => finished++)));
    await tester.tap(find.text('바로 시작'));
    await tester.pump();
    expect(finished, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(finished, 1);
  });

  testWidgets('seven calendar cells fit with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: CalendarDateCell(
                    date: DateTime(2026, 9, 21 + i),
                    count: i,
                    selected: i == 1,
                    enabled: true,
                    today: i == 1,
                    onTap: () {},
                  ),
                ),
            ],
          ),
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'calendar-large-text');
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets('travel list adapts to $width without clipping', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'cover_img_제주': '',
        'cover_img_부산': '',
      });
      final notifier = TodoNotifier();
      addTearDown(notifier.dispose);
      final start = DateTime.now().add(const Duration(days: 7));
      await tester.pumpWidget(
        app(
          TripsScreen(
            notifier: notifier,
            fetchTrips: () async => [
              Trip(
                id: 'island',
                title: '느리게 걷는 제주',
                destination: '제주',
                startDate: start,
                endDate: start.add(const Duration(days: 3)),
              ),
              const Trip(id: 'coast', title: '바다를 보러 가는 주말', destination: '부산'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TravelCard), findsNWidgets(2));
      if (width >= 760) {
        expect(
          tester.getTopLeft(find.byType(TravelCard).first).dy,
          tester.getTopLeft(find.byType(TravelCard).last).dy,
        );
      }
      await capture(tester, 'travel-list-${width.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dark travel card remains readable at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: TravelCard(
              title: '느리게 걷는 제주',
              destination: '제주',
              dateLabel: '날짜는 천천히 정해요',
              cover: const Color(0xFFEC6A4C),
              status: '날짜 미정',
              onTap: () => taps++,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
        scale: 2,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('느리게 걷는 제주'));
    expect(taps, 1);
    await capture(tester, 'travel-card-dark-large');
    expect(tester.takeException(), isNull);
  });
}
