import "dart:typed_data";

import "package:flutter/material.dart";
import "package:photos/models/memory_lane/memory_lane_models.dart";

class MemoryLaneCardWidget extends StatefulWidget {
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
  State<MemoryLaneCardWidget> createState() => _MemoryLaneCardWidgetState();
}

class _MemoryLaneCardWidgetState extends State<MemoryLaneCardWidget> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
