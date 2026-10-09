import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedMenuRow } from "../GroupedMenuRow/GroupedMenuRow";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import {
  GroupedFooter,
  GroupedSection,
} from "../GroupedSection/GroupedSection";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import { GroupedTextFieldRow } from "../GroupedTextFieldRow/GroupedTextFieldRow";
import { GroupedValueRow } from "../GroupedValueRow/GroupedValueRow";
import {
  SchedulePicker,
  type SchedulePickerProps,
} from "../SchedulePicker/SchedulePicker";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { type AppleDevice, type Platform } from "../../platform";

/** The "Advanced" fields of a job. */
export interface JobAdvancedFields {
  /** Skill names, comma separated: "news, calendar". */
  skills?: string;
  /** The model picked; omitted shows "Profile default". */
  model?: string;
  /** The model's provider label, the Model row's caption: "Anthropic". Add " · Not in the server's list" for a saved model the server no longer offers. */
  modelHelper?: string;
  /** Pre-run script file name. */
  script?: string;
  /** Ids of other jobs whose output is added as context, comma separated. */
  contextFrom?: string;
  /** Working directory. */
  workdir?: string;
}

export interface JobFormScreenProps {
  /** `edit` titles the screen "Edit task" and leaves out Profile and Start paused, which only a new job has. */
  mode?: "new" | "edit";
  /** Job name. */
  name?: string;
  /** What Hermes should do each time. */
  prompt?: string;
  /** The "When" group's state (mode, time, days, next runs…); see `SchedulePicker`. */
  schedule: SchedulePickerProps;
  /** Delivery targets the server offers: "Local (save only)", "Origin chat", "Telegram". */
  targets?: string[];
  /** The target picked. */
  deliverTo?: string;
  /** The target has no home channel on the server: a warning line under "Deliver results to". */
  noHomeChannel?: boolean;
  /** Profiles a new job can go to; with one or none the row is left out. */
  profiles?: string[];
  /** The profile picked; also the bar's subtitle. */
  profile?: string;
  /** New jobs only: start the job paused. */
  startPaused?: boolean;
  /** The "Advanced" fields, shown under the Advanced row while `advancedOpen`. */
  advanced?: JobAdvancedFields;
  /** "Advanced" is unfolded (the app opens it when any advanced field is set): its chevron turns down, the fields and their footer show. */
  advancedOpen?: boolean;
  /** The server refused the job: a red note under the last group. */
  error?: string;
  /** Saving: a spinner in place of Save. */
  saving?: boolean;
  /** Which menu starts open, for previews. */
  defaultOpen?: "deliver";
  /**
   * A `SettingsScaffold` form. iPhone: "Cancel" leading, the title over the
   * profile, "Save" trailing; borderless fields beside their labels.
   * Material: a close X, the title at the start, "Save" trailing; floating
   * labels. Mac (`device="mac"`): the toolbar with the back button and a
   * small filled Save. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`. Defaults to the enclosing `AppShell`'s, else touch. */
  device?: AppleDevice;
  /** A field was edited: `name`, `prompt`, or an advanced field's key. */
  onFieldChange?: (field: string, value: string) => void;
  /** A delivery target picked. */
  onDeliverChange?: (target: string) => void;
  /** A profile picked. */
  onProfileChange?: (profile: string) => void;
  /** Start paused flipped. */
  onStartPausedChange?: (paused: boolean) => void;
  /** "Advanced" pressed. */
  onToggleAdvanced?: () => void;
  /** The Model row pressed (the app opens the model picker with "Use the profile's default"). */
  onPickModel?: () => void;
  /** Save pressed. */
  onSave?: () => void;
  /** Cancel, the close X or back pressed (the app asks "Discard changes?" when something was typed). */
  onClose?: () => void;
}

/**
 * The job form, for a custom scheduled task and for editing one, as grouped
 * sections after the app's `JobFormScreen`: Name and Task, the "When"
 * `SchedulePicker`, "Delivery" (Deliver results to, Profile, Start paused),
 * and an "Advanced" row that unfolds Skills, Model, Pre-run script, Take
 * context from and Working directory with a footer explaining them. Save is
 * in the bar. Fills its parent.
 */
export function JobFormScreen({
  mode = "new",
  name = "",
  prompt = "",
  schedule,
  targets = [],
  deliverTo,
  noHomeChannel = false,
  profiles = [],
  profile,
  startPaused = false,
  advanced = {},
  advancedOpen = false,
  error,
  saving = false,
  defaultOpen,
  platform,
  device,
  onFieldChange,
  onDeliverChange,
  onProfileChange,
  onStartPausedChange,
  onToggleAdvanced,
  onPickModel,
  onSave,
  onClose,
}: JobFormScreenProps) {
  const creating = mode === "new";
  const field = (key: string, label: string, value = "", hint?: string) => (
    <GroupedTextFieldRow
      key={key}
      label={label}
      hint={hint}
      value={value}
      onChange={(v) => onFieldChange?.(key, v)}
    />
  );
  return (
    <SettingsScaffold
      title={creating ? "New task" : "Edit task"}
      subtitle={profile}
      onCancel={onClose ?? (() => {})}
      onBack={onClose ?? (() => {})}
      formAction={{ label: "Save", busy: saving, onClick: onSave }}
      platform={platform}
      device={device}
    >
      <GroupedListView>
        <GroupedSection>
          {field("name", "Name", name)}
          <GroupedTextFieldRow
            label="Task"
            hint="What should Hermes do each time?"
            rows={3}
            value={prompt}
            onChange={(v) => onFieldChange?.("prompt", v)}
          />
        </GroupedSection>
        <SchedulePicker {...schedule} />
        <GroupedSection header="Delivery">
          <GroupedMenuRow
            title="Deliver results to"
            options={targets}
            selected={deliverTo ? targets.indexOf(deliverTo) : undefined}
            placeholder={deliverTo}
            open={defaultOpen === "deliver"}
            warning={
              noHomeChannel
                ? "No home channel is set on the server for this platform."
                : undefined
            }
            onSelect={(i) => onDeliverChange?.(targets[i])}
          />
          {creating && profiles.length > 1 ? (
            <GroupedMenuRow
              title="Profile"
              options={profiles}
              selected={profile ? profiles.indexOf(profile) : undefined}
              placeholder={profile}
              onSelect={(i) => onProfileChange?.(profiles[i])}
            />
          ) : null}
          {creating ? (
            <GroupedSwitchRow
              title="Start paused"
              checked={startPaused}
              onChange={onStartPausedChange}
            />
          ) : null}
        </GroupedSection>
        <GroupedSection
          footer={
            advancedOpen
              ? "Skills and task ids are separated by commas. The pre-run script is a file in the profile’s scripts folder; its output is added to the prompt."
              : undefined
          }
        >
          <GroupedRow
            title="Advanced"
            expanded={advancedOpen}
            onClick={() => onToggleAdvanced?.()}
          />
          {advancedOpen
            ? [
                field("skills", "Skills", advanced.skills),
                <GroupedValueRow
                  key="model"
                  title="Model"
                  value={advanced.model || "Profile default"}
                  caption={advanced.model ? advanced.modelHelper : undefined}
                  onClick={() => onPickModel?.()}
                />,
                field("script", "Pre-run script", advanced.script),
                field(
                  "contextFrom",
                  "Take context from",
                  advanced.contextFrom,
                  "Task ids",
                ),
                field("workdir", "Working directory", advanced.workdir),
              ]
            : null}
        </GroupedSection>
        {error ? <GroupedFooter error>{error}</GroupedFooter> : null}
      </GroupedListView>
    </SettingsScaffold>
  );
}
