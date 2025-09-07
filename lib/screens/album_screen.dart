// lib/screens/album_screen.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final Map<String, List<File>> _byDate = {}; // dateKey -> files(新→旧)
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll(); // アルバムを読み込んで _loading を false にする
  }

  // 選択モード管理
  final Set<String> _selectedPaths = {};
  bool get _inSelection => _selectedPaths.isNotEmpty;

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

    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a)); // 新しい日付が上
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
    final filePath = f.path; // ← 競合回避のためリネーム
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

  Widget _checkBadge(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.lightBlueAccent : Colors.white.withOpacity(0.85),
        border: Border.all(
          color: selected ? Colors.lightBlueAccent : Colors.black38,
          width: 1,
        ),
      ),
      child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
    );
  }

  // ── ここから追記：スタイル統一（＋部位ボタン相当のトーンに合わせる） ──
  ButtonStyle _primaryFilledButtonStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
    );
  }

  ButtonStyle _dangerFilledButtonStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: cs.error,
      foregroundColor: cs.onError,
    );
  }

  // ── 追加：＋部位チップ風のピルボタン（濃い色） ──
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
          // ← 高さを“固定”して親に引き伸ばされないようにする
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
      backgroundColor: Colors.transparent, // ← 背景（壁紙）を通す
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // ← 追加：戻るアイコン等を白に
        title: Text(
          _inSelection
              ? l10n.selectedCount(_selectedPaths.length)
              : l10n.albumTitle,
          style: const TextStyle( // ← 追加：他ページと同じフォントに統一
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: _inSelection
            ? [
          TextButton(
            onPressed: _clearSelection,
            child: Text(
              l10n.clear,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ]
            : null,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.30),
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.00),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 背景トーンを暗くする半透明ブラック（壁紙はそのまま見せる）
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.80)),
          ),

          // 既存の本文はそのまま前面に表示
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _byDate.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      // 軽い背景でも読める、ダサくない“うっすらフロスト”
                      color: Colors.black.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Text(
                      l10n.albumEmptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,           // 大きめ
                        fontWeight: FontWeight.w700, // 太字
                        height: 1.5,
                        color: Colors.white,    // コントラスト確保
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ):
          ListView.builder(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8, // ← AppBarぶん余白
              bottom: _inSelection ? 96 : 24,
            ),
            itemCount: _byDate.length,
            itemBuilder: (ctx, section) {
              final dateKey = _byDate.keys.elementAt(section);
              final files = _byDate[dateKey]!;
              final dt = DateTime.tryParse('$dateKey 00:00:00');
              final label = dt != null
                  ? DateFormat('yyyy/MM/dd').format(dt)
                  : dateKey;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4), // ← 日付と写真の間を狭く
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: files.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemBuilder: (gctx, i) {
                        final f = files[i];
                        final selected = _selectedPaths.contains(f.path);
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
                                _selectedPaths.add(f.path); // 選択モード開始
                              });
                            }
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  f,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (selected)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              if (_inSelection)
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: _checkBadge(selected),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _inSelection
          ? SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: Colors.black.withOpacity(0.8), // 下部も暗トーンを維持
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // ← 2つのピルを中央寄せ
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
