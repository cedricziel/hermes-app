import {
  Chip,
  HermesProvider,
  IconButton,
  Menu,
  MenuAnchor,
  type MenuItem,
} from "@hermes-app/ui";

const chatActions: Array<MenuItem | "divider"> = [
  { label: "Copy transcript", value: "copy-transcript" },
  "divider",
  { label: "Rename", value: "rename" },
  { label: "Pin", value: "pin" },
  { label: "Archive", value: "archive" },
  { label: "Delete", value: "delete", destructive: true },
];

const boards: Array<MenuItem | "divider"> = [
  { label: "Platform (12)", checked: true },
  { label: "Marketing (4)", checked: false },
  { label: "Personal (31)", checked: false },
  "divider",
  { label: "Manage boards…" },
];

const account: Array<MenuItem | "divider"> = [
  { label: "https://hermes.example.com", info: true },
  "divider",
  { label: "Appearance" },
  { label: "Notifications" },
  { label: "Sign out" },
];

const stage = {
  display: "flex",
  gap: 24,
  alignItems: "flex-start",
  padding: 16,
  borderRadius: 14,
} as const;

/** The Material popup menu: 48px rows; the board switcher's check sits before the name. */
export const Material = () => (
  <HermesProvider style={stage}>
    <Menu items={chatActions} />
    <Menu items={boards} />
    <Menu items={account} />
  </HermesProvider>
);

/** iPhone and iPad: the iOS pull-down, 44px rows, hairlines, the check trailing. */
export const AppleTouch = () => (
  <HermesProvider
    platform="apple"
    style={{ ...stage, background: "var(--h-surface-high)" }}
  >
    <Menu items={chatActions} device="touch" />
    <Menu items={boards} device="touch" />
  </HermesProvider>
);

/** The compact Mac menu: 24px rows of 13px text, the hovered row filled. */
export const AppleMac = () => (
  <HermesProvider platform="apple" style={stage}>
    <Menu items={chatActions} device="mac" />
    <Menu items={boards} device="mac" />
    <Menu items={account} device="mac" />
  </HermesProvider>
);

/** Anchored: `MenuAnchor` holds the button and the open menu; `align="end"` lines the menu up with the button's right edge, `start` with its left. */
export const Anchored = () => (
  <HermesProvider
    style={{
      ...stage,
      height: 320,
      justifyContent: "space-between",
      width: 520,
    }}
  >
    <MenuAnchor>
      <Chip icon="filter_list" label="All assignees" />
      <Menu
        align="start"
        items={[
          { label: "All assignees" },
          { label: "ada" },
          { label: "grace" },
        ]}
      />
    </MenuAnchor>
    <MenuAnchor>
      <IconButton icon="more_horiz" label="Chat actions" tone="muted" />
      <Menu align="end" items={chatActions} />
    </MenuAnchor>
  </HermesProvider>
);

export const MaterialDark = () => (
  <HermesProvider theme="dark" style={stage}>
    <Menu items={chatActions} />
    <Menu items={boards} />
  </HermesProvider>
);

export const AppleDark = () => (
  <HermesProvider platform="apple" theme="dark" style={stage}>
    <Menu items={chatActions} device="touch" />
    <Menu items={boards} device="mac" />
  </HermesProvider>
);
