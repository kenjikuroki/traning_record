import 'package:flutter/foundation.dart';

class AlbumSync extends ChangeNotifier {
  AlbumSync._();

  static final AlbumSync instance = AlbumSync._();

  String? _latestAddedPath;

  String? get latestAddedPath => _latestAddedPath;

  void notifyPhotoAdded(String path) {
    _latestAddedPath = path;
    notifyListeners();
  }
}
