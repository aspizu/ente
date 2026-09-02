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
  final String personName;
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
    final name = personName.trim();
    final title = name.isEmpty
        ? context.strings.facesTimelineAppBarTitle
        : context.strings.memoryLaneCardTitle(name: name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kMemoryCardStripGap / 2),
      child: SizedBox(
        width: size.width * 150 / 148,
        height: size.height,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: size.height / 215,
              width: size.width * 40 / 148,
              height: size.width * 40 / 148,
              child: ClipOval(
                child: Image.memory(
                  face,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
            Positioned(
              left: size.width * 2 / 148,
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
              left: size.width * 14 / 148,
              bottom: 16,
              width: size.width * 124 / 148,
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
        ),
      ),
    );
  }
}

class _MemoryLaneBackgroundClipper extends CustomClipper<Path> {
  const _MemoryLaneBackgroundClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 132 / 148, 0)
      ..cubicTo(
        size.width * 140.836555 / 148,
        0,
        size.width,
        size.height * 7.163445 / 215,
        size.width,
        size.height * 16 / 215,
      )
      ..lineTo(size.width, size.height * 199 / 215)
      ..cubicTo(
        size.width,
        size.height * 207.836555 / 215,
        size.width * 140.836555 / 148,
        size.height,
        size.width * 132 / 148,
        size.height,
      )
      ..lineTo(size.width * 16 / 148, size.height)
      ..cubicTo(
        size.width * 7.163445 / 148,
        size.height,
        0,
        size.height * 207.836555 / 215,
        0,
        size.height * 199 / 215,
      )
      ..lineTo(0, size.height * 42.161135 / 215)
      ..arcToPoint(
        Offset(size.width * 3.499597 / 148, size.height * 40.837802 / 215),
        radius: Radius.elliptical(size.width * 2 / 148, size.height * 2 / 215),
        clockwise: true,
      )
      ..cubicTo(
        size.width * 4.397702 / 148,
        size.height * 41.855532 / 215,
        size.width * 10.831069 / 148,
        size.height * 45 / 215,
        size.width * 18 / 148,
        size.height * 45 / 215,
      )
      ..cubicTo(
        size.width * 31.254834 / 148,
        size.height * 45 / 215,
        size.width * 42 / 148,
        size.height * 34.254834 / 215,
        size.width * 42 / 148,
        size.height * 21 / 215,
      )
      ..cubicTo(
        size.width * 42 / 148,
        size.height * 11.962976 / 215,
        size.width * 37.00452 / 148,
        size.height * 4.093826 / 215,
        size.width * 36.382774 / 148,
        size.height * 3.748909 / 215,
      )
      ..arcToPoint(
        Offset(size.width * 37.352989 / 148, 0),
        radius: Radius.elliptical(size.width * 2 / 148, size.height * 2 / 215),
        clockwise: true,
      )
      ..close();
  }

  @override
  bool shouldReclip(_MemoryLaneBackgroundClipper oldClipper) => false;
}
