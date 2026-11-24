/// 音频播放页设计 token：对应 Ardot「简约音频播放器 UI」设计稿。
/// 色板取自设计稿「选择颜色」（8 色），版式取自画板 390×844 的自动布局参数。
library;

import 'package:flutter/material.dart';

class AudioTone {
  const AudioTone._();

  /// F5F2EC 页面米白底
  static const bg = Color(0xFFF5F2EC);

  /// 21201D 墨色（主文字）
  static const ink = Color(0xFF21201D);

  /// 938A7E 暖灰（次要文字 / 图标）
  static const muted = Color(0xFF938A7E);

  /// B85C38 陶土（主色：进度、播放键、当前项）
  static const accent = Color(0xFFB85C38);

  /// FFFFFF 卡片白
  static const surface = Color(0xFFFFFFFF);

  /// EDE4D8 浅沙（chip / 次级底）
  static const sand = Color(0xFFEDE4D8);

  /// E6DED3 沙灰（进度条未播放段 / 分隔）
  static const sandDeep = Color(0xFFE6DED3);

  /// C2B8A9 暖褐（描边）
  static const taupe = Color(0xFFC2B8A9);

  /// F1EDE5 封面占位暖底（介于 bg 与 sand 之间）
  static const coverFill = Color(0xFFF1EDE5);

  /// 墨色轻阴影
  static const cardShadow = Color(0x0D21201D);
  static const barShadow = Color(0x1A21201D);

  // ---- 排版 ----
  static const title = TextStyle(
    fontSize: 29,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.6,
    color: ink,
  );
  static const meta = TextStyle(fontSize: 12.5, height: 1.3, color: muted);
  static const sectionLabel = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted);
  static const rowTitle = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: ink);
  static const rowMeta = TextStyle(fontSize: 11, color: muted);
  static const time = TextStyle(fontSize: 12.5, color: muted);
  static const topBarTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ink);

  /// 版式：内容区左右 24，元素纵向间距 18（取自设计稿自动布局）
  static const pageH = 24.0;
  static const gap = 18.0;
}

/// 封面/占位卡片的浅色网格底（设计稿里封面区是带细网格的浅灰格子）
class GridBackdrop extends CustomPainter {
  const GridBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0F21201D)
      ..strokeWidth = 1;
    const step = 18.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridBackdrop oldDelegate) => false;
}
