import { Button } from "../Button/Button";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import "./TakeoverConfirmation.css";

export interface TakeoverConfirmationProps {
  /** "Don't ask again" is on: the user will not be asked again for this account. */
  dontAskAgain?: boolean;
  /** Flip "Don't ask again". */
  onDontAskAgainChange?: (value: boolean) => void;
  /** Cancel. */
  onCancel?: () => void;
  /** Take over, with the "Don't ask again" choice. */
  onConfirm?: (dontAskAgain: boolean) => void;
}

/**
 * The question before taking over the bot's screen (`TakeoverConfirmation` in
 * the app): what taking over does (Hermes stops using the screen until you
 * hand it back, and its step may end), that what you type goes to the server's
 * desktop, and that previews and other devices hide the picture meanwhile. A
 * "Don't ask again" switch (per account) and Cancel and Take over. It is the
 * content of a bottom sheet on a phone and of a dialog on a computer: put it
 * in a `Sheet`.
 */
export function TakeoverConfirmation({
  dontAskAgain = false,
  onDontAskAgainChange,
  onCancel,
  onConfirm,
}: TakeoverConfirmationProps) {
  return (
    <div className="h-takeover">
      <h2>Take over the screen?</h2>
      <p>
        Hermes stops using the screen until you hand it back. The step it is on
        may end, and you may need to tell it to continue.
      </p>
      <p>What you type goes to the server’s desktop.</p>
      <p>
        This app’s previews and your viewers on other devices hide the picture
        meanwhile. Hermes Desktop’s live viewers may still see it.
      </p>
      <SwitchRow
        title="Don't ask again"
        checked={dontAskAgain}
        onChange={onDontAskAgainChange}
      />
      <div className="h-takeover__actions">
        <Button variant="text" onClick={onCancel}>
          Cancel
        </Button>
        <Button variant="filled" onClick={() => onConfirm?.(dontAskAgain)}>
          Take over
        </Button>
      </div>
    </div>
  );
}
