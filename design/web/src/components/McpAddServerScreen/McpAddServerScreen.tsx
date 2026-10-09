import { Banner } from "../Banner/Banner";
import { Button } from "../Button/Button";
import { IconButton } from "../IconButton/IconButton";
import {
  McpCommandReview,
  type McpCommandReviewItem,
} from "../McpCommandReview/McpCommandReview";
import { FormSection } from "../FormSection/FormSection";
import { SegmentedButton } from "../SegmentedButton/SegmentedButton";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Sheet } from "../Sheet/Sheet";
import { TextField } from "../TextField/TextField";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";
import { noop, screenDevice, ScreenFrame } from "../../screen";
import "./McpAddServerScreen.css";

/** One environment variable row of a command server. The value is drawn masked. */
export interface McpEnvRow {
  name: string;
  value: string;
  /** Shown under the name: "Use letters, digits and underscores, not starting with a digit", "Already used above". */
  error?: string;
}

const AUTHS = ["none", "bearer", "oauth"] as const;

export interface McpAddServerScreenProps {
  /** `remote`: a URL and how it signs in. `command`: a program, its arguments and environment. */
  kind?: "remote" | "command";
  name?: string;
  /** The name is taken: "A server with this name already exists" under the field. */
  nameTaken?: boolean;
  /** Remote: the address. One that is not http(s) gets "Enter an http or https address". */
  url?: string;
  /** Remote: `none`, `bearer` (a token field appears) or `oauth` (signs in later from the server's page). */
  auth?: "none" | "bearer" | "oauth";
  /** Remote, `bearer`: the token, drawn masked. */
  token?: string;
  /** Command: the program, "npx". */
  command?: string;
  /** Command: arguments, one per line. */
  args?: string;
  /** Command: environment variables. */
  env?: McpEnvRow[];
  /** The request is out: fields are read-only and the bar's Add shows a spinner. */
  saving?: boolean;
  /** Hermes refused or the request failed: a red banner at the bottom. */
  error?: string;
  /** The profile it adds to, the bar's subtitle: "work". */
  profile?: string;
  /** Draw the command review before saving: a bottom sheet on a phone, a dialog on desktop. */
  review?: McpCommandReviewItem;
  /** `phone`: the review is a bottom sheet. `desktop`: a dialog. The form is 560px wide at most either way. */
  layout?: "phone" | "desktop";
  onBack?: () => void;
  onKindChange?: (kind: "remote" | "command") => void;
  onAuthChange?: (auth: "none" | "bearer" | "oauth") => void;
  onAdd?: () => void;
  onAddVariable?: () => void;
  onRemoveVariable?: (index: number) => void;
  onConfirmReview?: () => void;
  onCancelReview?: () => void;
  /**
   * The settings bar with Add last in it. `apple` on a phone: "‹ MCP
   * servers", the title centred over the profile, Add as a 17px semibold
   * text button. `apple` + `desktop`: the Mac toolbar with a small filled
   * Add push button. `material`: the 56px bar with Add as a 16px semibold
   * text button. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

function validUrl(url: string) {
  try {
    const u = new URL(url.trim());
    return (u.protocol === "http:" || u.protocol === "https:") && !!u.host;
  } catch {
    return false;
  }
}

/**
 * The "Add server" form for a custom MCP server: a segmented choice between a
 * remote server (URL, then None / Bearer token / OAuth) and a command server
 * (command, arguments one per line, environment variables), with Add in the
 * settings bar that stays disabled until the form is complete. A command server
 * goes through `McpCommandReview` before anything is sent (`review`). Fills
 * its parent; give it a size.
 */
export function McpAddServerScreen({
  kind = "remote",
  name = "",
  nameTaken = false,
  url = "",
  auth = "none",
  token = "",
  command = "",
  args = "",
  env = [],
  saving = false,
  error,
  profile,
  review,
  layout = "phone",
  onBack,
  onKindChange,
  onAuthChange,
  onAdd,
  onAddVariable,
  onRemoveVariable,
  onConfirmReview,
  onCancelReview,
  platform,
  device,
}: McpAddServerScreenProps) {
  const resolved = usePlatform(platform);
  const remote = kind === "remote";
  const urlOk = validUrl(url);
  const urlError =
    url.trim() && !urlOk ? "Enter an http or https address" : undefined;
  const canAdd =
    !saving &&
    name.trim() !== "" &&
    (remote
      ? urlOk && (auth !== "bearer" || token.trim() !== "")
      : command.trim() !== "" && env.every((r) => r.name && !r.error));

  const form = (
    <div className="h-mcp-add">
      <div className="h-mcp-add__kind">
        <SegmentedButton
          label="Server type"
          labels={["Remote (URL)", "Command"]}
          value={remote ? 0 : 1}
          disabled={saving}
          onChange={(i) => onKindChange?.(i === 0 ? "remote" : "command")}
        />
      </div>
      <TextField
        label="Name"
        value={name}
        readOnly={saving}
        error={nameTaken ? "A server with this name already exists" : undefined}
      />
      {remote ? (
        <>
          <TextField
            label="URL"
            placeholder="https://mcp.example.com/mcp"
            value={url}
            readOnly={saving}
            error={urlError}
          />
          <FormSection titleStyle="label" title="Authentication" gap={8}>
            <SegmentedButton
              label="Authentication"
              labels={["None", "Bearer token", "OAuth"]}
              value={AUTHS.indexOf(auth)}
              disabled={saving}
              onChange={(i) => onAuthChange?.(AUTHS[i])}
            />
          </FormSection>
          {auth === "oauth" ? (
            <div className="h-body-sm h-muted">
              After adding, you sign in from the server's page.
            </div>
          ) : null}
          {auth === "bearer" ? (
            <TextField
              label="Bearer token"
              type="password"
              value={token}
              readOnly={saving}
              helper="Kept on your Hermes server. It is never shown again."
            />
          ) : null}
        </>
      ) : (
        <>
          <TextField
            label="Command"
            placeholder="npx"
            mono
            value={command}
            readOnly={saving}
          />
          <TextField
            label="Arguments (one per line)"
            mono
            rows={3}
            value={args}
            readOnly={saving}
          />
          <FormSection
            titleStyle="label"
            title="Environment variables"
            helper="Values are sent to your Hermes server once and never shown again."
            gap={8}
          >
            {env.map((row, i) => (
              <div key={i} className="h-mcp-add__env">
                <TextField
                  label="Variable name"
                  mono
                  value={row.name}
                  readOnly={saving}
                  error={row.error}
                />
                <TextField
                  label="Value"
                  type="password"
                  value={row.value}
                  readOnly={saving}
                />
                <IconButton
                  icon="close"
                  label="Remove variable"
                  disabled={saving}
                  className="h-mcp-add__env-remove"
                  onClick={() => onRemoveVariable?.(i)}
                />
              </div>
            ))}
            <div className="h-mcp-add__add-variable">
              <Button
                variant="text"
                icon="add"
                disabled={saving}
                onClick={onAddVariable}
              >
                Add variable
              </Button>
            </div>
          </FormSection>
        </>
      )}
      {error ? <Banner tone="error" icon="error" title={error} /> : null}
    </div>
  );

  return (
    <ScreenFrame platform={resolved}>
      <SettingsScaffold
        title="Add server"
        subtitle={profile}
        onBack={onBack ?? noop}
        backLabel="MCP servers"
        device={screenDevice(layout, device)}
        formAction={{
          label: "Add",
          onClick: onAdd,
          busy: saving && !review,
          disabled: !canAdd,
        }}
      >
        <div className="h-mcp-add__scroll">{form}</div>
      </SettingsScaffold>
      {review ? (
        <Sheet
          presentation={layout === "desktop" ? "dialog" : "bottom"}
          width={520}
          padding={0}
          label="Review command server"
          onDismiss={onCancelReview}
        >
          <McpCommandReview
            commands={[review]}
            confirmLabel="Add and run on server"
            onConfirm={onConfirmReview}
            onBack={onCancelReview}
          />
        </Sheet>
      ) : null}
    </ScreenFrame>
  );
}
