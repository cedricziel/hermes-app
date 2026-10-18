import type { ToolCallItem } from "./ToolCallCard";

type Label = { name: string; text: string; preview?: string };

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

/** Resolve a display name without changing the identity used for tool results. */
export function toolCallPresentation(call: ToolCallItem) {
  const bridge = ["tool_call", "tool_search", "tool_describe"].includes(
    call.name,
  );
  let args = call.args;
  if (!args && bridge && call.input) {
    try {
      args = record(JSON.parse(call.input));
    } catch {
      /* Older plain-text input. */
    }
  }
  let tools: Label[] = call.labels?.filter((label) => label.text.trim()) ?? [];
  if (!tools.length && call.name === "tool_call") {
    const entries = Array.isArray(args?.calls)
      ? args.calls
      : args
        ? [args]
        : [];
    tools = entries
      .filter((entry) => record(entry))
      .map((entry) => {
        const target = record(entry)!;
        const name = typeof target.name === "string" ? target.name.trim() : "";
        let text = name || "Unnamed tool";
        if (name.startsWith("mcp__") || name.startsWith("connectors__")) {
          const [, source, ...action] = name.split("__");
          if (source && action.length)
            text = `${source} · ${action.join("__").replace(/_/g, " ")}`;
        }
        const arguments_ = record(target.arguments);
        const preview = ["command", "path", "query", "url", "pattern"]
          .map((key) => arguments_?.[key])
          .find(
            (value): value is string =>
              typeof value === "string" && !!value.trim(),
          );
        return { name, text, preview };
      });
  }
  const name = tools.length
    ? `${tools[0].text}${tools.length > 1 ? ` +${tools.length - 1}` : ""}`
    : ({
        tool_call: "Tool call",
        tool_search: "Search tools",
        tool_describe: "Tool details",
      }[call.name] ??
        call.name) ||
      "Tool";
  let summary = call.summary ?? "";
  if (tools.length === 1 && tools[0].preview) summary = tools[0].preview;
  else if (call.name === "tool_search" || call.name === "tool_describe") {
    const value = args?.[call.name === "tool_search" ? "queries" : "names"];
    if (typeof value === "string" && value.trim()) summary = value;
    else if (Array.isArray(value))
      summary =
        value.filter((item) => typeof item === "string").join(", ") || summary;
  }
  const entries =
    call.name === "tool_call"
      ? Array.isArray(args?.calls)
        ? args.calls
        : args
          ? [args]
          : []
      : [];
  const argumentGroups = entries.flatMap((entry, index) => {
    const arguments_ = record(record(entry)?.arguments);
    return arguments_
      ? [
          {
            title: tools[index]?.text ?? "Tool arguments",
            arguments: arguments_,
          },
        ]
      : [];
  });
  return {
    name,
    summary: summary.trim() === name ? "" : summary,
    bridge,
    tools,
    args,
    argumentGroups,
  };
}
