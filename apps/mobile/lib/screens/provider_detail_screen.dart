import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

/// Pronalazi verifikovanog pružaoca u katalogu i crta stanja učitavanja.
class ProviderGate extends StatelessWidget {
  const ProviderGate({super.key, required this.id, required this.builder});

  final ProviderId id;
  final Widget Function(BuildContext context, CatalogLoaded catalog, Provider provider) builder;

  @override
  Widget build(BuildContext context) => BlocBuilder<CatalogBloc, CatalogState>(
    builder: (context, state) => switch (state) {
      CatalogLoading() => const Scaffold(body: LoadingView()),
      CatalogError(:final cause) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: failureMessage(cause),
          onRetry: () => context.read<CatalogBloc>().add(const RetryCatalog()),
        ),
      ),
      CatalogLoaded() => switch (state.byId(id)) {
        final provider? => builder(context, state, provider),
        null => Scaffold(
          appBar: AppBar(),
          body: const EmptyView(title: 'Pružalac nije pronađen', message: 'Profil nije u katalogu.'),
        ),
      },
    },
  );
}

class ProviderDetailScreen extends StatelessWidget {
  const ProviderDetailScreen({super.key, required this.id});

  final ProviderId id;

  @override
  Widget build(BuildContext context) => ProviderGate(
    id: id,
    builder: (context, catalog, provider) {
      final theme = Theme.of(context);
      final free = catalog.freeSlotsOf(provider);
      return Scaffold(
        appBar: AppBar(title: Text(provider.name)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (provider.bio.isNotEmpty) Text(provider.bio, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            _Section(
              title: 'Usluge',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final s in provider.services) Chip(label: Text(s.label))],
              ),
            ),
            _Section(
              title: 'Žanrovi',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final g in provider.genres) Chip(label: Text(g.label))],
              ),
            ),
            _Section(
              title: 'Cena',
              child: Text('od ${provider.priceFrom} €', style: theme.textTheme.titleMedium),
            ),
            _Section(
              title: 'Slobodna mesta',
              child: Text(freeSlotsLabel(free, provider.capacity), style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: free == 0 ? null : () => context.go('/katalog/${provider.id.value}/novi-zahtev'),
              icon: const Icon(Icons.send_rounded),
              label: Text(free == 0 ? 'Nema slobodnih mesta' : 'Pošalji zahtev'),
            ),
          ),
        ),
      );
    },
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
