import {
  GroupedChoiceRow,
  GroupedDialog,
  GroupedDialogNote,
  GroupedRow,
  GroupedSection,
  GroupedSwitchRow,
  HermesProvider,
} from "@hermes-app/ui";

const noop = () => {};

const notifications = (
  <>
    <GroupedSection footer="When a reply finishes or Hermes needs you, while the app is not in front.">
      <GroupedSwitchRow
        title="Notify me"
        warning="Turn on notifications for Hermes in system settings."
        checked
        onChange={noop}
      />
    </GroupedSection>
    <GroupedSection footer="When a scheduled task finishes or fails, while the app is open.">
      <GroupedSwitchRow title="Scheduled tasks" checked onChange={noop} />
    </GroupedSection>
    <GroupedDialogNote>
      Alerts arrive while Hermes is running, including for a short time after
      you leave it.
    </GroupedDialogNote>
  </>
);

const screen = {
  position: "relative",
  width: 390,
  height: 560,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;

/** Notifications on iPhone: the dialog over the dimmed screen, title centred with Done. */
export const IPhone = () => (
  <HermesProvider platform="apple">
    <div style={screen}>
      <GroupedDialog title="Notifications" onDone={noop}>
        {notifications}
      </GroupedDialog>
    </div>
  </HermesProvider>
);

/** Notifications on a Mac (inline): a 44px title bar with a 13px bold title and Done, the Mac's compact rows and small toggles. */
export const Mac = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    style={{ width: 460, padding: 16, background: "var(--h-surface-high)" }}
  >
    <GroupedDialog title="Notifications" device="mac" inline onDone={noop}>
      {notifications}
    </GroupedDialog>
  </HermesProvider>
);

/** Appearance on Material: the title at the leading edge, no Done, radio choices. */
export const Material = () => (
  <HermesProvider>
    <div style={screen}>
      <GroupedDialog title="Appearance" onDone={noop}>
        <GroupedSection header="Theme" dividerIndent="choice">
          <GroupedChoiceRow title="System" checked />
          <GroupedChoiceRow title="Light" />
          <GroupedChoiceRow title="Dark" />
        </GroupedSection>
        <GroupedSection>
          <GroupedSwitchRow title="Show reasoning" checked onChange={noop} />
        </GroupedSection>
      </GroupedDialog>
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ display: "flex", gap: 16 }}>
    <HermesProvider theme="dark" platform="apple">
      <div style={screen}>
        <GroupedDialog title="About" onDone={noop}>
          <GroupedSection>
            <GroupedRow title="Version" value="0.1.55" />
            <GroupedRow title="Server" value="hermes.local" />
          </GroupedSection>
          <GroupedSection>
            <GroupedRow title="Licenses" onClick={noop} />
          </GroupedSection>
        </GroupedDialog>
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={{ ...screen, width: 380 }}>
        <GroupedDialog title="Notifications" onDone={noop}>
          {notifications}
        </GroupedDialog>
      </div>
    </HermesProvider>
  </HermesProvider>
);
