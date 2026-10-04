import { HermesProvider, Icon, SwipeActions } from "@hermes-app/ui";

const Row = ({ title, meta }: { title: string; meta: string }) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      gap: 12,
      minHeight: 44,
      padding: "8px 16px",
      background: "var(--h-surface)",
      borderBottom: "0.5px solid var(--h-border)",
    }}
  >
    <Icon name="schedule" size={20} color="var(--h-muted)" />
    <div style={{ flex: 1, minWidth: 0 }}>
      <div className="h-body-lg">{title}</div>
      <div className="h-body-sm h-muted">{meta}</div>
    </div>
  </div>
);

const list = {
  width: 390,
  borderRadius: 14,
  overflow: "hidden",
  border: "1px solid var(--h-border)",
} as const;

const remove = [{ label: "Delete", icon: "delete" }];
const pin = [{ label: "Pin", icon: "push_pin", color: "orange" as const }];

/** iPhone: the first row swiped from the trailing edge shows Delete in red, the second from the leading edge shows Pin in orange (chats only), the third is closed. */
export const AppleTouch = () => (
  <HermesProvider platform="apple" style={list}>
    <SwipeActions actions={remove} revealed>
      <Row title="Morning brief" meta="Every day at 07:30" />
    </SwipeActions>
    <SwipeActions actions={remove} leadingActions={pin} revealed="leading">
      <Row title="Fix the flaky login test" meta="Yesterday" />
    </SwipeActions>
    <SwipeActions actions={remove}>
      <Row title="Dependency audit" meta="Mondays at 09:00" />
    </SwipeActions>
  </HermesProvider>
);

export const AppleTouchDark = () => (
  <HermesProvider platform="apple" theme="dark" style={list}>
    <SwipeActions actions={[{ label: "Remove", icon: "delete" }]} revealed>
      <Row title="grafana" meta="Remote · OAuth · 4 tools" />
    </SwipeActions>
    <SwipeActions actions={remove} leadingActions={pin} revealed="leading">
      <Row title="Draft the release notes" meta="2 days ago" />
    </SwipeActions>
  </HermesProvider>
);

/** A Mac and Material draw the row unchanged, even with `revealed`: there is no swipe there. */
export const MacAndMaterial = () => (
  <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
    <HermesProvider platform="apple" style={list}>
      <SwipeActions actions={remove} revealed device="mac">
        <Row title="Morning brief" meta="Mac: right-click opens the menu" />
      </SwipeActions>
    </HermesProvider>
    <HermesProvider style={list}>
      <SwipeActions actions={remove} revealed>
        <Row title="Morning brief" meta="Material: the row's own controls" />
      </SwipeActions>
    </HermesProvider>
  </div>
);
