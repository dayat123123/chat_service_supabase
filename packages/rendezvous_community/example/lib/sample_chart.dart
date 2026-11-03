import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<Uint8List> renderSampleChart(String stockCode, {int width = 640, int height = 360}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0E1A2B));

  final grid = Paint()
    ..color = const Color(0x22FFFFFF)
    ..strokeWidth = 1;
  for (var i = 1; i < 6; i++) {
    final y = size.height * i / 6;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
  }

  final random = math.Random(stockCode.hashCode);
  final points = <Offset>[];
  var price = 0.5;
  for (var i = 0; i <= 60; i++) {
    price = (price + (random.nextDouble() - 0.47) * 0.08).clamp(0.1, 0.9);
    points.add(Offset(size.width * i / 60, size.height * (1 - price)));
  }
  final area = Path()..moveTo(points.first.dx, size.height);
  for (final p in points) {
    area.lineTo(p.dx, p.dy);
  }
  area
    ..lineTo(points.last.dx, size.height)
    ..close();
  canvas.drawPath(area, Paint()..color = const Color(0x3322C55E));
  final line = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    line.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(
    line,
    Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );

  final label = TextPainter(
    text: TextSpan(
      text: '\$$stockCode · 1D',
      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, const Offset(20, 16));

  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
