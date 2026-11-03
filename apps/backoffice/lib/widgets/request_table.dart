import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

/// Kolone tabele: naslov, kolona za sortiranje (`null` = ne sortira se) i širina.
const _columns = <(String, AdminColumn?, int)>[
  ('Oznaka', null, 2),
  ('Poslat', AdminColumn.createdAt, 3),
  ('Klijent', AdminColumn.client, 4),
  ('Pružalac', AdminColumn.provider, 4),
  ('Usluga', AdminColumn.service, 2),
  ('Stanje', AdminColumn.status, 3),
  ('Revizije', null, 2),
];

class RequestTable extends StatelessWidget {
  const RequestTable({
    super.key,
    required this.state,
    required this.focusNode,
    required this.controller,
    required this.onSelect,
  });

  static const rowExtent = 48.0;

  final AdminRequestsLoaded state;
  final FocusNode focusNode;
  final ScrollController controller;
  final ValueChanged<RequestId> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = state.visible;
    return Column(
      children: [
        _Header(state: state),
        const Divider(height: 1),
        Expanded(
          child: FocusedFrame(
            focusNode: focusNode,
            builder: (context, focused) => rows.isEmpty
                ? Center(child: Text('Nijedan zahtev ne odgovara filteru.', style: theme.textTheme.bodyLarge))
                : ListView.builder(
                    controller: controller,
                    itemExtent: rowExtent,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final request = rows[index];
                      return _Row(
                        state: state,
                        request: request,
                        selected: request.id == state.selectedId,
                        focused: focused,
                        striped: index.isOdd,
                        onTap: () => onSelect(request.id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Okvir koji drži fokus tastature i jasno pokazuje kada je fokus u njemu.
class FocusedFrame extends StatelessWidget {
  const FocusedFrame({super.key, required this.focusNode, required this.builder});

  final FocusNode focusNode;
  final Widget Function(BuildContext context, bool focused) builder;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: focusNode,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: focusNode.hasFocus ? color : Colors.transparent, width: 2),
          ),
          child: builder(context, focusNode.hasFocus),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AdminRequestsLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        children: [
          for (final (title, column, flex) in _columns)
            Expanded(
              flex: flex,
              child: column == null
                  ? Text(title, style: theme.textTheme.labelLarge)
                  : InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.read<AdminRequestsBloc>().add(AdminSortChanged(column)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Flexible(child: Text(title, style: theme.textTheme.labelLarge)),
                            if (state.sortColumn == column)
                              Icon(state.ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                          ],
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.state,
    required this.request,
    required this.selected,
    required this.focused,
    required this.striped,
    required this.onTap,
  });

  final AdminRequestsLoaded state;
  final CollaborationRequest request;
  final bool selected;
  final bool focused;
  final bool striped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodyMedium;
    final cells = [
      request.id.value,
      formatDate(request.createdAt),
      state.clientName(request),
      state.providerName(request),
      request.service.label,
      null,
      '${request.revisions} / $maxRevisions',
    ];
    return Material(
      color: selected
          ? scheme.primaryContainer
          : striped
          ? scheme.surfaceContainerLowest
          : scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: selected && focused ? Border(left: BorderSide(color: scheme.primary, width: 4)) : null,
          ),
          child: Row(
            children: [
              for (final (i, (_, _, flex)) in _columns.indexed)
                Expanded(
                  flex: flex,
                  child: cells[i] == null
                      ? Align(alignment: Alignment.centerLeft, child: StatusChip(request.status))
                      : Text(cells[i]!, style: text, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
