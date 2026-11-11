import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

/// Zahtevi prijavljenog korisnika: klijent vidi svoje, pružalac zahteve upućene njemu.
/// Četiri stanja ekrana dolaze iz [RequestsBloc].
class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<RequestsBloc>().user;
    final isProvider = user.role == Role.provider;
    return Scaffold(
      appBar: AppBar(
        title: Text(isProvider ? 'Upućeni zahtevi' : 'Moji zahtevi'),
        actions: [
          IconButton(
            tooltip: 'Osveži',
            onPressed: () => context.read<RequestsBloc>().add(const LoadRequests()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<RequestsBloc, RequestsState>(
        builder: (context, state) => switch (state) {
          RequestsLoading() => const LoadingView(),
          RequestsError(:final cause) => ErrorView(
            message: failureMessage(cause),
            onRetry: () => context.read<RequestsBloc>().add(const RetryLoad()),
          ),
          RequestsEmpty() when isProvider => const EmptyView(
            title: 'Još nema zahteva',
            message: 'Kada vam klijent pošalje zahtev za saradnju, pojaviće se ovde.',
          ),
          RequestsEmpty() => EmptyView(
            title: 'Još nema zahteva',
            message: 'Izaberite pružaoca u katalogu i pošaljite prvi zahtev za saradnju.',
            action: FilledButton(onPressed: () => context.go('/katalog'), child: const Text('Otvori katalog')),
          ),
          RequestsLoaded(:final items) => RefreshIndicator(
            onRefresh: () async => context.read<RequestsBloc>().add(const LoadRequests()),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = items[index];
                final title = isProvider
                    ? state.clientName(request)
                    : state.providerOf(request)?.name ?? request.providerId.value;
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(title),
                    subtitle: Text('${request.service.label} · ${formatDate(request.createdAt)}'),
                    trailing: StatusChip(request.status),
                    onTap: () => context.go('/zahtevi/${request.id.value}'),
                  ),
                );
              },
            ),
          ),
        },
      ),
    );
  }
}
