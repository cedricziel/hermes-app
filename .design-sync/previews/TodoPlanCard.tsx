import { HermesProvider, TodoPlanCard } from "@hermes-app/ui";

const col = { width: 640 } as const;

const tasks = [
  { content: "Review the change", status: "completed" },
  { content: "Implement the change", status: "in_progress" },
  { content: "Verify the change", status: "pending" },
] as const;

export const Compact = () => (
  <div style={col}>
    <TodoPlanCard items={[...tasks]} />
  </div>
);

export const Expanded = () => (
  <div style={col}>
    <TodoPlanCard items={[...tasks]} defaultOpen />
  </div>
);

export const Nested = () => (
  <div style={col}>
    <TodoPlanCard
      defaultOpen
      items={[
        { content: "Draft the daily brief", status: "in_progress" },
        {
          content: "List the agents it oversees",
          status: "completed",
          nested: true,
        },
        {
          content: "Skip the weekend digest",
          status: "cancelled",
          nested: true,
        },
        { content: "Schedule the brief", status: "pending" },
      ]}
    />
  </div>
);

export const UnsupportedTask = () => (
  <div style={col}>
    <TodoPlanCard items={[tasks[0], null]} defaultOpen />
  </div>
);

export const LongTask = () => (
  <div style={{ width: 360 }}>
    <TodoPlanCard
      defaultOpen
      items={[
        {
          content:
            "Read the reported task details without changing the server plan. This longer entry demonstrates wrapping on narrow conversation windows.",
          status: "in_progress",
        },
      ]}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ padding: 16, borderRadius: 14, width: 640 }}
  >
    <TodoPlanCard items={[...tasks]} defaultOpen />
  </HermesProvider>
);
