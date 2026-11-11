import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

/// Detalj zahteva. Dugmad su tačno akcije koje domen dozvoljava prijavljenom korisniku ([RequestsLoaded.actionsFor]):
/// klijentu otkazivanje, potvrda isporuke i revizija, pružaocu prihvatanje i odbijanje.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.id});

  final RequestId id;

  Future<void> _run(BuildContext context, RequestAction action) async {
    final question = _confirmation(action);
    if (question != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(question.title),
          content: Text(question.body),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Odustani')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(_label(action))),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    context.read<RequestsBloc>().add(RequestActionRequested(action, id));
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<RequestsBloc, RequestsState>(
    builder: (context, state) {
      final request = state is RequestsLoaded ? state.byId(id) : null;
      if (state is! RequestsLoaded || request == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Zahtev')),
          body: switch (state) {
            RequestsLoading() => const LoadingView(),
            RequestsError(:final cause) => ErrorView(
              message: failureMessage(cause),
              onRetry: () => context.read<RequestsBloc>().add(const RetryLoad()),
            ),
            _ => const EmptyView(title: 'Zahtev nije pronađen', message: 'Možda je uklonjen ili adresa nije tačna.'),
          },
        );
      }
      final theme = Theme.of(context);
      final isProvider = context.read<RequestsBloc>().user.role == Role.provider;
      final busy = state.busyId == id;
      final actions = state.actionsFor(request);
      final cancelBlocked = isProvider ? null : state.whyNotCancellable(request);
      final providerName = state.providerOf(request)?.name ?? request.providerId.value;
      return Scaffold(
        appBar: AppBar(title: Text(isProvider ? state.clientName(request) : providerName)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(child: Text(request.service.label, style: theme.textTheme.headlineSmall)),
                StatusChip(request.status),
              ],
            ),
            const SizedBox(height: 16),
            if (isProvider) _Row(label: 'Klijent', value: state.clientName(request)),
            _Row(label: 'Poslat', value: formatDate(request.createdAt)),
            _Row(label: 'Revizije', value: '${request.revisions} od $maxRevisions'),
            _Row(label: 'Oznaka', value: request.id.value),
            const SizedBox(height: 16),
            Text('Napomena', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(request.note, style: theme.textTheme.bodyLarge),
            if (cancelBlocked != null && !actions.contains(RequestAction.cancel)) ...[
              const SizedBox(height: 24),
              Text(domainErrorMessage(cancelBlocked), style: theme.textTheme.bodySmall),
            ],
            if (request.status == RequestStatus.delivered && !isProvider)
              if (withinRevisionLimit(request) case Failure(:final error)) ...[
                const SizedBox(height: 8),
                Text(domainErrorMessage(error), style: theme.textTheme.bodySmall),
              ],
          ],
        ),
        bottomNavigationBar: actions.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final action in actions)
                        _ActionButton(
                          action: action,
                          busy: busy,
                          onPressed: state.isBusy ? null : () => _run(context, action),
                        ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}

String _label(RequestAction action) => switch (action) {
  RequestAction.cancel => 'Otkaži zahtev',
  RequestAction.complete => 'Potvrdi isporuku',
  RequestAction.revise => 'Traži reviziju',
  RequestAction.accept => 'Prihvati',
  RequestAction.reject => 'Odbij',
  RequestAction.close => 'Zatvori kao završen',
  RequestAction.reopen => 'Vrati u izradu',
};

/// Akcije koje ne mogu da se ponište traže potvrdu.
({String title, String body})? _confirmation(RequestAction action) => switch (action) {
  RequestAction.cancel => (
    title: 'Otkazati zahtev?',
    body: 'Otkazivanje ne može da se poništi. Pružalac više neće raditi na ovom zahtevu.',
  ),
  RequestAction.reject => (
    title: 'Odbiti zahtev?',
    body: 'Odbijanje ne može da se poništi; klijent će videti da je odbijen.',
  ),
  RequestAction.revise => (
    title: 'Tražiti reviziju?',
    body: 'Zahtev se vraća pružaocu na doradu i troši jednu od $maxRevisions revizije.',
  ),
  RequestAction.complete => (title: 'Potvrditi isporuku?', body: 'Zahtev postaje završen i više se ne menja.'),
  RequestAction.accept || RequestAction.close || RequestAction.reopen => null,
};

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.busy, required this.onPressed});

  final RequestAction action;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = Text(_label(action));
    final spinner = const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2));
    final destructive = action == RequestAction.cancel || action == RequestAction.reject;
    final primary = action == RequestAction.accept || action == RequestAction.complete;
    if (primary) return FilledButton(onPressed: onPressed, child: busy ? spinner : label);
    return OutlinedButton(
      onPressed: onPressed,
      style: destructive ? OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error) : null,
      child: busy ? spinner : label,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    ),
  );
}
