import 'package:flutter/material.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import '../services/iap_service.dart';
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
                if (IAPService.instance.isBusy.value) return;
                
                final success = await IAPService.instance.purchasePremium();
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchase failed or canceled')),
                  );
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
                      child: ValueListenableBuilder<bool>(
                        valueListenable: IAPService.instance.isBusy,
                        builder: (context, isBusy, _) {
                          if (isBusy) {
                            return const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            );
                          }
                          return const Icon(
                            Icons.diamond_outlined,
                            color: Colors.white,
                            size: 28,
                          );
                        },
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
