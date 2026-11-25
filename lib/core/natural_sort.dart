/// 自然排序比较器：数字段按数值比较，保证 2 < 10 < 100。
/// 纯函数，供浏览器排序与"正在播放"队列生成共用。
library;

bool _isAsciiDigit(int cu) => cu >= 0x30 && cu <= 0x39;

int _toLowerAscii(int cu) => (cu >= 0x41 && cu <= 0x5A) ? (cu + 0x20) : cu;

/// 零列表/零 BigInt 分配的流式双指针自然排序比较器：
/// - 数字块排在文本块之前；
/// - 数字块跳过前导零后先比较有效位数，位数相同再逐位比较，天然支持任意超长数字且无溢出；
/// - 前导零不同但数值相等（如 007 与 7）视为相等，继续比较后续块；
/// - 文本块忽略大小写比较。
int compareNatural(String a, String b) {
  if (identical(a, b)) return 0;
  final lenA = a.length;
  final lenB = b.length;
  var ia = 0;
  var ib = 0;

  while (ia < lenA && ib < lenB) {
    final ca = a.codeUnitAt(ia);
    final cb = b.codeUnitAt(ib);
    final digitA = _isAsciiDigit(ca);
    final digitB = _isAsciiDigit(cb);

    if (digitA != digitB) {
      return digitA ? -1 : 1; // 数字块排在文本块前，保持稳定
    }

    if (digitA) {
      // 扫描双方完整数字块 [ia, endA) 与 [ib, endB)
      var endA = ia + 1;
      while (endA < lenA && _isAsciiDigit(a.codeUnitAt(endA))) {
        endA++;
      }
      var endB = ib + 1;
      while (endB < lenB && _isAsciiDigit(b.codeUnitAt(endB))) {
        endB++;
      }

      // 跳过前导 '0'（0x30）定位有效最高位
      var sigA = ia;
      while (sigA < endA && a.codeUnitAt(sigA) == 0x30) {
        sigA++;
      }
      var sigB = ib;
      while (sigB < endB && b.codeUnitAt(sigB) == 0x30) {
        sigB++;
      }

      final sigLenA = endA - sigA;
      final sigLenB = endB - sigB;
      if (sigLenA != sigLenB) {
        return sigLenA.compareTo(sigLenB);
      }
      for (var k = 0; k < sigLenA; k++) {
        final diff = a.codeUnitAt(sigA + k).compareTo(b.codeUnitAt(sigB + k));
        if (diff != 0) return diff;
      }
      // 数值完全相等（如 007 vs 7），推进到下一块
      ia = endA;
      ib = endB;
    } else {
      // 扫描双方完整非数字块 [ia, endA) 与 [ib, endB)
      var endA = ia + 1;
      var asciiOnly = ca < 0x80 && cb < 0x80;
      while (endA < lenA && !_isAsciiDigit(a.codeUnitAt(endA))) {
        if (a.codeUnitAt(endA) >= 0x80) asciiOnly = false;
        endA++;
      }
      var endB = ib + 1;
      while (endB < lenB && !_isAsciiDigit(b.codeUnitAt(endB))) {
        if (b.codeUnitAt(endB) >= 0x80) asciiOnly = false;
        endB++;
      }

      if (asciiOnly) {
        final lenSubA = endA - ia;
        final lenSubB = endB - ib;
        final minLen = lenSubA < lenSubB ? lenSubA : lenSubB;
        for (var k = 0; k < minLen; k++) {
          final diff =
              _toLowerAscii(a.codeUnitAt(ia + k)).compareTo(_toLowerAscii(b.codeUnitAt(ib + k)));
          if (diff != 0) return diff;
        }
        if (lenSubA != lenSubB) {
          return lenSubA.compareTo(lenSubB);
        }
      } else {
        final subA = a.substring(ia, endA).toLowerCase();
        final subB = b.substring(ib, endB).toLowerCase();
        final c = subA.compareTo(subB);
        if (c != 0) return c;
      }
      ia = endA;
      ib = endB;
    }
  }

  if (ia < lenA) return 1;
  if (ib < lenB) return -1;
  return 0; // 忽略大小写与前导零后完全相等
}
