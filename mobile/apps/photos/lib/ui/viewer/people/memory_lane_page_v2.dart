import "dart:async";
import "dart:typed_data";
import "dart:ui";

import "package:collection/collection.dart";
import "package:ente_pure_utils/ente_pure_utils.dart";
import "package:ente_strings/ente_strings.dart";
import "package:flutter/material.dart";
import "package:hugeicons/hugeicons.dart";
import "package:intl/intl.dart" show DateFormat;
import "package:logging/logging.dart";
import "package:photos/db/ml/db.dart";
import "package:photos/ente_theme_data.dart";
import "package:photos/models/file/file.dart";
import "package:photos/models/memory_lane/memory_lane_models.dart";
import "package:photos/models/ml/face/face.dart";
import "package:photos/models/ml/face/person.dart";
import "package:photos/service_locator.dart";
import "package:photos/services/memory_lane/memory_lane_service.dart";
import "package:photos/services/memory_share_service.dart";
import "package:photos/ui/viewer/gallery/jump_to_date_gallery.dart";
import "package:photos/ui/viewer/people/memory_lane_page.dart";
import "package:photos/utils/dialog_util.dart";
import "package:photos/utils/face/face_thumbnail_cache.dart";
import "package:photos/utils/share_util.dart";

Future<void> openMemoryLanePage(
  BuildContext context, {
  required String personId,
  required PersonEntity? person,
  bool isCluster = false,
}) async {
  if (!context.mounted || (!isCluster && person == null)) return;

  final Widget page;
  if (flagService.internalUser) {
    page = MemoryLanePageV2(
      personId: personId,
      isCluster: isCluster,
      person: person,
    );
  } else {
    page = MemoryLanePage(
      personId: personId,
      isCluster: isCluster,
      person: person,
    );
  }
  await routeToPage(context, page);
}

class MemoryLanePageV2 extends StatefulWidget {
  final String personId;
  final bool isCluster;
  final PersonEntity? person;

  const MemoryLanePageV2({
    required this.personId,
    required this.isCluster,
    required this.person,
    super.key,
  });

  @override
  State<MemoryLanePageV2> createState() => _MemoryLanePageV2State();
}

class _MemoryLanePageV2State extends State<MemoryLanePageV2> {
  static const _playbackInterval = Duration(seconds: 3);

  final _logger = Logger("MemoryLanePageV2");
  Timer? _playbackTimer;
  bool _wasPlayingBeforeSeek = false;
  late final Future<void> _memoryLaneLoaded;
  Future<Uint8List?>? _currentEntryFuture;
  Key _currentEntryKey = UniqueKey();
  MemoryLanePersonTimeline? _timeline;
  final List<Future<Uint8List?>> _entries = [];
  final List<EnteFile> _files = [];
  int i = 0;

  @override
  void initState() {
    super.initState();
    _memoryLaneLoaded = _loadMemoryLane();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMemoryLane() async {
    try {
      final timeline = await MemoryLaneService.instance.getTimeline(
        widget.personId,
        isCluster: widget.isCluster,
      );
      if (!mounted) return;
      _timeline = timeline;
      if (timeline == null ||
          !timeline.isEligible ||
          timeline.entries.isEmpty) {
        return;
      }
      final files = await MemoryLaneService.instance.getTimelineFiles(
        timeline.entries.map((entry) => entry.fileId).toSet(),
      );
      if (!mounted) return;
      Future<Uint8List?> previousEntry = Future.value();
      for (final entry in timeline.entries) {
        final file = files[entry.fileId];
        if (file != null) {
          _files.add(file);
          final entryFuture = previousEntry.then((_) async {
            if (!mounted) return null;
            return _loadEntry(entry, file);
          });
          _entries.add(entryFuture);
          previousEntry = entryFuture;
        }
      }
      if (_entries.isNotEmpty) {
        _currentEntryFuture = _entries.first;
        if (_entries.length > 1) _play(0);
      }
    } catch (error) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      await showGenericErrorDialog(context: navigator.context, error: error);
    }
  }

  void _play(int index) {
    if (_entries.isEmpty) return;
    setState(() {
      _playbackTimer?.cancel();
      _selectEntry(index);
      if (i == _entries.length - 1) return;
      _playbackTimer = Timer.periodic(_playbackInterval, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (i < _entries.length - 1) {
            _selectEntry(i + 1);
          }
          if (i == _entries.length - 1) {
            timer.cancel();
          }
        });
      });
    });
  }

  void _pause() {
    setState(() {
      _playbackTimer?.cancel();
    });
  }

  void _resume() {
    _play(i);
  }

  void _seekFromPosition(double x, double width) {
    if (width <= 0 || _entries.isEmpty) return;
    final index = (x / width * _entries.length).floor().clamp(
      0,
      _entries.length - 1,
    );
    setState(() {
      _playbackTimer?.cancel();
      _selectEntry(index);
    });
  }

  void _onPlayPauseTap() {
    if (_playbackTimer?.isActive ?? false) {
      _pause();
    } else if (i == _entries.length - 1) {
      _play(0);
    } else {
      _resume();
    }
  }

  void _onSeekEnd() {
    final wasPlaying = _wasPlayingBeforeSeek;
    _wasPlayingBeforeSeek = false;
    if (wasPlaying) _resume();
  }

  Future<Uint8List?> _loadEntry(MemoryLaneEntry entry, EnteFile file) async {
    try {
      final mlDataDB = isLocalGalleryMode
          ? MLDataDB.localGalleryInstance
          : MLDataDB.instance;
      final List<Face>? faces = await mlDataDB.getFacesForGivenFileID(
        entry.fileId,
      );
      final face = faces?.firstWhereOrNull(
        (face) => face.faceID == entry.faceId,
      );
      if (face == null) return null;
      final crops = await getCachedFaceCrops(
        file,
        [face],
        useFullFile: true,
        useTempCache: false,
      );
      final bytes = crops?[entry.faceId];
      if (bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
      return null;
    } catch (e, s) {
      _logger.severe("Failed to load memory lane entry", e, s);
      return null;
    }
  }

  void _selectEntry(int index) {
    if (i != index) _currentEntryKey = UniqueKey();
    i = index;
    _currentEntryFuture = _entries[index];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _memoryLaneLoaded,
      builder: (context, snapshot) {
        final name = widget.person?.data.name.trim();
        var title = context.strings.facesTimelineAppBarTitle;
        if (name != null && name.isNotEmpty) {
          title = context.strings.memoryLaneCardTitle(name: name);
        }
        final file = _files.isEmpty ? null : _files[i];
        final creationTime = file?.creationTime;
        return Theme(
          data: darkThemeData,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 750),
                    switchInCurve: Curves.easeOutExpo,
                    switchOutCurve: Curves.easeInExpo,
                    child: FutureBuilder<Uint8List?>(
                      key: _currentEntryKey,
                      future: _currentEntryFuture,
                      builder: (context, entrySnapshot) {
                        final crop = entrySnapshot.data;
                        if (crop == null) return const SizedBox.expand();
                        return ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 100,
                            sigmaY: 100,
                          ),
                          child: Image.memory(
                            crop,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'memory-lane-title-${widget.personId}',
                        child: Text(title),
                      ),
                      if (file != null && creationTime != null)
                        GestureDetector(
                          onTap: () => _onDateTap(file),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat.yMMMd(
                                  Localizations.localeOf(context).languageCode,
                                ).format(
                                  DateTime.fromMicrosecondsSinceEpoch(
                                    creationTime,
                                  ),
                                ),
                                style: darkThemeData.textTheme.bodySmall
                                    ?.copyWith(color: Colors.white),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  leadingWidth: 48 + 16,
                  actionsPadding: const EdgeInsets.only(right: 16),
                  // TODO: Replace with an Ente component when it supports this pressed overlay.
                  leading: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox.square(
                      dimension: 48,
                      child: IconButton(
                        tooltip: context.strings.close,
                        padding: const EdgeInsets.all(8),
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(48),
                          maximumSize: const Size.square(48),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          overlayColor: Colors.white.withValues(alpha: 0.08),
                        ),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  actions: [
                    if (widget.person != null)
                      // TODO: Replace with an Ente component when it supports this pressed overlay.
                      SizedBox.square(
                        dimension: 48,
                        child: IconButton(
                          tooltip: context.strings.shareLink,
                          padding: const EdgeInsets.all(8),
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(48),
                            maximumSize: const Size.square(48),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            overlayColor: Colors.white.withValues(alpha: 0.08),
                          ),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedShare08,
                            size: 24,
                          ),
                          onPressed: _onShareTap,
                        ),
                      ),
                  ],
                ),
                body: Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsetsGeometry.all(32),
                        child: Align(
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 1000),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 1,
                                          end: 1.1,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                    builder: (context, child) {
                                      final blur = 12 * (1 - animation.value);
                                      return ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: blur,
                                          sigmaY: blur,
                                        ),
                                        child: child,
                                      );
                                    },
                                  );
                                },
                                child: switch (snapshot.connectionState) {
                                  ConnectionState.done when file != null =>
                                    FutureBuilder<Uint8List?>(
                                      key: _currentEntryKey,
                                      future: _currentEntryFuture,
                                      builder: (context, entrySnapshot) {
                                        final crop = entrySnapshot.data;
                                        if (crop == null) {
                                          if (entrySnapshot.connectionState ==
                                              ConnectionState.done) {
                                            return Center(
                                              child: Text(
                                                context
                                                    .strings
                                                    .facesTimelineUnavailable,
                                              ),
                                            );
                                          }
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        return Image.memory(
                                          crop,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        );
                                      },
                                    ),
                                  ConnectionState.done => Center(
                                    key: const ValueKey("memory-lane-empty"),
                                    child: Text(
                                      context.strings.facesTimelineUnavailable,
                                    ),
                                  ),
                                  _ => const Center(
                                    key: ValueKey("memory-lane-loading"),
                                    child: CircularProgressIndicator(),
                                  ),
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Row(
                          mainAxisAlignment: .center,
                          children: [
                            IconButtonComponent(
                              variant: IconButtonComponentVariant
                                  .circularTranslucent,
                              tooltip: (_playbackTimer?.isActive ?? false)
                                  ? context.strings.facesTimelinePlaybackPause
                                  : context.strings.facesTimelinePlaybackPlay,
                              onTap: _onPlayPauseTap,
                              icon: HugeIcon(
                                icon: (_playbackTimer?.isActive ?? false)
                                    ? HugeIcons.strokeRoundedPause
                                    : HugeIcons.strokeRoundedPlay,
                              ),
                              size: 48,
                            ),
                            if (_entries.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onHorizontalDragDown: (_) {
                                        _wasPlayingBeforeSeek =
                                            _playbackTimer?.isActive ?? false;
                                      },
                                      onTapDown: (details) => _seekFromPosition(
                                        details.localPosition.dx,
                                        constraints.maxWidth,
                                      ),
                                      onTapUp: (_) => _onSeekEnd(),
                                      onHorizontalDragStart: (details) =>
                                          _seekFromPosition(
                                            details.localPosition.dx,
                                            constraints.maxWidth,
                                          ),
                                      onHorizontalDragUpdate: (details) =>
                                          _seekFromPosition(
                                            details.localPosition.dx,
                                            constraints.maxWidth,
                                          ),
                                      onHorizontalDragEnd: (_) =>
                                          _onSeekEnd(),
                                      child: Row(
                                        children: List.generate(
                                          _entries.length,
                                          (index) {
                                            final distance = (index - i).abs();
                                            final double size =
                                                switch (distance) {
                                                  0 => 15,
                                                  1 => 10,
                                                  2 => 7.5,
                                                  _ => 5,
                                                };
                                            return Expanded(
                                              child: SizedBox(
                                                height: 40,
                                                child: Center(
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    width: size,
                                                    height: size,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: distance == 0
                                                                ? 1
                                                                : 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onShareTap() async {
    final timeline = _timeline;
    final person = widget.person;
    if (timeline == null ||
        person == null ||
        !timeline.isEligible ||
        timeline.entries.isEmpty) {
      return;
    }
    final l10n = context.strings;
    final name = person.data.name.trim();
    var title = l10n.facesTimelineAppBarTitle;
    if (name.isNotEmpty) {
      title = l10n.memoryLaneCardTitle(name: name);
    }
    final dialog = createProgressDialog(context, l10n.creatingLink);
    final wasPlaying = _playbackTimer?.isActive ?? false;
    _pause();

    try {
      final shareLinkData = await MemoryShareService.instance
          .getOrCreateMemoryLaneLink(
            entries: timeline.entries,
            title: title,
            personId: person.remoteID,
            personName: person.data.name,
            birthDate: person.data.birthDate,
          );
      if (!mounted) return;
      await shareText(
        formatMemoryShareText(title, shareLinkData.$1),
        context: context,
      );
    } catch (e) {
      await dialog.hide();
      if (!mounted) return;
      await showGenericErrorBottomSheet(context: context, error: e);
    } finally {
      if (mounted && wasPlaying && ModalRoute.of(context)?.isCurrent == true) {
        _resume();
      }
    }
  }

  Future<void> _onDateTap(EnteFile file) async {
    final wasPlaying = _playbackTimer?.isActive ?? false;
    _pause();
    try {
      await routeToPage(context, JumpToDateGallery(fileToJumpTo: file));
    } finally {
      if (mounted && wasPlaying && ModalRoute.of(context)?.isCurrent == true) {
        _resume();
      }
    }
  }
}
