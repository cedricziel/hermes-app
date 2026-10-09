import { GroupedValueRow } from "../GroupedValueRow/GroupedValueRow";
import type { AppleDevice, Platform } from "../../platform";

/** A model a slot runs on: provider and model id, with an optional reasoning effort. */
export interface ModelChoice {
  /** Provider id: "openrouter", "openai", "anthropic". */
  provider: string;
  /** Model id within the provider: "gemini-flash", "anthropic/claude-opus-4.8". Empty means the provider's default model. */
  model: string;
  /** Reasoning effort as Hermes names it: "none", "minimal", "low", "medium", "high", "xhigh". Set in the picker, not shown on the row. */
  effort?: string;
}

export interface ModelSlotRowProps {
  /** The slot: a helper task ("Chat titles", "Context compression", "Vision") or a mixture-of-agents slot ("Advisor 1", "Aggregator"). */
  label: string;
  /** The model it runs on, shown by the last segment of its id ("claude-opus-4.8" for "anthropic/claude-opus-4.8"); "Provider default" when the model is empty. Leave out for Hermes' `auto`: "Main model". */
  choice?: ModelChoice;
  /** A mixture-of-agents advisor that is switched off: the value reads "Off". */
  off?: boolean;
  /** The pick is being saved: a spinner takes the value's place and the row ignores presses. */
  saving?: boolean;
  /** The row cannot be changed here (MoA slots while Hermes' privacy filter is on): the value shows but nothing opens. */
  disabled?: boolean;
  /** The row was pressed: open the model picker for this slot. */
  onClick?: () => void;
  /**
   * A `GroupedValueRow`. iOS: the label left, the model muted on the right
   * and a chevron. Mac: the model in a bordered pop-up button (12px, a
   * small chevron down). Material: the label over the model, no chevron.
   * Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited from `SettingsScaffold` or `GroupedSection`, else touch. */
  device?: AppleDevice;
}

/** What the dashboard calls a reasoning effort: "none" is "Off", "xhigh" "Extra High", the rest capitalised (the app's `effortLabel`). */
export function effortLabel(effort: string) {
  if (effort === "none") return "Off";
  if (effort === "xhigh") return "Extra High";
  return effort.charAt(0).toUpperCase() + effort.slice(1);
}

/** What a slot's row reads: "Main model", "Provider default", or the model id's last segment. */
function slotValue(choice?: ModelChoice) {
  if (!choice) return "Main model";
  if (!choice.model) return "Provider default";
  return choice.model.split("/").pop() ?? choice.model;
}

/**
 * One slot of the Helper models screen, as the app's helper model list
 * draws it: a value row with the slot and the short name of the model it
 * runs on, which opens the model picker. Stack rows in a `GroupedSection`.
 */
export function ModelSlotRow({
  label,
  choice,
  off = false,
  saving = false,
  disabled = false,
  onClick,
  platform,
  device,
}: ModelSlotRowProps) {
  return (
    <GroupedValueRow
      title={label}
      value={off ? "Off" : slotValue(choice)}
      busy={saving}
      onClick={disabled ? undefined : onClick}
      platform={platform}
      device={device}
    />
  );
}
