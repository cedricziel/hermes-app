import { HermesProvider, TakeoverConfirmation } from "@hermes-app/ui";

const column = { width: 420 } as const;

/** The question before taking over, as the content of a bottom sheet or a dialog. */
export const BeforeTakingOver = () => (
  <HermesProvider>
    <div style={column}>
      <TakeoverConfirmation onCancel={() => {}} onConfirm={() => {}} />
    </div>
  </HermesProvider>
);

/** The user chose not to be asked again for this account. */
export const DontAskAgain = () => (
  <HermesProvider>
    <div style={column}>
      <TakeoverConfirmation dontAskAgain />
    </div>
  </HermesProvider>
);
