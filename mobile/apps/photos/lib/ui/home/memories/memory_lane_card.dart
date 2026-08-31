import "dart:convert";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:photos/models/memory_lane/memory_lane_models.dart";
import "package:photos/ui/home/memories/memory_card_constants.dart";

class MemoryLaneCardWidget extends StatelessWidget {
  final MemoryLanePersonTimeline timeline;
  final Uint8List oldestFace;
  final Uint8List newestFace;

  const MemoryLaneCardWidget(
    this.timeline,
    this.oldestFace,
    this.newestFace, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final timelineDump = const JsonEncoder.withIndent(
      "  ",
    ).convert(timeline.toJson());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kMemoryCardStripGap / 2),
      child: Container(
        width: 320,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(kMemoryCardBorderRadius),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 96,
              child: Row(
                children: [
                  Expanded(child: _FaceDebugView("oldest", oldestFace)),
                  Expanded(child: _FaceDebugView("newest", newestFace)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: Text(
                  timelineDump,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: "monospace",
                    fontSize: 8,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceDebugView extends StatelessWidget {
  final String label;
  final Uint8List bytes;

  const _FaceDebugView(this.label, this.bytes);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: MemoryImage(bytes),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: ColoredBox(
            color: Colors.black54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
