import { ChatComposer, HermesProvider, ModelPill } from "@hermes-app/ui";

const box = { width: 744 };

export const Empty = () => (
  <div style={box}>
    <ChatComposer
      onAttach={() => {}}
      modelPill={<ModelPill model="claude-opus-4" />}
    />
  </div>
);

export const WithText = () => (
  <div style={box}>
    <ChatComposer
      value="Why did the nightly upload fail?"
      onAttach={() => {}}
      modelPill={<ModelPill model="claude-opus-4" effort="Medium" />}
    />
  </div>
);

export const WithAttachments = () => (
  <div style={box}>
    <ChatComposer
      onAttach={() => {}}
      attachments={[
        { name: "quarterly-report-final-v3.pdf" },
        { name: "notes.txt" },
        { name: "IMG_20260920_153012_034.png", image: true },
      ]}
      modelPill={<ModelPill model="claude-opus-4" />}
    />
  </div>
);

export const ReplyingWithQueue = () => (
  <div style={box}>
    <ChatComposer
      replying
      onAttach={() => {}}
      queued={[
        { text: "Then bump the backoff cap to 30 s and open a PR." },
        {
          text: "Also check whether the nightly job uses the same policy.",
          files: ["nightly.yaml"],
        },
        { text: "", files: ["trace.png"] },
      ]}
      modelPill={<ModelPill model="claude-opus-4" effort="Medium" />}
    />
  </div>
);

export const QueuePaused = () => (
  <div style={box}>
    <ChatComposer
      onAttach={() => {}}
      queuePaused
      queued={[
        { text: "Then run the backup on production too." },
        { text: "And post the result in #ops." },
      ]}
      modelPill={<ModelPill model="claude-opus-4" />}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ padding: 16, borderRadius: 14, width: 744 }}
  >
    <ChatComposer
      replying
      value="Also check the nightly policy"
      onAttach={() => {}}
      modelPill={<ModelPill model="claude-opus-4" effort="Medium" />}
    />
  </HermesProvider>
);
