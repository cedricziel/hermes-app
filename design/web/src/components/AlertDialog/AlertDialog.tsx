import { useId } from "react";
import { Button } from "../Button/Button";
import { Sheet } from "../Sheet/Sheet";
import { useModalFocus } from "../../modalFocus";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./AlertDialog.css";

/** A button of an `AlertDialog`. */
export interface AlertDialogAction {
  /** The button's label: "Cancel", "Sign Out". */
  label: string;
  /**
   * The action the dialog is asking about. Apple: bold. Material: the one
   * filled button (the others are text buttons).
   */
  isDefault?: boolean;
  /** It deletes or loses something. Apple: system red. Material draws it like any other button, as the app does. */
  destructive?: boolean;
  disabled?: boolean;
  onClick?: () => void;
}

export interface AlertDialogProps {
  /** The question, short: "Sign out of the dashboard?". */
  title: string;
  /** One or two sentences under it: "You will need to sign in again to see your chats." */
  message?: string;
  /** The buttons, dismissive first and the confirming one last: Cancel, then Sign Out. */
  actions: AlertDialogAction[];
  /**
   * Apple only: stack the buttons one per row. Two buttons sit side by side
   * by default and three or more stack, as an iOS and Mac alert lays them
   * out when the labels fit.
   */
  stacked?: boolean;
  /**
   * `apple`: the iOS and Mac alert (`CupertinoAlertDialog`): a 270px panel
   * with 14px corners on a light barrier, the title (17px semibold) and
   * message (13px) centred, then full-width buttons under hairlines, in the
   * primary color. `material`: an M3 `AlertDialog` (a 28px-radius `Sheet`
   * dialog as wide as its text, a 24px title, the message muted, the buttons
   * at the bottom right). Inherits the provider's platform.
   */
  platform?: Platform;
  /** The barrier was clicked or Escape pressed (the app treats it as Cancel). */
  onDismiss?: () => void;
}

/**
 * A short question with two or three answers over a dimmed screen: the
 * app's `AppAlertDialog` and `showConfirmDialog` (sign out, delete a chat,
 * discard changes). It covers its nearest positioned ancestor, so put it
 * last inside the screen's frame (which needs `position: relative`). For a
 * form or longer content use `Sheet`.
 */
export function AlertDialog({
  title,
  message,
  actions,
  stacked,
  platform,
  onDismiss,
}: AlertDialogProps) {
  const resolved = usePlatform(platform);
  return (
    <PlatformScope platform={resolved}>
      {resolved === "apple" ? (
        <AppleAlert
          title={title}
          message={message}
          actions={actions}
          stacked={stacked ?? actions.length > 2}
          onDismiss={onDismiss}
        />
      ) : (
        <Sheet
          presentation="dialog"
          title={title}
          fitContent
          onDismiss={onDismiss}
          actions={actions.map((a) => (
            <Button
              key={a.label}
              variant={a.isDefault ? "filled" : "text"}
              disabled={a.disabled}
              onClick={a.onClick}
            >
              {a.label}
            </Button>
          ))}
        >
          {message ? (
            <p className="h-body-md h-alert-dialog__message">{message}</p>
          ) : null}
        </Sheet>
      )}
    </PlatformScope>
  );
}

function AppleAlert({
  title,
  message,
  actions,
  stacked,
  onDismiss,
}: Omit<AlertDialogProps, "platform"> & { stacked: boolean }) {
  const titleId = useId();
  const messageId = useId();
  const { ref, onKeyDown } = useModalFocus<HTMLDivElement>(onDismiss);
  return (
    <div className="h-apple-alert-overlay" onClick={onDismiss}>
      <div
        ref={ref}
        role="alertdialog"
        aria-modal
        aria-labelledby={titleId}
        aria-describedby={message ? messageId : undefined}
        tabIndex={-1}
        className="h-apple-alert"
        onClick={(e) => e.stopPropagation()}
        onKeyDown={onKeyDown}
      >
        <div className="h-apple-alert__content">
          <h2 id={titleId} className="h-apple-alert__title">
            {title}
          </h2>
          {message ? (
            <p id={messageId} className="h-apple-alert__message">
              {message}
            </p>
          ) : null}
        </div>
        <div
          className={cx(
            "h-apple-alert__actions",
            stacked && "h-apple-alert__actions--stacked",
          )}
        >
          {actions.map((a) => (
            <button
              key={a.label}
              type="button"
              disabled={a.disabled}
              className={cx(
                "h-apple-alert__action",
                a.isDefault && "h-apple-alert__action--default",
                a.destructive && "h-apple-alert__action--destructive",
              )}
              onClick={a.onClick}
            >
              {a.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
