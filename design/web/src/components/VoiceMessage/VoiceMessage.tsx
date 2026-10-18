import { useState } from "react";
import { Icon } from "../Icon/Icon";
import "./VoiceMessage.css";

export interface VoiceMessageProps {
  name: string;
  playing?: boolean;
  loading?: boolean;
  /** Playback position and duration, in seconds. */
  position?: number;
  duration?: number;
  error?: string;
  /** Matching text_to_speech input; omitted when the spoken text is unknown. */
  transcript?: string;
  initiallyExpanded?: boolean;
  onToggle?: () => void;
  onSeek?: (seconds: number) => void;
  onSave?: () => void;
}

const time = (value: number) => {
  const seconds = Math.max(0, Math.floor(value));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
};

/** Compact inline voice player matching Flutter's VoiceMessageView. Play,
 * progress, time and actions fit in one 52px row. The optional transcript
 * opens below it; playback belongs to the caller. */
export function VoiceMessage({ name, playing = false, loading = false,
  position = 0, duration = 0, error, transcript, initiallyExpanded = false,
  onToggle, onSeek, onSave,
}: VoiceMessageProps) {
  const [expanded, setExpanded] = useState(initiallyExpanded);
  const action = error ? "Retry voice message" : playing ? "Pause voice message" : "Play voice message";
  return (
    <div className="h-voice-message" role="group" aria-label={name}>
      <div className="h-voice-message__row">
        {loading ? <span className="h-voice-message__loading" role="status" aria-label="Loading voice message">◌</span> :
          <button className="h-voice-message__button" type="button" aria-label={action} onClick={onToggle} disabled={!onToggle}>
            <Icon name={error ? "refresh" : playing ? "pause" : "play_arrow"} size={24} />
          </button>}
        {error || loading || !duration ?
          <span className={`h-voice-message__notice${error ? " h-voice-message__error" : ""}`}>{error ?? (loading ? "Loading audio…" : "Voice message")}</span> : <>
            <input type="range" aria-label="Voice message position" min={0} max={duration}
              value={Math.min(position, duration)} step={0.1} disabled={!onSeek}
              aria-valuetext={`${time(position)} of ${time(duration)}`}
              onChange={(event) => onSeek?.(Number(event.target.value))} />
            <small>{time(position)} / {time(duration)}</small>
          </>}
        {transcript ? <button className="h-voice-message__button" type="button" aria-label="Transcript"
          title={expanded ? "Hide transcript" : "Show transcript"} aria-expanded={expanded} onClick={() => setExpanded(!expanded)}>
          <Icon name="subject" size={18} />
        </button> : null}
        {onSave ? <button className="h-voice-message__button" type="button" aria-label="Save voice message" onClick={onSave}>
          <Icon name="download" size={18} />
        </button> : null}
      </div>
      {transcript && expanded ? <div className="h-voice-message__transcript">{transcript}</div> : null}
    </div>
  );
}
