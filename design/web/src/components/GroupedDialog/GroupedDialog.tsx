import { useId, type ReactNode } from "react";
import { useModalFocus } from "../../modalFocus";
import {
  cx,
  DeviceScope,
  PlatformScope,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { metricsClass } from "../../grouped";
import "./GroupedDialog.css";

export interface GroupedDialogProps {
  /** The dialog's name: "Notifications", "Appearance", "App lock", "About". */
  title: string;
  /** `GroupedSection`s, and any `GroupedDialogNote` between or after them. */
  children?: ReactNode;
  /** Apple: the Done button in the title bar was pressed. Material (no Done): the barrier was clicked or Escape pressed. */
  onDone?: () => void;
  /** Draw the dialog alone, without the dimmed barrier over its parent, for a catalog cell. */
  inline?: boolean;
  /**
   * The dialog's panel is the page background with the groups on it.
   * `apple` + `touch`: at most 400px wide, 14px corners, a 52px title bar
   * with the title centred (17px semibold) and Done (17px semibold) at the
   * trailing edge. `apple` + `mac`: at most 460px, 10px corners, a 44px
   * bar with a 13px bold title and Done. `material`: at most 560px, 28px
   * corners, the title at the leading edge (18px semibold), no Done. The
   * groups keep the platform's gutter. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * A small settings dialog whose content is grouped sections: the app's
 * Notifications, Appearance, App lock, About and Settings dialogs. It
 * covers its nearest positioned ancestor with a dimmed barrier, so put it
 * last inside the screen's frame (`position: relative`), or pass `inline`.
 */
export function GroupedDialog({
  title,
  children,
  onDone,
  inline = false,
  platform,
  device,
}: GroupedDialogProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  const titleId = useId();
  const { ref, onKeyDown } = useModalFocus<HTMLDivElement>(
    inline ? undefined : onDone,
  );
  const panel = (
    <div
      ref={inline ? undefined : ref}
      role="dialog"
      aria-modal={!inline || undefined}
      aria-labelledby={titleId}
      tabIndex={-1}
      className={cx(
        "h-grouped-dialog",
        `h-grouped-dialog--${chrome}`,
        metricsClass(chrome),
      )}
      onClick={(e) => e.stopPropagation()}
      onKeyDown={inline ? undefined : onKeyDown}
    >
      <div className="h-grouped-dialog__bar">
        <h2 id={titleId} className="h-grouped-dialog__title">
          {title}
        </h2>
        {chrome !== "material" ? (
          <button
            type="button"
            className="h-grouped-dialog__done"
            onClick={onDone}
          >
            Done
          </button>
        ) : null}
      </div>
      <div className="h-grouped-dialog__body">{children}</div>
    </div>
  );
  return (
    <PlatformScope platform={resolved}>
      <DeviceScope device={device}>
        {inline ? (
          panel
        ) : (
          <div
            className={cx(
              "h-grouped-dialog-overlay",
              chrome !== "material" && "h-grouped-dialog-overlay--apple",
              chrome === "mac" && "h-grouped-dialog-overlay--mac",
            )}
            onClick={onDone}
          >
            {panel}
          </div>
        )}
      </DeviceScope>
    </PlatformScope>
  );
}

export interface GroupedDialogNoteProps {
  /** The paragraph: "Alerts arrive while Hermes is running, including for a short time after you leave it." */
  children?: ReactNode;
  platform?: Platform;
  device?: AppleDevice;
}

/** A muted paragraph between or after the groups of a `GroupedDialog`, set like a section's footer with half a section gap above. */
export function GroupedDialogNote({
  children,
  platform,
  device,
}: GroupedDialogNoteProps) {
  const chrome = useGroupedChrome(platform, device);
  return (
    <p className={cx("h-grouped-dialog-note", metricsClass(chrome))}>
      {children}
    </p>
  );
}
