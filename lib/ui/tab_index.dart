/// 全局 tab 索引（首页引导"去设置"需要跨页切换 tab）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int i) => state = i;
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);
