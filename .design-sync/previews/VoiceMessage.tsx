import { HermesProvider, VoiceMessage } from "@hermes-app/ui";

const col = { width: 420, display: "grid", gap: 12 } as const;

const transcript =
  "The nightly backup failed because nas-02 was rebooting after its update. I moved the job to 03:30.";

/** Ready, playing part-way and with the transcript open. */
export const Playback = () => (
  <div style={col}>
    <VoiceMessage
      name="reply.ogg"
      duration={42}
      transcript={transcript}
      onToggle={() => {}}
      onSeek={() => {}}
      onSave={() => {}}
    />
    <VoiceMessage
      name="reply.ogg"
      playing
      position={17}
      duration={42}
      transcript={transcript}
      initiallyExpanded
      onToggle={() => {}}
      onSeek={() => {}}
      onSave={() => {}}
    />
  </div>
);

/** Loading the audio, no transcript, and a failed load with Retry. */
export const LoadingAndFailed = () => (
  <div style={col}>
    <VoiceMessage name="reply.ogg" loading />
    <VoiceMessage name="reply.ogg" duration={42} onToggle={() => {}} />
    <VoiceMessage
      name="reply.ogg"
      error="Couldn't play this voice message."
      onToggle={() => {}}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", padding: 16, borderRadius: 14 }}
  >
    <div style={col}>
      <VoiceMessage
        name="reply.ogg"
        playing
        position={17}
        duration={42}
        transcript={transcript}
        initiallyExpanded
        onToggle={() => {}}
        onSeek={() => {}}
        onSave={() => {}}
      />
    </div>
  </HermesProvider>
);
