import { HermesProvider, UserMessage } from "@hermes-app/ui";

const chart =
  "data:image/svg+xml;utf8," +
  encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="240" height="150" viewBox="0 0 240 150"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2fa36b"/><stop offset="1" stop-color="#1e5fa3"/></linearGradient></defs><rect width="240" height="150" fill="url(#g)"/><g fill="#fff" fill-opacity="0.85"><rect x="18" y="110" width="30" height="40"/><rect x="62" y="52" width="30" height="98"/><rect x="106" y="90" width="30" height="60"/><rect x="150" y="32" width="30" height="118"/><rect x="192" y="70" width="30" height="80"/></g></svg>`,
  );

export const Text = () => (
  <div style={{ width: 720 }}>
    <UserMessage text="Why did the nightly backup fail?" />
  </div>
);

export const WithAttachments = () => (
  <div style={{ width: 720 }}>
    <UserMessage
      text="Summarize these for me"
      attachments={[
        { name: "quarterly-report-final-v3.pdf", size: "2.3 MB" },
        { name: "IMG_20260920_153012_034.png", kind: "image", src: chart },
        {
          name: "Quarterly numbers final (v3) with a really long file name that has to wrap somewhere sensible.csv",
          size: "18 KB",
        },
      ]}
    />
  </div>
);

export const Multiline = () => (
  <div style={{ width: 720 }}>
    <UserMessage
      text={
        "Can you re-pin the certificate and run it again?\nOnly on staging for now, production waits until tomorrow."
      }
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ padding: 16, borderRadius: 14, width: 720 }}
  >
    <UserMessage
      text="Go ahead, but only on staging."
      attachments={[{ name: "nightly.yaml", size: "1 KB" }]}
    />
  </HermesProvider>
);
