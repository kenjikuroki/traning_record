import 'package:flutter/material.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';

import '../services/iap_service.dart';

Future<void> showPremiumUpgradeSheet(
  BuildContext context, {
  required String headline,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _PremiumUpgradeSheet(
        headline: headline,
        message: message,
      );
    },
  );
}

String premiumSettingsDescription(AppLocalizations l10n) {
  return l10n.premiumUnlockDescription;
}

String premiumSettingsButtonLabel(AppLocalizations l10n) {
  return l10n.premiumUnlockButton;
}

List<String> premiumFeatureLabels(AppLocalizations l10n) {
  return [
    l10n.premiumFeaturePhotoSaving,
    l10n.premiumFeatureGraphs,
    l10n.premiumFeatureOneTime,
  ];
}

String premiumPhotoHeadline(AppLocalizations l10n) {
  return l10n.premiumPhotoHeadline;
}

String premiumPhotoMessage(AppLocalizations l10n) {
  return l10n.premiumPhotoMessage;
}

String premiumGraphHeadline(AppLocalizations l10n) {
  return l10n.premiumGraphHeadline;
}

String premiumGraphMessage(AppLocalizations l10n) {
  return l10n.premiumGraphMessage;
}

class _PremiumUpgradeSheet extends StatelessWidget {
  const _PremiumUpgradeSheet({
    required this.headline,
    required this.message,
  });

  final String headline;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFFFC266).withOpacity(0.60),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFC94D),
                            Color(0xFFFF9800),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1D6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color: Color(0xFFB86A00),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            headline,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in premiumFeatureLabels(l10n))
                      _FeatureChip(label: label),
                  ],
                ),
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFB100),
                        Color(0xFFFF8A00),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (IAPService.instance.isBusy.value) return;
                        final success =
                            await IAPService.instance.purchasePremium();
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.of(context).pop();
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.purchaseFailed),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: IAPService.instance.isBusy,
                        builder: (context, isBusy, child) {
                          if (isBusy) {
                            return const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_open_rounded, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  l10n.premiumUnlockButton,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    if (IAPService.instance.isBusy.value) return;
                    await IAPService.instance.restorePurchases();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    l10n.restorePurchase,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFC266).withOpacity(0.55),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
