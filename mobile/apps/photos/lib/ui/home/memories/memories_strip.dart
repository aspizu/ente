import "dart:async";
import "dart:math";
import "dart:typed_data";

import "package:collection/collection.dart";
import 'package:flutter/material.dart';
import "package:flutter_animate/flutter_animate.dart";
import "package:photos/core/event_bus.dart";
import "package:photos/events/event.dart";
import "package:photos/events/memories_changed_event.dart";
import "package:photos/events/memories_setting_changed.dart";
import "package:photos/events/memory_seen_event.dart";
import "package:photos/events/ml_consent_changed_event.dart";
import "package:photos/models/file/file.dart";
import "package:photos/models/memories/smart_memory.dart";
import "package:photos/models/memory_lane/memory_lane_models.dart";
import "package:photos/service_locator.dart";
import "package:photos/services/memory_lane/memory_lane_cache_service.dart";
import "package:photos/services/memory_lane/memory_lane_service.dart";
import "package:photos/ui/home/memories/crafting_memories_card.dart";
import 'package:photos/ui/home/memories/memory_card.dart';
import "package:photos/ui/home/memories/memory_card_constants.dart";
import "package:photos/ui/home/memories/memory_cover_util.dart";
import "package:photos/ui/home/memories/memory_lane_card.dart";
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
  late StreamSubscription<MLConsentChangedEvent> _mlConsentChangedSubscription;
  late double _cardWidth;

  // Delay cover warming past startup; generations invalidate stale work.
  Timer? _warmTimer;
  int _warmGeneration = 0;
  int _fetchMemoriesGeneration = 0;
  String? _lastWarmSignature;
  MemoryLanePersonTimeline? _memoryLane;
  EnteFile? _oldestMemoryLaneFile;
  Uint8List? _newestMemoryLaneFace;
  String? _memoryLanePersonName;
  final _videoPrefetcher = MemoryVideoPrefetcher();
  final _scrollController = ScrollController();
  bool _shouldShowCraftingMemories = false;
  late Future<void> _shouldShowCraftingMemoriesLoaded;
  late Future<void> _memoryLaneLoaded;
  late List<SmartMemory> _initialMemories;
  late Future<List<SmartMemory>> _memories;

  @override
  void initState() {
    super.initState();
    _initialMemories = _getInitialMemories();
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
    _mlConsentChangedSubscription = Bus.instance
        .on<MLConsentChangedEvent>()
        .listen(_onMLConsentChanged);
    _memoryLaneLoaded = _loadScheduledMemoryLane();
    MemoryLaneService.instance.readyPersonIds.addListener(
      _onMemoryLaneReadyTimelinesChanged,
    );
  }

  @override
  void dispose() {
    _memoriesSettingSubscription.cancel();
    _memoriesChangedSubscription.cancel();
    _memorySeenSubscription.cancel();
    _mlConsentChangedSubscription.cancel();
    _warmTimer?.cancel();
    _videoPrefetcher.dispose();
    _scrollController.dispose();
    MemoryLaneService.instance.readyPersonIds.removeListener(
      _onMemoryLaneReadyTimelinesChanged,
    );
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
      initialData: _initialMemories,
      builder: (context, snapshot) {
        final memories = snapshot.data ?? [];
        return FutureBuilder(
          future: _shouldShowCraftingMemoriesLoaded,
          builder: (context, _) {
            final cardHeight = _cardWidth / kMemoryCardAspectRatio;
            return FutureBuilder(
              future: _memoryLaneLoaded,
              builder: (context, _) {
                final cards = _buildCards(memories, cardHeight);
                if (cards.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 10),
                  child: SizedBox(
                    height: cardHeight + 2,
                    child: ListView.builder(
                      controller: _scrollController,
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
                  ),
                );
              },
            );
          },
        ).animate().fadeIn(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCirc,
        );
      },
    );
  }

  List<SmartMemory> _sortMemories(List<SmartMemory> memories) {
    final indexedMemories = memories.indexed.sorted((a, b) {
      final aIsSeen = a.$2.memories.every((item) => item.isSeen());
      final bIsSeen = b.$2.memories.every((item) => item.isSeen());
      if (aIsSeen == bIsSeen) return a.$1.compareTo(b.$1);
      return aIsSeen ? 1 : -1;
    });

    return indexedMemories.map((entry) => entry.$2).toList();
  }

  List<SmartMemory> _getInitialMemories() {
    return _sortMemories(
      (memoriesCacheService.currentMemoriesSync ?? [])
          .where((memory) => memory.shouldShowNow())
          .toList(),
    );
  }

  List<MemoryCardWrapper> _buildCards(
    List<SmartMemory> memories,
    double cardHeight,
  ) {
    final memoryLane = _memoryLane;
    final oldestMemoryLaneFile = _oldestMemoryLaneFile;
    final newestMemoryLaneFace = _newestMemoryLaneFace;
    final hasContent = memories.isNotEmpty || memoryLane != null;
    return [
      if (_shouldShowCraftingMemories && hasContent)
        MemoryCardWrapper(
          id: "craftingMemories",
          widget: () => CraftingMemoriesCardWidget(
            width: cardHeight / 2,
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
      if (flagService.internalUser &&
          MemoryLaneService.instance.isFeatureEnabled &&
          memoryLane != null &&
          oldestMemoryLaneFile != null &&
          newestMemoryLaneFace != null)
        MemoryCardWrapper(
          id: "memoryLane_${memoryLane.personId}",
          widget: () => MemoryLaneCardWidget(
            oldestFile: oldestMemoryLaneFile,
            face: newestMemoryLaneFace,
            personName: _memoryLanePersonName ?? "",
            size: Size(_cardWidth, cardHeight),
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

  void _fetchMemories(Event? event) {
    final fetchGeneration = ++_fetchMemoriesGeneration;
    setState(() {
      if (event is MemoriesSettingChanged &&
          memoriesCacheService.showAnyMemories) {
        _initialMemories = _getInitialMemories();
      }
      _memories = memoriesCacheService
          .getMemories()
          .then(_sortMemories)
          .then((memories) {
            if (!mounted || fetchGeneration != _fetchMemoriesGeneration) {
              return memories;
            }
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
            if (memories.isEmpty || !memoriesCacheService.showAnyMemories) {
              _cancelPendingWarm();
              return <SmartMemory>[];
            } else {
              _scheduleWarmCovers(memories);
            }
            return memories;
          })
          .onError((_, _) {
            if (mounted && fetchGeneration == _fetchMemoriesGeneration) {
              _cancelPendingWarm();
            }
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

  Future<void> _loadScheduledMemoryLane() async {
    if (!flagService.internalUser ||
        !MemoryLaneService.instance.isFeatureEnabled) {
      return;
    }
    final timeline = await MemoryLaneService.instance
        .getScheduledMemoriesStripTimeline();
    if (timeline == null) {
      return;
    }
    final newestFaceCrop = await MemoryLaneService.instance.getNewestFaceCrop(
      timeline,
    );
    final oldestEntry = timeline.entries.first;
    final oldestFile = (await MemoryLaneService.instance.getTimelineFiles([
      oldestEntry.fileId,
    ]))[oldestEntry.fileId];
    final personName =
        (await MemoryLaneCacheService.instance.getComputeLogEntry(
          timeline.personId,
        ))?.name;
    if (newestFaceCrop == null || oldestFile == null || !hasGrantedMLConsent) {
      return;
    }
    _memoryLane = timeline;
    _oldestMemoryLaneFile = oldestFile;
    _newestMemoryLaneFace = newestFaceCrop;
    _memoryLanePersonName = personName;
  }

  void _onMLConsentChanged(MLConsentChangedEvent event) {
    if (event.enabled || !mounted || _memoryLane == null) {
      return;
    }
    setState(() {
      _memoryLane = null;
      _oldestMemoryLaneFile = null;
      _newestMemoryLaneFace = null;
      _memoryLanePersonName = null;
    });
  }

  void _onMemoryLaneReadyTimelinesChanged() {
    final memoryLane = _memoryLane;
    if (memoryLane == null ||
        MemoryLaneService.instance.readyPersonIds.value.contains(
          memoryLane.personId,
        )) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _memoryLane = null;
      _oldestMemoryLaneFile = null;
      _newestMemoryLaneFace = null;
      _memoryLanePersonName = null;
    });
  }
}
