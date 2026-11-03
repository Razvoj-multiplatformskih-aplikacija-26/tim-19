import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

import 'request_table.dart';

/// Isti zapisi kao [RequestTable], za uzak prozor. Izbor i fokus su isti, pa se ne gube pri prelomu.
class RequestList extends StatelessWidget {
  const RequestList({
    super.key,
    required this.state,
    required this.focusNode,
    required this.controller,
    required this.onSelect,
  });

  static const itemExtent = 72.0;

  final AdminRequestsLoaded state;
  final FocusNode focusNode;
  final ScrollController controller;
  final ValueChanged<RequestId> onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = state.visible;
    final scheme = Theme.of(context).colorScheme;
    return FocusedFrame(
      focusNode: focusNode,
      builder: (context, _) => rows.isEmpty
          ? const Center(child: Text('Nijedan zahtev ne odgovara filteru.'))
          : ListView.builder(
              controller: controller,
              itemExtent: itemExtent,
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final request = rows[index];
                final selected = request.id == state.selectedId;
                return ListTile(
                  selected: selected,
                  selectedTileColor: scheme.primaryContainer,
                  title: Text('${state.clientName(request)} → ${state.providerName(request)}', maxLines: 1),
                  subtitle: Text('${request.id.value} · ${request.service.label} · ${formatDate(request.createdAt)}'),
                  trailing: StatusChip(request.status),
                  onTap: () => onSelect(request.id),
                );
              },
            ),
    );
  }
}
