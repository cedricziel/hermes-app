part of 'chat_controller.dart';

/// Billing verification scoped to the current protected attachment.
extension _ChatControllerBilling on ChatController {
  BillingVerificationController? _billingVerificationInImpl(ChatThread thread) {
    final owner = (_profile, thread.id),
        controller = _billing[(_profile, thread.id)],
        binding = _billingBindings[(_profile, thread.id)];
    return controller != null &&
            binding != null &&
            _threads.contains(thread) &&
            _currentBilling(owner, controller, binding, _activityEpoch)
        ? controller
        : null;
  }

  bool _currentBilling(
    (String?, String) owner,
    BillingVerificationController controller,
    OwnedSessionBinding binding,
    int epoch,
  ) {
    final source = transport;
    return appLock != null &&
        _currentActivity(epoch) &&
        _profile == owner.$1 &&
        _billing[owner] == controller &&
        _billingBindings[owner] == binding &&
        source is OwnedSessionTransport &&
        (source as OwnedSessionTransport).ownedSessionFor(
              owner.$2,
              profile: owner.$1,
            ) ==
            binding;
  }

  BillingVerificationController? _adoptBilling(
    (String?, String) owner,
    OwnedSessionBinding binding,
  ) {
    if (appLock == null) return null;
    final existing = _billing[owner];
    if (existing != null && _billingBindings[owner] == binding) return existing;
    _removeBilling(owner);
    final source = transport, epoch = _activityEpoch;
    final controller = BillingVerificationController(
      now: _clock,
      openBrowser: billingBrowser,
      copyCode: billingCopyCode,
      events: events,
      breadcrumbs: breadcrumbs,
    );
    _billing[owner] = controller;
    _billingBindings[owner] = binding;
    bool current() =>
        _currentBilling(owner, controller, binding, epoch) &&
        !(appLock?.covered ?? true);
    controller.addListener(notifyListeners);
    controller.setLocked(appLock?.covered ?? true);
    controller.bind(
      BillingVerificationScope(
        connection: binding.connection,
        attachment: binding,
        sessionId: binding.runtimeId,
        profile: binding.profile,
      ),
      authorize: current,
      supported: source is BillingVerificationTransport
          ? () => (source as BillingVerificationTransport)
                .billingVerificationSupported(binding)
          : () => false,
      request: source is BillingVerificationTransport
          ? (_) {
              if (!current()) throw StateError('Billing attachment retired');
              return (source as BillingVerificationTransport).stepUpBilling(
                binding,
                authorize: current,
              );
            }
          : null,
    );
    return controller;
  }

  void _removeBilling((String?, String) owner) {
    _billingBindings.remove(owner);
    _billing.remove(owner)?.dispose();
  }

  void _clearBilling() {
    for (final controller in _billing.values) {
      controller.dispose();
    }
    _billing.clear();
    _billingBindings.clear();
  }

  void _billingLockChanged() {
    if (disposed) return;
    for (final controller in _billing.values.toList()) {
      controller.setLocked(appLock?.covered ?? true);
    }
  }

  void _onBillingOwnership(OwnedSessionChange change) {
    final owner = (change.binding.profile, change.threadId);
    if (!change.connected) {
      if (_billingBindings[owner] == change.binding) {
        _removeBilling(owner);
        notifyListeners();
      }
      return;
    }
    final source = transport;
    if ((owner.$1?.isEmpty ?? true) ||
        source is! OwnedSessionTransport ||
        (source as OwnedSessionTransport).ownedSessionFor(
              owner.$2,
              profile: owner.$1,
            ) !=
            change.binding) {
      return;
    }
    _adoptBilling(owner, change.binding);
  }

  bool _onBillingEvent(ChatThread thread, ChatEvent event, String? profile) {
    if (event is! BillingVerificationReceived) return false;
    final source = transport;
    if (!active ||
        profile != _profile ||
        (profile?.isEmpty ?? true) ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return true;
    }
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: profile,
    );
    if (binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection)) {
      return true;
    }
    final owner = (profile, thread.id),
        epoch = _activityEpoch,
        controller = _adoptBilling((profile, thread.id), binding);
    if (controller == null ||
        !_currentBilling(owner, controller, binding, epoch)) {
      return true;
    }
    controller.acceptVerification({
      'verification_url': event.details.verificationUrl,
      'user_code': event.details.userCode,
    }, attachment: binding);
    return true;
  }
}
