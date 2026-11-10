/// Kodovi grešaka na mreži. Kôd je stabilan; tekst poruke bira klijent.
abstract final class ErrorCodes {
  // Pravila i prava iz domena.
  static const invalidTransition = 'invalid-transition';
  static const cancelNotAllowed = 'cancel-not-allowed';
  static const revisionLimitReached = 'revision-limit-reached';
  static const noFreeSlots = 'no-free-slots';
  static const noteTooLong = 'note-too-long';
  static const noteEmpty = 'note-empty';
  static const providerNotListed = 'provider-not-listed';
  static const serviceNotOffered = 'service-not-offered';
  static const requestClosed = 'request-closed';
  static const notDelivered = 'not-delivered';
  static const notFound = 'not-found';
  static const notAllowed = 'not-allowed';
  static const wrongApp = 'wrong-app';
  static const staleRequest = 'stale-request';

  // Prijava.
  static const invalidCredentials = 'invalid-credentials';
  static const signInRequired = 'sign-in-required';
  static const sessionExpired = 'session-expired';

  // HTTP.
  static const badRequest = 'bad-request';
  static const unsupportedMediaType = 'unsupported-media-type';
  static const serverError = 'server-error';
}
