// Mobilna i desktop šalju token u zaglavlju; pregledač ne sme da drži token u skladištu dostupnom skriptama,
// pa prijavu čuva u HttpOnly kolačiću koji šalje sam pregledač (withCredentials).
export 'platform_client_io.dart' if (dart.library.js_interop) 'platform_client_web.dart';
