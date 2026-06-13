// lib/screens/album_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import '../settings_manager.dart';
import '../widgets/centered_constrained.dart';
import '../widgets/premium_upgrade_sheet.dart';
import '../services/album_sync.dart';
import '../widgets/app_dialog.dart';

Future<bool> _ensureAlbumCameraPermission(BuildContext context) async {
  var status = await Permission.camera.status;
  if (status.isGranted) return true;
  status = await Permission.camera.request();
  if (status.isGranted) return true;

  if (status.isPermanentlyDenied) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.cameraPermissionRequired),
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        action: SnackBarAction(
          label: l10n.openSettings,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }
  return false;
}

typedef AlbumScreenState = _AlbumScreenState;

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final Map<String, List<File>> _byDate = {}; // dateKey -> files(新→旧)
  bool _loading = true;

  final ImagePicker _imagePicker = ImagePicker();
  bool _captureInProgress = false;

  // 選択モード管理
  final Set<String> _selectedPaths = {};
  bool get _inSelection => _selectedPaths.isNotEmpty;

  // 統一マージン（Graph/Calendarに合わせる）
  static const double _kOuterPad = 16.0; // 画面の外側
  static const double _kGap = 12.0; // 広告下の余白 等

  @override
  void initState() {
    super.initState();
    _loadAll(); // アルバムを読み込んで _loading を false にする
    AlbumSync.instance.addListener(_handleAlbumSync);
  }

  void _handleAlbumSync() {
    if (!mounted) return;
    _loadAll(force: true);
  }

  Future<void> _loadAll({bool force = false}) async {
    if (!mounted) return;
    if (force) {
      setState(() => _loading = true);
    } else {
      setState(() => _loading = true);
    }

    final base = await getApplicationDocumentsDirectory();
    final mediaRoot = Directory(p.join(base.path, 'media'));
    final map = <String, List<File>>{};

    if (await mediaRoot.exists()) {
      for (final ent in mediaRoot.listSync()) {
        if (ent is! Directory) continue;
        final dateKey = p.basename(ent.path);
        final files = ent.listSync().whereType<File>().where((f) {
          final name = f.path.toLowerCase();
          return name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png') ||
              name.endsWith('.heic');
        }).toList();
        /* AWARD画像はファイル名 'award-' プレフィクスで識別する想定（フィルタUIで使用） */

        files.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        ); // 新→旧

        if (files.isNotEmpty) {
          map[dateKey] = files;
        }
      }
    }

    // 日付キーを降順（新しい→古い）
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    final sorted = <String, List<File>>{};
    for (final k in sortedKeys) {
      sorted[k] = map[k]!;
    }

    if (!mounted) return;
    setState(() {
      _byDate
        ..clear()
        ..addAll(sorted);
      _loading = false;
    });
  }

  @override
  void dispose() {
    AlbumSync.instance.removeListener(_handleAlbumSync);
    super.dispose();
  }

  void _openViewer(List<_AlbumPhoto> photos, int initialIndex) {
    if (photos.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (ctx) => _AlbumViewerDialog(
        photos: photos,
        initialIndex: initialIndex.clamp(0, photos.length - 1),
      ),
    );
  }

  List<MapEntry<String, List<File>>> _filteredEntries() {
    final entries = _byDate.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final result = <MapEntry<String, List<File>>>[];
    for (final entry in entries) {
      final files =
          entry.value.where((file) => !_isAwardFile(file.path)).toList();
      if (files.isEmpty) continue;
      result.add(MapEntry(entry.key, files));
    }
    return result;
  }

  List<_AlbumPhoto> _flattenPhotos([
    List<MapEntry<String, List<File>>>? entries,
  ]) {
    final source = entries ?? _filteredEntries();
    final result = <_AlbumPhoto>[];
    for (final entry in source) {
      final dateKey = entry.key;
      for (final file in entry.value) {
        result.add(_AlbumPhoto(file: file, dateKey: dateKey));
      }
    }
    return result;
  }

  bool _isAwardFile(String path) => path.toLowerCase().contains('/award-');

  void _confirmDelete(File file, String dateKey, int index) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.mediaDelete,
        icon: Icons.delete_outline_rounded,
        actions: [
          AppDialogAction(
            label: l10n.mediaCancel,
            isCancel: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppDialogAction(
            label: l10n.delete,
            isDestructive: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ).then((ok) async {
      if (ok != true) return;
      try {
        await file.delete();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _byDate[dateKey]!.removeAt(index);
        if (_byDate[dateKey]!.isEmpty) {
          _byDate.remove(dateKey);
        }
      });
    });
  }

  void _toggleSelect(File f) {
    final filePath = f.path;
    setState(() {
      if (_selectedPaths.contains(filePath)) {
        _selectedPaths.remove(filePath);
      } else {
        _selectedPaths.add(filePath);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedPaths.clear());
  }

  Future<void> _shareSelected() async {
    if (_selectedPaths.isEmpty) return;
    try {
      final files = _selectedPaths.map((e) => XFile(e)).toList();
      await Share.shareXFiles(files);
    } catch (_) {}
  }

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedPaths.length;
    final ok = await showConfirmDialog(
      context,
      title: l10n.deleteSelectedConfirmTitle(count),
      cancelLabel: l10n.mediaCancel,
      confirmLabel: l10n.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok != true) return;

    final targets = Set<String>.from(_selectedPaths);
    for (final entry in _byDate.entries.toList()) {
      final list = entry.value;
      list.removeWhere((f) {
        if (targets.contains(f.path)) {
          try {
            f.deleteSync();
          } catch (_) {}
          return true;
        }
        return false;
      });
      if (list.isEmpty) {
        _byDate.remove(entry.key);
      }
    }
    setState(() {
      _selectedPaths.clear();
    });
  }

  Future<List<XFile>> _captureNewShots() async {
    XFile? shot;
    try {
      shot = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (_) {}

    if (shot != null) {
      return [shot];
    }

    if (!Platform.isAndroid) {
      return <XFile>[];
    }

    try {
      final LostDataResponse resp = await _imagePicker.retrieveLostData();
      if (resp.isEmpty) return <XFile>[];
      final List<XFile> recovered = [];
      if (resp.file != null) {
        recovered.add(resp.file!);
      }
      if (resp.files != null && resp.files!.isNotEmpty) {
        recovered.addAll(resp.files!);
      }
      return recovered;
    } catch (_) {
      return <XFile>[];
    }
  }

  Future<void> _saveShotToToday(XFile shot) async {
    final now = DateTime.now();
    final dir = Directory(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'media',
        DateFormat('yyyy-MM-dd').format(now),
      ),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final ext = p.extension(shot.path).toLowerCase();
    final fileName =
        '${DateFormat('HHmmss_SSS').format(DateTime.now())}${ext.isNotEmpty ? ext : '.jpg'}';
    final savePath = p.join(dir.path, fileName);
    await shot.saveTo(savePath);
    AlbumSync.instance.notifyPhotoAdded(savePath);
  }

  Future<void> _handleAddPressed() async {
    if (_captureInProgress) return;
    if (!SettingsManager.isPremium) {
      final l10n = AppLocalizations.of(context)!;
      await showPremiumUpgradeSheet(
        context,
        headline: premiumPhotoHeadline(l10n),
        message: premiumPhotoMessage(l10n),
      );
      return;
    }
    if (!await _ensureAlbumCameraPermission(context)) return;
    if (!mounted) return;

    setState(() => _captureInProgress = true);
    try {
      final shots = await _captureNewShots();
      if (shots.isEmpty) return;

      for (final shot in shots) {
        await _saveShotToToday(shot);
      }
      if (mounted) {
        await _loadAll(force: true);
      }
    } finally {
      if (mounted) {
        setState(() => _captureInProgress = false);
      }
    }
  }

  Future<void> handleAddAction() => _handleAddPressed();

  // 空表示（BackdropFilterは使わない）
  Widget _centerEmptyMessage(BuildContext context, AppLocalizations l10n) {
    final h = MediaQuery.of(context).size.height;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: h / 4, // 少し小さめに縮小
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24), // 角丸
                  child: Image.asset(
                    'assets/album/hint2.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.albumEmptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ピル型アクションボタン（選択時の下部操作用）
  static const Color _kBrandBlueDark = Color(0xFF1D4ED8); // 濃い青
  static const Color _kDangerRedDark = Color(0xFFB91C1C); // 濃い赤
  Widget _pillActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    final radius = BorderRadius.circular(22);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.white.withOpacity(0.06),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: SettingsManager.backgroundAssetNotifier.value.isEmpty
          ? null
          : Colors.transparent, // 壁紙を透過表示

      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // 背景を少し暗く（レイアウトに影響しない）
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.black.withOpacity(0.70)),
              ),
            ),

            // 本文（Graph/Calendarと同じ余白感）
            CenteredConstrained(
              maxWidth: 760,
              padding: const EdgeInsets.all(_kOuterPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_inSelection)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.selectedCount(_selectedPaths.length),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearSelection,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: Text(l10n.clear),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : () {
                            final filteredEntries = _filteredEntries();
                            if (filteredEntries.isEmpty) {
                              return _centerEmptyMessage(context, l10n);
                            }
                            final flattenedPhotos =
                                _flattenPhotos(filteredEntries);
                            final offsetMap = <String, int>{};
                            var running = 0;
                            for (final entry in filteredEntries) {
                              offsetMap[entry.key] = running;
                              running += entry.value.length;
                            }
                            return ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 8, 12, 12 + 72),
                              itemCount: filteredEntries.length,
                              itemBuilder: (ctx, index) {
                                final entry = filteredEntries[index];
                                final dateKey = entry.key; // "yyyy-MM-dd"
                                final files = entry.value;

                                final dt =
                                    DateTime.tryParse('$dateKey 00:00:00');
                                final label = dt != null
                                    ? DateFormat('yyyy/MM/dd').format(dt)
                                    : dateKey;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 見出し（日付）
                                    Container(
                                      alignment: Alignment.centerLeft,
                                      padding:
                                          const EdgeInsets.fromLTRB(2, 8, 2, 6),
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    // サムネイルグリッド
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: 6,
                                        crossAxisSpacing: 6,
                                      ),
                                      itemCount: files.length,
                                      itemBuilder: (ctx2, i) {
                                        final file = files[i];
                                        final selected =
                                            _selectedPaths.contains(file.path);
                                        final isAward = _isAwardFile(file.path);
                                        final ribbonTop =
                                            _inSelection ? 34.0 : 6.0;
                                        return GestureDetector(
                                          onTap: () {
                                            if (_inSelection) {
                                              _toggleSelect(file);
                                            } else {
                                              final globalIndex =
                                                  (offsetMap[dateKey] ?? 0) + i;
                                              _openViewer(
                                                flattenedPhotos,
                                                globalIndex,
                                              );
                                            }
                                          },
                                          onLongPress: () {
                                            if (_inSelection) {
                                              _toggleSelect(file);
                                            } else {
                                              setState(() {
                                                _selectedPaths.add(file.path);
                                              });
                                            }
                                          },
                                          child: Stack(
                                            children: [
                                              // サムネイル
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.file(
                                                  file,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
                                              ),
                                              // 選択中オーバーレイ
                                              if (selected)
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.black26,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      border: Border.all(
                                                        color: Colors.white70,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (isAward)
                                                Positioned(
                                                  right: 6,
                                                  top: ribbonTop,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(6, 2, 6, 2),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.amber.shade700,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      l10n.albumAwardRibbon,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              // チェックマーク
                                              if (_inSelection)
                                                Positioned(
                                                  right: 8,
                                                  top: 8,
                                                  child: Container(
                                                    width: 22,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: selected
                                                          ? Colors
                                                              .lightGreenAccent
                                                          : Colors.white24,
                                                      border: Border.all(
                                                        color: Colors.white70,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      selected
                                                          ? Icons.check
                                                          : Icons
                                                              .circle_outlined,
                                                      size: 16,
                                                      color: selected
                                                          ? Colors.black87
                                                          : Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                );
                              },
                            );
                          }(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _inSelection
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                color: Colors.black.withOpacity(0.80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pillActionButton(
                      icon: Icons.ios_share,
                      label: l10n.share,
                      onTap: _shareSelected,
                      color: _kBrandBlueDark,
                    ),
                    const SizedBox(width: 12),
                    _pillActionButton(
                      icon: Icons.delete_outline,
                      label: l10n.delete,
                      onTap: _deleteSelected,
                      color: _kDangerRedDark,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _AlbumViewerDialog extends StatefulWidget {
  final List<_AlbumPhoto> photos;
  final int initialIndex;

  const _AlbumViewerDialog({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_AlbumViewerDialog> createState() => _AlbumViewerDialogState();
}

class _AlbumViewerDialogState extends State<_AlbumViewerDialog> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: PageView.builder(
                controller: _controller,
                itemCount: photos.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (_, index) {
                  final photo = photos[index];
                  return InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.file(
                      photo.file,
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
            ),
          ),
          // Date Label
          Positioned(
            left: 16,
            top: 16 + MediaQuery.of(context).padding.top,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _formatDateLabel(photos[_currentIndex].dateKey),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Close Button
          Positioned(
            top: 16 + MediaQuery.of(context).padding.top,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black26,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Counter
          Positioned(
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${photos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateLabel(String dateKey) {
    final parsed = DateTime.tryParse(dateKey);
    if (parsed == null) {
      return dateKey;
    }
    return DateFormat('yyyy/MM/dd').format(parsed);
  }
}

class _AlbumPhoto {
  final File file;
  final String dateKey;

  _AlbumPhoto({required this.file, required this.dateKey});
}
