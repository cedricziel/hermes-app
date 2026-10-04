import type { CSSProperties, ReactNode } from "react";
import { cx } from "../../platform";
import "./Sheet.css";

export interface SheetProps {
  /**
   * `bottom`: Flutter's modal bottom sheet, the full width of a phone (at most
   * 640px), 28px top corners, rising from the bottom edge and as tall as its
   * content up to `maxHeight`. `dialog`: a centred 28px-radius panel 280 to
   * `width` px wide, as `Dialog` and `AlertDialog`, used from 900px wide.
   */
  presentation?: "bottom" | "dialog";
  /** `bottom` only: the 32x4 drag handle at the top (the Plugins detail sheets). The MCP sheets have none. */
  dragHandle?: boolean;
  /** Heading of an alert-style dialog or sheet, 24px: "Install from Git URL". Leave out when the content brings its own heading. */
  title?: string;
  /** Buttons at the bottom right, Cancel (`text`) before the one `filled` action. */
  actions?: ReactNode;
  /** `dialog`: the widest the panel gets, in px (560 for an alert, 520 for the command review). */
  width?: number;
  /** `bottom`: the tallest the sheet gets, as a CSS length. Default 90%, leaving the screen's top visible. */
  maxHeight?: string;
  /** Inner padding in px around the content: 24 for an alert, 0 when the content pads itself. */
  padding?: number;
  /** The scrim was clicked. */
  onDismiss?: () => void;
  /** What the sheet shows. It scrolls when it is taller than the sheet. */
  children?: ReactNode;
}

/**
 * A modal surface over a dimmed screen: a bottom sheet on a phone or a
 * dialog on a wide layout. It covers its nearest positioned ancestor, so put
 * it last inside the screen's frame (which needs `position: relative`). It
 * looks the same on every platform, as the app's Material sheets and
 * dialogs do; the controls inside follow the platform. It has no
 * open/close state: render it to show it.
 */
export function Sheet({
  presentation = "bottom",
  dragHandle = false,
  title,
  actions,
  width = 560,
  maxHeight = "90%",
  padding = 24,
  onDismiss,
  children,
}: SheetProps) {
  const dialog = presentation === "dialog";
  return (
    <div
      className={cx("h-sheet-overlay", dialog && "h-sheet-overlay--dialog")}
      onClick={onDismiss}
    >
      <div
        role="dialog"
        aria-modal
        aria-label={title}
        className={cx(
          "h-sheet",
          dialog ? "h-sheet--dialog" : "h-sheet--bottom",
        )}
        style={{
          ...(dialog ? { maxWidth: width } : { maxHeight }),
          ...({ "--h-sheet-pad": `${padding}px` } as CSSProperties),
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {!dialog && dragHandle ? (
          <div className="h-sheet__handle-area">
            <span className="h-sheet__handle" />
          </div>
        ) : null}
        <div className="h-sheet__body">
          {title ? <div className="h-sheet__title">{title}</div> : null}
          {children}
        </div>
        {actions ? <div className="h-sheet__actions">{actions}</div> : null}
      </div>
    </div>
  );
}
