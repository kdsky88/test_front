import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_front/models/destination_cover.dart';
import 'package:test_front/widgets/cover_image.dart';
import 'package:test_front/widgets/travel_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exact city aliases accept country qualifiers but reject false matches',
    () {
      expect(DestinationCover.find('  JAPAN, Tokyo ')?.name, '도쿄');
      expect(DestinationCover.find('서울특별시')?.name, '서울');
      expect(DestinationCover.find('제주도')?.name, '제주');
      for (final unknown in [
        null,
        '',
        '서울역',
        '제주 4·3 사건',
        '미국 파리',
        '도쿄 오사카',
        '파리바게뜨',
        '미등록 여행지',
      ]) {
        expect(
          DestinationCover.find(unknown),
          isNull,
          reason: '$unknown must not borrow an unrelated photo',
        );
      }
    },
  );

  test(
    'every curated asset decodes as a bounded landscape and has credits',
    () async {
      expect(DestinationCover.all.length, 20);
      final aliases = <String>{};
      for (final cover in DestinationCover.all) {
        expect(cover.author, isNotEmpty);
        expect(Uri.parse(cover.source).host, 'commons.wikimedia.org');
        expect(Uri.parse(cover.licenseUrl).scheme, 'https');
        expect(File(cover.asset).lengthSync(), lessThan(600000));
        final data = await rootBundle.load(cover.asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(frame.image.height));
        expect(frame.image.width, lessThanOrEqualTo(960));
        frame.image.dispose();
        codec.dispose();
        for (final alias in cover.aliases) {
          expect(aliases.add(alias.toLowerCase()), isTrue);
          expect(DestinationCover.find(alias), same(cover));
        }
      }
    },
  );

  testWidgets('photo credit is accessible and does not open the trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TravelCard(
              title: '제주 여행',
              destination: '제주',
              dateLabel: '날짜 미정',
              cover: Colors.green,
              onTap: () => taps++,
              onEdit: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final picture = tester.widget<Image>(find.byType(Image));
    expect(picture.image, isA<AssetImage>());
    expect(picture.fit, BoxFit.contain);
    final area = tester.getSize(find.byType(CoverImage));
    expect(area.width / area.height, closeTo(16 / 9, .001));
    await tester.tap(find.byTooltip('사진 출처'));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(find.text('제주 커버 사진'), findsOneWidget);
    expect(find.textContaining('CC BY-SA 2.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown destinations use an offline gradient without a photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: CoverImage(destination: '미등록 여행지', fallback: Colors.green),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byTooltip('사진 출처'), findsNothing);
  });
}
