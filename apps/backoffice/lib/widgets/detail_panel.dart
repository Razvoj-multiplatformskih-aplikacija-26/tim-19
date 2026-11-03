import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

import '../shortcuts.dart';

/// Detalj izabranog zahteva u bočnom panelu, sa akcijama moderatora.
class DetailPanel extends StatelessWidget {
  const DetailPanel({
    super.key,
    required this.state,
    required this.request,
    required this.onClose,
    required this.onAction,
  });

  final AdminRequestsLoaded state;
  final CollaborationRequest request;
  final VoidCallback onClose;
  final ValueChanged<ModeratorAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = state.busyId == request.id;
    Widget action(ModeratorAction action, IconData icon, String label, String keys, {bool destructive = false}) {
      final enabled = state.canApply(action, request) && !state.isBusy;
      final style = destructive ? OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error) : null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          style: style,
          onPressed: enabled ? () => onAction(action) : null,
          icon: Icon(icon),
          label: Row(
            children: [
              Expanded(child: Text(label)),
              Text(keys, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: Text('Zahtev ${request.id.value}', style: theme.textTheme.titleLarge)),
              IconButton(tooltip: 'Zatvori (Esc)', onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: StatusChip(request.status)),
          const SizedBox(height: 16),
          _Field('Klijent', state.clientName(request)),
          _Field('Pružalac', state.providerName(request)),
          _Field('Usluga', request.service.label),
          _Field('Poslat', formatDate(request.createdAt)),
          _Field('Revizije', '${request.revisions} od $maxRevisions'),
          const SizedBox(height: 8),
          Text('Napomena', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(request.note, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Akcije moderatora', style: theme.textTheme.labelLarge),
              if (busy) ...[
                const SizedBox(width: 12),
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          action(ModeratorAction.close, Icons.task_alt, 'Zatvori kao završen', '$commandKeyLabel Enter'),
          action(ModeratorAction.reopen, Icons.replay, 'Vrati u izradu', '$commandKeyLabel Shift Enter'),
          action(ModeratorAction.cancel, Icons.block, 'Otkaži zahtev', '$commandKeyLabel K', destructive: true),
          if (state.whyLocked(request) case final locked?)
            Text(domainErrorMessage(locked), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 88, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    ),
  );
}
