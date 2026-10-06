import { BusyBar } from "../BusyBar/BusyBar";
import { Button } from "../Button/Button";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./SkillJobSheet.css";

/** Where a hub job (install, update, uninstall) stands. */
export type SkillJobState = "running" | "succeeded" | "failed" | "unknown";

export interface SkillJobSheetProps {
  /** What runs: "Installing web-scraper", "Updating hub skills", "Uninstalling compose". */
  title: string;
  /** `running`: a busy bar and "Run in background". The others show the outcome and "Close": `succeeded` "Done.", `failed` the `error` in red, `unknown` a note that the result could not be confirmed. */
  state: SkillJobState;
  /** Why it failed, shown for `failed`; defaults to "It failed.". */
  error?: string;
  /** The job's log. Only the last six lines show, in monospace on an inverted panel. */
  lines?: string[];
  /** "Run in background" or "Close" was pressed: the sheet closes, a running job keeps running. */
  onClose?: () => void;
  /** Buttons follow it. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * The content of the bottom sheet a skills hub job opens in: its title, a busy
 * bar or the outcome, the tail of its log and a close button. It draws no
 * sheet chrome (drag handle, scrim); put it in the app's sheet. While it runs
 * after "Run in background", the Skills screen shows the job as a bar under
 * its tabs instead.
 */
export function SkillJobSheet({
  title,
  state,
  error,
  lines = [],
  onClose,
  platform,
}: SkillJobSheetProps) {
  const resolved = usePlatform(platform);
  const running = state === "running";
  const tail = lines.slice(-6);
  const outcome =
    state === "succeeded"
      ? "Done."
      : state === "failed"
        ? (error ?? "It failed.")
        : "The result could not be confirmed. The installed list was refreshed.";
  return (
    <PlatformScope platform={resolved}>
      <div className="h-skill-job">
        <div className="h-title-md h-skill-job__title">{title}</div>
        {running ? (
          <BusyBar label={title} />
        ) : (
          <div
            className={
              state === "succeeded"
                ? "h-body-md"
                : "h-body-md h-skill-job__outcome--error"
            }
          >
            {outcome}
          </div>
        )}
        {tail.length > 0 ? (
          <pre className="h-mono h-skill-job__log">{tail.join("\n")}</pre>
        ) : null}
        <div className="h-skill-job__actions">
          <Button variant="text" onClick={onClose}>
            {running ? "Run in background" : "Close"}
          </Button>
        </div>
      </div>
    </PlatformScope>
  );
}
