import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'router.dart';

class SoundConnectApp extends StatefulWidget {
  const SoundConnectApp({super.key, required this.dependencies, this.initialLocation = '/katalog'});

  final AppDependencies dependencies;
  final String initialLocation;

  @override
  State<SoundConnectApp> createState() => _SoundConnectAppState();
}

class _SoundConnectAppState extends State<SoundConnectApp> {
  late final GoRouter _router = createRouter(initialLocation: widget.initialLocation);
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  void _onNotice(BuildContext context, RequestsState state) {
    if (state is! RequestsLoaded) return;
    final notice = state.notice;
    if (notice == null) return;
    final text = switch (notice) {
      RequestCancelled() => 'Zahtev je otkazan.',
      CancelRejected(:final error) => domainErrorMessage(error),
      CancelFailed(:final cause) => failureMessage(cause),
    };
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    // Otkazan zahtev oslobađa mesto kod pružaoca.
    if (notice is RequestCancelled) context.read<CatalogBloc>().add(const LoadCatalog());
    context.read<RequestsBloc>().add(const RequestsNoticeShown());
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    return RepositoryProvider.value(
      value: deps,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                RequestsBloc(requests: deps.requests, providers: deps.providers, clientId: deps.client.id)
                  ..add(const LoadRequests()),
          ),
          BlocProvider(
            create: (_) => CatalogBloc(providers: deps.providers, requests: deps.requests)..add(const LoadCatalog()),
          ),
        ],
        child: BlocListener<RequestsBloc, RequestsState>(
          listenWhen: (previous, current) => current is RequestsLoaded && current.notice != null,
          listener: _onNotice,
          child: MaterialApp.router(
            title: 'SoundConnect',
            debugShowCheckedModeBanner: false,
            theme: SoundTheme.light(),
            darkTheme: SoundTheme.dark(),
            scaffoldMessengerKey: _messenger,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
