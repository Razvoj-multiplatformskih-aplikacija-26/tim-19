import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import 'dependencies.dart';
import 'screens/requests_screen.dart';

class BackofficeApp extends StatelessWidget {
  const BackofficeApp({super.key, required this.dependencies});

  final BackofficeDependencies dependencies;

  @override
  Widget build(BuildContext context) => RepositoryProvider.value(
    value: dependencies,
    child: BlocProvider(
      create: (_) => AdminRequestsBloc(
        requests: dependencies.requests,
        providers: dependencies.providers,
        clients: dependencies.clients,
      )..add(const LoadAdminRequests()),
      child: MaterialApp(
        title: 'SoundConnect backoffice',
        debugShowCheckedModeBanner: false,
        theme: SoundTheme.light(),
        darkTheme: SoundTheme.dark(),
        home: const RequestsScreen(),
      ),
    ),
  );
}
