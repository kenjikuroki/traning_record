import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ttraining_record/l10n/app_localizations.dart';
import '../settings_manager.dart';

class SisterAppBanner extends StatelessWidget {
  const SisterAppBanner({super.key});

  static const _appStoreUrl = 'https://apps.apple.com/app/id6739669527';

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return const SizedBox.shrink();
    }

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
          onTap: () {
            launchUrl(
              Uri.parse(_appStoreUrl),
              mode: LaunchMode.externalApplication,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/album/sister_app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.apps,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.sisterAppPromotionTitle,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
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
