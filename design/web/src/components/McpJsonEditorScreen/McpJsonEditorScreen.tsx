import { Banner } from "../Banner/Banner";
import {
  McpCommandReview,
  type McpCommandReviewItem,
} from "../McpCommandReview/McpCommandReview";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Sheet } from "../Sheet/Sheet";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";
import { noop, screenDevice, ScreenFrame, ScreenState } from "../../screen";
import "./McpJsonEditorScreen.css";

export interface McpJsonEditorScreenProps {
  /** The profile's whole `mcp_servers` map as indented JSON, secrets included. */
  text?: string;
  /** The profile, in the bar's subtitle "work · mcp_servers". */
  profile?: string;
  /** `loading`: a centred spinner. `failed`: "Could not load the configuration" with Retry. */
  state?: "loaded" | "loading" | "failed";
  /** The text differs from what was loaded; Save needs it. */
  dirty?: boolean;
  /** The text is not valid: the parse error in red under the field ("Expected ',' at line 4"). Save stays disabled. */
  invalid?: string;
  /** Hermes refused the save: one red line per problem. */
  problems?: string[];
  /** The save failed: "Could not save". */
  failure?: string;
  /** The save is out: the bar's Save shows a spinner and the text is read-only. */
  saving?: boolean;
  /** Draw the review of new or changed command servers before saving. */
  review?: McpCommandReviewItem[];
  /** `phone`: the review is a bottom sheet. `desktop`: a dialog. */
  layout?: "phone" | "desktop";
  onBack?: () => void;
  onTextChange?: (text: string) => void;
  onSave?: () => void;
  onRetry?: () => void;
  onConfirmReview?: () => void;
  onCancelReview?: () => void;
  /**
   * The settings bar with Save last in it (left out while loading).
   * `apple` on a phone: "‹ MCP servers" and Save as a 17px semibold text
   * button. `apple` + `desktop`: the Mac toolbar with a small filled Save
   * push button. `material`: the 56px bar with Save as a 16px semibold
   * text button. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * Edits the profile's whole `mcp_servers` map as JSON and replaces it on
 * Save: a warning that this replaces every server and holds secrets, then a
 * monospace editor that fills the screen, with parse errors and Hermes'
 * problems under it. New or changed command servers go through
 * `McpCommandReview` first (`review`). Fills its parent; give it a size.
 */
export function McpJsonEditorScreen({
  text = "",
  profile,
  state = "loaded",
  dirty = false,
  invalid,
  problems = [],
  failure,
  saving = false,
  review,
  layout = "phone",
  onBack,
  onTextChange,
  onSave,
  onRetry,
  onConfirmReview,
  onCancelReview,
  platform,
  device,
}: McpJsonEditorScreenProps) {
  const resolved = usePlatform(platform);
  const loaded = state === "loaded";
  const canSave = loaded && dirty && !invalid && !saving && !review;
  const body =
    state !== "loaded" ? (
      <ScreenState
        state={state}
        failedTitle="Could not load the configuration"
        onRetry={onRetry}
      />
    ) : (
      <div className="h-mcp-json">
        <Banner
          tone="warning"
          icon="warning"
          title="Replaces all servers of this profile."
          detail="Anything you remove here is deleted, not just switched off. This is the profile's real configuration, including secrets such as environment values and bearer tokens. It is not saved on this device."
        />
        <textarea
          className="h-mcp-json__text"
          aria-label="mcp_servers JSON"
          spellCheck={false}
          value={text}
          readOnly={saving || Boolean(review)}
          onChange={(e) => onTextChange?.(e.target.value)}
        />
        {[invalid, ...problems, failure].filter(Boolean).map((line, i) => (
          <div key={i} className="h-mcp-json__error">
            {line}
          </div>
        ))}
      </div>
    );
  return (
    <ScreenFrame platform={resolved}>
      <SettingsScaffold
        title="Edit as JSON"
        subtitle={[profile, "mcp_servers"].filter(Boolean).join(" · ")}
        onBack={onBack ?? noop}
        backLabel="MCP servers"
        device={screenDevice(layout, device)}
        formAction={
          state === "loading"
            ? undefined
            : {
                label: "Save",
                onClick: onSave,
                busy: saving && !review,
                disabled: !canSave,
              }
        }
      >
        {body}
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
            commands={review}
            confirmLabel="Save and run on server"
            onConfirm={onConfirmReview}
            onBack={onCancelReview}
          />
        </Sheet>
      ) : null}
    </ScreenFrame>
  );
}
