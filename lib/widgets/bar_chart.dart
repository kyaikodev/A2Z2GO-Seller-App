import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Simple tappable bar chart. Handles negatives (e.g. a loss day) and empty data.
class BarChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;

  /// Longer names for the tap message and screen readers ("Nov 5"); the axis
  /// labels stay short.
  final List<String>? tooltips;
  final Color color;
  final double height;
  final String Function(double) format;

  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.tooltips,
    // Sales are not an alarm, so the default is the calm dark colour; red is
    // kept for losses and problems.
    this.color = Brand.navy,
    this.height = 170,
    this.format = pesoShort,
  });

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final hasData = widget.values.any((v) => v != 0);
    String nameOf(int i) => widget.tooltips?[i] ?? widget.labels[i];
    // What a screen reader says, since the bars are drawn on a canvas.
    final summary = hasData
        ? [
            for (var i = 0; i < widget.values.length; i++)
              if (widget.values[i] != 0)
                '${nameOf(i)} ${peso(widget.values[i])}',
          ].join(', ')
        : 'No data in this period yet';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
          child: Text(
            _selected != null && _selected! < widget.values.length
                ? '${nameOf(_selected!)}: ${peso(widget.values[_selected!])}'
                : hasData
                ? 'Tap a bar to see the exact amount'
                : 'No data in this period yet',
            style: const TextStyle(color: Brand.muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Bar chart. $summary',
          child: LayoutBuilder(
            builder: (context, c) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final n = widget.values.length;
                  if (n == 0) return;
                  final i = (d.localPosition.dx / (c.maxWidth / n))
                      .floor()
                      .clamp(0, n - 1);
                  setState(() => _selected = _selected == i ? null : i);
                },
                child: CustomPaint(
                  size: Size(c.maxWidth, widget.height),
                  painter: _Painter(
                    widget.values,
                    widget.labels,
                    widget.color,
                    _selected,
                    widget.format,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Painter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final int? selected;
  final String Function(double) format;

  _Painter(this.values, this.labels, this.color, this.selected, this.format);

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    const topPad = 14.0;
    final chartH = size.height - labelH - topPad;
    final n = values.length;
    if (n == 0) return;

    var maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    var minV = values.fold<double>(0, (m, v) => v < m ? v : m);
    if (maxV == 0 && minV == 0) maxV = 1;
    final range = maxV - minV;
    final zeroY = topPad + chartH * (maxV / range);

    final grid = Paint()
      ..color = Brand.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), grid);
    canvas.drawLine(const Offset(0, topPad), Offset(size.width, topPad), grid);

    final slot = size.width / n;
    final barW = (slot * 0.62).clamp(3.0, 34.0);
    final skip = n > 14 ? (n / 7).ceil() : 1;

    for (var i = 0; i < n; i++) {
      final v = values[i];
      final x = slot * i + (slot - barW) / 2;
      final h = (v.abs() / range) * chartH;
      final isSel = selected == i;
      final paint = Paint()
        ..color = (v < 0 ? Brand.bad : color).withValues(
          alpha: selected == null || isSel ? 1 : 0.35,
        );
      final rect = v >= 0
          ? Rect.fromLTWH(x, zeroY - h, barW, h < 2 && v != 0 ? 2 : h)
          : Rect.fromLTWH(x, zeroY, barW, h < 2 ? 2 : h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );

      if (i % skip == 0 || i == n - 1 && skip == 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              fontSize: 10.5,
              color: isSel ? Brand.navy : Brand.muted,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(slot * i + (slot - tp.width) / 2, size.height - labelH + 4),
        );
      }
    }

    // value label above the tallest bar (when nothing is selected)
    if (selected == null && maxV > 0) {
      final i = values.indexOf(maxV);
      final tp = TextPainter(
        text: TextSpan(
          text: format(maxV),
          style: const TextStyle(
            fontSize: 10.5,
            color: Brand.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final h = (maxV / range) * chartH;
      var dx = slot * i + (slot - tp.width) / 2;
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, (zeroY - h - 13).clamp(0.0, size.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) =>
      old.values != values || old.selected != selected || old.color != color;
}
