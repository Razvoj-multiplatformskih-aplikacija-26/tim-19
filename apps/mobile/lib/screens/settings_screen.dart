import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ui/ui.dart';

import '../dependencies.dart';

/// Prijavljeni korisnik i odjava; nad lažnim portom i prekidači za demonstraciju stanja ekrana.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDependencies>();
    final fake = deps.fake;
    final user = context.read<RequestsBloc>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Podešavanja')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(user.name),
            subtitle: Text(user.role == Role.provider ? 'Pružalac usluga' : 'Klijent'),
          ),
          ListTile(
            key: const Key('odjava'),
            leading: const Icon(Icons.logout),
            title: const Text('Odjavi se'),
            onTap: () => context.read<SessionBloc>().add(const SignOutRequested()),
          ),
          const Divider(),
          if (fake == null)
            const ListTile(
              leading: Icon(Icons.dns_outlined),
              title: Text('Aplikacija radi nad serverom.'),
              subtitle: Text('Grešku veze pokazuje zaustavljen server (docker compose stop server).'),
            )
          else ...[
            SwitchListTile(
              secondary: const Icon(Icons.cloud_off_outlined),
              title: const Text('Sledeći zahtev vraća grešku'),
              subtitle: const Text('Simulira prekid veze pri sledećem pozivu porta'),
              value: fake.failingRequests > 0,
              onChanged: (on) => setState(() => fake.failingRequests = on ? 1 : 0),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.inbox_outlined),
              title: const Text('Sledeća lista zahteva je prazna'),
              subtitle: const Text('Prikazuje prazan ekran sa zahtevima'),
              value: fake.emptyResponses > 0,
              onChanged: (on) => setState(() => fake.emptyResponses = on ? 1 : 0),
            ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('Prijava ističe sada'),
              subtitle: const Text(sessionExpiredMessage),
              onTap: () => deps.fakeSessions?.expire(),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Ponovo učitaj zahteve'),
              onTap: () {
                context.read<RequestsBloc>().add(const LoadRequests());
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }
}
