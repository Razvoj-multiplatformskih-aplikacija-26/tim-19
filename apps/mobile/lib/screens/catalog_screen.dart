import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Katalog pružalaca')),
    body: BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) => switch (state) {
        CatalogLoading() => const LoadingView(),
        CatalogError(:final cause) => ErrorView(
          message: failureMessage(cause),
          onRetry: () => context.read<CatalogBloc>().add(const RetryCatalog()),
        ),
        CatalogLoaded() => _CatalogBody(state: state),
      },
    ),
  );
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({required this.state});

  final CatalogLoaded state;

  void _filter(BuildContext context, {Genre? genre, ServiceType? service}) =>
      context.read<CatalogBloc>().add(CatalogFilterChanged(genre: genre, service: service));

  @override
  Widget build(BuildContext context) {
    final visible = state.visible;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final genre in [null, ...Genre.values])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(genre?.label ?? 'Svi žanrovi'),
                    selected: state.genre == genre,
                    onSelected: (_) => _filter(context, genre: genre, service: state.service),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final service in [null, ...ServiceType.values])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(service?.label ?? 'Sve usluge'),
                    selected: state.service == service,
                    onSelected: (_) => _filter(context, genre: state.genre, service: service),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? EmptyView(
                  icon: Icons.search_off_rounded,
                  title: 'Nema pružalaca',
                  message: 'Nijedan verifikovan pružalac ne odgovara filteru.',
                  action: OutlinedButton(onPressed: () => _filter(context), child: const Text('Poništi filter')),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final provider = visible[index];
                    return ProviderCard(provider: provider, free: state.freeSlotsOf(provider));
                  },
                ),
        ),
      ],
    );
  }
}

class ProviderCard extends StatelessWidget {
  const ProviderCard({super.key, required this.provider, required this.free});

  final Provider provider;
  final int free;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () => context.go('/katalog/${provider.id.value}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Text(provider.name.characters.first)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(provider.name, style: theme.textTheme.titleMedium)),
                  Text('od ${provider.priceFrom} €', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                [...provider.services.map((s) => s.label), ...provider.genres.map((g) => g.label)].join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                freeSlotsLabel(free, provider.capacity),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: free == 0 ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
