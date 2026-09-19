/// Telemetry must never break the app.
void safely(void Function() body) {
  try {
    body();
  } catch (_) {}
}
