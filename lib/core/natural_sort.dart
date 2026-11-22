/// 自然排序比较器：数字段按数值比较，保证 2 < 10 < 100。
/// 纯函数，供浏览器排序与"正在播放"队列生成共用。
library;

/// 将字符串切分成 文本块/数字块 序列。
List<String> _tokenize(String s) {
  final tokens = <String>[];
  final buf = StringBuffer();
  var inDigits = false;
  for (final cu in s.runes) {
    final isDigit = cu >= 0x30 && cu <= 0x39;
    if (buf.isNotEmpty && isDigit != inDigits) {
      tokens.add(buf.toString());
      buf.clear();
    }
    inDigits = isDigit;
    buf.writeCharCode(cu);
  }
  if (buf.isNotEmpty) tokens.add(buf.toString());
  return tokens;
}

int _compareTokens(String a, String b) {
  final ta = _tokenize(a);
  final tb = _tokenize(b);
  for (var i = 0; i < ta.length && i < tb.length; i++) {
    final x = ta[i];
    final y = tb[i];
    final xDigit = x.codeUnitAt(0) >= 0x30 && x.codeUnitAt(0) <= 0x39;
    final yDigit = y.codeUnitAt(0) >= 0x30 && y.codeUnitAt(0) <= 0x39;
    if (xDigit && yDigit) {
      // 去前导零后按数值比较（BigInt 防超长数字溢出）；数值相等（如 007 vs 7）视为相等
      final c = BigInt.parse(x).compareTo(BigInt.parse(y));
      if (c != 0) return c;
    } else if (xDigit != yDigit) {
      return xDigit ? -1 : 1; // 数字块排在文本块前，保持稳定
    } else {
      final c = x.toLowerCase().compareTo(y.toLowerCase());
      if (c != 0) return c;
    }
  }
  if (ta.length != tb.length) return ta.length - tb.length;
  return 0; // 忽略大小写后完全相等
}

/// 目录树中条目排序：目录在前、文件在后；各自按自然排序。
int compareNatural(String a, String b) => _compareTokens(a, b);
