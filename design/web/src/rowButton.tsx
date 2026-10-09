import { Spinner } from "./components/Spinner/Spinner";
import { cx, useGroupedChrome, type AppleDevice } from "./platform";
import "./rowButton.css";

/**
 * Internal: a grouped row's small trailing button (the app's
 * `InstallButton`, the Mac "Check for Updates"): a tinted 28px pill on iOS,
 * a bordered 22px push button on a Mac, an outlined 32px pill on Material.
 * Spins while `busy`.
 */
export function RowButton({
  label,
  busyLabel = label,
  ariaLabel,
  busy = false,
  disabled = false,
  onClick,
  device,
}: {
  label: string;
  /** The spinner's name while busy: "Installing". */
  busyLabel?: string;
  /** A fuller accessible name: "Install rss-reader". */
  ariaLabel?: string;
  busy?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  device?: AppleDevice;
}) {
  const chrome = useGroupedChrome(undefined, device);
  return (
    <button
      type="button"
      className={cx("h-row-button", `h-row-button--${chrome}`)}
      aria-label={ariaLabel}
      disabled={busy || disabled}
      onClick={onClick}
    >
      {busy ? (
        <Spinner size={chrome === "mac" ? 12 : 16} label={busyLabel} />
      ) : (
        label
      )}
    </button>
  );
}
