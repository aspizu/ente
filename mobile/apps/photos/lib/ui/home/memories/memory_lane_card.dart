import "dart:typed_data";

import "package:ente_components/ente_components.dart";
import "package:ente_strings/ente_strings.dart";
import "package:flutter/material.dart";
import "package:photos/core/constants.dart";
import "package:photos/models/file/file.dart";
import "package:photos/ui/home/memories/memory_card_constants.dart";
import "package:photos/ui/viewer/file/thumbnail_widget.dart";

class MemoryLaneCardWidget extends StatelessWidget {
  final EnteFile oldestFile;
  final Uint8List face;
  final String? personName;
  final Size size;

  const MemoryLaneCardWidget({
    required this.oldestFile,
    required this.face,
    required this.personName,
    required this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final name = personName?.trim() ?? "";
    final title = name.isEmpty
        ? context.strings.facesTimelineAppBarTitle
        : context.strings.memoryLaneCardTitle(name: name);
    final scaleX = size.width / 148;
    final faceDiameter = 40 * scaleX;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kMemoryCardStripGap / 2),
      child: SizedBox(
        width: 150 * scaleX,
        height: size.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scaleY = constraints.maxHeight / 215;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: scaleY,
                  width: faceDiameter,
                  height: faceDiameter,
                  child: ClipOval(
                    child: Image.memory(
                      face,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                Positioned(
                  left: 2 * scaleX,
                  top: 0,
                  bottom: 0,
                  width: size.width,
                  child: ClipPath(
                    clipper: const _MemoryLaneBackgroundClipper(),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      foregroundDecoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB8000000)],
                          stops: [0.53663, 0.89955],
                        ),
                      ),
                      child: ThumbnailWidget(
                        oldestFile,
                        rawThumbnail: true,
                        shouldShowSyncStatus: false,
                        thumbnailSize: thumbnailLargeSize,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14 * scaleX,
                  bottom: 17 * scaleY,
                  width: 124 * scaleX,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.body.copyWith(
                      height: 16 / 14,
                      fontFamily: TextStyles.outfitFontFamily,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MemoryLaneBackgroundClipper extends CustomClipper<Path> {
  const _MemoryLaneBackgroundClipper();

  @override
  Path getClip(Size size) {
    final scaleX = size.width / 148;
    final scaleY = size.height / 215;
    double x(double value) => value * scaleX;
    double y(double value) => value * scaleY;
    final notchCornerRadius = Radius.elliptical(x(2), y(2));

    return Path()
      ..moveTo(x(132), 0)
      ..cubicTo(x(140.836555), 0, x(148), y(7.163445), x(148), y(16))
      ..lineTo(x(148), y(199))
      ..cubicTo(x(148), y(207.836555), x(140.836555), y(215), x(132), y(215))
      ..lineTo(x(16), y(215))
      ..cubicTo(x(7.163445), y(215), 0, y(207.836555), 0, y(199))
      ..lineTo(0, y(42.161135))
      ..arcToPoint(
        Offset(x(3.499597), y(40.837802)),
        radius: notchCornerRadius,
        clockwise: true,
      )
      ..cubicTo(x(4.397702), y(41.855532), x(10.831069), y(45), x(18), y(45))
      ..cubicTo(x(31.254834), y(45), x(42), y(34.254834), x(42), y(21))
      ..cubicTo(
        x(42),
        y(11.962976),
        x(37.00452),
        y(4.093826),
        x(36.382774),
        y(3.748909),
      )
      ..arcToPoint(
        Offset(x(37.352989), 0),
        radius: notchCornerRadius,
        clockwise: true,
      )
      ..close();
  }

  @override
  bool shouldReclip(_MemoryLaneBackgroundClipper oldClipper) => false;
}
