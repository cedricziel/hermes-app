import { AlertDialog, HermesProvider, ListRow } from "@hermes-app/ui";
import type { AlertDialogAction } from "@hermes-app/ui";

const frame = {
  position: "relative",
  width: 800,
  height: 360,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;

const phone = { ...frame, width: 390, height: 520 } as const;

const behind = (
  <div style={{ padding: 16 }}>
    <ListRow title="Plan the Lisbon trip" subtitle="Yesterday" />
    <ListRow title="Why did the nightly backup fail?" subtitle="Today" />
    <ListRow title="Fix the flaky login test" subtitle="Friday" />
  </div>
);

const signOut: AlertDialogAction[] = [
  { label: "Cancel" },
  { label: "Sign Out", isDefault: true },
];

const deleteChat: AlertDialogAction[] = [
  { label: "Cancel" },
  { label: "Delete", isDefault: true, destructive: true },
];

const signOutText = {
  title: "Sign out of the dashboard?",
  message: "You will need to sign in again to see your chats.",
};

/** Mac (and iOS): Sign Out asks first, from the account footer's menu or the Hermes menu (#445). Centred title and message, Cancel and a bold Sign Out side by side under hairlines. */
export const AppleSignOut = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={frame}>
      {behind}
      <AlertDialog {...signOutText} actions={signOut} />
    </div>
  </HermesProvider>
);

/** Material (Android, Windows, Linux): the same question as an M3 dialog as wide as its text, Cancel as a text button before the filled Sign Out. */
export const MaterialSignOut = () => (
  <HermesProvider>
    <div style={frame}>
      {behind}
      <AlertDialog {...signOutText} actions={signOut} />
    </div>
  </HermesProvider>
);

/** iPhone: deleting a chat. The destructive answer is red and bold; Material draws it as its plain filled button. */
export const AppleDestructive = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      {behind}
      <AlertDialog
        title="Delete this chat?"
        message={
          '"Plan the Lisbon trip" and its messages will be deleted for good.'
        }
        actions={deleteChat}
      />
    </div>
  </HermesProvider>
);

/** Three answers stack one per row on Apple. */
export const AppleStacked = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      {behind}
      <AlertDialog
        title="Discard your changes?"
        message="The server list has edits you have not saved."
        actions={[
          { label: "Save", isDefault: true },
          { label: "Discard", destructive: true },
          { label: "Cancel" },
        ]}
      />
    </div>
  </HermesProvider>
);

/** Dark, Apple and Material. */
export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ display: "flex", flexDirection: "column", gap: 16, padding: 16 }}
  >
    <HermesProvider theme="dark" platform="apple" typeRamp="default">
      <div style={frame}>
        {behind}
        <AlertDialog {...signOutText} actions={signOut} />
      </div>
    </HermesProvider>
    <div style={frame}>
      {behind}
      <AlertDialog {...signOutText} actions={signOut} />
    </div>
  </HermesProvider>
);
