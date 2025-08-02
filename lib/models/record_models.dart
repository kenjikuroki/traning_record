import 'package:flutter/material.dart';
import 'dart:math';

// Defines the SetInputData class
class SetInputData {
  final TextEditingController weightController;
  final TextEditingController repController;
  final bool isSuggestion; // Flag to indicate if this set is a suggestion

  SetInputData({
    required this.weightController,
    required this.repController,
    this.isSuggestion = false, // Default is false
  });

  void dispose() {
    weightController.dispose();
    repController.dispose();
  }
}

// Helper class to hold data for each target section
class SectionData {
  final Key key; // Section key
  String? selectedPart; // Selected training part for this section
  List<TextEditingController> menuControllers; // Controllers for exercise names in this section
  List<List<SetInputData>> setInputDataList; // List of SetInputData
  int? initialSetCount; // Number of sets to display for this section (max(actual sets, default sets))
  List<Key> menuKeys; // Keys for each menu item

  SectionData({
    Key? key,
    this.selectedPart,
    required this.menuControllers,
    required this.setInputDataList,
    this.initialSetCount,
    required this.menuKeys,
  }) : this.key = key ?? UniqueKey();

  // Factory constructor to create a new empty section data with default controllers
  static SectionData createEmpty(int setCount, {bool shouldPopulateDefaults = true}) {
    return SectionData(
      menuControllers: shouldPopulateDefaults ? List.generate(1, (_) => TextEditingController()) : [],
      setInputDataList: shouldPopulateDefaults ? List.generate(1, (_) => List.generate(setCount, (_) => SetInputData(weightController: TextEditingController(), repController: TextEditingController(), isSuggestion: true))) : [], // New sections start as suggestions
      initialSetCount: setCount,
      menuKeys: shouldPopulateDefaults ? List.generate(1, (_) => UniqueKey()) : [],
    );
  }

  // Method to dispose all controllers within this section
  void dispose() {
    for (var c in menuControllers) {
      c.dispose();
    }
    for (var list in setInputDataList) {
      for (var data in list) {
        data.dispose();
      }
    }
  }
}
