# Audience and MAU

MAU means distinct people active in a calendar month or rolling 30 days; name which window is used. The app has no account or stable cross-launch user identifier. Its diagnostic ID changes on every launch, and `user.id` is absent in the Hermes `apps` dataset. Do not call distinct sessions, traces, requests, or SignalDB's `USERS 0` card MAU or a count of people. `USERS 0` means no user IDs were recorded.

In App Store Connect, open **Companion for Hermes Agent → Analytics → Metrics → Usage → Active in Last 30 Days** (and Active Devices if useful). Report Apple's metric as active *devices*, with its opt-in and availability qualifiers, not people. A dash or “insufficient data” is unavailable, not zero. Apple may delay recent dates. If neither source supports a people count, say so and report a clearly labeled activity proxy such as distinct sessions.

For a session proxy, this Query IR counts IDs observed in Hermes logs over a rolling 30 days. `count_distinct` is approximate (about 1–2% error); records without the ID do not count. Inspect the response window and retention before reporting it:

```json
{"irVersion":9,"from":"logs","range":{"from":"now-30d","to":"now"},"result":"table","pipeline":[{"where":{"field":"service.name","op":"eq","value":"hermes-app"}},{"aggregate":{"by":[],"aggs":[{"fn":"count_distinct","of":"session.id","as":"sessions"},{"fn":"count_distinct","of":"user.id","as":"users_with_id"}]}}]}
```

Run with `query_ir(tenant="homelab", dataset="apps", query=...)`. A `users_with_id` value of zero does not imply zero users. SignalDB Real users → `hermes-app` also shows distinct `session.id` sessions and network activity. Never sum daily distinct counts to get a monthly distinct count.

Person-level SignalDB MAU would need an agreed activity event and a privacy-reviewed person identifier stable for the chosen month; an installation ID would measure active installations instead. Do not add instrumentation just to answer a KPI request.
