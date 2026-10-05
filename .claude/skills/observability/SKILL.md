---
name: observability
description: Use for Hermes app audience, usage, reliability, or performance questions using SignalDB and App Store Connect; distinguish people from sessions and telemetry events.
---

# Hermes observability

Use the SignalDB MCP server for reproducible numbers. Start with `server_info` and `discover_datasets`; Hermes release telemetry is in tenant `homelab`, dataset `apps`, service `hermes-app`. Before filtering or grouping, use `resolve_attribute` or `resolve_metric` for this tenant. State the time window, dataset, service filter, metric definition, and whether the value is a count, estimate, rate, or unavailable. Check query retention and oldest data before calling a window complete. Keep ingest URLs, headers, and keys out of reports.

- For people counts, MAU, active devices, or session counts, read [references/audience.md](references/audience.md).
- For adoption, reliability, network, sign-in, or other operational KPIs, read [references/kpis.md](references/kpis.md).

Read only the relevant reference. For `query_ir`, read SignalDB's `get_skill("query-ir")` and the sections needed for the query before constructing a document.
