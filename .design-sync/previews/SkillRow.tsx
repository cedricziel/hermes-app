import { HermesProvider, SkillRow } from "@hermes-app/ui";

const pane = { width: 480 } as const;

const skills = [
  {
    name: "apple-notes",
    description: "Read Apple Notes",
    category: "apple",
    source: "bundled" as const,
    enabled: true,
    usage: 14,
  },
  {
    name: "pr-review",
    description: "Review a pull request",
    category: "github",
    source: "agent" as const,
    enabled: true,
  },
  {
    name: "compose",
    description:
      "Manage Compose stacks across the homelab hosts and their volumes",
    category: "devops",
    source: "hub" as const,
    enabled: false,
    usage: 3,
  },
];

export const Installed = () => (
  <div style={pane}>
    {skills.map((s) => (
      <SkillRow key={s.name} skill={s} />
    ))}
  </div>
);

export const Apple = () => (
  <HermesProvider platform="apple" style={{ width: 390 }}>
    {skills.map((s) => (
      <SkillRow key={s.name} skill={s} />
    ))}
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: "8px 0", borderRadius: 14 }}>
    <div style={pane}>
      {skills.map((s) => (
        <SkillRow key={s.name} skill={s} />
      ))}
    </div>
  </HermesProvider>
);
