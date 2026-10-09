import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedValueRow } from "../GroupedValueRow/GroupedValueRow";
import { ModelSlotRow, type ModelChoice } from "../ModelSlotRow/ModelSlotRow";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";
import { noop, ScreenFrame, ScreenState } from "../../screen";

/** One of Hermes' side jobs and the model it runs on. */
export interface HelperSlot {
  /** Hermes' task key: "vision", "title_generation", "compression", "approval". */
  task: string;
  /** What the app calls it: "Vision", "Chat titles", "Context compression", "Approval checks". */
  label: string;
  /** The model. Leave out for `auto`, the main model ("Main model"). */
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
  /** An advisor switched off in the preset: its value reads "Off". Default true. */
  enabled?: boolean;
  saving?: boolean;
}

/** The default mixture-of-agents preset. */
export interface MoaSetup {
  /** Preset name, the value of the group's Preset row ("default" reads "Default"). */
  preset: string;
  slots: MoaSlot[];
  /** Hermes' privacy filter is on: the group's footer says to change the slots on the server, and they cannot be pressed. */
  privacyFilterOn?: boolean;
}

export interface HelperModelsScreenProps {
  /** The profile's helper task slots. */
  slots?: HelperSlot[];
  /** The main model id, named by its last segment in the slots' footer ("Main model is claude-opus-4."), on a Mac in the toolbar subtitle instead ("work · main model claude-opus-4"). */
  mainModel?: string;
  /** The profile whose models these are, under the title: "work". */
  profile?: string;
  /** The mixture of agents group. Leave out when Hermes reports none (the group is not drawn). */
  moa?: MoaSetup;
  /** `loaded` (default), `loading` (a spinner) or `failed` ("Could not load the helper models" with Retry). */
  state?: "loaded" | "loading" | "failed";
  /** A helper slot was pressed: the app opens the model picker with "Use the profile's default". */
  onOpenSlot?: (task: string) => void;
  /** A mixture-of-agents slot was pressed. */
  onOpenMoaSlot?: (key: string) => void;
  onRetry?: () => void;
  onBack?: () => void;
  /** `phone` or `desktop`; under `apple`, `desktop` is a Mac window with the toolbar and the 600px column. */
  layout?: "phone" | "desktop";
  /** `apple`: the iOS bar ("Chat" back, the title centred over the profile) and value rows with a muted model and chevron; on a Mac the toolbar and pop-up buttons. `material`: the 56px bar and two-line rows. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * Helper models on `SettingsScaffold`, pushed from the chat sidebar: one
 * `ModelSlotRow` per side job in a group whose footer says changes apply
 * to new chats, and below it the "Mixture of agents" group: the Preset,
 * the advisors and the aggregator. A slot saves when its picker closes,
 * showing a spinner meanwhile.
 */
export function HelperModelsScreen({
  slots = [],
  mainModel,
  profile,
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
  const resolved = usePlatform(platform);
  const mac =
    resolved === "apple" && layout === "desktop" && device !== "touch";
  const main =
    state === "loaded" && mainModel ? mainModel.split("/").pop() : undefined;
  const subtitle =
    [profile, mac && main ? `main model ${main}` : null]
      .filter(Boolean)
      .join(" · ") || undefined;
  return (
    <ScreenFrame platform={resolved}>
      <SettingsScaffold
        device={mac ? "mac" : "touch"}
        title="Helper models"
        subtitle={subtitle}
        onBack={onBack ?? noop}
      >
        {state !== "loaded" ? (
          <ScreenState
            state={state}
            failedTitle="Could not load the helper models"
            onRetry={onRetry}
          />
        ) : (
          <GroupedListView>
            <GroupedSection
              footer={[
                "Hermes runs side jobs on these models.",
                !mac && main ? `Main model is ${main}.` : null,
                "Changes apply to new chats.",
              ]
                .filter(Boolean)
                .join(" ")}
            >
              {slots.map((slot) => (
                <ModelSlotRow
                  key={slot.task}
                  label={slot.label}
                  choice={slot.choice}
                  saving={slot.saving}
                  onClick={() => onOpenSlot?.(slot.task)}
                />
              ))}
            </GroupedSection>
            {moa ? (
              <GroupedSection
                header="Mixture of agents"
                footer={
                  moa.privacyFilterOn
                    ? "Hermes’ privacy filter is on, and saving here would turn it off. Change these slots on the server."
                    : undefined
                }
              >
                <GroupedValueRow
                  title="Preset"
                  value={moa.preset === "default" ? "Default" : moa.preset}
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
              </GroupedSection>
            ) : null}
          </GroupedListView>
        )}
      </SettingsScaffold>
    </ScreenFrame>
  );
}
