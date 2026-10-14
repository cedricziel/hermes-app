## Design

Extract address entry and status summary as plain widgets accepting values and callbacks. Use grouped controls and shared platform metrics. Keep setup scrollable above the keyboard. Connection details retain asynchronous status loading and refresh, with an explicit toolbar refresh action. The state-update callback uses a block so assigning the future does not return it to setState; actions retain existing auth-controller calls.

## Validation

Exercise catalog states on Apple and Material, URL and recovery behavior, native renders and isolated connection data. No production credentials or connections.
