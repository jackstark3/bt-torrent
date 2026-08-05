import 'dart:typed_data';

import 'package:bt_torrent/core/models/torrent_info.dart';
import 'package:bt_torrent/core/models/search_query.dart';
import 'package:bt_torrent/core/utils/magnet_parser.dart';
import 'package:bt_torrent/core/utils/result.dart';
import 'package:bt_torrent/data/remote/search_aggregator.dart';
import 'package:bt_torrent/data/remote/search_provider.dart';
import 'package:bt_torrent/providers/search_providers.dart';
import 'package:bt_torrent/data/remote/providers/leetx_provider.dart';
import 'package:bt_torrent/data/remote/providers/ciligou_provider.dart';
import 'package:bt_torrent/data/remote/providers/sokitty_provider.dart';
import 'package:bt_torrent/data/remote/providers/dmhy_provider.dart';
import 'package:bt_torrent/data/remote/providers/animetosho_provider.dart';
import 'package:bt_torrent/data/remote/providers/piratebay_provider.dart';
import 'package:bt_torrent/data/remote/providers/provider_utils.dart';
import 'package:bt_torrent/data/remote/providers/solidtorrents_provider.dart';
import 'package:bt_torrent/data/remote/providers/torznab_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 返回固定响应内容的假 HttpClientAdapter
class FakeAdapter implements HttpClientAdapter {
  final String Function() dataBuilder;
  FakeAdapter(this.dataBuilder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      dataBuilder(),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 聚合测试用假搜索源
class _FakeProvider extends SearchProvider {
  final String providerName;
  final List<TorrentInfo> results;

  _FakeProvider(this.providerName, this.results);

  @override
  String get name => providerName;

  @override
  String get id => providerName;

  @override
  String get baseUrl => 'https://fake.example';

  @override
  bool get isEnabled => true;

  @override
  bool get supportsCategories => false;

  @override
  bool get supportsSorting => false;

  @override
  Future<Result<List<TorrentInfo>>> search({
    required String query,
    TorrentCategory? category,
    SortBy sortBy = SortBy.seeders,
    int page = 1,
  }) async {
    return Result.success(results);
  }

  @override
  Future<bool> healthCheck() async => true;

  @override
  String? getCategoryPath(TorrentCategory category) => null;

  @override
  String? getSortParam(SortBy sortBy) => null;
}

/// 构造返回固定内容的 Dio
Dio fakeDio(String Function() dataBuilder) {
  return Dio(BaseOptions())..httpClientAdapter = FakeAdapter(dataBuilder);
}

const leetxHtml = '''
<html><body>
<table class="table-list">
<tbody>
<tr>
  <td class="coll-1 name"><a href="/torrent/123/"><img src="x"></a>
    <a href="/torrent/123/test-movie-2024-1080p/">Test Movie 2024 1080p</a></td>
  <td class="coll-2 seeds">1234</td>
  <td class="coll-3 leeches">56</td>
  <td class="coll-4 size">2.5 GB</td>
</tr>
</tbody>
</table>
</body></html>
''';

const ciligouHtml = '''
<html><body>
<ul id="Search_list_wrapper">
<li>
  <div class="Search_title_wrapper"><div class="SearchListTitle_list_title">
    <a class="SearchListTitle_result_title" href="/information/cc36bc02bada18ed55c888d06733ddecfed59f6f">(10-06) [TGIRLSXXX] Ivory Mayhem &amp; <em>Rick</em> Fuck Hard</a>
  </div></div>
  <div class="Search_list_info"><span class="Search_result_type"><i class="iconfont icon-citie Search_icon_citie"></i>4198</span><em>文件大小：</em>1003.25 MB<em>创建时间：</em>2023-10-06<em>文件格式：</em>.mp4</div>
</li>
<li>
  <div class="Search_title_wrapper"><div class="SearchListTitle_list_title">
    <a class="SearchListTitle_result_title" href="/information/ddc6717c303faa746311f9d406e89e1001bee055">SeeHimFuck.23.01.21.Malina.Melendez.And.Rick.Waters.XXX.1080p.MP4</a>
  </div></div>
  <div class="Search_list_info"><span class="Search_result_type"><i class="iconfont icon-citie Search_icon_citie"></i>9536</span><em>文件大小：</em>3.48 GB<em>创建时间：</em>2023-01-27<em>文件格式：</em>.mp4</div>
</li>
</ul>
</body></html>
''';

const sokittyHtml = '''
<html><body>
<div class="panel panel-default search-panel">
  <div class="panel-heading pbc"><h3 class="panel-title">
    <a class="list-title" href="/bt/fa79381cd9c63a71468c0f7e7db5d83923b67edf">onlyfans-KittyxKum---<em>Spider</em>-Girl-Cosplay-Squirt</a>
  </h3></div>
  <div class="panel-body"><ul class="list-unstyled" style="margin-bottom:0;"><li class="list-file"><span><i class="fa fa-file-video-o"></i>KittyxKum---Spider-Girl-Cosplay-Squirt.mp4</span> <span class="badge2">944.99MB</span></li></ul></div>
  <div class="panel-footer pbc">文件大小: <span class="info-item">947.25 MB</span>文件数量: <span class="info-item">1</span>收录时间: <span class="info-item">2024-04-11</span></div>
</div>
</body></html>
''';

const dmhyRss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
<item>
<title><![CDATA[[Skymoon-Raws][One Piece 海賊王][1172][ViuTV][WEB-RIP][1080p][MKV]]]></title>
<link>http://share.dmhy.org/topics/view/724131.html</link>
<pubDate>Tue, 04 Aug 2026 01:15:48 +0800</pubDate>
<enclosure url="magnet:?xt=urn:btih:J4IFTS3RXW4BKDFNGDDSK35JRYLM2J7C&amp;dn=&amp;tr=http%3A%2F%2Ftracker.openbittorrent.com%3A80%2Fannounce" length="0" type="application/x-bittorrent"/>
</item>
</channel>
</rss>
''';

const animetoshoHtml = '''
<html><body>
<div class="home_list_entry">
  <div class="size" title="Total file size: 2,012,372,487 bytes">1.874 GB</div>
  <div class="link"><a href="https://animetosho.org/view/one-piece-vol002.n2106671">One.Piece.Vol002.DVDRip.480p.x265<wbr/>.Multi-uP</a></div>
  <div class="links"><a href="magnet:?xt=urn:btih:PDJTN7UDSTJTYMLDI7FWSWCVSAUEFDZA&amp;tr=udp%3A%2F%2Fopen.stealth.si%3A80%2Fannounce&amp;dn=One.Piece">Magnet</a> <span title="Seeders: 2 / Leechers: 10" style="color: #808080;">[2&#8593;/10&#8595;]</span></div>
</div>
</body></html>
''';

const pirateBayHtml = '''
<html><body>
<table id="searchResult">
  <tr>
    <td class="vertTh"><center><img src="x" alt="Video"></center></td>
    <td>
      <div class="detName">
        <a href="/torrent/123/test-movie-2024-1080p" class="detLink">Test Movie 2024 1080p</a>
      </div>
      <a href="magnet:?xt=urn:btih:abcdef0123456789abcdef0123456789abcdef01&amp;dn=test"
         title="Download this torrent using magnet"><img src="magnet.png"></a>
      <font class="detDesc">Uploaded 07-31 2024, Size 2.5 GiB, ULed by uploader</font>
    </td>
    <td align="right">1234</td>
    <td align="right">56</td>
  </tr>
</table>
</body></html>
''';

const pirateBayNewHtml = '''
<html><body>
<table id="searchResult">
  <thead id="tableHead">
    <tr class="header"><th>Type</th><th>Name</th><th>Uploaded</th><th>&nbsp;</th>
    <th>Size</th><th>SE</th><th>LE</th><th>ULed by</th></tr>
  </thead>
  <tr>
    <td class="vertTh"><a href="/browse/207">Video &gt; HD - Movies</a></td>
    <td><a href="/torrent/83970962/Test-Movie-2024-1080p"
        title="Details for Test Movie 2024 1080p">Test Movie 2024 1080p</a></td>
    <td>Y-day&nbsp;19:00</td>
    <td><nobr><a href="magnet:?xt=urn:btih:abcdef0123456789abcdef0123456789abcdef01&amp;dn=test">
        <img src="magnet.png"></a></nobr></td>
    <td>2.5 GiB</td>
    <td>1234</td>
    <td>56</td>
    <td>uploader</td>
  </tr>
</table>
</body></html>
''';

const solidTorrentsJson = '''
{"total":1,"data":{"torrents":[
  {
    "title":"Test Movie 2024 1080p",
    "hash":"abcdef0123456789abcdef0123456789abcdef01",
    "size":2684354560,
    "seeders":12,
    "leechers":3,
    "category":"Video > Movies",
    "magnet":"magnet:?xt=urn:btih:abcdef0123456789abcdef0123456789abcdef01",
    "poster":"http://example.com/poster.jpg",
    "date":"2024-07-31T10:00:00Z"
  }
]}}
''';

const torznabXml = '''
<rss version="2.0" xmlns:torznab="http://torznab.com/schemas/2015/feed">
  <channel>
    <item>
      <title>Test Movie 2024 1080p</title>
      <guid>abcdef0123456789abcdef0123456789abcdef01</guid>
      <link>magnet:?xt=urn:btih:abcdef0123456789abcdef0123456789abcdef01</link>
      <size>1073741824</size>
      <pubDate>Wed, 31 Jul 2024 10:00:00 +0000</pubDate>
      <torznab:attr name="seeders" value="42"/>
      <torznab:attr name="peers" value="50"/>
    </item>
  </channel>
</rss>
''';

void main() {
  group('SearchAggregator', () {
    test('聚合去重保留多来源归属', () async {
      const hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final torrentA = TorrentInfo(
        title: 'Test Movie',
        infoHash: hash,
        sizeBytes: 100,
        seeders: 1,
        leechers: 0,
        sourceProvider: '源A',
      );
      final torrentB = TorrentInfo(
        title: 'Test Movie',
        infoHash: hash,
        sizeBytes: 100,
        seeders: 1,
        leechers: 0,
        sourceProvider: '源B',
      );
      final aggregator = SearchAggregator([
        _FakeProvider('源A', [torrentA]),
        _FakeProvider('源B', [torrentB]),
      ]);

      AggregatedResult? last;
      await for (final r in aggregator.searchStream(
          const SearchQuery(query: 'test'))) {
        last = r;
      }

      final result =
          last ??
          const AggregatedResult(
              results: [], sourceStatuses: {}, isComplete: true);
      expect(result.results, hasLength(1));
      expect(result.results.first.sourceProvider, '源A');
      expect(result.results.first.additionalSources, contains('源B'));
    });

    test('跨批次合并保留同主来源的附加来源', () {
      const hash = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final base = TorrentInfo(
        title: 'Test',
        infoHash: hash,
        sizeBytes: 1,
        seeders: 1,
        leechers: 0,
        sourceProvider: '磁力狗',
      );
      // 第二批次的同资源已由聚合器标上 SoKitty 归属（主来源仍是磁力狗）
      final withAttribution = base.copyWith(
        additionalSources: const ['SoKitty'],
      );

      final merged = <String, TorrentInfo>{};
      mergeTorrentSources(merged, [base]);
      mergeTorrentSources(merged, [withAttribution]);

      expect(merged[hash]!.sourceProvider, '磁力狗');
      expect(merged[hash]!.additionalSources, contains('SoKitty'));
    });
  });

  group('ProviderUtils', () {
    test('parseSize 支持各种单位', () {
      expect(ProviderUtils.parseSize('512 B'), 512);
      expect(ProviderUtils.parseSize('1.5 KB'), 1536);
      expect(ProviderUtils.parseSize('2 MB'), 2 * 1024 * 1024);
      expect(ProviderUtils.parseSize('2.5 GB'), 2684354560);
      expect(ProviderUtils.parseSize('2.5 GiB'), 2684354560);
      expect(ProviderUtils.parseSize('1 TB'), 1099511627776);
      expect(ProviderUtils.parseSize('abc'), 0);
    });

    test('extractHashFromMagnet 提取 info_hash', () {
      expect(
        ProviderUtils.extractHashFromMagnet(
            'magnet:?xt=urn:btih:ABCDEF0123456789abcdef0123456789abcdef01'),
        'abcdef0123456789abcdef0123456789abcdef01',
      );
      expect(ProviderUtils.extractHashFromMagnet('not a magnet'), isNull);
    });

    test('detectCategory 识别分类', () {
      expect(ProviderUtils.detectCategory('Movie XXX 1080p'),
          TorrentCategory.xxx);
      expect(ProviderUtils.detectCategory('Show S01E02 720p'),
          TorrentCategory.tv);
      expect(ProviderUtils.detectCategory('Album FLAC'), TorrentCategory.music);
      expect(ProviderUtils.detectCategory('Anime Subbed'),
          TorrentCategory.anime);
      expect(ProviderUtils.detectCategory('Random Title'), isNull);
    });
  });

  group('LeetXProvider', () {
    test('解析搜索结果 HTML', () async {
      final provider = LeetXProvider(fakeDio(() => leetxHtml));
      final result =
          await provider.search(query: 'test', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(1));
      expect(items.first.title, 'Test Movie 2024 1080p');
      expect(items.first.seeders, 1234);
      expect(items.first.leechers, 56);
      expect(items.first.sizeBytes, 2684354560);
      expect(items.first.sourceProvider, '1337x');
    });
  });

  group('CiliGouProvider', () {
    test('解析搜索结果 HTML 并拼出磁力链接', () async {
      final provider = CiliGouProvider(fakeDio(() => ciligouHtml));
      final result = await provider.search(query: 'rick', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(2));

      final first = items.first;
      expect(first.title, '(10-06) [TGIRLSXXX] Ivory Mayhem & Rick Fuck Hard');
      expect(first.infoHash, 'cc36bc02bada18ed55c888d06733ddecfed59f6f');
      expect(first.magnetUri,
          startsWith('magnet:?xt=urn:btih:cc36bc02bada18ed55c888d06733ddecfed59f6f'));
      expect(first.sizeBytes, closeTo(1003.25 * 1024 * 1024, 2));
      expect(first.addedDate, DateTime(2023, 10, 6));
      expect(first.sourceProvider, '磁力狗');
      expect(first.isVerified, isTrue);

      expect(items[1].sizeBytes, closeTo(3.48 * 1024 * 1024 * 1024, 2));
    });
  });

  group('SoKittyProvider', () {
    test('解析搜索结果 HTML 并拼出磁力链接', () async {
      final provider = SoKittyProvider(fakeDio(() => sokittyHtml));
      final result = await provider.search(query: 'spider', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(1));

      final first = items.first;
      expect(first.title, 'onlyfans-KittyxKum---Spider-Girl-Cosplay-Squirt');
      expect(first.infoHash, 'fa79381cd9c63a71468c0f7e7db5d83923b67edf');
      expect(first.magnetUri,
          startsWith('magnet:?xt=urn:btih:fa79381cd9c63a71468c0f7e7db5d83923b67edf'));
      expect(first.sizeBytes, closeTo(947.25 * 1024 * 1024, 2));
      expect(first.addedDate, DateTime(2024, 4, 11));
      expect(first.sourceProvider, 'SoKitty');
      expect(first.isVerified, isTrue);
    });
  });

  group('DmhyProvider', () {
    test('解析 RSS 并归一化 base32 磁力哈希', () async {
      final provider = DmhyProvider(fakeDio(() => dmhyRss));
      final result = await provider.search(query: 'one piece', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(1));

      final first = items.first;
      expect(first.title, contains('One Piece'));
      expect(first.infoHash, hasLength(40));
      expect(RegExp(r'^[a-f0-9]{40}$').hasMatch(first.infoHash), isTrue);
      expect(first.magnetUri, startsWith('magnet:?xt=urn:btih:'));
      expect(first.sourceProvider, '动漫花园');
      expect(first.isVerified, isTrue);
    });

    test('base32 归一化为 40 位十六进制', () {
      final hex = MagnetParser.normalizeInfoHash(
          'J4IFTS3RXW4BKDFNGDDSK35JRYLM2J7C');
      expect(hex, isNotNull);
      expect(hex!.length, 40);
      expect(RegExp(r'^[a-f0-9]{40}$').hasMatch(hex), isTrue);
    });
  });

  group('AnimeToshoProvider', () {
    test('解析搜索结果（含做种数）', () async {
      final provider = AnimeToshoProvider(fakeDio(() => animetoshoHtml));
      final result = await provider.search(query: 'one piece', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(1));

      final first = items.first;
      expect(first.title, 'One.Piece.Vol002.DVDRip.480p.x265.Multi-uP');
      expect(first.infoHash, hasLength(40));
      expect(first.magnetUri, contains('urn:btih:'));
      expect(first.seeders, 2);
      expect(first.leechers, 10);
      expect(first.sizeBytes, closeTo(1.874 * 1024 * 1024 * 1024, 2));
      expect(first.sourceProvider, 'AnimeTosho');
    });
  });

  group('PirateBayProvider', () {
    test('解析搜索结果 HTML 并从磁力提取 hash', () async {
      final provider = PirateBayProvider(fakeDio(() => pirateBayHtml));
      final result =
          await provider.search(query: 'test', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(1));
      expect(items.first.title, 'Test Movie 2024 1080p');
      expect(items.first.seeders, 1234);
      expect(items.first.leechers, 56);
      expect(items.first.sizeBytes, 2684354560);
      expect(items.first.infoHash,
          'abcdef0123456789abcdef0123456789abcdef01');
      expect(items.first.isVerified, isTrue);
    });

    test('解析新版 TPB 结构（无 detLink 类）', () async {
      final provider = PirateBayProvider(fakeDio(() => pirateBayNewHtml));
      final result =
          await provider.search(query: 'test', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(1));
      expect(items.first.title, 'Test Movie 2024 1080p');
      expect(items.first.seeders, 1234);
      expect(items.first.leechers, 56);
      expect(items.first.sizeBytes, 2684354560);
      expect(items.first.infoHash,
          'abcdef0123456789abcdef0123456789abcdef01');
    });
  });

  group('SolidTorrentsProvider', () {
    test('解析 JSON API 响应', () async {
      final provider =
          SolidTorrentsProvider(fakeDio(() => solidTorrentsJson));
      final result =
          await provider.search(query: 'test', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(1));
      expect(items.first.title, 'Test Movie 2024 1080p');
      expect(items.first.sizeBytes, 2684354560);
      expect(items.first.seeders, 12);
      expect(items.first.leechers, 3);
      expect(items.first.category, TorrentCategory.movies);
      expect(items.first.posterUrl, 'http://example.com/poster.jpg');
      expect(items.first.addedDate, isNotNull);
    });
  });

  group('TorznabProvider', () {
    test('解析 Torznab XML 响应', () async {
      final provider = TorznabProvider(
        fakeDio(() => torznabXml),
        baseUrl: 'http://localhost:9117',
        apiKey: 'test-key',
      );
      final result =
          await provider.search(query: 'test', category: null);

      expect(result.isSuccess, isTrue);
      final items = result.value!;
      expect(items, hasLength(1));
      expect(items.first.title, 'Test Movie 2024 1080p');
      expect(items.first.seeders, 42);
      expect(items.first.leechers, 8); // peers(50) - seeders(42)
      expect(items.first.sizeBytes, 1073741824);
      expect(items.first.infoHash,
          'abcdef0123456789abcdef0123456789abcdef01');
    });

    test('未配置 API Key 时返回错误', () async {
      final provider = TorznabProvider(
        fakeDio(() => torznabXml),
        baseUrl: 'http://localhost:9117',
        apiKey: '',
      );
      expect(provider.isEnabled, isFalse);
      final result = await provider.search(query: 'test');
      expect(result.isSuccess, isFalse);
    });
  });
}
