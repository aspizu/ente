import "dart:ui";

import "package:ente_pure_utils/ente_pure_utils.dart";
import "package:ente_strings/ente_strings.dart";
import "package:flutter/material.dart";
import "package:hugeicons/hugeicons.dart";
import "package:intl/intl.dart";
import "package:logging/logging.dart";
import "package:photo_manager/photo_manager.dart";
import "package:photos/ente_theme_data.dart";
import "package:photos/models/file/file.dart";
import "package:photos/models/memory_lane/memory_lane_models.dart";
import "package:photos/models/ml/face/person.dart";
import "package:photos/service_locator.dart";
import "package:photos/services/memory_lane/memory_lane_service.dart";
import "package:photos/services/memory_share_service.dart";
import "package:photos/ui/viewer/file/file_widget.dart";
import "package:photos/ui/viewer/file/thumbnail_widget.dart";
import "package:photos/ui/viewer/gallery/jump_to_date_gallery.dart";
import "package:photos/ui/viewer/people/memory_lane_page.dart";
import "package:photos/utils/dialog_util.dart";
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
  final _logger = Logger("MemoryLanePageV2");
  late final Future<void> _memoryLaneLoaded;
  Future<_MemoryLaneEntry>? _currentEntryFuture;
  MemoryLanePersonTimeline? _timeline;
  final List<Future<_MemoryLaneEntry>> _entries = [];
  final List<EnteFile> _files = [];
  int i = 0;

  @override
  void initState() {
    super.initState();
    _memoryLaneLoaded = _loadMemoryLane();
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
      for (final entry in timeline.entries) {
        final file = files[entry.fileId];
        if (file != null) {
          _files.add(file);
          _entries.add(() async {
            AssetEntity? asset;
            try {
              asset = await file.getAsset;
            } catch (e, s) {
              _logger.warning("file.getAsset failed", e, s);
            }
            return _MemoryLaneEntry(file: file, asset: asset);
          }());
        }
      }
      if (_entries.isNotEmpty) {
        _currentEntryFuture = _entries.first;
      }
    } catch (error) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      await showGenericErrorDialog(context: navigator.context, error: error);
    }
  }

  void _selectEntry(int index) {
    setState(() {
      i = index;
      _currentEntryFuture = _entries[index];
    });
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
              ColoredBox(
                color: Colors.black,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 750),
                  switchInCurve: Curves.easeOutExpo,
                  switchOutCurve: Curves.easeInExpo,
                  child: ImageFiltered(
                    key: ValueKey(file?.tag),
                    imageFilter: ImageFilter.blur(
                      sigmaX: 100,
                      sigmaY: 100,
                      tileMode: TileMode.mirror,
                    ),
                    child: file != null
                        ? ThumbnailWidget(
                            file,
                            placeholderColor: Colors.black,
                            shouldShowSyncStatus: false,
                            shouldShowFavoriteIcon: false,
                            shouldShowVideoOverlayIcon: false,
                          )
                        : null,
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
                body: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 750),
                  switchInCurve: Curves.easeOutExpo,
                  switchOutCurve: Curves.easeInExpo,
                  child: switch (snapshot.connectionState) {
                    ConnectionState.done when file != null =>
                      FutureBuilder<_MemoryLaneEntry>(
                        key: ValueKey(file.tag),
                        future: _currentEntryFuture,
                        builder: (context, entrySnapshot) {
                          final entry = entrySnapshot.data;
                          if (entry == null) {
                            if (entrySnapshot.connectionState ==
                                ConnectionState.done) {
                              return Center(
                                child: Text(
                                  context.strings.facesTimelineUnavailable,
                                ),
                              );
                            }
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final asset = entry.asset;
                          var width = entry.file.width.toDouble();
                          var height = entry.file.height.toDouble();
                          if (asset != null &&
                              asset.width > 0 &&
                              asset.height > 0) {
                            width = asset.width.toDouble();
                            height = asset.height.toDouble();
                          }
                          return Padding(
                            padding: const EdgeInsetsGeometry.all(32),
                            child: Align(
                              child: AspectRatio(
                                aspectRatio: 3 / 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: width > 0 ? width : 3,
                                      child: AspectRatio(
                                        aspectRatio: width > 0 && height > 0
                                            ? width / height
                                            : 3 / 4,
                                        child: FileWidget(
                                          entry.file,
                                          tagPrefix: "memory_lane_v2",
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ConnectionState.done => Center(
                      key: const ValueKey("memory-lane-empty"),
                      child: Text(context.strings.facesTimelineUnavailable),
                    ),
                    _ => const Center(
                      key: ValueKey("memory-lane-loading"),
                      child: CircularProgressIndicator(),
                    ),
                  },
                ),
                // TODO: Remove these temporary navigation buttons once swiping is implemented.
                bottomNavigationBar: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: context.strings.previous,
                        icon: const Icon(Icons.chevron_left),
                        onPressed:
                            snapshot.connectionState == ConnectionState.done &&
                                _entries.isNotEmpty &&
                                i > 0
                            ? () => _selectEntry(i - 1)
                            : null,
                      ),
                      IconButton(
                        tooltip: context.strings.next,
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            snapshot.connectionState == ConnectionState.done &&
                                _entries.isNotEmpty &&
                                i < _entries.length - 1
                            ? () => _selectEntry(i + 1)
                            : null,
                      ),
                    ],
                  ),
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
    setState(() => _playbackTimer?.cancel());

    try {
      await dialog.show();
      final shareLinkData = await MemoryShareService.instance
          .getOrCreateMemoryLaneLink(
            entries: timeline.entries,
            title: title,
            personId: person.remoteID,
            personName: person.data.name,
            birthDate: person.data.birthDate,
          );
      await dialog.hide();
      if (!mounted) return;
      await shareText(
        formatMemoryShareText(title, shareLinkData.$1),
        context: context,
      );
    } catch (e) {
      await dialog.hide();
      if (!mounted) return;
      await showGenericErrorBottomSheet(context: context, error: e);
    }
  }

  Future<void> _onDateTap(EnteFile file) async {
    await routeToPage(context, JumpToDateGallery(fileToJumpTo: file));
  }
}

class _MemoryLaneEntry {
  final EnteFile file;
  final AssetEntity? asset;

  const _MemoryLaneEntry({required this.file, required this.asset});
}
