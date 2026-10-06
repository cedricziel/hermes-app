import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { FormSection } from "../FormSection/FormSection";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import { ModelPill } from "../ModelPill/ModelPill";
import { SelectField } from "../SelectField/SelectField";
import { Spinner } from "../Spinner/Spinner";
import { TextField } from "../TextField/TextField";
import {
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "../../styles/form-screen.css";

export interface KanbanCreateScreenProps {
  /** Title typed so far; Create and "Estimate the work" need one. */
  title?: string;
  /** Description typed so far. */
  description?: string;
  /** Profiles the task can be assigned to, offered after "Auto (triage picks)". */
  assignees?: string[];
  /** The assignee picked; omitted means "Auto (triage picks)". */
  assignee?: string;
  /**
   * The model field. `list`: a `ModelPill` under a "Model" label, opening
   * the picker with the plugin's models (`model`, `effort`; "Profile
   * default" when none is picked). `freeText`: the plugin lists no models,
   * so a "Model" text field (`modelName`) with "Leave empty for the profile
   * default". `loading`: nothing yet.
   */
  modelField?: "list" | "freeText" | "loading";
  /** `list`: the model picked; omitted shows "Profile default". */
  model?: string;
  /** `list`: the reasoning effort picked with it, e.g. `High`. */
  effort?: string;
  /** `freeText`: the model name typed. */
  modelName?: string;
  /** 0 is Normal, 1 to 3 are P1 to P3. */
  priority?: number;
  /** Start in Triage (default) rather than Todo. */
  triage?: boolean;
  /** The estimate's summary, shown under "Estimate the work": "About 2 hours of work". */
  estimate?: string;
  /** The estimate is being worked out: "Estimate the work" disabled. */
  estimating?: boolean;
  /** The task is being created: Create disabled. */
  saving?: boolean;
  /** Which dropdown starts open, for previews. */
  defaultOpen?: "assignee";
  /** `phone` shows the parent's title ("Kanban") beside the Apple back chevron. */
  layout?: "phone" | "desktop";
  /**
   * `apple`: the chevron back button and the iOS type ramp; the form itself
   * is Material on every platform, as in the app, and its menus follow
   * `device`. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac` for the assignee menu. */
  device?: AppleDevice;
  /** The title was edited. */
  onTitleChange?: (title: string) => void;
  /** The description was edited. */
  onDescriptionChange?: (description: string) => void;
  /** An assignee was picked; `undefined` for "Auto (triage picks)". */
  onAssigneeChange?: (assignee: string | undefined) => void;
  /** The model pill was pressed (the app opens the model picker with a "Use the default" entry). */
  onPickModel?: () => void;
  /** The free-text model name was edited. */
  onModelNameChange?: (name: string) => void;
  /** A priority chip was pressed. */
  onPriorityChange?: (priority: number) => void;
  /** Triage or Todo was picked. */
  onTriageChange?: (triage: boolean) => void;
  /** "Estimate the work" pressed. */
  onEstimate?: () => void;
  /** Create pressed. */
  onCreate?: () => void;
  /** Back pressed (the app asks before throwing a typed task away). */
  onBack?: () => void;
}

const auto = "Auto (triage picks)";

/**
 * "New task" on the Kanban board: title, description, "Estimate the work",
 * assignee, model, priority and the column it starts in, with Create in the
 * bar. A column of `FormSection`s with `TextField`, `SelectField`,
 * `ModelPill` and `Chip`s, at most 560px wide and centred, on
 * `ListDetailLayout`'s `list` layout. Fills its parent.
 */
export function KanbanCreateScreen({
  title = "",
  description = "",
  assignees = [],
  assignee,
  modelField = "list",
  model,
  effort,
  modelName = "",
  priority = 0,
  triage = true,
  estimate,
  estimating = false,
  saving = false,
  defaultOpen,
  layout = "phone",
  platform,
  device,
  onTitleChange,
  onDescriptionChange,
  onAssigneeChange,
  onPickModel,
  onModelNameChange,
  onPriorityChange,
  onTriageChange,
  onEstimate,
  onCreate,
  onBack,
}: KanbanCreateScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <ListDetailLayout
        layout="list"
        title="New task"
        onBack={onBack ?? (() => {})}
        backLabel={layout === "phone" ? "Kanban" : undefined}
        actions={
          <Button variant="text" disabled={saving} onClick={onCreate}>
            Create
          </Button>
        }
        list={
          <div className="h-form-screen h-form-screen--narrow">
            <FormSection gap={12}>
              <TextField
                label="Title"
                value={title}
                onChange={(e) => onTitleChange?.(e.target.value)}
                readOnly={!onTitleChange}
              />
              <TextField
                label="Description"
                rows={3}
                value={description}
                onChange={(e) => onDescriptionChange?.(e.target.value)}
                readOnly={!onDescriptionChange}
              />
            </FormSection>
            <FormSection gap={4}>
              <div>
                <Button
                  variant="text"
                  icon={estimating ? undefined : "speed"}
                  disabled={estimating || !title.trim()}
                  onClick={onEstimate}
                >
                  {estimating ? <Spinner size={18} label="Estimating" /> : null}
                  Estimate the work
                </Button>
              </div>
              {estimate ? (
                <div className="h-form-screen__note">{estimate}</div>
              ) : null}
            </FormSection>
            <SelectField
              label="Assignee"
              value={assignee ?? auto}
              options={[auto, ...assignees]}
              defaultOpen={defaultOpen === "assignee"}
              device={device}
              onChange={(v) => onAssigneeChange?.(v === auto ? undefined : v)}
            />
            {modelField === "list" ? (
              <FormSection title="Model" titleStyle="label" gap={4}>
                <div>
                  <ModelPill
                    model={model}
                    effort={model ? effort : undefined}
                    placeholder="Profile default"
                    onClick={onPickModel}
                  />
                </div>
              </FormSection>
            ) : modelField === "freeText" ? (
              <TextField
                label="Model"
                helper="Leave empty for the profile default"
                value={modelName}
                onChange={(e) => onModelNameChange?.(e.target.value)}
                readOnly={!onModelNameChange}
              />
            ) : null}
            <FormSection title="Priority" titleStyle="label">
              <div className="h-form-screen__chips">
                {[0, 1, 2, 3].map((p) => (
                  <Chip
                    key={p}
                    label={p === 0 ? "Normal" : `P${p}`}
                    selected={priority === p}
                    onClick={() => onPriorityChange?.(p)}
                  />
                ))}
              </div>
            </FormSection>
            <FormSection title="Start as" titleStyle="label">
              <div className="h-form-screen__chips">
                <Chip
                  label="Triage"
                  selected={triage}
                  onClick={() => onTriageChange?.(true)}
                />
                <Chip
                  label="Todo"
                  selected={!triage}
                  onClick={() => onTriageChange?.(false)}
                />
              </div>
            </FormSection>
          </div>
        }
      />
    </PlatformScope>
  );
}
