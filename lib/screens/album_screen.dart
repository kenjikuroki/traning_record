// lib/screens/album_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../widgets/ad_banner.dart';
import '../settings_manager.dart';
import '../widgets/centered_constrained.dart';
import '../theme/app_theme.dart';       // appFabGradient / appFabSolid
import '../widgets/gradient_fab.dart';  // カレンダーと同じ見た目のFAB

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
  static const double _kGap = 12.0;      // 広告下の余白 等

  @override
  void initState() {
    super.initState();
    _loadAll(); // アルバムを読み込んで _loading を false にする
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    final base = await getApplicationDocumentsDirectory();
    final mediaRoot = Directory(p.join(base.path, 'media'));
    final map = <String, List<File>>{};

    if (await mediaRoot.exists()) {
      for (final ent in mediaRoot.listSync()) {
        if (ent is! Directory) continue;
        final dateKey = p.basename(ent.path);
        final files = ent
            .listSync()
            .whereType<File>()
            .where((f) {
          final name = f.path.toLowerCase();
          return name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png');
        })
            .toList();

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

  void _openViewer(File file) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4.0,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(File file, String dateKey, int index) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mediaDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.mediaCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
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
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSelectedConfirmTitle(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.mediaCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
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
  }

  Future<void> _handleAddPressed() async {
    if (_captureInProgress) return;
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
        await _loadAll();
      }
    } finally {
      if (mounted) {
        setState(() => _captureInProgress = false);
      }
    }
  }

  // 空表示（BackdropFilterは使わない）
  Widget _centerEmptyMessage(BuildContext context, AppLocalizations l10n) {
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
          child: Text(
            l10n.albumEmptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: Colors.white,
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

      // ぼかしは撤去。カレンダーと同じく透明AppBar＋白文字。
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,               // M3のスクロール時着色を無効
        surfaceTintColor: Colors.transparent,     // 追加のティントも無効
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
        title: Text(
          _inSelection
              ? l10n.selectedCount(_selectedPaths.length)
              : l10n.albumTitle,
        ),
        actions: _inSelection
            ? [
          TextButton(
            onPressed: _clearSelection,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            ),
            child: Text(l10n.clear),
          ),
        ]
            : null,
      ),


      body: Stack(
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
                const AdBanner(screenName: 'album'),
                const SizedBox(height: _kGap),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_byDate.isEmpty
                      ? _centerEmptyMessage(context, l10n)
                      : ListView.builder(
                    padding:
                    const EdgeInsets.fromLTRB(12, 8, 12, 12 + 72),
                    itemCount: _byDate.length,
                    itemBuilder: (ctx, index) {
                      // builder内で降順に並べ替えて参照
                      final entries = _byDate.entries.toList()
                        ..sort((a, b) => b.key.compareTo(a.key));

                      final dateKey = entries[index].key; // "yyyy-MM-dd"
                      final files = entries[index].value;

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
                            padding: const EdgeInsets.fromLTRB(
                                2, 8, 2, 6),
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
                              final f = files[i];
                              final selected =
                              _selectedPaths.contains(f.path);
                              return GestureDetector(
                                onTap: () {
                                  if (_inSelection) {
                                    _toggleSelect(f);
                                  } else {
                                    _openViewer(f);
                                  }
                                },
                                onLongPress: () {
                                  if (_inSelection) {
                                    _toggleSelect(f);
                                  } else {
                                    setState(() {
                                      _selectedPaths.add(f.path);
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
                                        f,
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
                  )),
                )
              ],
            ),
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: GradientFAB(
        onPressed: _handleAddPressed, // 既存の追加ハンドラに合わせる
        tooltip: l10n.add,
        heroTag: 'albumAddFab',
        width: 60,
        height: 56,
        borderRadius: 16,
        colors: appFabGradient(context), // app_themeの“くすんだ濃色”グラデ
        // 単色にするなら ↓ を使う
        // colors: [appFabSolid(context), appFabSolid(context)],
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
