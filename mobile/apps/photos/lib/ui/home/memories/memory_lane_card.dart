import "dart:typed_data";

import "package:ente_components/ente_components.dart";
import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
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
    var title = personName?.trim() ?? "";
    title = title.isEmpty ? "Memory lane" : "$title’s memory lane";
    final radius = size.width * (14 / 148);
    final stroke = size.width * (5.5 / 148);
    final colors = context.componentColors;
    final border = Border.all(color: colors.backgroundBase, width: stroke);
    final badge = BoxDecoration(shape: BoxShape.circle, border: border);
    final image = Image.memory(face, fit: BoxFit.cover, gaplessPlayback: true);
    final tint = ColorFilter.mode(colors.textBase, BlendMode.srcIn);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kMemoryCardStripGap / 2),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                radius,
              ).copyWith(topRight: Radius.circular(size.width * (74 / 148))),
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
            Positioned(
              left: size.width * (94.5 / 148),
              top: size.height * (1.5 / 215),
              width: size.width * (55 / 148),
              height: size.width * (55 / 148),
              child: Container(
                decoration: badge,
                child: ClipOval(child: image),
              ),
            ),
            Positioned(
              left: size.width * (129.1 / 148),
              top: size.height * (-0.9 / 215),
              width: size.width * (19.8 / 148),
              height: size.width * (19.8 / 148),
              child: SvgPicture.asset(
                "assets/icons/memory_lane_card_sparkle.svg",
                colorFilter: tint,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
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
