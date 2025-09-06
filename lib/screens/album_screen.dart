// lib/screens/album_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import 'dart:ui';

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
    _loadAll();
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

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
          return name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png');
        })
            .toList();
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())); // 新→旧
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
              try { await file.delete(); } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
    backgroundColor: Colors.transparent, // ← 背景（壁紙）を通す
    extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.albumTitle), // 既存のままでOK（l10nがあればそのまま）
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              // うっすらグラデで読みやすさ確保（home_screenのボトムバーと同系）
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _byDate.isEmpty
          ? Center(child: Text(l10n.noGraphData)) // 既存「記録がありません」を流用
          : ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _byDate.length,
        itemBuilder: (ctx, section) {
          final dateKey = _byDate.keys.elementAt(section);
          final files = _byDate[dateKey]!;
          final dt = DateTime.tryParse('$dateKey 00:00:00');
          final label = dt != null ? DateFormat('yyyy/MM/dd').format(dt) : dateKey;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GridView.builder(
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
                    return GestureDetector(
                      onTap: () => _openViewer(f),
                      onLongPress: () => _confirmDelete(f, dateKey, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(f, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
