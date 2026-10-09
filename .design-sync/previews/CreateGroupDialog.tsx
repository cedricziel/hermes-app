import { CreateGroupDialog, HermesProvider } from "@hermes-app/ui";

const members = [
  { name: "writer", title: "Editor" },
  { name: "research", title: "Researcher" },
  { name: "analyst", title: "Analyst" },
];

const frame = {
  position: "relative",
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;
const mac = { ...frame, width: 720, height: 560 } as const;
const row = { display: "flex", gap: 16, alignItems: "flex-start" } as const;

/** iPhone: nothing picked yet, so Create is disabled; trailing blue checks once picked. Beside it two bots picked and a name typed. */
export const IPhone = () => (
  <HermesProvider platform="apple" style={row}>
    <div style={frame}>
      <CreateGroupDialog members={members} />
    </div>
    <div style={frame}>
      <CreateGroupDialog
        members={members}
        name="Pricing"
        selected={["writer", "analyst"]}
      />
    </div>
  </HermesProvider>
);

/** Mac: the toolbar search field above compact rows; the create failed, so the button reads Retry. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <CreateGroupDialog
        members={members}
        name="Pricing"
        selected={["writer", "research"]}
        error="Could not create the group. Check the connection and retry."
        device="mac"
      />
    </div>
  </HermesProvider>
);

/** Material: leading checkboxes; light while creating, dark with a search that matches nothing. */
export const Material = () => (
  <div style={row}>
    <HermesProvider>
      <div style={frame}>
        <CreateGroupDialog
          members={members}
          name="Pricing"
          selected={["writer", "research", "analyst"]}
          pending
        />
      </div>
    </HermesProvider>
    <HermesProvider theme="dark">
      <div style={frame}>
        <CreateGroupDialog members={members} query="ops" />
      </div>
    </HermesProvider>
  </div>
);
