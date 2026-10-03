import { HermesProvider, TextField } from "@hermes-app/ui";

const col = {
  display: "flex",
  flexDirection: "column",
  gap: 16,
  width: 360,
} as const;

export const Outlined = () => (
  <div style={col}>
    <TextField
      label="Server address"
      placeholder="https://hermes.example.com"
    />
    <TextField
      label="Username"
      defaultValue="cedric"
      helper="The account you use for the Hermes dashboard."
    />
  </div>
);

export const Error = () => (
  <div style={col}>
    <TextField
      label="Server address"
      defaultValue="hermes.local:9119"
      error="Can't reach this server. Check the address and that you're on the right network."
    />
  </div>
);

export const Search = () => (
  <div style={col}>
    <TextField
      variant="search"
      leadingIcon="search"
      placeholder="Search tasks"
    />
  </div>
);

export const Multiline = () => (
  <div style={col}>
    <TextField
      label="Prompt"
      rows={4}
      defaultValue="Check last night's backup logs and tell me which jobs failed."
    />
    <TextField
      label="Command"
      mono
      defaultValue="npx -y @modelcontextprotocol/server-github"
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={col}>
      <TextField
        label="Server address"
        placeholder="https://hermes.example.com"
      />
      <TextField
        variant="search"
        leadingIcon="search"
        placeholder="Search skills"
      />
    </div>
  </HermesProvider>
);
