import type { ButtonHTMLAttributes } from "react";
import { Icon } from "../Icon/Icon";
import "./ModelPill.css";

export interface ModelPillProps extends Omit<
  ButtonHTMLAttributes<HTMLButtonElement>,
  "children"
> {
  /** Model id the chat runs on, e.g. `claude-opus-4`. Long ids are cut with an ellipsis. Without it the pill shows `placeholder`. */
  model?: string;
  /** Reasoning effort label shown after a dot in the muted color: `Off`, `Minimal`, `Low`, `Medium`, `High`, `Extra High`. Leave out when the model has none. */
  effort?: string;
  /** Text when no model is picked: `Choose a model` (default), or `Profile default` where the caller can go back to the profile's model. */
  placeholder?: string;
}

/**
 * The quiet pill in the chat composer's bottom row naming the chat's model and
 * reasoning effort ("claude-opus-4 · Medium ⌄"); pressing it opens the model
 * picker. Also used in the Kanban task form.
 */
export function ModelPill({
  model,
  effort,
  placeholder = "Choose a model",
  className,
  type = "button",
  ...rest
}: ModelPillProps) {
  return (
    <button
      type={type}
      className={["h-model-pill", className].filter(Boolean).join(" ")}
      {...rest}
    >
      <span className="h-model-pill__model">{model ?? placeholder}</span>
      {effort ? (
        <span className="h-model-pill__effort">{` · ${effort}`}</span>
      ) : null}
      <Icon name="expand_more" size={16} className="h-model-pill__chevron" />
    </button>
  );
}
