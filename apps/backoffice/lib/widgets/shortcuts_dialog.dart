import 'package:flutter/material.dart';

import '../shortcuts.dart';

Future<void> showShortcutsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Prečice'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (keys, description) in shortcutDescriptions())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(keys, style: theme.textTheme.labelLarge?.copyWith(fontFamily: 'monospace')),
                    ),
                    Expanded(child: Text(description)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(autofocus: true, onPressed: () => Navigator.of(context).pop(), child: const Text('U redu')),
      ],
    );
  },
);
