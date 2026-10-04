import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./ImageViewerScreen.css";

export interface ImageViewerScreenProps {
  /** The image's file name, the bar's title ("chart.png"), cut with an ellipsis. */
  name: string;
  /** The image's URL. Without one, or with `broken`, the muted broken-image glyph stands in for it. */
  src?: string;
  /** The image could not be drawn: the broken-image glyph instead. */
  broken?: boolean;
  /** Close (leading). */
  onClose?: () => void;
  /** Save (trailing download button); left out when the platform cannot save the file. */
  onSave?: () => void;
  /** `apple`: CupertinoIcons glyphs (xmark, arrow down to line) and a 17px title instead of 16px. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * The full-screen viewer a tapped image attachment opens (`ImageViewerPage`
 * in the app): black in both themes, a 56px bar with Close, the file name
 * and Save in white, and the image fitted in the middle (the app lets it be
 * pinched up to 8x). Fills its parent.
 */
export function ImageViewerScreen({
  name,
  src,
  broken = false,
  onClose,
  onSave,
  platform,
}: ImageViewerScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div className="h-image-viewer">
        <header
          className={cx(
            "h-image-viewer__bar",
            resolvedPlatform === "apple" && "h-image-viewer__bar--apple",
          )}
        >
          <IconButton icon="close" label="Close" onClick={onClose} />
          <span className="h-image-viewer__title">{name}</span>
          {onSave ? (
            <IconButton icon="download" label="Save" onClick={onSave} />
          ) : null}
        </header>
        <div className="h-image-viewer__stage">
          {src && !broken ? (
            <img className="h-image-viewer__image" src={src} alt={name} />
          ) : (
            <Icon name="broken_image" size={24} className="h-muted" />
          )}
        </div>
      </div>
    </PlatformScope>
  );
}
