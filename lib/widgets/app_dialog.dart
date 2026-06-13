import 'package:flutter/material.dart';

/// Polished confirmation/info dialog styled to match the app's visual language.
///
/// Two-button layout: cancel (left, muted) / confirm (right, primary or error).
/// Single-button layout: full-width centered button.
/// Optional `contentWidget` for custom content (e.g. text fields).
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.contentWidget,
    this.icon,
    this.iconColor,
    required this.actions,
  });

  final String title;
  final String? message;
  final Widget? contentWidget;
  final IconData? icon;
  final Color? iconColor;
  final List<AppDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasContent = message != null || contentWidget != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cs.surface,
      surfaceTintColor: cs.surfaceTint,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, icon != null ? 20 : 24, 24, hasContent ? 8 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (iconColor ?? cs.primary).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: iconColor ?? cs.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (contentWidget != null) ...[
                  const SizedBox(height: 12),
                  contentWidget!,
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, thickness: 1, color: cs.outlineVariant.withOpacity(0.5)),
          _buildActions(context, cs, theme),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, ColorScheme cs, ThemeData theme) {
    if (actions.length == 1) {
      return _ActionButton(action: actions[0], cs: cs, position: _ButtonPosition.single);
    }
    if (actions.length == 2) {
      return IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _ActionButton(action: actions[0], cs: cs, position: _ButtonPosition.left)),
            VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant.withOpacity(0.5)),
            Expanded(child: _ActionButton(action: actions[1], cs: cs, position: _ButtonPosition.right)),
          ],
        ),
      );
    }
    return Column(
      children: actions
          .map((a) => _ActionButton(action: a, cs: cs, position: _ButtonPosition.single))
          .toList(),
    );
  }
}

enum _ButtonPosition { single, left, right }

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.cs, required this.position});

  final AppDialogAction action;
  final ColorScheme cs;
  final _ButtonPosition position;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    if (action.isDestructive) {
      fg = cs.error;
    } else if (action.isCancel) {
      fg = cs.onSurfaceVariant;
    } else {
      fg = cs.primary;
    }

    final borderRadius = switch (position) {
      _ButtonPosition.single =>
        const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      _ButtonPosition.left =>
        const BorderRadius.only(bottomLeft: Radius.circular(20)),
      _ButtonPosition.right =>
        const BorderRadius.only(bottomRight: Radius.circular(20)),
    };

    return TextButton(
      onPressed: action.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        action.label,
        style: TextStyle(
          fontWeight: action.isCancel ? FontWeight.w500 : FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class AppDialogAction {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isCancel = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool isCancel;
}

/// Show a yes/no confirmation dialog. Returns `true` if confirmed.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String cancelLabel,
  required String confirmLabel,
  bool isDestructive = false,
  IconData? icon,
  Color? iconColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title,
      message: message,
      icon: icon,
      iconColor: iconColor,
      actions: [
        AppDialogAction(
          label: cancelLabel,
          isCancel: true,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        AppDialogAction(
          label: confirmLabel,
          isDestructive: isDestructive,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
}

/// Show an informational dialog with a single OK button.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? contentWidget,
  required String okLabel,
  IconData? icon,
  Color? iconColor,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title,
      message: message,
      contentWidget: contentWidget,
      icon: icon,
      iconColor: iconColor,
      actions: [
        AppDialogAction(
          label: okLabel,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}
