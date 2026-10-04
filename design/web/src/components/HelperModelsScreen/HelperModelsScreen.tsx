import { Button } from "../Button/Button";
import { ModelSlotRow, type ModelChoice } from "../ModelSlotRow/ModelSlotRow";
import { SectionHeader } from "../SectionHeader/SectionHeader";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import type { AppleDevice, Platform } from "../../platform";
import "./HelperModelsScreen.css";

/** One of Hermes' side jobs and the model it runs on. */
export interface HelperSlot {
  /** Hermes' task key: "vision", "title_generation", "compression", "approval". */
  task: string;
  /** What the app calls it: "Vision", "Chat titles", "Context compression", "Approval checks". */
  label: string;
  /** The model. Leave out for `auto`, the main model. */
  choice?: ModelChoice;
  /** Its new pick is being saved. */
  saving?: boolean;
}

/** One slot of the mixture-of-agents preset: an advisor or the aggregator. */
export interface MoaSlot {
  key: string;
  /** "Advisor 1", "Advisor 2", "Aggregator". */
  label: string;
  choice: ModelChoice;
  /** An advisor switched off in the preset: " (off)". Default true. */
  enabled?: boolean;
  saving?: boolean;
}

/** The default mixture-of-agents preset. */
export interface MoaSetup {
  /** Preset name; anything but "default" shows in the heading ("Mixture of agents · cheap"). */
  preset: string;
  slots: MoaSlot[];
  /** Hermes' privacy filter is on: a note says to change the slots on the server, and they cannot be pressed. */
  privacyFilterOn?: boolean;
}

export interface HelperModelsScreenProps {
  /** The profile's helper task slots. */
  slots?: HelperSlot[];
  /** The main model id, named by `auto` slots: "Same as main model (claude-opus-4)". */
  mainModel?: string;
  /** The mixture of agents section. Leave out when Hermes reports none (the section is not drawn). */
  moa?: MoaSetup;
  /** `loaded` (default), `loading` (a spinner) or `failed` ("Could not load the helper models" with Retry). */
  state?: "loaded" | "loading" | "failed";
  /** A helper slot was pressed: the app opens the model picker with "Use the profile's default". */
  onOpenSlot?: (task: string) => void;
  /** A mixture-of-agents slot was pressed. */
  onOpenMoaSlot?: (key: string) => void;
  onRetry?: () => void;
  onBack?: () => void;
  /** `phone` or `desktop`; the list stays in a 640px column. */
  layout?: ScreenLayout;
  /** `apple`: chevron back with "Chat", iOS rows and spinners. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * Helper models, pushed from the chat sidebar: which model each of Hermes'
 * side jobs runs on, one `ModelSlotRow` per slot, and below them the
 * "Mixture of agents" advisors and aggregator under a `SectionHeader`. A
 * slot saves when its picker closes, showing a spinner meanwhile; changes
 * apply to new chats.
 */
export function HelperModelsScreen({
  slots = [],
  mainModel,
  moa,
  state = "loaded",
  onOpenSlot,
  onOpenMoaSlot,
  onRetry,
  onBack,
  layout = "phone",
  platform,
  device,
}: HelperModelsScreenProps) {
  return (
    <ScreenFrame
      title="Helper models"
      onBack={onBack}
      backLabel="Chat"
      layout={layout}
      platform={platform}
      device={device}
      state={state}
      loadingLabel="Loading helper models"
      failedTitle="Could not load the helper models"
      onRetry={onRetry}
    >
      <div className="h-helper-models">
        <div className="h-body-sm h-muted h-helper-models__intro">
          Hermes runs side jobs on these models. Changes apply to new chats.
        </div>
        {slots.map((slot) => (
          <ModelSlotRow
            key={slot.task}
            label={slot.label}
            choice={slot.choice}
            mainModel={mainModel}
            saving={slot.saving}
            onClick={() => onOpenSlot?.(slot.task)}
          />
        ))}
        {moa ? (
          <>
            <SectionHeader
              title={
                moa.preset === "default"
                  ? "Mixture of agents"
                  : `Mixture of agents · ${moa.preset}`
              }
              caption={
                moa.privacyFilterOn
                  ? "Hermes’ privacy filter is on, and saving here would turn it off. Change these slots on the server."
                  : undefined
              }
            />
            {moa.slots.map((slot) => (
              <ModelSlotRow
                key={slot.key}
                label={slot.label}
                choice={slot.choice}
                off={slot.enabled === false}
                saving={slot.saving}
                disabled={moa.privacyFilterOn}
                onClick={() => onOpenMoaSlot?.(slot.key)}
              />
            ))}
          </>
        ) : null}
      </div>
    </ScreenFrame>
  );
}
