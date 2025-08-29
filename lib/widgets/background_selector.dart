// lib/widgets/background_selector.dart
import 'package:flutter/material.dart';
import '../constants/backgrounds.dart';
import '../settings_manager.dart';

class BackgroundSelector extends StatelessWidget {
  final String selectedAsset;
  final ValueChanged<String> onChanged;

  const BackgroundSelector({
    super.key,
    required this.selectedAsset,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 4 / 3,
      ),
      itemCount: allBackgrounds.length + 1, // +1は「なし」
      itemBuilder: (context, i) {
        final asset = (i == 0) ? '' : allBackgrounds[i - 1];
        final bool isSelected = asset == selectedAsset;

        return GestureDetector(
          onTap: () => onChanged(asset),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                width: isSelected ? 2 : 1,
                color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              ),
              color: asset.isEmpty ? colorScheme.surface : null,
              image: asset.isEmpty
                  ? null
                  : DecorationImage(image: AssetImage(asset), fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: asset.isEmpty
                ? Text(
              'なし',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
