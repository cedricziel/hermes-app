import { useId } from "react";
import {
  cx,
  useGroupedChrome,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { metricsClass } from "../../grouped";
import "./GroupedTextFieldRow.css";

export interface GroupedTextFieldRowProps {
  /** The field's name: "Name", "Prompt", "Command". */
  label: string;
  /** Placeholder text: "nightly-backup", "What should Hermes do?". On Apple a multi-line field shows the label when there is no hint. */
  hint?: string;
  /** The text (controlled). */
  value?: string;
  /** The starting text (uncontrolled). */
  defaultValue?: string;
  /** Called with the new text. */
  onChange?: (value: string) => void;
  /** Rows of a multi-line field (a prompt, a description); leave out for one line. */
  rows?: number;
  /** Sets the text in the monospace font at the footer size (13px, Mac 11px): a command, a cron expression, JSON. */
  monospace?: boolean;
  /** The input's type for a one-line field: "text" (default), "url", "number", "password". */
  type?: "text" | "url" | "number" | "password" | "email";
  disabled?: boolean;
  /** Draws the field focused, for previews. */
  autoFocus?: boolean;
  /**
   * `apple` (iOS Settings style): a one-line field sits borderless beside
   * its label (the label at the title size, the text after it); a
   * multi-line field is borderless under nothing, with `hint` or the label
   * as its placeholder. `material`: the label floats small and muted over
   * the borderless text inside the card. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` (13px, 40px rows) or `touch` (17px, 44px rows); inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * A borderless text field as a row of a `GroupedSection`: the name of a job,
 * a Kanban task's title and body, an MCP server's URL. Group a form's fields
 * into sections with headers and put help text in the section's `footer`.
 */
export function GroupedTextFieldRow({
  label,
  hint,
  value,
  defaultValue,
  onChange,
  rows,
  monospace = false,
  type = "text",
  disabled,
  autoFocus,
  platform,
  device,
}: GroupedTextFieldRowProps) {
  const chrome = useGroupedChrome(platform, device);
  const apple = chrome !== "material";
  const id = useId();
  const multiline = rows !== undefined && rows > 1;
  const common = {
    id,
    value,
    defaultValue,
    disabled,
    autoFocus,
    className: cx(
      "h-grouped-field__input",
      monospace && "h-grouped-field__input--mono",
    ),
    placeholder: apple && multiline ? (hint ?? label) : hint,
    "aria-label": apple ? label : undefined,
    onChange: (e: { target: { value: string } }) => onChange?.(e.target.value),
  };
  const input = multiline ? (
    <textarea {...common} rows={rows} />
  ) : (
    <input {...common} type={type} />
  );
  return (
    <div
      className={cx(
        "h-grouped-field",
        metricsClass(chrome),
        apple ? "h-grouped-field--apple" : "h-grouped-field--material",
        multiline && "h-grouped-field--multiline",
      )}
    >
      {apple ? (
        multiline ? null : (
          <label htmlFor={id} className="h-grouped-field__label">
            {label}
          </label>
        )
      ) : (
        <label htmlFor={id} className="h-grouped-field__float">
          {label}
        </label>
      )}
      {input}
    </div>
  );
}
