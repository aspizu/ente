import "package:ente_components/ente_components.dart";
import "package:ente_pure_utils/ente_pure_utils.dart";
import "package:flutter/material.dart";
import "package:photos/core/constants.dart";
import "package:photos/models/memories/smart_memory.dart";
import "package:photos/theme/colors.dart";
import "package:photos/ui/home/memories/all_memories_page.dart";
import "package:photos/ui/home/memories/memory_card_constants.dart";
import "package:photos/ui/home/memories/memory_cover_util.dart";
import "package:photos/ui/viewer/file/thumbnail_widget.dart";

class MemoryCardWidget extends StatefulWidget {
  final List<SmartMemory> memories;
  final double width;
  final double height;
  final int index;

  const MemoryCardWidget({
    required this.memories,
    required this.width,
    required this.height,
    required this.index,
    super.key,
  }) : assert(index >= 0);

  @override
  State<MemoryCardWidget> createState() => _MemoryCardWidgetState();
}

class _MemoryCardWidgetState extends State<MemoryCardWidget> {
  Future<void> _onTap() async {
    await routeToPage(
      context,
      forceCustomPageRoute: true,
      AllMemoriesPage(
        initialPageIndex: widget.index,
        allMemories: widget.memories,
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // The list can be empty after deleting every memory and returning here.
    if (widget.index >= widget.memories.length) {
      return const SizedBox.shrink();
    }
    final memory = widget.memories[widget.index];
    if (memory.memories.isEmpty) {
      return const SizedBox.shrink();
    }
    final itemIndex = getNextMemoryIndex(memory.memories);
    final item = memory.memories[itemIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kMemoryCardStripGap / 2.0,
      ),
      child: GestureDetector(
        onTap: _onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kMemoryCardBorderRadius),
          child: Container(
            height: widget.height,
            width: widget.width,
            foregroundDecoration: item.isSeen()
                ? const BoxDecoration(
                    color: Color(0xFFBFBFBF),
                    backgroundBlendMode: BlendMode.saturation,
                  )
                : null,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.bottomCenter,
              children: [
                Hero(
                  tag: "memories" + item.file.tag,
                  child: ThumbnailWidget(
                    item.file,
                    shouldShowSyncStatus: false,
                    thumbnailSize: thumbnailLargeSize,
                    key: Key("memories" + item.file.tag),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.53663, 0.89955],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: SizedBox(
                    width: widget.width,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Hero(
                        tag: memory.title,
                        child: Text(
                          memory.title,
                          maxLines: 3,
                          style: TextStyle(
                            fontSize: 14,
                            height: 16 / 14,
                            fontFamily: TextStyles.outfitFontFamily,
                            package: TextStyles.fontPackage,
                            color: item.isSeen() ? textFaintDark : Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
