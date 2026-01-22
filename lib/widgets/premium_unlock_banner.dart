import 'package:flutter/material.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import '../settings_manager.dart';

class PremiumUnlockBanner extends StatelessWidget {
  const PremiumUnlockBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.isPremiumNotifier,
      builder: (context, isPremium, child) {
        if (isPremium) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                // 課金モック処理 (SettingsScreenと同じ)
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.premiumUnlockTitle),
                    content: Text(l10n.premiumUnlockDescription),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.sisterAppPromotionDialogCancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Unlock (Mock)'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await SettingsManager.setPremium(true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Premium Unlocked (Mock)!')),
                    );
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B), // Amber 600
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.diamond_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.premiumUnlockTitle,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.premiumUnlockButton,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
