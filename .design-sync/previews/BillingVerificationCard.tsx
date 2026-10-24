import { BillingVerificationCard, HermesProvider } from "@hermes-app/ui";

const col = { width: 420, display: "flex", flexDirection: "column" } as const;

const details = {
  userCode: "EXAMPLE-CODE",
  verificationUrl: "https://billing.example.com/verify",
};

/** Reference state: nothing asked yet. A collapsed tile and the one filled action. */
export const Optional = () => (
  <div style={col}>
    <BillingVerificationCard onStart={() => {}} />
  </div>
);

/** Needs you: a code is waiting. Collapsed (status pending) and opened with the code, the page's host and Copy code / Open verification. */
export const NeedsYou = () => (
  <div style={col}>
    <BillingVerificationCard
      status="pending"
      verification={details}
      canStart={false}
    />
    <BillingVerificationCard
      status="pending"
      verification={details}
      defaultOpen
      canStart={false}
      onCopyCode={() => {}}
      onOpenVerification={() => {}}
    />
  </div>
);

/** An address the app will not open (plain http): the host line is replaced by "Browser opening unavailable." and Open verification is disabled. */
export const UnsafeDestination = () => (
  <div style={col}>
    <BillingVerificationCard
      status="pending"
      defaultOpen
      canStart={false}
      verification={{
        userCode: "EXAMPLE-CODE",
        verificationUrl: "http://billing.example.com/verify",
      }}
    />
  </div>
);

/** App Lock hides the code and asks to unlock; settled outcomes with the server's message and delay. */
export const LockedAndSettled = () => (
  <div style={col}>
    <BillingVerificationCard
      status="pending"
      defaultOpen
      locked
      canStart={false}
    />
    <BillingVerificationCard
      status="refused"
      defaultOpen
      message="The server did not grant billing access."
      retryPending
      canStart={false}
    />
    <BillingVerificationCard status="granted" />
  </div>
);

/** The server cannot verify on this connection: the tile says so and the action stays off. */
export const Unavailable = () => (
  <div style={col}>
    <BillingVerificationCard
      status="unavailable"
      defaultOpen
      canStart={false}
      message="Billing verification is unavailable on this connection."
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", padding: 16, borderRadius: 14 }}
  >
    <div style={{ ...col, padding: 8 }}>
      <BillingVerificationCard
        status="pending"
        verification={details}
        defaultOpen
        canStart={false}
      />
    </div>
  </HermesProvider>
);
