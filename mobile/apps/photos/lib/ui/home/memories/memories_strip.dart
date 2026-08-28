import "dart:async";
import "dart:math";

import "package:collection/collection.dart";
import 'package:flutter/material.dart';
import "package:flutter_animate/flutter_animate.dart";
import "package:photos/core/event_bus.dart";
import "package:photos/events/event.dart";
import "package:photos/events/memories_changed_event.dart";
import "package:photos/events/memories_setting_changed.dart";
import "package:photos/events/memory_seen_event.dart";
import "package:photos/models/memories/smart_memory.dart";
import "package:photos/service_locator.dart";
import "package:photos/ui/home/memories/crafting_memories_card.dart";
import 'package:photos/ui/home/memories/memory_card.dart';
import "package:photos/ui/home/memories/memory_card_constants.dart";
import "package:photos/ui/home/memories/memory_cover_util.dart";
import "package:photos/ui/home/memories/memory_video_prefetcher.dart";

class MemoryCardWrapper {
  final String id;
  final Widget Function() widget;

  const MemoryCardWrapper({required this.id, required this.widget});
}

class MemoriesStripWidget extends StatefulWidget {
  const MemoriesStripWidget({super.key});

  @override
  State<MemoriesStripWidget> createState() => _MemoriesStripWidgetState();
}

class _MemoriesStripWidgetState extends State<MemoriesStripWidget> {
  late StreamSubscription<MemoriesSettingChanged> _memoriesSettingSubscription;
  late StreamSubscription<MemoriesChangedEvent> _memoriesChangedSubscription;
  late StreamSubscription<MemorySeenEvent> _memorySeenSubscription;
  late double _cardWidth;

  // Delay cover warming past startup; generations invalidate stale work.
  Timer? _warmTimer;
  int _warmGeneration = 0;
  String? _lastWarmSignature;
  final _videoPrefetcher = MemoryVideoPrefetcher();
  bool _shouldShowCraftingMemories = false;
  late Future<void> _shouldShowCraftingMemoriesLoaded;
  late Future<List<SmartMemory>> _memories;

  @override
  void initState() {
    super.initState();
    _shouldShowCraftingMemoriesLoaded = CraftingMemoriesCardWidget.shouldShow()
        .then((value) {
          _shouldShowCraftingMemories = value;
        });

    _fetchMemories(null);

    _memoriesSettingSubscription = Bus.instance
        .on<MemoriesSettingChanged>()
        .listen(_fetchMemories);
    _memoriesChangedSubscription = Bus.instance
        .on<MemoriesChangedEvent>()
        .listen(_fetchMemories);
    _memorySeenSubscription = Bus.instance.on<MemorySeenEvent>().listen(
      _fetchMemories,
    );
  }

  @override
  void dispose() {
    _memoriesSettingSubscription.cancel();
    _memoriesChangedSubscription.cancel();
    _memorySeenSubscription.cancel();
    _warmTimer?.cancel();
    _videoPrefetcher.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    const defaultWidth = 145.011;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    if (screenWidth < screenHeight) {
      _cardWidth = min(
        screenWidth * (defaultWidth / 376.0),
        defaultWidth * 1.5,
      );
    } else {
      _cardWidth = min(screenHeight * .3, defaultWidth * 1.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!memoriesCacheService.showAnyMemories) {
      _cancelPendingWarm();
      return const SizedBox.shrink();
    }
    return FutureBuilder(
      future: _memories,
      builder: (context, snapshot) {
        final indexedMemories = (snapshot.data ?? []).indexed.sorted((a, b) {
          final aIsSeen = a.$2.memories.every((item) => item.isSeen());
          final bIsSeen = b.$2.memories.every((item) => item.isSeen());
          if (aIsSeen == bIsSeen) return a.$1.compareTo(b.$1);
          return aIsSeen ? 1 : -1;
        });
        if (indexedMemories.isEmpty) {
          return const SizedBox.shrink();
        }
        final memories = indexedMemories.map((entry) => entry.$2).toList();
        return Column(
          key: ValueKey(identityHashCode(_memories)),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            FutureBuilder(
              future: _shouldShowCraftingMemoriesLoaded,
              builder: (context, _) {
                final cardHeight = _cardWidth / kMemoryCardAspectRatio;
                final cards = _buildCards(memories, cardHeight);
                return SizedBox(
                  height: cardHeight + 2,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kMemoryCardStripGap / 2.0,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: cards.length,
                    itemBuilder: (context, i) => KeyedSubtree(
                      key: ValueKey(cards[i].id),
                      child: cards[i].widget(),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
          ],
        ).animate().fadeIn(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCirc,
        );
      },
    );
  }

  List<MemoryCardWrapper> _buildCards(
    List<SmartMemory> memories,
    double cardHeight,
  ) {
    return [
      if (_shouldShowCraftingMemories)
        MemoryCardWrapper(
          id: "craftingMemories",
          widget: () => CraftingMemoriesCardWidget(
            width: _cardWidth / 2,
            height: cardHeight,
            onShouldShowChanged: (shouldShow) {
              if (!mounted || shouldShow == _shouldShowCraftingMemories) {
                return;
              }
              setState(() {
                _shouldShowCraftingMemories = shouldShow;
              });
            },
          ),
        ),
      ...memories.indexed.map(
        (entry) => MemoryCardWrapper(
          id: entry.$2.id,
          widget: () => MemoryCardWidget(
            memories: memories,
            width: _cardWidth,
            height: cardHeight,
            index: entry.$1,
          ),
        ),
      ),
    ];
  }

  void _fetchMemories(Event? _) {
    setState(() {
      _memories = memoriesCacheService
          .getMemories()
          .then((memories) {
            if (memories.isEmpty) {
              _cancelPendingWarm();
            } else {
              _scheduleWarmCovers(memories);
            }
            return memories;
          })
          .onError((_, _) {
            _cancelPendingWarm();
            return [];
          });
    });
  }

  void _scheduleWarmCovers(List<SmartMemory> memories) {
    final warmSignature = _warmSignature(memories);
    if (warmSignature == _lastWarmSignature) return;
    _lastWarmSignature = warmSignature;
    _warmGeneration++;
    final gen = _warmGeneration;
    _warmTimer?.cancel();
    _warmTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || gen != _warmGeneration) return;
      final itemLists = memories.map((e) => e.memories).toList(growable: false);
      _videoPrefetcher.prefetchFiles(
        itemLists
            .take(kMemoryCoverWarmCap)
            .where((items) => items.isNotEmpty)
            .map((items) => items[getNextMemoryIndex(items)].file),
        stillActive: () => mounted && gen == _warmGeneration,
        replacePending: true,
      );
      unawaited(
        warmMemoryCovers(
          itemLists,
          stillActive: () => mounted && gen == _warmGeneration,
        ),
      );
    });
  }

  String _warmSignature(List<SmartMemory> memories) {
    return memories
        .map((e) => e.memories)
        .take(kMemoryCoverWarmCap)
        .where((items) => items.isNotEmpty)
        .map((items) {
          final file = items[getNextMemoryIndex(items)].file;
          return '${file.uploadedFileID ?? ""}|'
              '${file.generatedID ?? ""}|'
              '${file.localID ?? ""}|'
              '${file.fileType.name}';
        })
        .join(',');
  }

  // Invalidate in-flight work and allow the same dataset to be scheduled again.
  void _cancelPendingWarm() {
    _warmTimer?.cancel();
    _warmTimer = null;
    _warmGeneration++;
    _lastWarmSignature = null;
    _videoPrefetcher.clearPending();
  }
}
