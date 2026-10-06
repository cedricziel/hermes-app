import { Banner } from "../Banner/Banner";
import { Button } from "../Button/Button";
import { Card } from "../Card/Card";
import { FactList, type Fact } from "../FactList/FactList";
import "./McpCommandReview.css";

/** A command server about to be saved, as the review lists it. Values of environment variables are never shown. */
export interface McpCommandReviewItem {
  /** Server name: "notes-fs". */
  name: string;
  /** The program: "npx". */
  command: string;
  /** Each argument, one line each. */
  args?: string[];
  /** The directory it starts in, when the entry sets one. */
  cwd?: string;
  /** Names of its environment variables, never their values. */
  envNames?: string[];
}

export interface McpCommandReviewProps {
  /** The command servers to confirm. More than one changes the wording to plural (the JSON editor's save). */
  commands: McpCommandReviewItem[];
  /** The filled confirm button: "Add and run on server" (Add server form) or "Save and run on server" (JSON editor). */
  confirmLabel: string;
  /** The confirm button. */
  onConfirm?: () => void;
  /** "Back to edit": nothing is sent. */
  onBack?: () => void;
}

/**
 * The step before a command server is saved: it says the server is a
 * program that runs on the Hermes host, shows the exact command, each
 * argument, the start directory and the variable names, warns to add only
 * commands you recognise, and asks to confirm. It is the content of a
 * `Sheet`: a bottom sheet on a phone (`padding={0}`) and a 520px dialog from
 * 900px. `McpAddServerScreen` and `McpJsonEditorScreen` show it with
 * `review`.
 */
export function McpCommandReview({
  commands,
  confirmLabel,
  onConfirm,
  onBack,
}: McpCommandReviewProps) {
  const many = commands.length > 1;
  return (
    <div className="h-mcp-review">
      <div className="h-title-lg">
        {many ? "Run these on your server?" : "Run this on your server?"}
      </div>
      <div className="h-body-md">
        {many
          ? "Command servers are programs that run on your Hermes host, with that machine's permissions, every time a chat uses them."
          : "A command server is a program that runs on your Hermes host, with that machine's permissions, every time a chat uses it."}
      </div>
      {commands.map((c) => {
        const facts: Fact[] = [{ label: "command", value: c.command }];
        if (c.args?.length) facts.push({ label: "args", value: c.args });
        if (c.cwd) facts.push({ label: "cwd", value: c.cwd });
        if (c.envNames?.length) facts.push({ label: "env", value: c.envNames });
        return (
          <Card key={c.name} padding={12}>
            <div className="h-title-sm h-mcp-review__name">{c.name}</div>
            <FactList labelWidth={72} facts={facts} />
          </Card>
        );
      })}
      <Banner
        tone="warning"
        icon="warning"
        title="Only add commands you recognise."
        detail="You can remove the server afterwards, but not undo what it ran."
      />
      <div className="h-mcp-review__buttons">
        <Button fullWidth onClick={onConfirm}>
          {confirmLabel}
        </Button>
        <Button variant="text" fullWidth onClick={onBack}>
          Back to edit
        </Button>
      </div>
    </div>
  );
}
