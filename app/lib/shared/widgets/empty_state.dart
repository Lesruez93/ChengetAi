import 'package:flutter/material.dart';

/// A reusable "nothing to show yet" / error placeholder.
///
/// Used for: the initial check-message state, no lookup performed yet, an
/// empty feed, no file selected in the sentinel screen, and network-error
/// fallbacks — so every screen renders empty/error states the same way
/// instead of ad-hoc `Text('No data')` widgets scattered around.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14.5),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
