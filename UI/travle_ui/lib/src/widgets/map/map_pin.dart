import 'package:flutter/material.dart';

/// A teardrop map marker with a true white outline. Pass [number] for an
/// itinerary-style numbered pin (a white badge sits in the head); leave it null
/// for a plain location pin.
///
/// The outline is the *same* pin glyph drawn twice at the same size — once
/// stroked in white, once filled on top — so the white hugs the pin's edge as a
/// border (not a second pin peeking out behind it). Keeping the pin legible on
/// satellite imagery (where forest-green blends into greenery) without any
/// blurred shadow — a blur would paint past the marker bounds and leave "ghost"
/// pins while panning.
///
/// Markers use `alignment: Alignment.topCenter` so the tip lands on the
/// coordinate.
class MapPin extends StatelessWidget {
  const MapPin({super.key, this.number, this.color});

  final int? number;
  final Color? color;

  static const double width = 44;
  static const double height = 46;
  static const double _glyphSize = 42;
  static const double _outlineWidth = 3.5;

  Widget _glyph({Paint? stroke, Color? fill}) {
    return Text(
      String.fromCharCode(Icons.location_on.codePoint),
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: Icons.location_on.fontFamily,
        package: Icons.location_on.fontPackage,
        fontSize: _glyphSize,
        height: 1,
        color: fill,
        foreground: stroke,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _glyph(
            stroke: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = _outlineWidth
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          ),
          _glyph(fill: pinColor),
          if (number != null)
            Positioned(
              top: 9,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: pinColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
