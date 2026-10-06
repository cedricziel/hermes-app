import { Button } from "../Button/Button";
import { FormSection } from "../FormSection/FormSection";
import { Icon } from "../Icon/Icon";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import {
  SchedulePicker,
  type SchedulePickerProps,
} from "../SchedulePicker/SchedulePicker";
import { SelectField } from "../SelectField/SelectField";
import { Spinner } from "../Spinner/Spinner";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import { TextField } from "../TextField/TextField";
import {
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "../../styles/form-screen.css";
import "./JobFormScreen.css";

/** The "Advanced" fields of a job. */
export interface JobAdvancedFields {
  /** Skill names, comma separated: "news, calendar". */
  skills?: string;
  /** The model picked; omitted shows "Profile default". */
  model?: string;
  /** The model's provider label, under the field: "Anthropic". Add " · Not in the server's list" for a saved model the server no longer offers. */
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
  /** The "When" picker's state (mode, time, days, next runs…); see `SchedulePicker`. */
  schedule: SchedulePickerProps;
  /** Delivery targets the server offers: "Local (save only)", "Origin chat", "Telegram". */
  targets?: string[];
  /** The target picked. */
  deliverTo?: string;
  /** The target has no home channel on the server: an amber warning under the field. */
  noHomeChannel?: boolean;
  /** Profiles a new job can go to; with one or none the field is left out. */
  profiles?: string[];
  /** The profile picked. */
  profile?: string;
  /** New jobs only: start the job paused. */
  startPaused?: boolean;
  /** The "Advanced" section, folded unless `advancedOpen`. */
  advanced?: JobAdvancedFields;
  /** "Advanced" is unfolded (the app opens it when any advanced field is set). */
  advancedOpen?: boolean;
  /** The server refused the job: red text above Save task. */
  error?: string;
  /** Saving: Save disabled and a spinner in Save task. */
  saving?: boolean;
  /** Which dropdown starts open, for previews. */
  defaultOpen?: "deliver";
  /**
   * `apple`: the iOS type ramp and the Apple switch; the form is Material on
   * every platform and closes with an X, as in the app. Its menus follow
   * `device`. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac` for the dropdowns. */
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
  /** The model field pressed (the app opens the model picker with "Use the profile's default"). */
  onPickModel?: () => void;
  /** Save or Save task pressed. */
  onSave?: () => void;
  /** The close button pressed (the app asks "Discard changes?" when something was typed). */
  onClose?: () => void;
}

/**
 * The job form, for a custom scheduled task and for editing one: name, the
 * task, a `SchedulePicker` for when it runs, where results go, the profile,
 * Start paused, a folded "Advanced" section (skills, model, script,
 * context, working directory) and Save. A column of `FormSection`s with
 * `TextField`, `SelectField` and `SwitchRow` on `ListDetailLayout`'s `list`
 * layout with a close button. Fills its parent.
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
  const resolvedPlatform = usePlatform(platform);
  const creating = mode === "new";
  const field = (key: string, label: string, value = "", helper?: string) => (
    <TextField
      label={label}
      helper={helper}
      value={value}
      onChange={(e) => onFieldChange?.(key, e.target.value)}
      readOnly={!onFieldChange}
    />
  );
  return (
    <PlatformScope platform={resolvedPlatform}>
      <ListDetailLayout
        layout="list"
        title={creating ? "New task" : "Edit task"}
        onClose={onClose ?? (() => {})}
        actions={
          <Button variant="text" disabled={saving} onClick={onSave}>
            Save
          </Button>
        }
        list={
          <div className="h-form-screen">
            {field("name", "Name", name)}
            <TextField
              label="Task"
              placeholder="What should Hermes do each time?"
              rows={3}
              value={prompt}
              onChange={(e) => onFieldChange?.("prompt", e.target.value)}
              readOnly={!onFieldChange}
            />
            <FormSection title="When" gap={8}>
              <SchedulePicker {...schedule} />
            </FormSection>
            <FormSection gap={6}>
              <SelectField
                label="Deliver results to"
                value={deliverTo}
                options={targets}
                defaultOpen={defaultOpen === "deliver"}
                device={device}
                onChange={onDeliverChange}
              />
              {noHomeChannel ? (
                <div className="h-job-form__warning">
                  <Icon name="warning" size={16} color="var(--h-warning)" />
                  <span>
                    No home channel is set on the server for this platform.
                  </span>
                </div>
              ) : null}
            </FormSection>
            {creating && profiles.length > 1 ? (
              <SelectField
                label="Profile"
                value={profile}
                options={profiles}
                device={device}
                onChange={onProfileChange}
              />
            ) : null}
            {creating ? (
              <SwitchRow
                title="Start paused"
                checked={startPaused}
                onChange={onStartPausedChange}
              />
            ) : null}
            <FormSection
              title="Advanced"
              collapsible
              open={advancedOpen}
              onToggle={onToggleAdvanced}
            >
              {field(
                "skills",
                "Skills",
                advanced.skills,
                "Names, separated by commas",
              )}
              <SelectField
                label="Model"
                value={advanced.model}
                placeholder="Profile default"
                helper={advanced.model ? advanced.modelHelper : undefined}
                onClick={onPickModel}
              />
              {field(
                "script",
                "Pre-run script",
                advanced.script,
                "A file in the profile’s scripts folder; its output is added to the prompt",
              )}
              {field(
                "contextFrom",
                "Take context from",
                advanced.contextFrom,
                "Ids of other tasks, separated by commas",
              )}
              {field("workdir", "Working directory", advanced.workdir)}
            </FormSection>
            {error ? <div className="h-form-screen__error">{error}</div> : null}
            <Button fullWidth disabled={saving} onClick={onSave}>
              {saving ? <Spinner size={18} label="Saving" /> : "Save task"}
            </Button>
          </div>
        }
      />
    </PlatformScope>
  );
}
