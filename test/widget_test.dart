import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bt_torrent/app.dart';
import 'package:bt_torrent/providers/core_providers.dart';

void main() {
  testWidgets('App 启动后显示搜索界面', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const BtApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 搜索框提示语
    expect(find.text('搜索种子或粘贴磁力链接...'), findsOneWidget);
    // 底部导航
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
