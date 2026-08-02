import 'package:bt_torrent/core/utils/title_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TitleMatcher.normalize', () {
    test('忽略大小写、标点与空格', () {
      expect(TitleMatcher.normalize('Rick.and.Morty S09E09!'),
          'rickandmortys09e09');
    });

    test('& 转为 and', () {
      expect(TitleMatcher.normalize('Rick & Morty'), 'rickandmorty');
    });
  });

  group('TitleMatcher.matches', () {
    test('中文短语完整匹配', () {
      expect(TitleMatcher.matches('麻豆传媒 网红 视频', '麻豆传媒'), isTrue);
      expect(TitleMatcher.matches('麻豆 影视合集', '麻豆传媒'), isFalse);
    });

    test('英文多词匹配（含 & 与点号变体）', () {
      expect(
          TitleMatcher.matches('Rick and Morty S09E09 1080p', 'rick and morty'),
          isTrue);
      expect(TitleMatcher.matches('Rick & Morty S09', 'rick and morty'), isTrue);
      expect(
          TitleMatcher.matches('Rick.and.Morty.S09E09', 'rick and morty'),
          isTrue);
    });

    test('多词部分命中不算匹配', () {
      expect(
          TitleMatcher.matches('The Amazing Spider-Man', 'spider man'), isTrue);
      expect(TitleMatcher.matches('Man of Steel 2013', 'spider man'), isFalse);
      expect(TitleMatcher.matches('Morty and Friends', 'rick and morty'),
          isFalse);
    });

    test('剧集号精确匹配', () {
      expect(TitleMatcher.matches('Rick and Morty S09E09 1080p', 's09e09'),
          isTrue);
      expect(TitleMatcher.matches('Rick and Morty Season 9', 's09e09'),
          isFalse);
    });
  });

  group('TitleMatcher.score', () {
    test('完整命中与部分命中打分不同', () {
      final full = TitleMatcher.score(
          'Rick and Morty S09E09 1080p WEB', 'rick s09e09');
      final partial =
          TitleMatcher.score('Rick and Morty Season 9 Complete', 'rick s09e09');
      expect(full, greaterThan(partial));
    });
  });
}
