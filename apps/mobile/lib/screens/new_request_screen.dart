import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import '../dependencies.dart';
import 'provider_detail_screen.dart';

class NewRequestScreen extends StatelessWidget {
  const NewRequestScreen({super.key, required this.providerId});

  final ProviderId providerId;

  @override
  Widget build(BuildContext context) => ProviderGate(
    id: providerId,
    builder: (context, catalog, provider) {
      final deps = context.read<AppDependencies>();
      return BlocProvider(
        create: (_) => NewRequestBloc(requests: deps.requests, provider: provider, user: deps.user),
        child: _NewRequestForm(provider: provider),
      );
    },
  );
}

class _NewRequestForm extends StatelessWidget {
  const _NewRequestForm({required this.provider});

  final Provider provider;

  void _onDone(BuildContext context, NewRequestState state) {
    final created = state.created!;
    context.read<RequestsBloc>().add(const LoadRequests());
    context.read<CatalogBloc>().add(const LoadCatalog());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zahtev je poslat.')));
    context.go('/zahtevi/${created.id.value}');
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<NewRequestBloc, NewRequestState>(
    listenWhen: (previous, current) => previous.status != current.status && current.status == NewRequestStatus.done,
    listener: _onDone,
    builder: (context, state) {
      final bloc = context.read<NewRequestBloc>();
      final submitting = state.status != NewRequestStatus.editing;
      final problem = switch ((state.submitError, state.failure)) {
        (final DomainError error, _) => domainErrorMessage(error),
        (_, final Object cause) => failureMessage(cause),
        _ => null,
      };
      return Scaffold(
        appBar: AppBar(title: const Text('Novi zahtev')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Pružalac', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(provider.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            Text('Usluga', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final service in provider.services)
                  ChoiceChip(
                    label: Text(service.label),
                    selected: state.service == service,
                    onSelected: submitting ? null : (_) => bloc.add(ServiceChanged(service)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('note'),
              enabled: !submitting,
              minLines: 4,
              maxLines: 8,
              onChanged: (text) => bloc.add(NoteChanged(text)),
              decoration: InputDecoration(
                labelText: 'Napomena',
                hintText: 'Šta vam treba, rok, reference…',
                alignLabelWithHint: true,
                helperText: '${state.noteLength} / $maxNoteLength znakova',
                errorText: state.noteError == null ? null : domainErrorMessage(state.noteError!),
              ),
            ),
            if (problem != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(padding: const EdgeInsets.all(16), child: Text(problem)),
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: submitting ? null : () => bloc.add(const SubmitNewRequest()),
              child: submitting
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Pošalji zahtev'),
            ),
          ),
        ),
      );
    },
  );
}
