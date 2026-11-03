import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.id});

  final RequestId id;

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Otkazati zahtev?'),
        content: const Text('Otkazivanje ne može da se poništi. Pružalac više neće videti ovaj zahtev.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Odustani')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Otkaži zahtev')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) context.read<RequestsBloc>().add(CancelRequest(id));
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
      final busy = state.busyId == id;
      final cancelBlocked = state.whyNotCancellable(request);
      return Scaffold(
        appBar: AppBar(title: Text(state.providerOf(request)?.name ?? 'Zahtev')),
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
            _Row(label: 'Poslat', value: formatDate(request.createdAt)),
            _Row(label: 'Revizije', value: '${request.revisions} od $maxRevisions'),
            _Row(label: 'Oznaka', value: request.id.value),
            const SizedBox(height: 16),
            Text('Napomena', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(request.note, style: theme.textTheme.bodyLarge),
            if (cancelBlocked != null) ...[
              const SizedBox(height: 24),
              Text(domainErrorMessage(cancelBlocked), style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        bottomNavigationBar: state.canCancel(request)
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: busy || state.isBusy ? null : () => _confirmCancel(context),
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    icon: busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cancel_outlined),
                    label: const Text('Otkaži zahtev'),
                  ),
                ),
              )
            : null,
      );
    },
  );
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
