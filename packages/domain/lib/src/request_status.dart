/// Stanja zahteva za saradnju. Stanja nemaju podatke, pa su enum.
enum RequestStatus {
  sent,
  accepted,
  inProgress,
  delivered,
  completed,
  rejected,
  cancelled;

  /// Završen, odbijen i otkazan zahtev više ne menjaju stanje.
  bool get isFinal => switch (this) {
    completed || rejected || cancelled => true,
    sent || accepted || inProgress || delivered => false,
  };

  /// Zahtev zauzima mesto kod pružaoca dok nije završen, odbijen ili otkazan.
  bool get occupiesSlot => !isFinal;
}
