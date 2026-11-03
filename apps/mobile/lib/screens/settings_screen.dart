import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dependencies.dart';

/// Prekidači za demonstraciju stanja ekrana. Rade samo nad lažnim portom.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Podešavanja')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(deps.client.name),
            subtitle: const Text('Prijavljen klijent (prijava stiže u KT2)'),
          ),
          const Divider(),
          if (fake == null)
            const ListTile(title: Text('Aplikacija koristi pravi server.'))
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
              subtitle: const Text('Prikazuje prazan ekran „Moji zahtevi“'),
              value: fake.emptyResponses > 0,
              onChanged: (on) => setState(() => fake.emptyResponses = on ? 1 : 0),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Ponovo učitaj moje zahteve'),
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
