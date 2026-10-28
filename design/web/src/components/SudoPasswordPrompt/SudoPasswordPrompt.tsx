import { useState } from "react";
import { AlertDialog } from "../AlertDialog/AlertDialog";
import { TextField } from "../TextField/TextField";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./SudoPasswordPrompt.css";

export interface SudoPasswordPromptProps {
  /** The Hermes host the password is for, as the dashboard's address names it: "hermes.example.com". */
  host: string;
  /** What the field holds at first. Leave out: the app starts empty. A preview can show a filled field. */
  defaultValue?: string;
  /** Install, with the typed password. It is disabled while the field is empty. */
  onInstall?: (password: string) => void;
  /** Cancel, or the barrier or Escape: the app answers an empty value, which declines. */
  onCancel?: () => void;
  /** Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * The question Hermes asks before it installs the desktop on the server: the
 * sudo password of the server's user. The app shows it over whatever screen
 * is up, because the install outlives the chat that started it. It is the
 * platform's alert (`AlertDialog`: the iOS and Mac alert on `apple`, the M3
 * dialog on `material`) with a masked field under the message, Cancel and
 * Install. The field is a password field that tells the browser and the
 * keyboard to remember nothing; the app turns autocorrect, suggestions,
 * keyboard learning and autofill off. The password goes to the server once
 * and the app does not store it. Place it last inside a positioned frame, as
 * `AlertDialog`.
 */
export function SudoPasswordPrompt({
  host,
  defaultValue = "",
  onInstall,
  onCancel,
  platform,
}: SudoPasswordPromptProps) {
  const resolved = usePlatform(platform);
  const [value, setValue] = useState(defaultValue);
  const install = () => {
    if (!value) return;
    const password = value;
    setValue("");
    onInstall?.(password);
  };
  return (
    <PlatformScope platform={resolved}>
      <AlertDialog
        title="Sudo password"
        message={`Hermes on ${host} needs the password of its user to install the desktop. It goes to your server once and is not stored.`}
        actions={[
          { label: "Cancel", onClick: onCancel },
          {
            label: "Install",
            isDefault: true,
            disabled: !value,
            onClick: install,
          },
        ]}
        onDismiss={onCancel}
      >
        <div className="h-sudo-prompt__field">
          <TextField
            type="password"
            placeholder="Password"
            aria-label="Password"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") install();
            }}
            autoComplete="off"
            autoCorrect="off"
            autoCapitalize="off"
            spellCheck={false}
            data-lpignore="true"
            data-1p-ignore="true"
          />
        </div>
      </AlertDialog>
    </PlatformScope>
  );
}
