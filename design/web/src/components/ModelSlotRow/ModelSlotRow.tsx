import { Icon } from "../Icon/Icon";
import { ListRow } from "../ListRow/ListRow";
import { Spinner } from "../Spinner/Spinner";
import { usePlatform, type Platform } from "../../platform";

/** A model a slot runs on: provider and model id, with an optional reasoning effort. */
export interface ModelChoice {
  /** Provider id: "openrouter", "openai", "anthropic". */
  provider: string;
  /** Model id within the provider: "gemini-flash". Empty means the provider's default model. */
  model: string;
  /** Reasoning effort as Hermes names it: "none", "minimal", "low", "medium", "high", "xhigh". */
  effort?: string;
}

export interface ModelSlotRowProps {
  /** The slot: a helper task ("Chat titles", "Context compression", "Vision") or a mixture-of-agents slot ("Advisor 1", "Aggregator"). */
  label: string;
  /** The model it runs on. Leave out for Hermes' `auto`: "Same as main model". */
  choice?: ModelChoice;
  /** The profile's main model id, named in "Same as main model (claude-opus-4)". */
  mainModel?: string;
  /** A mixture-of-agents advisor that is switched off: " (off)" after the label. */
  off?: boolean;
  /** The pick is being saved: a small spinner replaces the chevron and the row ignores presses. */
  saving?: boolean;
  /** The row cannot be changed here (MoA slots while Hermes' privacy filter is on). */
  disabled?: boolean;
  /** The row was pressed: open the model picker for this slot. */
  onClick?: () => void;
  /** `apple`: the iOS row (44px minimum, iOS type ramp) and spinner. Inherits the provider's platform. */
  platform?: Platform;
}

const effortLabels: Record<string, string> = {
  none: "Off",
  xhigh: "Extra High",
};

/** "model · provider · effort", or "Same as main model (x)" for `auto`, as the app's helper model list words it. */
export function describeModelChoice(choice?: ModelChoice, mainModel?: string) {
  if (!choice) {
    return mainModel
      ? `Same as main model (${mainModel})`
      : "Same as main model";
  }
  const effort = choice.effort
    ? (effortLabels[choice.effort] ??
      choice.effort.charAt(0).toUpperCase() + choice.effort.slice(1))
    : undefined;
  return [choice.model || "Provider default", choice.provider, effort]
    .filter(Boolean)
    .join(" · ");
}

/**
 * One slot of the Helper models screen: what the slot does and the model it
 * runs on ("gemini-flash · openrouter · Low"), with a chevron that opens the
 * model picker. Built on `ListRow` as a plain, full-width row on every
 * platform, as the app draws it.
 */
export function ModelSlotRow({
  label,
  choice,
  mainModel,
  off = false,
  saving = false,
  disabled = false,
  onClick,
  platform,
}: ModelSlotRowProps) {
  const resolved = usePlatform(platform);
  return (
    <ListRow
      platform={resolved}
      grouped={false}
      title={off ? `${label} (off)` : label}
      subtitle={describeModelChoice(choice, mainModel)}
      trailing={
        saving ? (
          <Spinner size={18} label="Saving" />
        ) : (
          <Icon name="chevron_right" size={24} />
        )
      }
      onClick={saving || disabled ? undefined : onClick}
    />
  );
}
