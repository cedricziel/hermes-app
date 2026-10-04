import { HermesProvider, Icon } from "@hermes-app/ui";

const row = {
  display: "flex",
  gap: 16,
  alignItems: "center",
  flexWrap: "wrap",
} as const;

const everyday = [
  "chat_bubble",
  "view_kanban",
  "schedule",
  "extension",
  "dns",
  "search",
  "more_vert",
  "delete",
  "edit",
  "attach_file",
];

export const Outlined = () => (
  <div style={row}>
    {everyday.map((name) => (
      <Icon key={name} name={name} />
    ))}
  </div>
);

export const Apple = () => (
  <div style={row}>
    {everyday.map((name) => (
      <Icon key={name} name={name} platform="apple" />
    ))}
  </div>
);

const filledSet = (platform?: "apple") => (
  <div style={row}>
    <Icon
      name="check_circle"
      filled
      color="var(--h-success)"
      platform={platform}
    />
    <Icon name="error" filled color="var(--h-error)" platform={platform} />
    <Icon name="warning" filled color="var(--h-warning)" platform={platform} />
    <Icon name="push_pin" filled platform={platform} />
    <Icon name="chat_bubble" filled platform={platform} />
  </div>
);

export const Filled = () => filledSet();

export const AppleFilled = () => filledSet("apple");

/** `apple` names a Cupertino glyph outright, `apple={false}` keeps Material; `settings` has no pair in the app, so it stays Material too. */
export const AppleOverrides = () => (
  <HermesProvider platform="apple">
    <div style={row}>
      <Icon name="arrow_back" apple="back" color="var(--h-primary)" />
      <Icon name="check" apple="checkmark" />
      <Icon name="expand_more" apple={false} />
      <Icon name="content_copy" apple={false} size={18} />
      <Icon name="settings" />
    </div>
  </HermesProvider>
);

export const Sizes = () => (
  <div style={row}>
    {(["material", "apple"] as const).flatMap((platform) =>
      [16, 20, 24, 40].map((size) => (
        <Icon
          key={`${platform}-${size}`}
          name="auto_awesome"
          size={size}
          platform={platform}
        />
      )),
    )}
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={row}>
      <Icon name="chat_bubble" />
      <Icon name="view_kanban" />
      <Icon name="check_circle" filled color="var(--h-success)" />
    </div>
  </HermesProvider>
);

export const AppleDark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    style={{ padding: 16, borderRadius: 14 }}
  >
    <div style={row}>
      <Icon name="chat_bubble" />
      <Icon name="view_kanban" />
      <Icon name="check_circle" filled color="var(--h-success)" />
      <Icon name="more_vert" />
    </div>
  </HermesProvider>
);
