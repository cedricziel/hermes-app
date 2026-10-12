import { Badge } from "../Badge/Badge";
import { skillSourceLabels, type Skill } from "../SkillRow/SkillRow";
import { Spinner } from "../Spinner/Spinner";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { SkillMarkdown } from "../../skillMarkdown";
import { type ScreenLayout } from "../../screenFrame";
import type { AppleDevice, Platform } from "../../platform";
import "./SkillDetailScreen.css";

export { skillMarkdownBody } from "../../skillMarkdown";

export interface SkillDetailScreenProps {
  /** The skill. Leave out when it no longer exists ("This skill no longer exists."). */
  skill?: Skill;
  /** Name for the title when `skill` is gone. */
  name?: string;
  /** Its `SKILL.md`, front matter included (stripped before rendering). */
  content?: string;
  /** The `SKILL.md` content: `loaded` (default), `loading` (a spinner) or `failed` ("Could not load this skill" with Retry). */
  contentState?: "loaded" | "loading" | "failed";
  /** A skills hub is connected: a hub skill offers Uninstall. */
  hub?: boolean;
  /** A hub job is running: Uninstall is disabled. */
  hubBusy?: boolean;
  onBack?: () => void;
  onEnabledChange?: (enabled: boolean) => void;
  /** Agent skills: Edit (opens `SkillEditorScreen`). */
  onEdit?: () => void;
  /** Agent skills: "Ask agent to delete" drafts a chat message (the server cannot delete skills). */
  onAskDelete?: () => void;
  /** Hub skills: Uninstall (confirmed, then a `SkillJobSheet`). */
  onUninstall?: () => void;
  onRetry?: () => void;
  /** `phone` or `desktop`; the content uses the grouped platform column. */
  layout?: ScreenLayout;
  /** `apple`: chevron back with "Skills", the Apple toggle and spinner. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/**
 * One installed skill, pushed from the Skills screen: its category, source
 * and usage, an Enabled grouped switch, the actions its source allows (Edit and
 * "Ask agent to delete" for an agent skill, Uninstall for a hub skill, a
 * note for a bundled one), and its rendered `SKILL.md` in a grouped surface.
 */
export function SkillDetailScreen({
  skill,
  name,
  content = "",
  contentState = "loaded",
  hub = false,
  hubBusy = false,
  onBack,
  onEnabledChange,
  onEdit,
  onAskDelete,
  onUninstall,
  onRetry,
  layout = "phone",
  platform,
  device,
}: SkillDetailScreenProps) {
  return (
    <SettingsScaffold
      title={skill?.name ?? name ?? ""}
      onBack={onBack}
      backLabel="Skills"
      platform={platform}
      device={layout === "phone" ? "touch" : (device ?? "mac")}
    >
      {!skill ? (
        <div className="h-skill-detail__state h-body-md">
          This skill no longer exists.
        </div>
      ) : (
        <GroupedListView>
          <div className="h-skill-detail__facts">
            {skill.category ? (
              <span className="h-body-sm">{skill.category}</span>
            ) : null}
            <Badge>{skillSourceLabels[skill.source]}</Badge>
            {skill.usage ? (
              <span className="h-body-md">used {skill.usage}×</span>
            ) : null}
          </div>
          <GroupedSection
            footer={
              skill.source !== "agent" && !(skill.source === "hub" && hub)
                ? "Bundled and hub skills can only be switched on or off here."
                : undefined
            }
          >
            <GroupedSwitchRow
              title="Enabled"
              subtitle="The agent may load this skill"
              checked={skill.enabled}
              onChange={onEnabledChange}
              onClick={
                onEnabledChange
                  ? () => onEnabledChange(!skill.enabled)
                  : undefined
              }
            />
            {skill.source === "agent" ? (
              <GroupedRow
                title="Edit"
                disabled={contentState !== "loaded"}
                onClick={onEdit}
              />
            ) : null}
            {skill.source === "agent" ? (
              <GroupedRow
                title="Ask agent to delete"
                destructive
                chevron={false}
                onClick={onAskDelete}
              />
            ) : skill.source === "hub" && hub ? (
              <GroupedRow
                title="Uninstall"
                destructive
                chevron={false}
                disabled={hubBusy}
                onClick={onUninstall}
              />
            ) : null}
          </GroupedSection>
          {contentState === "failed" ? (
            <GroupedSection>
              <GroupedRow title="Could not load this skill" chevron={false} />
              <GroupedRow title="Retry" chevron={false} onClick={onRetry} />
            </GroupedSection>
          ) : contentState === "loading" ? (
            <GroupedSection>
              <GroupedRow
                title="Loading skill contents…"
                chevron={false}
                trailing={<Spinner size={18} label="Loading the skill" />}
              />
            </GroupedSection>
          ) : (
            <GroupedSection>
              <div className="h-skill-detail__markdown">
                <SkillMarkdown text={content} />
              </div>
            </GroupedSection>
          )}
        </GroupedListView>
      )}
    </SettingsScaffold>
  );
}
