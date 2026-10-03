import { HermesProvider, ModelPill } from "@hermes-app/ui";

export const WithEffort = () => (
  <ModelPill model="claude-opus-4" effort="Medium" />
);

export const ModelOnly = () => <ModelPill model="claude-haiku-4-5" />;

export const LongModelTruncated = () => (
  <div style={{ width: 260 }}>
    <ModelPill
      model="meta-llama/llama-4-maverick-17b-128e-instruct-long-context"
      effort="High"
    />
  </div>
);

export const ProfileDefault = () => <ModelPill placeholder="Profile default" />;

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <ModelPill model="claude-opus-4" effort="Extra High" />
  </HermesProvider>
);
