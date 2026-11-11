import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import '../dependencies.dart';
import '../shortcuts.dart';
import '../widgets/detail_panel.dart';
import '../widgets/request_list.dart';
import '../widgets/request_table.dart';
import '../widgets/shortcuts_dialog.dart';

/// Ispod ove širine tabela postaje lista.
const narrowBreakpoint = 720.0;

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'pretraga');
  final _tableFocus = FocusNode(debugLabel: 'tabela');
  final _scroll = ScrollController();
  bool _detailOpen = false;
  bool _narrow = false;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _tableFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  AdminRequestsBloc get _bloc => context.read<AdminRequestsBloc>();

  AdminRequestsLoaded? get _loaded => switch (_bloc.state) {
    final AdminRequestsLoaded s => s,
    _ => null,
  };

  void _openDetail() {
    if (_loaded?.selected != null) setState(() => _detailOpen = true);
  }

  void _closeDetail() {
    if (_searchFocus.hasFocus) {
      _tableFocus.requestFocus();
      return;
    }
    setState(() => _detailOpen = false);
    _tableFocus.requestFocus();
  }

  void _select(RequestId id) {
    _bloc.add(AdminRequestSelected(id));
    setState(() => _detailOpen = true);
    _tableFocus.requestFocus();
  }

  Future<void> _act(ModeratorAction action) async {
    final state = _loaded;
    final request = state?.selected;
    if (state == null || request == null) return;
    // Nedozvoljenu akciju šaljemo bez dijaloga: pravilo iz domena je odbija i ekran prikazuje razlog.
    final needsConfirm = state.canApply(action, request) && action != ModeratorAction.reopen;
    if (needsConfirm && !await _confirm(action, state, request)) return;
    _bloc.add(ModeratorActionRequested(action, request.id));
  }

  Future<bool> _confirm(ModeratorAction action, AdminRequestsLoaded state, CollaborationRequest request) async {
    final (title, verb) = switch (action) {
      ModeratorAction.cancel => ('Otkazati zahtev?', 'Otkaži'),
      ModeratorAction.close => ('Zatvoriti zahtev kao završen?', 'Zatvori'),
      ModeratorAction.reopen => ('Vratiti zahtev u izradu?', 'Vrati'),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          '${request.id.value} · ${state.clientName(request)} → ${state.providerName(request)}\n'
          'Ova izmena ne može da se poništi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Odustani')),
          FilledButton(autofocus: true, onPressed: () => Navigator.of(context).pop(true), child: Text(verb)),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _onNotice(BuildContext context, AdminRequestsState state) {
    if (state is! AdminRequestsLoaded || state.notice == null) return;
    final text = switch (state.notice!) {
      ModeratorActionDone(:final action, :final request) => switch (action) {
        ModeratorAction.cancel => 'Zahtev ${request.id.value} je otkazan.',
        ModeratorAction.close => 'Zahtev ${request.id.value} je zatvoren kao završen.',
        ModeratorAction.reopen => 'Zahtev ${request.id.value} je vraćen u izradu.',
      },
      ModeratorActionRejected(:final error) => domainErrorMessage(error),
      ModeratorActionFailed(:final cause) => failureMessage(cause),
      AdminLoadFailed(:final cause) => failureMessage(cause),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    _bloc.add(const AdminNoticeShown());
  }

  /// Drži izabrani red u vidljivom delu tabele ili liste.
  void _ensureVisible(AdminRequestsState state) {
    if (state is! AdminRequestsLoaded || !_scroll.hasClients) return;
    final index = state.visible.indexWhere((r) => r.id == state.selectedId);
    if (index < 0) return;
    final extent = _narrow ? RequestList.itemExtent : RequestTable.rowExtent;
    final top = index * extent;
    final position = _scroll.position;
    final target = top < position.pixels
        ? top
        : top + extent > position.pixels + position.viewportDimension
        ? top + extent - position.viewportDimension
        : null;
    if (target != null) {
      _scroll.animateTo(
        target.clamp(0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: globalShortcuts(),
    child: Actions(
      actions: {
        FocusSearchIntent: CallbackAction<FocusSearchIntent>(
          onInvoke: (_) {
            _searchFocus.requestFocus();
            _search.selection = TextSelection(baseOffset: 0, extentOffset: _search.text.length);
            return null;
          },
        ),
        CloseDetailIntent: CallbackAction<CloseDetailIntent>(onInvoke: (_) => _closeDetail()),
        CancelSelectedIntent: CallbackAction<CancelSelectedIntent>(onInvoke: (_) => _act(ModeratorAction.cancel)),
        CloseSelectedIntent: CallbackAction<CloseSelectedIntent>(onInvoke: (_) => _act(ModeratorAction.close)),
        ReopenSelectedIntent: CallbackAction<ReopenSelectedIntent>(onInvoke: (_) => _act(ModeratorAction.reopen)),
        ShowShortcutsIntent: CallbackAction<ShowShortcutsIntent>(onInvoke: (_) => showShortcutsDialog(context)),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Zahtevi za saradnju'),
            actions: [
              IconButton(
                tooltip: 'Prečice (F1)',
                onPressed: () => showShortcutsDialog(context),
                icon: const Icon(Icons.keyboard_outlined),
              ),
              _DemoMenu(onReload: () => _bloc.add(const LoadAdminRequests())),
              IconButton(
                tooltip: 'Osveži',
                onPressed: () => _bloc.add(const LoadAdminRequests()),
                icon: const Icon(Icons.refresh),
              ),
              const _AccountMenu(),
              const SizedBox(width: 8),
            ],
          ),
          body: BlocConsumer<AdminRequestsBloc, AdminRequestsState>(
            listener: (context, state) {
              _onNotice(context, state);
              WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(state));
            },
            builder: (context, state) => switch (state) {
              AdminRequestsLoading() => const LoadingView(),
              AdminRequestsError(:final cause) => ErrorView(
                message: failureMessage(cause),
                onRetry: () => _bloc.add(const RetryAdminRequests()),
              ),
              AdminRequestsEmpty() => const EmptyView(
                title: 'Nema zahteva',
                message: 'Kada klijenti pošalju zahteve za saradnju, pojaviće se ovde.',
              ),
              AdminRequestsLoaded() => _buildLoaded(state),
            },
          ),
        ),
      ),
    ),
  );

  Widget _buildLoaded(AdminRequestsLoaded state) => LayoutBuilder(
    builder: (context, constraints) {
      _narrow = constraints.maxWidth < narrowBreakpoint;
      final selected = state.selected;
      final showDetail = _detailOpen && selected != null;
      final panel = showDetail
          ? DetailPanel(state: state, request: selected, onClose: _closeDetail, onAction: _act)
          : null;
      final records = Shortcuts(
        shortcuts: tableShortcuts(),
        child: Actions(
          actions: {
            MoveSelectionIntent: CallbackAction<MoveSelectionIntent>(
              onInvoke: (intent) => _bloc.add(AdminSelectionMoved(intent.delta)),
            ),
            OpenDetailIntent: CallbackAction<OpenDetailIntent>(onInvoke: (_) => _openDetail()),
          },
          child: _narrow
              ? RequestList(state: state, focusNode: _tableFocus, controller: _scroll, onSelect: _select)
              : RequestTable(state: state, focusNode: _tableFocus, controller: _scroll, onSelect: _select),
        ),
      );
      return Column(
        children: [
          _Toolbar(state: state, controller: _search, focusNode: _searchFocus, narrow: _narrow),
          const Divider(height: 1),
          Expanded(
            child: _narrow
                ? (panel ?? records)
                : Row(
                    children: [
                      Expanded(child: records),
                      if (panel != null) ...[const VerticalDivider(width: 1), SizedBox(width: 380, child: panel)],
                    ],
                  ),
          ),
        ],
      );
    },
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state, required this.controller, required this.focusNode, required this.narrow});

  final AdminRequestsLoaded state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AdminRequestsBloc>();
    final search = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (query) => bloc.add(AdminSearchChanged(query)),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        hintText: 'Klijent, pružalac ili oznaka ($commandKeyLabel F)',
      ),
    );
    final filter = DropdownButtonHideUnderline(
      child: DropdownButton<RequestStatus?>(
        value: state.statusFilter,
        hint: const Text('Sva stanja'),
        borderRadius: BorderRadius.circular(12),
        onChanged: (status) => bloc.add(AdminStatusFilterChanged(status)),
        items: [
          const DropdownMenuItem(child: Text('Sva stanja')),
          for (final status in RequestStatus.values) DropdownMenuItem(value: status, child: Text(status.label)),
        ],
      ),
    );
    final count = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${state.visible.length} od ${state.total}'),
        if (state.hasMore) ...[
          const SizedBox(width: 8),
          TextButton(
            key: const Key('ucitaj-jos'),
            onPressed: state.loadingMore ? null : () => bloc.add(const AdminLoadMore()),
            child: Text(state.loadingMore ? 'Učitavanje…' : 'Učitaj još'),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 8),
                Row(children: [filter, const Spacer(), count]),
              ],
            )
          : Row(
              children: [
                SizedBox(width: 420, child: search),
                const SizedBox(width: 16),
                filter,
                const Spacer(),
                count,
              ],
            ),
    );
  }
}

/// Prekidači lažnog porta za demonstraciju stanja ekrana.
class _DemoMenu extends StatelessWidget {
  const _DemoMenu({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final fake = context.read<BackofficeDependencies>().fake;
    if (fake == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Demo',
      icon: const Icon(Icons.science_outlined),
      onSelected: (choice) {
        switch (choice) {
          case 'greska':
            fake.failingRequests = 1;
          case 'prazno':
            fake.emptyResponses = 1;
            onReload();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'greska', child: Text('Sledeći zahtev vraća grešku')),
        PopupMenuItem(value: 'prazno', child: Text('Učitaj prazan odgovor')),
      ],
    );
  }
}

/// Prijavljeni moderator i odjava.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final moderator = context.read<AdminRequestsBloc>().moderator;
    return PopupMenuButton<String>(
      key: const Key('nalog'),
      tooltip: moderator.name,
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (_) => context.read<SessionBloc>().add(const SignOutRequested()),
      itemBuilder: (context) => [
        PopupMenuItem(enabled: false, child: Text(moderator.name)),
        const PopupMenuDivider(),
        const PopupMenuItem(key: Key('odjava'), value: 'odjava', child: Text('Odjavi se')),
      ],
    );
  }
}
