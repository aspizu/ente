import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedDigitComponent extends StatefulWidget {
  const AnimatedDigitComponent({
    required this.value,
    this.style,
    this.formatter,
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
    super.key,
  }) : assert(value >= 0);

  final int value;
  final TextStyle? style;
  final String Function(int)? formatter;
  final Duration duration;
  final Curve curve;

  @override
  State<AnimatedDigitComponent> createState() => _AnimatedDigitComponentState();
}

class _AnimatedDigitComponentState extends State<AnimatedDigitComponent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _previousValue;
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(AnimatedDigitComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.value != oldWidget.value) {
      _previousValue = oldWidget.value;
      _direction = widget.value > oldWidget.value ? 1 : -1;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.formatter?.call(widget.value) ?? '${widget.value}';
    final previous =
        widget.formatter?.call(_previousValue) ?? '$_previousValue';
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: current,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = disableAnimations
                ? 1.0
                : widget.curve.transform(_controller.value);
            final length = progress == 1
                ? current.length
                : math.max(current.length, previous.length);
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              textDirection: TextDirection.ltr,
              children: [
                for (var place = length - 1; place >= 0; place--)
                  Builder(
                    key: ValueKey(place),
                    builder: (context) {
                      final nextDigit = place < current.length
                          ? current[current.length - place - 1]
                          : null;
                      final oldDigit = place < previous.length
                          ? previous[previous.length - place - 1]
                          : null;
                      if (progress == 1 || oldDigit == nextDigit) {
                        return Text(nextDigit ?? '', style: widget.style);
                      }
                      return ClipRect(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (oldDigit != null)
                              FractionalTranslation(
                                translation: Offset(0, -_direction * progress),
                                child: Text(oldDigit, style: widget.style),
                              ),
                            if (nextDigit != null)
                              FractionalTranslation(
                                translation: Offset(
                                  0,
                                  _direction * (1 - progress),
                                ),
                                child: Text(nextDigit, style: widget.style),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
