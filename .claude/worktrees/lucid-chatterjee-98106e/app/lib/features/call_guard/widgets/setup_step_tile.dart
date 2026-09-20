import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// One step in the Call Guard setup checklist.
///
/// Completed steps keep their action button rather than collapsing to a tick:
/// every one of these can be revoked from system settings without the app
/// being told, so the user needs a way back to the same prompt without
/// reinstalling.
class SetupStepTile extends StatelessWidget {
  const SetupStepTile({
    required this.done,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    super.key,
    this.isDestructiveAction = false,
  });

  final bool done;
  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function() onAction;

  /// Styles the action as a step backwards (pausing protection) rather than
  /// forwards, so "Pause" doesn't read as the thing you're meant to press.
  final bool isDestructiveAction;

  @override
  Widget build(BuildContext context) {
    final Color accent = done ? AppColors.safe : AppColors.warning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: isDestructiveAction ? AppColors.danger : null,
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
