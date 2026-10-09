import { Icon } from "../Icon/Icon";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { Spinner } from "../Spinner/Spinner";
import {
  useGroupedChrome,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./GroupedValueRow.css";

export interface GroupedValueRowProps {
  /** The setting's label: "Vision", "Model", "Repeat", "Preset". */
  title: string;
  /** The current value: "Main model", "gpt-5-mini", "Every day". */
  value: string;
  /** A muted line under the label, such as the model's provider. */
  caption?: string;
  /** A warning line under the label. */
  warning?: string;
  /** Saving: a spinner takes the value's place and clicks are ignored. */
  busy?: boolean;
  /** Opens the picker. Without it the value shows but nothing opens (no chevron on iOS, a muted pop-up on a Mac). */
  onClick?: () => void;
  /**
   * `apple` + `touch`: the label left, the value muted on the right (cut
   * at 45% of the row) and a chevron, the whole row one button. `apple` +
   * `mac`: a 40px row with the label left and the value in a bordered
   * pop-up button on the right (12px, 6px corners, a small chevron down).
   * `material`: two lines, the label over the value (muted, 14px), no
   * chevron. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * A labelled value that opens a picker: a helper model slot, a form's
 * model, schedule or repeat field. For a value picked from a short fixed
 * list use `GroupedMenuRow`.
 */
export function GroupedValueRow({
  title,
  value,
  caption,
  warning,
  busy = false,
  onClick,
  platform,
  device,
}: GroupedValueRowProps) {
  const chrome = useGroupedChrome(platform, device);
  const open = busy ? undefined : onClick;
  const progress = busy ? (
    <Spinner size={chrome === "mac" ? 14 : 18} label="Saving" />
  ) : undefined;
  if (chrome === "material") {
    return (
      <GroupedRow
        title={title}
        subtitle={value}
        caption={caption}
        warning={warning}
        trailing={progress}
        chevron={false}
        onClick={progress ? undefined : open}
        platform={platform}
        device={device}
      />
    );
  }
  if (chrome === "mac") {
    return (
      <GroupedRow
        title={title}
        caption={caption}
        warning={warning}
        trailing={
          progress ?? (
            <MacPopUpValue value={value} onClick={open} enabled={!!open} />
          )
        }
        platform={platform}
        device={device}
      />
    );
  }
  return (
    <GroupedRow
      title={title}
      caption={caption}
      warning={warning}
      value={progress ? undefined : value}
      trailing={progress}
      chevron={!!open}
      onClick={progress ? undefined : open}
      platform={platform}
      device={device}
    />
  );
}

/** The Mac pop-up button showing a value. */
function MacPopUpValue({
  value,
  enabled,
  onClick,
}: {
  value: string;
  enabled: boolean;
  onClick?: () => void;
}) {
  return (
    <button
      type="button"
      className="h-mac-popup"
      disabled={!enabled}
      aria-haspopup="menu"
      onClick={onClick}
    >
      <span className="h-mac-popup__value">{value}</span>
      <Icon name="expand_more" size={12} />
    </button>
  );
}
