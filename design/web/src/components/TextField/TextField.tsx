import { useId } from "react";
import type { InputHTMLAttributes, TextareaHTMLAttributes } from "react";
import { Icon } from "../Icon/Icon";
import "./TextField.css";

type FieldAttrs = Omit<
  InputHTMLAttributes<HTMLInputElement> &
    TextareaHTMLAttributes<HTMLTextAreaElement>,
  "size"
>;

export interface TextFieldProps extends FieldAttrs {
  /** Label above the field. */
  label?: string;
  /** Hint below the field. Replaced by `error` when set. */
  helper?: string;
  /** Error text below the field; also turns the border red. */
  error?: string;
  /** Leading Material Symbols icon name (search fields use `search`). */
  leadingIcon?: string;
  /**
   * `outlined`: the default form field (1px border, 10px radius).
   * `search`: borderless filled field, as the Kanban and catalog search bars.
   */
  variant?: "outlined" | "search";
  /** Grow into a textarea of this many rows. */
  rows?: number;
  /** Monospace text, for commands, URLs and JSON. */
  mono?: boolean;
}

/** A labelled text input matching the app's InputDecorationTheme. */
export function TextField({
  label,
  helper,
  error,
  leadingIcon,
  variant = "outlined",
  rows,
  mono = false,
  className,
  id,
  ...rest
}: TextFieldProps) {
  const autoId = useId();
  const fieldId = id ?? autoId;
  const box = [
    "h-field__box",
    `h-field__box--${variant}`,
    error ? "h-field__box--error" : null,
  ]
    .filter(Boolean)
    .join(" ");
  const inputClass = ["h-field__input", mono ? "h-mono" : null]
    .filter(Boolean)
    .join(" ");
  return (
    <div className={["h-field", className].filter(Boolean).join(" ")}>
      {label ? (
        <label className="h-field__label" htmlFor={fieldId}>
          {label}
        </label>
      ) : null}
      <div className={box}>
        {leadingIcon ? (
          <Icon name={leadingIcon} size={20} className="h-field__icon" />
        ) : null}
        {rows ? (
          <textarea id={fieldId} rows={rows} className={inputClass} {...rest} />
        ) : (
          <input id={fieldId} className={inputClass} {...rest} />
        )}
      </div>
      {error || helper ? (
        <div className={error ? "h-field__error" : "h-field__helper"}>
          {error ?? helper}
        </div>
      ) : null}
    </div>
  );
}
