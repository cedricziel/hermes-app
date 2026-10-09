/**
 * Internal: the MCP screens' share of Flutter's `mcp_presentation.dart`.
 * Not exported from the package.
 */

export function mcpPlural(n: number, noun: string) {
  return `${n} ${noun}${n === 1 ? "" : "s"}`;
}

/** "Remote" or "Command", then how it signs in ("No auth" for a remote server without one). */
export function mcpFacts(server: {
  transport: "remote" | "command";
  auth?: string;
}) {
  const auth =
    server.auth || (server.transport === "remote" ? "No auth" : undefined);
  return [server.transport === "remote" ? "Remote" : "Command", auth].filter(
    (f): f is string => Boolean(f),
  );
}

/** A tool schema's size: "840 chars", "2.4k chars". */
export function mcpSchemaSize(chars: number) {
  return chars < 1000
    ? `${chars} chars`
    : `${(chars / 1000).toFixed(1)}k chars`;
}
