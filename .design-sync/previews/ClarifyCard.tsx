import { ClarifyCard, HermesProvider } from "@hermes-app/ui";

const box = { width: 640 } as const;

export const Choices = () => (
  <div style={box}>
    <ClarifyCard
      questions={[
        {
          id: "",
          question: "Which cluster should the backup run against?",
          choices: [
            "staging",
            "production",
            "both of them, one after the other",
          ],
        },
      ]}
      onAnswer={() => {}}
    />
  </div>
);

export const FreeText = () => (
  <div style={box}>
    <ClarifyCard
      questions={[{ id: "", question: "What should I name the tag?" }]}
      answers={{ "": ["v0.1.42"] }}
      onAnswer={() => {}}
    />
  </div>
);

export const Batch = () => (
  <div style={box}>
    <ClarifyCard
      batch
      questions={[
        {
          id: "targets",
          question: "Which platforms?",
          choices: ["iOS", "Android", "macOS"],
          multiSelect: true,
        },
        { id: "notes", question: "Anything to add to the notes?" },
      ]}
      answers={{ targets: ["iOS", "macOS"] }}
      onAnswer={() => {}}
    />
  </div>
);

export const Answered = () => (
  <div style={{ ...box, display: "flex", flexDirection: "column", gap: 8 }}>
    <ClarifyCard
      status="answered"
      questions={[
        {
          id: "",
          question: "Which environment should I deploy to?",
          choices: ["Staging", "Production"],
        },
      ]}
      answers={{ "": ["Staging"] }}
    />
    <ClarifyCard
      status="expired"
      questions={[
        { id: "", question: "Which cluster should the backup run against?" },
      ]}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={box}>
      <ClarifyCard
        questions={[
          {
            id: "",
            question: "Which environment should I deploy to?",
            choices: ["Staging", "Production"],
          },
        ]}
        answers={{ "": ["Staging"] }}
        onAnswer={() => {}}
      />
    </div>
  </HermesProvider>
);
