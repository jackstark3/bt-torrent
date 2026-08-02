/// 标题与关键词匹配工具
/// 本地过滤搜索源返回的松散结果：标题未包含关键词（或关键词词项不全）的结果会被剔除；
/// "相关度"排序基于标题匹配打分。
class TitleMatcher {
  TitleMatcher._();

  /// 常见停用词（匹配时可选，避免 "Rick & Morty" 因缺 "and" 被误杀）
  static const _stopwords = {'and', 'the', 'of', 'feat', 'ft', 'a', 'an'};

  /// 归一化：小写、& 转 and、去掉所有非字母数字字符（含空格与标点）
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');
  }

  /// 把查询拆成词项（按空白和中英文标点拆分）
  static List<String> queryTerms(String query) {
    return query
        .split(RegExp(r'[\s\u3000,，、;；/|·.\-_]+'))
        .where((t) => t.trim().isNotEmpty)
        .map(normalize)
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// 标题是否匹配关键词：
  /// - 完整关键词短语出现在标题中（归一化后），或
  /// - 所有非停用词词项都出现在标题中
  static bool matches(String title, String query) {
    final t = normalize(title);
    final q = normalize(query);
    if (q.isEmpty) return true;
    if (t.contains(q)) return true;

    final terms = queryTerms(query)
        .where((term) => !_stopwords.contains(term))
        .toList();
    if (terms.isEmpty) return true;
    return terms.every(t.contains);
  }

  /// 相关度打分（0-100+）：
  /// 词项命中比例占大头，完整短语命中加分，标题越短（关键词占比越高）分越高
  static double score(String title, String query) {
    final t = normalize(title);
    final q = normalize(query);
    final terms = queryTerms(query)
        .where((term) => !_stopwords.contains(term))
        .toList();
    if (terms.isEmpty || t.isEmpty) return 0;

    var matched = 0;
    for (final term in terms) {
      if (t.contains(term)) matched++;
    }
    var s = (matched / terms.length) * 60;
    if (q.isNotEmpty && t.contains(q)) s += 40; // 完整短语命中
    s -= (t.length / 8).clamp(0, 20).toDouble(); // 标题越短越相关
    return s;
  }
}
