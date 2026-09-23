/// Reviewed local photos. Never infer a city from a substring or search result.
class DestinationCover {
  const DestinationCover({
    required this.name,
    required this.landmark,
    required this.asset,
    required this.file,
    required this.author,
    required this.license,
    required this.licenseUrl,
    required this.source,
    required this.aliases,
    required this.countries,
  });
  final String name, landmark, asset, file, author, license, licenseUrl, source;
  final List<String> aliases, countries;

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s,·]+'), ' ');

  static DestinationCover? find(String? destination) {
    if (destination == null || destination.trim().isEmpty) return null;
    final query = _normalize(destination);
    for (final cover in all) {
      for (final alias in cover.aliases) {
        if (query == _normalize(alias)) return cover;
        for (final country in cover.countries) {
          if (query == _normalize('$country $alias') ||
              query == _normalize('$alias $country')) {
            return cover;
          }
        }
      }
    }
    return null;
  }

  static const all = <DestinationCover>[
    DestinationCover(
      name: "부산",
      landmark: "광안대교",
      asset: "assets/covers/busan.jpg",
      file: "Gwangan_Bridge1.jpg",
      author: "Glabb",
      license: "Public domain",
      licenseUrl: "https://commons.wikimedia.org/wiki/Help:Public_domain",
      source: "https://commons.wikimedia.org/wiki/File:Gwangan_Bridge1.jpg",
      aliases: ["부산", "busan", "부산시", "부산광역시"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "제주",
      landmark: "성산일출봉",
      asset: "assets/covers/jeju.jpg",
      file: "Seongsan_Ilchulbong_from_the_air.jpg",
      author: "Korea.net / Korean Culture and Information Service",
      license: "CC BY-SA 2.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/2.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Seongsan_Ilchulbong_from_the_air.jpg",
      aliases: ["제주", "jeju", "제주도", "제주시", "제주특별자치도", "jeju island"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "경주",
      landmark: "동궁과 월지",
      asset: "assets/covers/gyeongju.jpg",
      file:
          "Water_reflection_of_Donggung_Palace_in_Wolji_Pond_at_blue_hour_in_Gyeongju_South_Korea.jpg",
      author: "Basile Morin",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Water_reflection_of_Donggung_Palace_in_Wolji_Pond_at_blue_hour_in_Gyeongju_South_Korea.jpg",
      aliases: ["경주", "gyeongju", "경주시"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "속초",
      landmark: "설악산 울산바위",
      asset: "assets/covers/sokcho.jpg",
      file: "Dinosaur_Ridge_of_Seoraksan.jpg",
      author: "Taewangkorea",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Dinosaur_Ridge_of_Seoraksan.jpg",
      aliases: ["속초", "sokcho", "속초시"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "여수",
      landmark: "돌산대교",
      asset: "assets/covers/yeosu.jpg",
      file: "Dolsan_Bridge1.JPG",
      author: "Glabb",
      license: "Public domain",
      licenseUrl: "https://commons.wikimedia.org/wiki/Help:Public_domain",
      source: "https://commons.wikimedia.org/wiki/File:Dolsan_Bridge1.JPG",
      aliases: ["여수", "yeosu", "여수시"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "인천",
      landmark: "송도 센트럴파크",
      asset: "assets/covers/incheon.jpg",
      file: "Songdo_Central_Park_in_2021.jpg",
      author: "José Carioca",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Songdo_Central_Park_in_2021.jpg",
      aliases: ["인천", "incheon", "인천시", "인천광역시"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "도쿄",
      landmark: "레인보우 브리지",
      asset: "assets/covers/tokyo.jpg",
      file: "Rainbow_Bridge_(Tokyo)_at_night_8.jpg",
      author: "Kakidai",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Rainbow_Bridge_(Tokyo)_at_night_8.jpg",
      aliases: ["도쿄", "tokyo", "동경", "東京"],
      countries: ["일본", "japan"],
    ),
    DestinationCover(
      name: "오사카",
      landmark: "오사카성",
      asset: "assets/covers/osaka.jpg",
      file: "Osaka_Castle_03bs3200.jpg",
      author: "663highland",
      license: "CC BY 2.5",
      licenseUrl: "https://creativecommons.org/licenses/by/2.5",
      source:
          "https://commons.wikimedia.org/wiki/File:Osaka_Castle_03bs3200.jpg",
      aliases: ["오사카", "osaka", "大阪"],
      countries: ["일본", "japan"],
    ),
    DestinationCover(
      name: "후쿠오카",
      landmark: "오호리 공원",
      asset: "assets/covers/fukuoka.jpg",
      file: "大濠公園_(3360365578).jpg",
      author: "Tzuhsun Hsu from Taipei, Taiwan",
      license: "CC BY-SA 2.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/2.0",
      source:
          "https://commons.wikimedia.org/wiki/File:%E5%A4%A7%E6%BF%A0%E5%85%AC%E5%9C%92_(3360365578).jpg",
      aliases: ["후쿠오카", "fukuoka", "福岡"],
      countries: ["일본", "japan"],
    ),
    DestinationCover(
      name: "삿포로",
      landmark: "오도리 공원",
      asset: "assets/covers/sapporo.jpg",
      file: "Hokkaido_Sapporo_Odori_Park.jpg",
      author: "Nkns",
      license: "CC BY-SA 3.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/3.0/",
      source:
          "https://commons.wikimedia.org/wiki/File:Hokkaido_Sapporo_Odori_Park.jpg",
      aliases: ["삿포로", "sapporo", "札幌"],
      countries: ["일본", "japan"],
    ),
    DestinationCover(
      name: "싱가포르",
      landmark: "마리나 베이 샌즈",
      asset: "assets/covers/singapore.jpg",
      file: "Marina_Bay_Sands_(I).jpg",
      author: "Supanut Arunoprayote",
      license: "CC BY 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Marina_Bay_Sands_(I).jpg",
      aliases: ["싱가포르", "singapore"],
      countries: ["싱가포르", "singapore"],
    ),
    DestinationCover(
      name: "방콕",
      landmark: "왓 아룬",
      asset: "assets/covers/bangkok.jpg",
      file: "เจดีย์ประธานทรงปรางค์วัดอรุณ2.jpg",
      author: "Mastertongapollo",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:%E0%B9%80%E0%B8%88%E0%B8%94%E0%B8%B5%E0%B8%A2%E0%B9%8C%E0%B8%9B%E0%B8%A3%E0%B8%B0%E0%B8%98%E0%B8%B2%E0%B8%99%E0%B8%97%E0%B8%A3%E0%B8%87%E0%B8%9B%E0%B8%A3%E0%B8%B2%E0%B8%87%E0%B8%84%E0%B9%8C%E0%B8%A7%E0%B8%B1%E0%B8%94%E0%B8%AD%E0%B8%A3%E0%B8%B8%E0%B8%932.jpg",
      aliases: ["방콕", "bangkok"],
      countries: ["태국", "thailand"],
    ),
    DestinationCover(
      name: "런던",
      landmark: "타워 브리지",
      asset: "assets/covers/london.jpg",
      file: "Tower_Bridge_at_Dawn.jpg",
      author: "Fuzzypiggy",
      license: "CC BY-SA 3.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/3.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Tower_Bridge_at_Dawn.jpg",
      aliases: ["런던", "london"],
      countries: ["영국", "uk", "united kingdom"],
    ),
    DestinationCover(
      name: "로마",
      landmark: "콜로세움",
      asset: "assets/covers/rome.jpg",
      file: "Colosseo_2020.jpg",
      author: "FeaturedPics",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source: "https://commons.wikimedia.org/wiki/File:Colosseo_2020.jpg",
      aliases: ["로마", "rome", "roma"],
      countries: ["이탈리아", "italy"],
    ),
    DestinationCover(
      name: "서울",
      landmark: "경복궁",
      asset: "assets/covers/seoul.jpg",
      file:
          "Front view of the Imperial Throne Hall Geunjeongjeon at Gyeongbokgung Palace with blue sky in Seoul.jpg",
      author: "Basile Morin",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Front_view_of_the_Imperial_Throne_Hall_Geunjeongjeon_at_Gyeongbokgung_Palace_with_blue_sky_in_Seoul.jpg",
      aliases: ["서울", "seoul", "서울시", "서울특별시"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "강릉",
      landmark: "경포해변",
      asset: "assets/covers/gangneung.jpg",
      file: "Gyeongpo Beach 20220502 018.jpg",
      author: "Mobius6",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Gyeongpo_Beach_20220502_018.jpg",
      aliases: ["강릉", "gangneung", "강릉시"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "전주",
      landmark: "한옥마을",
      asset: "assets/covers/jeonju.jpg",
      file: "Jeonju Hanok Maeul 01.jpg",
      author: "Bernard Gagnon",
      license: "CC0",
      licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/deed.en",
      source:
          "https://commons.wikimedia.org/wiki/File:Jeonju_Hanok_Maeul_01.jpg",
      aliases: ["전주", "jeonju", "전주시"],
      countries: ["한국", "대한민국", "korea", "south korea"],
    ),
    DestinationCover(
      name: "교토",
      landmark: "금각사",
      asset: "assets/covers/kyoto.jpg",
      file: "Kinkaku-ji temple in Kyoto.jpg",
      author: "Geertchaos",
      license: "CC BY-SA 4.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0",
      source:
          "https://commons.wikimedia.org/wiki/File:Kinkaku-ji_temple_in_Kyoto.jpg",
      aliases: ["교토", "kyoto", "京都"],
      countries: ["일본", "japan"],
    ),
    DestinationCover(
      name: "파리",
      landmark: "에펠탑과 파리 전경",
      asset: "assets/covers/paris.jpg",
      file:
          "La Tour Eiffel vue de la Tour Saint-Jacques, Paris août 2014 (2).jpg",
      author: "Yann Caradec from Paris, France",
      license: "CC BY-SA 2.0",
      licenseUrl: "https://creativecommons.org/licenses/by-sa/2.0",
      source:
          "https://commons.wikimedia.org/wiki/File:La_Tour_Eiffel_vue_de_la_Tour_Saint-Jacques,_Paris_ao%C3%BBt_2014_(2).jpg",
      aliases: ["파리", "paris"],
      countries: ["프랑스", "france"],
    ),
    DestinationCover(
      name: "타이베이",
      landmark: "타이베이 전경",
      asset: "assets/covers/taipei.jpg",
      file: "Taipei, assorted - TaipeiCityscapes4969.jpg",
      author: "lumoplank",
      license: "CC0",
      licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/deed.en",
      source:
          "https://commons.wikimedia.org/wiki/File:Taipei,_assorted_-_TaipeiCityscapes4969.jpg",
      aliases: ["타이베이", "taipei", "타이페이", "台北"],
      countries: ["대만", "taiwan"],
    ),
  ];
}
