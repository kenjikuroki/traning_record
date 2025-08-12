import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../models/menu_data.dart';
import '../models/record_models.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import '../settings_manager.dart';
import '../widgets/ad_banner.dart';
import 'calendar_screen.dart';

// ignore_for_file: library_private_types_in_public_api

enum DisplayMode { day, week }

class GraphScreen extends StatefulWidget {
  final Box<DailyRecord> recordsBox;
  final Box<List> lastUsedMenusBox;
  final Box<dynamic> settingsBox;
  final Box<int> setCountBox;

  const GraphScreen({
    super.key,
    required this.recordsBox,
    required this.lastUsedMenusBox,
    required this.settingsBox,
    required this.setCountBox,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  // ---- 追加：選択状態の保存キー ----
  static const String _prefGraphPart = 'graph_selected_part';
  static const String _prefGraphMenu = 'graph_selected_menu';
  static const String _prefGraphMode = 'graph_display_mode'; // 0:day, 1:week

  List<String> _filteredBodyParts = [];
  String? _selectedPart;
  List<String> _menusForPart = [];
  String? _selectedMenu;
  List<FlSpot> _spots = [];
  double _maxY = 0;
  double _minY = 0;
  bool _isFavorite = false;
  DisplayMode _displayMode = DisplayMode.day;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettingsAndParts();
  }

  String _getOriginalPartName(BuildContext context, String translatedPart) {
    final l10n = AppLocalizations.of(context)!;
    if (translatedPart == l10n.aerobicExercise) return '有酸素運動';
    if (translatedPart == l10n.arm) return '腕';
    if (translatedPart == l10n.chest) return '胸';
    if (translatedPart == l10n.back) return '背中';
    if (translatedPart == l10n.shoulder) return '肩';
    if (translatedPart == l10n.leg) return '足';
    if (translatedPart == l10n.fullBody) return '全身';
    if (translatedPart == l10n.other1) return 'その他１';
    if (translatedPart == l10n.other2) return 'その他２';
    if (translatedPart == l10n.other3) return 'その他３';
    if (translatedPart == l10n.favorites) return 'お気に入り';
    return translatedPart;
  }

  String _translatePartToLocale(BuildContext context, String part) {
    final l10n = AppLocalizations.of(context)!;
    switch (part) {
      case '有酸素運動':
        return l10n.aerobicExercise;
      case '腕':
        return l10n.arm;
      case '胸':
        return l10n.chest;
      case '背中':
        return l10n.back;
      case '肩':
        return l10n.shoulder;
      case '足':
        return l10n.leg;
      case '全身':
        return l10n.fullBody;
      case 'その他１':
        return l10n.other1;
      case 'その他２':
        return l10n.other2;
      case 'その他３':
        return l10n.other3;
      case 'お気に入り':
        return l10n.favorites;
      default:
        return part;
    }
  }

  void _loadSettingsAndParts() {
    final l10n = AppLocalizations.of(context)!;
    final allBodyParts = [
      '有酸素運動', '腕', '胸', '背中', '肩', '足',
      '全身', 'その他１', 'その他２', 'その他３'
    ];
    Map<String, bool>? savedBodyPartsSettings;
    final dynamic rawSettings = widget.settingsBox.get('selectedBodyParts');

    if (rawSettings != null && rawSettings is Map) {
      savedBodyPartsSettings = {};
      rawSettings.forEach((key, value) {
        if (key is String && value is bool) {
          savedBodyPartsSettings![key] = value;
        }
      });
    }

    _filteredBodyParts = [];
    if (savedBodyPartsSettings != null && savedBodyPartsSettings.isNotEmpty) {
      _filteredBodyParts = allBodyParts.where((originalPart) {
        return savedBodyPartsSettings![originalPart] == true;
      }).map((originalPart) {
        return _translatePartToLocale(context, originalPart);
      }).toList();
    } else {
      _filteredBodyParts = allBodyParts.map((originalPart) {
        return _translatePartToLocale(context, originalPart);
      }).toList();
    }

    // 「お気に入り」を先頭に
    _filteredBodyParts.insert(0, l10n.favorites);

    // ---- 追加：前回の表示モード/部位の復元 ----
    final int? savedModeIdx = widget.settingsBox.get(_prefGraphMode) as int?;
    if (savedModeIdx != null && savedModeIdx >= 0 && savedModeIdx < DisplayMode.values.length) {
      _displayMode = DisplayMode.values[savedModeIdx];
    }

    final String? savedPart = widget.settingsBox.get(_prefGraphPart) as String?;
    if (savedPart != null && _filteredBodyParts.contains(savedPart)) {
      _selectedPart = savedPart;
    } else {
      _selectedPart = _filteredBodyParts.isNotEmpty ? _filteredBodyParts.first : null;
    }

    if (mounted) {
      setState(() {
        if (_selectedPart != null) {
          _loadMenusForPart(_selectedPart!);
        }
      });
    }
  }

  void _loadMenusForPart(String translatedPart) {
    _menusForPart.clear();

    if (translatedPart == AppLocalizations.of(context)!.favorites) {
      final dynamic rawFavorites = widget.settingsBox.get('favorites');
      if (rawFavorites is List) {
        _menusForPart = rawFavorites.whereType<String>().toList();
      }
    } else {
      final originalPartName = _getOriginalPartName(context, translatedPart);
      final dynamic rawList = widget.lastUsedMenusBox.get(originalPartName);
      if (rawList is List) {
        final List<MenuData> lastUsedMenus = rawList.whereType<MenuData>().toList();
        _menusForPart = lastUsedMenus.map((m) => m.name).toList();
      }
    }

    // ---- 追加：前回のメニュー復元 ----
    final String? savedMenu = widget.settingsBox.get(_prefGraphMenu) as String?;
    if (savedMenu != null && _menusForPart.contains(savedMenu)) {
      _selectedMenu = savedMenu;
    } else {
      _selectedMenu = _menusForPart.isNotEmpty ? _menusForPart.first : null;
    }

    if (mounted) {
      setState(() {
        if (_selectedMenu != null) {
          _loadGraphData(_selectedMenu!);
        } else {
          _spots = [];
          _maxY = 0;
          _minY = 0;
        }
      });
    }
  }

  void _loadGraphData(String menuName) {
    final translatedPart = _selectedPart;
    if (translatedPart == null) return;

    final Map<double, double> data = {};
    _maxY = 0;
    _minY = double.infinity;

    final recordsMap = widget.recordsBox.toMap().values.whereType<DailyRecord>();
    final allBodyParts = [
      '有酸素運動', '腕', '胸', '背中', '肩', '足',
      '全身', 'その他１', 'その他２', 'その他３'
    ];

    if (_displayMode == DisplayMode.day) {
      for (var record in recordsMap) {
        for (var part in allBodyParts) {
          final List<MenuData>? menuList = record.menus[part];
          if (menuList != null) {
            final MenuData? foundMenu = menuList.firstWhereOrNull((m) => m.name == menuName);
            if (foundMenu != null) {
              double maxWeight = 0;
              for (int i = 0; i < foundMenu.weights.length; i++) {
                final weightStr = foundMenu.weights[i];
                final repStr = foundMenu.reps[i];
                if (weightStr.isNotEmpty && repStr.isNotEmpty) {
                  final weight = double.tryParse(weightStr);
                  final reps = int.tryParse(repStr);
                  if (weight != null && reps != null && reps >= 1) {
                    if (weight > maxWeight) {
                      maxWeight = weight;
                    }
                  }
                }
              }
              if (maxWeight > 0) {
                final date = record.date;
                final xValue = date.millisecondsSinceEpoch.toDouble();
                data[xValue] = maxWeight;
                _maxY = max(_maxY, maxWeight);
                _minY = min(_minY, maxWeight);
              }
            }
          }
        }
      }
    } else if (_displayMode == DisplayMode.week) {
      final Map<int, double> weeklyData = {};

      for (var record in recordsMap) {
        final DateTime date = record.date;
        // 月曜始まり
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final weekStartMs = weekStart.millisecondsSinceEpoch;

        for (var part in allBodyParts) {
          final List<MenuData>? menuList = record.menus[part];
          if (menuList != null) {
            final MenuData? foundMenu = menuList.firstWhereOrNull((m) => m.name == menuName);
            if (foundMenu != null) {
              double maxWeight = 0;
              for (int i = 0; i < foundMenu.weights.length; i++) {
                final weightStr = foundMenu.weights[i];
                final repStr = foundMenu.reps[i];
                if (weightStr.isNotEmpty && repStr.isNotEmpty) {
                  final weight = double.tryParse(weightStr);
                  final reps = int.tryParse(repStr);
                  if (weight != null && reps != null && reps >= 1) {
                    if (weight > maxWeight) {
                      maxWeight = weight;
                    }
                  }
                }
              }
              if (maxWeight > 0) {
                if (weeklyData.containsKey(weekStartMs)) {
                  weeklyData[weekStartMs] = max(weeklyData[weekStartMs]!, maxWeight);
                } else {
                  weeklyData[weekStartMs] = maxWeight;
                }
                _maxY = max(_maxY, maxWeight);
                _minY = min(_minY, maxWeight);
              }
            }
          }
        }
      }

      weeklyData.forEach((key, value) {
        data[key.toDouble()] = value;
      });
    }

    if (data.isNotEmpty) {
      final sortedKeys = data.keys.toList()..sort();
      _spots = sortedKeys.map((key) => FlSpot(key, data[key]!)).toList();
    } else {
      _spots = [];
    }

    if (mounted) {
      setState(() {
        _checkIfFavorite();
        _saveGraphPrefs(); // ← 追加：描画データ確定時にも保存
      });
    }
  }

  void _checkIfFavorite() {
    if (_selectedMenu != null) {
      final dynamic rawFavorites = widget.settingsBox.get('favorites');
      if (rawFavorites is List) {
        setState(() {
          _isFavorite = rawFavorites.contains(_selectedMenu);
        });
      } else {
        setState(() {
          _isFavorite = false;
        });
      }
    }
  }

  void _toggleFavorite() {
    if (_selectedMenu == null) return;

    final dynamic rawFavorites = widget.settingsBox.get('favorites');
    List<String> favorites = rawFavorites is List ? rawFavorites.whereType<String>().toList() : [];

    final l10n = AppLocalizations.of(context)!;
    String message;

    if (favorites.contains(_selectedMenu!)) {
      favorites.remove(_selectedMenu!);
      message = l10n.unfavorited(_selectedMenu!);
    } else {
      favorites.add(_selectedMenu!);
      message = l10n.favorited(_selectedMenu!);
    }

    widget.settingsBox.put('favorites', favorites);

    setState(() {
      _isFavorite = favorites.contains(_selectedMenu);
      _loadMenusForPart(_selectedPart!);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---- 追加：選択状態の保存 ----
  void _saveGraphPrefs() {
    widget.settingsBox.put(_prefGraphPart, _selectedPart);
    widget.settingsBox.put(_prefGraphMenu, _selectedMenu);
    widget.settingsBox.put(_prefGraphMode, _displayMode.index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // 何もしない
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          title: Text(
            l10n.graphScreenTitle,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
          ),
          backgroundColor: colorScheme.surface,
          elevation: 0.0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const AdBanner(screenName: 'graph'),
              const SizedBox(height: 16.0),
              ToggleButtons(
                isSelected: [_displayMode == DisplayMode.day, _displayMode == DisplayMode.week],
                onPressed: (index) {
                  setState(() {
                    _displayMode = index == 0 ? DisplayMode.day : DisplayMode.week;
                    _saveGraphPrefs(); // ← 保存
                    if (_selectedMenu != null) {
                      _loadGraphData(_selectedMenu!);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20.0),
                selectedColor: colorScheme.onPrimary,
                fillColor: colorScheme.primary,
                color: colorScheme.onSurface,
                borderColor: colorScheme.outlineVariant,
                selectedBorderColor: colorScheme.primary,
                splashColor: colorScheme.primary.withOpacity(0.2),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(l10n.dayDisplay),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(l10n.weekDisplay),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Expanded(
                child: Card(
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                  elevation: 4,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _spots.isEmpty
                            ? Center(
                          child: Text(
                            l10n.noGraphData,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        )
                            : LineChart(
                          LineChartData(
                            minX: _spots.first.x,
                            maxX: _spots.last.x,
                            minY: _minY > 0 ? _minY * 0.9 : 0,
                            maxY: _maxY > 0 ? _maxY * 1.1 : 1,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  interval: _spots.length > 1
                                      ? (_spots.last.x - _spots.first.x) / 5
                                      : 1,
                                  getTitlesWidget: (value, meta) {
                                    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                    if (_spots.map((spot) => spot.x).contains(value)) {
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Text(
                                          DateFormat('MM/dd').format(date),
                                          style: TextStyle(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _spots,
                                isCurved: false,
                                color: colorScheme.primary,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(show: false),
                              ),
                            ],
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              getDrawingVerticalLine: (value) {
                                if (_spots.map((spot) => spot.x).contains(value)) {
                                  return const FlLine(color: Colors.grey, strokeWidth: 0.5);
                                }
                                return const FlLine(color: Colors.transparent);
                              },
                              getDrawingHorizontalLine: (value) {
                                return const FlLine(
                                  color: Colors.grey,
                                  strokeWidth: 0.5,
                                );
                              },
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: colorScheme.outlineVariant, width: 1),
                            ),
                          ),
                        ),
                      ),
                      if (_selectedMenu != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: Icon(
                              _isFavorite ? Icons.star : Icons.star_border,
                              color: _isFavorite ? Colors.indigo : colorScheme.onSurface,
                              size: 28,
                            ),
                            onPressed: _toggleFavorite,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: l10n.selectTrainingPart,
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
                      filled: true,
                      fillColor: colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    value: _selectedPart,
                    items: _filteredBodyParts
                        .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                        p,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedPart = value;
                          _saveGraphPrefs(); // ← 保存
                          _loadMenusForPart(value);
                        });
                      }
                    },
                    dropdownColor: colorScheme.surfaceContainer,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  const SizedBox(height: 8.0),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: l10n.selectExercise,
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.0),
                      filled: true,
                      fillColor: colorScheme.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    value: _selectedMenu,
                    items: _menusForPart
                        .map((menu) => DropdownMenuItem(
                      value: menu,
                      child: Text(
                        menu,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedMenu = value;
                          _saveGraphPrefs(); // ← 保存
                          _loadGraphData(value);
                        });
                      }
                    },
                    dropdownColor: colorScheme.surfaceContainer,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note),
              label: 'Record',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Graph',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          currentIndex: 2,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                    selectedDate: DateTime.now(),
                  ),
                ),
                    (route) => false,
              );
            } else if (index == 1) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordScreen(
                    selectedDate: DateTime.now(),
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
                    (route) => false,
              );
            } else if (index == 3) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    recordsBox: widget.recordsBox,
                    lastUsedMenusBox: widget.lastUsedMenusBox,
                    settingsBox: widget.settingsBox,
                    setCountBox: widget.setCountBox,
                  ),
                ),
                    (route) => false,
              );
            }
          },
        ),
      ),
    );
  }
}
