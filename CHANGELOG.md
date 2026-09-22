# Changelog

## [0.1.36](https://github.com/cedricziel/hermes-app/compare/v0.1.35...v0.1.36) (2026-09-22)


### Bug Fixes

* stop controllers acting after their screen closes, and drop stale async results ([#283](https://github.com/cedricziel/hermes-app/issues/283)) ([ceded2b](https://github.com/cedricziel/hermes-app/commit/ceded2bafcd262164fbd0c525a17bb354e321b07))

## [0.1.35](https://github.com/cedricziel/hermes-app/compare/v0.1.34...v0.1.35) (2026-09-22)


### Features

* **models:** add a model/effort picker preview for chat ([#281](https://github.com/cedricziel/hermes-app/issues/281)) ([0632bed](https://github.com/cedricziel/hermes-app/commit/0632bededdf665552e3134ea5f63ae371a20f64a))
* **telemetry:** report crashes with message, stack trace and breadcrumbs ([#280](https://github.com/cedricziel/hermes-app/issues/280)) ([c5e2643](https://github.com/cedricziel/hermes-app/commit/c5e2643bc23141a934798c22082b05b85c1ac637))

## [0.1.34](https://github.com/cedricziel/hermes-app/compare/v0.1.33...v0.1.34) (2026-09-22)


### Features

* add an About dialog and a Report a bug link ([#276](https://github.com/cedricziel/hermes-app/issues/276)) ([4353d29](https://github.com/cedricziel/hermes-app/commit/4353d29fbbf99e74b159a48fc9470f1acb9fe6c2))
* **chat:** add rename, pin, archive, delete and copy transcript to the header ([#279](https://github.com/cedricziel/hermes-app/issues/279)) ([06cb86c](https://github.com/cedricziel/hermes-app/commit/06cb86c1a90fce977b4be1be71c2b69240db9030))


### Bug Fixes

* **chat:** give the composer a visible border ([#277](https://github.com/cedricziel/hermes-app/issues/277)) ([05fceb7](https://github.com/cedricziel/hermes-app/commit/05fceb743af04d323493fae2f0afa4d993933217))

## [0.1.33](https://github.com/cedricziel/hermes-app/compare/v0.1.32...v0.1.33) (2026-09-22)


### Features

* **chat:** collapse a run of tool calls into one row ([#270](https://github.com/cedricziel/hermes-app/issues/270)) ([6553567](https://github.com/cedricziel/hermes-app/commit/65535675fcab771dec1738f4281822ad38b8a333))
* **chat:** show elapsed time and current activity while a reply runs ([#273](https://github.com/cedricziel/hermes-app/issues/273)) ([7c7cc4d](https://github.com/cedricziel/hermes-app/commit/7c7cc4d67cbde855b184d0af49c9d56a448e96dc))


### Bug Fixes

* **chat:** drop the canned follow-up chips under a reply ([#275](https://github.com/cedricziel/hermes-app/issues/275)) ([577106d](https://github.com/cedricziel/hermes-app/commit/577106d87c97c76e67b49db8dcd33c22a643c917))
* **chat:** keep text written before a tool call in its place, not lost ([#274](https://github.com/cedricziel/hermes-app/issues/274)) ([3820054](https://github.com/cedricziel/hermes-app/commit/3820054f75227be08f640a36ea6298950d7cfdd9))
* **chat:** pick a reply back up instead of failing it when the connection drops mid-turn ([#271](https://github.com/cedricziel/hermes-app/issues/271)) ([4fe4d0b](https://github.com/cedricziel/hermes-app/commit/4fe4d0b6dc2bb6abd0ccf9186417ac415196d167))

## [0.1.32](https://github.com/cedricziel/hermes-app/compare/v0.1.31...v0.1.32) (2026-09-22)


### Features

* **chat:** merge the nav rail into a denser sidebar ([#266](https://github.com/cedricziel/hermes-app/issues/266)) ([9c4b0c7](https://github.com/cedricziel/hermes-app/commit/9c4b0c7744f362aaf09b215b74ad3f64d14d0696))


### Bug Fixes

* **chat:** reconnect after the app sleeps instead of hanging ([#267](https://github.com/cedricziel/hermes-app/issues/267)) ([64a4858](https://github.com/cedricziel/hermes-app/commit/64a4858c3e89a558044b35d92ed423415a57a473))
* **chat:** show turns Hermes chains after a reply ([#265](https://github.com/cedricziel/hermes-app/issues/265)) ([6340e42](https://github.com/cedricziel/hermes-app/commit/6340e42ebaa8a26bface03c69d4d3c15814300e3))
* **watch:** connection gate, missing notifications, stale list, background relay ([#269](https://github.com/cedricziel/hermes-app/issues/269)) ([9675a25](https://github.com/cedricziel/hermes-app/commit/9675a25af015f12fd416f62a0f61b5cf5da00b0b))

## [0.1.31](https://github.com/cedricziel/hermes-app/compare/v0.1.30...v0.1.31) (2026-09-21)


### Bug Fixes

* **telemetry:** use the stable HTTP semantic-convention attribute names ([#263](https://github.com/cedricziel/hermes-app/issues/263)) ([b52edf4](https://github.com/cedricziel/hermes-app/commit/b52edf49b85d3430aeb81e34338ccf7f20691923))

## [0.1.30](https://github.com/cedricziel/hermes-app/compare/v0.1.29...v0.1.30) (2026-09-21)


### Documentation

* make the Widgetbook catalog the first step of UI work ([#261](https://github.com/cedricziel/hermes-app/issues/261)) ([f45d042](https://github.com/cedricziel/hermes-app/commit/f45d0426add3f91d8ea2193a50529d3f1a8aae69))

## [0.1.29](https://github.com/cedricziel/hermes-app/compare/v0.1.28...v0.1.29) (2026-09-21)


### Bug Fixes

* **bots:** let the pairing wait note wrap on narrow screens ([1d726e8](https://github.com/cedricziel/hermes-app/commit/1d726e8c254f6a217945821724d844d8b9bf1c90))
* **watch:** show the message of a failed reply ([#249](https://github.com/cedricziel/hermes-app/issues/249)) ([58fea94](https://github.com/cedricziel/hermes-app/commit/58fea9433cfff36968fef22da6565f7587c7cf9f))

## [0.1.28](https://github.com/cedricziel/hermes-app/compare/v0.1.27...v0.1.28) (2026-09-21)


### Features

* **kanban:** drag cards on phones, instant moves and a progress bar on running cards ([#232](https://github.com/cedricziel/hermes-app/issues/232)) ([d290608](https://github.com/cedricziel/hermes-app/commit/d290608f66bc2b6dc54d3882c14bbba2f09a76cb))


### Bug Fixes

* **chat:** let the input card title shrink on narrow screens ([535544e](https://github.com/cedricziel/hermes-app/commit/535544e6d5b1950687e470a4c2cb16336159861a))
* **kanban:** let the assignee dropdown fill the row ([5e3d802](https://github.com/cedricziel/hermes-app/commit/5e3d802b5a4c93ff66e42ebb8ede5d66a568e9e3))


### Documentation

* **fastlane:** explain the network.server entitlement in review notes ([#230](https://github.com/cedricziel/hermes-app/issues/230)) ([627066f](https://github.com/cedricziel/hermes-app/commit/627066fe192ebaa74afd85436cb1467c3196b869))
* link the component catalog from the readme ([#246](https://github.com/cedricziel/hermes-app/issues/246)) ([d1fef3d](https://github.com/cedricziel/hermes-app/commit/d1fef3d116f0b88398a2364a79f8e5d68d859551))

## [0.1.27](https://github.com/cedricziel/hermes-app/compare/v0.1.26...v0.1.27) (2026-09-20)


### Features

* **chat:** load older messages when scrolling to the top ([#225](https://github.com/cedricziel/hermes-app/issues/225)) ([ddd5b79](https://github.com/cedricziel/hermes-app/commit/ddd5b79304b07eb4cc91c2ca659c4ae03726bf32))

## [0.1.26](https://github.com/cedricziel/hermes-app/compare/v0.1.25...v0.1.26) (2026-09-20)


### Bug Fixes

* **ios:** add privacy manifests for the app, share extension and watch app ([#222](https://github.com/cedricziel/hermes-app/issues/222)) ([028c34e](https://github.com/cedricziel/hermes-app/commit/028c34e035c287f114ba56d4fe740cff99043510))

## [0.1.25](https://github.com/cedricziel/hermes-app/compare/v0.1.24...v0.1.25) (2026-09-20)


### Features

* **auth:** help users who reach Hermes over Tailscale or WireGuard ([#221](https://github.com/cedricziel/hermes-app/issues/221)) ([d3cd22b](https://github.com/cedricziel/hermes-app/commit/d3cd22b39a3f6a0e76ed7333ea5ac2d4283298a9))
* **chat:** expand tool calls and give messages room ([#216](https://github.com/cedricziel/hermes-app/issues/216)) ([facd672](https://github.com/cedricziel/hermes-app/commit/facd672262b0cd05a6ff49e9f4fd1f9920bef9c9))


### Bug Fixes

* **chat:** keep reasoning in order with tool calls and send on Enter ([#218](https://github.com/cedricziel/hermes-app/issues/218)) ([726c95e](https://github.com/cedricziel/hermes-app/commit/726c95e0cd5cc554abb9839044b9564165c4063c))
* **chat:** stretch the sections of an expanded tool card ([#217](https://github.com/cedricziel/hermes-app/issues/217)) ([07c4f1f](https://github.com/cedricziel/hermes-app/commit/07c4f1fbb5eadb0e8f2ab32f6d7628465c363c25))
* rendering problems found by the workflow screenshots ([#219](https://github.com/cedricziel/hermes-app/issues/219)) ([f3b9da2](https://github.com/cedricziel/hermes-app/commit/f3b9da2a83dfea4b9dc70f211eeec2ce0d72e07a))


### Documentation

* **openspec:** archive assistant-message-ui and plugins-providers ([#215](https://github.com/cedricziel/hermes-app/issues/215)) ([cf4694c](https://github.com/cedricziel/hermes-app/commit/cf4694c5c507866854e6b997697ff0183794d25d))
* **openspec:** archive the scheduled tasks changes ([#213](https://github.com/cedricziel/hermes-app/issues/213)) ([797942d](https://github.com/cedricziel/hermes-app/commit/797942d49dda4833596f3510d16b85a04fccd6a3))

## [0.1.24](https://github.com/cedricziel/hermes-app/compare/v0.1.23...v0.1.24) (2026-09-20)


### Features

* **mcp:** add custom MCP servers and edit them as JSON ([#212](https://github.com/cedricziel/hermes-app/issues/212)) ([10a25d7](https://github.com/cedricziel/hermes-app/commit/10a25d75bfc484dcfd1392920897b3ab05c01743))
* **mcp:** install MCP servers from the catalog and sign in to them ([#204](https://github.com/cedricziel/hermes-app/issues/204)) ([3c77539](https://github.com/cedricziel/hermes-app/commit/3c7753907ebbbe2716f199f8c98d9b24e81b39a5))
* **schedules:** notify when a scheduled task runs ([#207](https://github.com/cedricziel/hermes-app/issues/207)) ([a6d443f](https://github.com/cedricziel/hermes-app/commit/a6d443f8100d982e1170e417ffa8f415595675e8))

## [0.1.23](https://github.com/cedricziel/hermes-app/compare/v0.1.22...v0.1.23) (2026-09-20)


### Features

* **chat:** show files and images the agent sends ([#210](https://github.com/cedricziel/hermes-app/issues/210)) ([cee2f4e](https://github.com/cedricziel/hermes-app/commit/cee2f4e308884751e0d2874b07ba9bd01e0aa687))
* **chat:** show reasoning, reply actions and follow-up chips ([#208](https://github.com/cedricziel/hermes-app/issues/208)) ([b349ad7](https://github.com/cedricziel/hermes-app/commit/b349ad7cfa6b4caa8e01fcf50a058e70d9128f8d))
* **plugins:** choose the memory provider and context engine from the app ([#202](https://github.com/cedricziel/hermes-app/issues/202)) ([cf00024](https://github.com/cedricziel/hermes-app/commit/cf000249a8cfeebfad817de51e78d564509c7afc))
* **schedules:** create and edit scheduled tasks ([#206](https://github.com/cedricziel/hermes-app/issues/206)) ([c037d3f](https://github.com/cedricziel/hermes-app/commit/c037d3f09d333e3b56070f6165b5832b5681e7b5))
* **schedules:** watch and control scheduled tasks from a Schedules tab ([#205](https://github.com/cedricziel/hermes-app/issues/205)) ([822d183](https://github.com/cedricziel/hermes-app/commit/822d18349b0e0f24db595815541122a5a91a6791))

## [0.1.22](https://github.com/cedricziel/hermes-app/compare/v0.1.21...v0.1.22) (2026-09-20)


### Features

* **chat:** attach from the file picker, camera, drop and paste ([#196](https://github.com/cedricziel/hermes-app/issues/196)) ([37e47ca](https://github.com/cedricziel/hermes-app/commit/37e47ca1a80559482cd3999d902800f94c902d6d))
* **chat:** send attached files to Hermes ([#194](https://github.com/cedricziel/hermes-app/issues/194)) ([c74c88b](https://github.com/cedricziel/hermes-app/commit/c74c88ba7acd39bd2d751fee5648710e26178852))
* **mcp:** manage MCP servers from the app ([#193](https://github.com/cedricziel/hermes-app/issues/193)) ([f75b93f](https://github.com/cedricziel/hermes-app/commit/f75b93fdf9c44cd804e2a2ed428d3e576cbb25e4))


### Bug Fixes

* **ios:** add location purpose string for App Store validation ([#203](https://github.com/cedricziel/hermes-app/issues/203)) ([79ea223](https://github.com/cedricziel/hermes-app/commit/79ea223e9f19202dde5ced77edb5a7891a2cb1af))

## [0.1.21](https://github.com/cedricziel/hermes-app/compare/v0.1.20...v0.1.21) (2026-09-20)


### Features

* **kanban:** active workers and board export and import ([#198](https://github.com/cedricziel/hermes-app/issues/198)) ([fee6303](https://github.com/cedricziel/hermes-app/commit/fee6303fbfe5576dfd325652ed6cd60fa01a2dec))
* **plugins:** browse the catalog and install plugins from the app ([#199](https://github.com/cedricziel/hermes-app/issues/199)) ([29bda4f](https://github.com/cedricziel/hermes-app/commit/29bda4f849c885c49082fff04f5c7d98f1056b69))

## [0.1.20](https://github.com/cedricziel/hermes-app/compare/v0.1.19...v0.1.20) (2026-09-20)


### Features

* **kanban:** estimate work and post task updates to a home channel ([#197](https://github.com/cedricziel/hermes-app/issues/197)) ([23638ee](https://github.com/cedricziel/hermes-app/commit/23638ee288b332c0ea4f431c61fc6402aa8d0a2a))
* **plugins:** manage installed Hermes plugins from the app ([#191](https://github.com/cedricziel/hermes-app/issues/191)) ([e2ea4d8](https://github.com/cedricziel/hermes-app/commit/e2ea4d86d97a5dd24d219c3333e36db88dae3df1))
* **skills:** discover, scan and install skills from the hub ([#192](https://github.com/cedricziel/hermes-app/issues/192)) ([454fe12](https://github.com/cedricziel/hermes-app/commit/454fe122905a359a014a58d081a8639725e249ab))

## [0.1.19](https://github.com/cedricziel/hermes-app/compare/v0.1.18...v0.1.19) (2026-09-20)


### Features

* **kanban:** attach and save files on a task ([#185](https://github.com/cedricziel/hermes-app/issues/185)) ([6efb2e3](https://github.com/cedricziel/hermes-app/commit/6efb2e3c9ace883970b9418e03ee1993cfa5f71e))
* **skills:** add a Skills page to the chat sidebar ([#189](https://github.com/cedricziel/hermes-app/issues/189)) ([e6ecdd0](https://github.com/cedricziel/hermes-app/commit/e6ecdd0e21c23fb70ef5ad461c2f1b4ee8d17438))


### Bug Fixes

* **android:** compile file_picker's Kotlin sources with Built-in Kotlin turned off ([#188](https://github.com/cedricziel/hermes-app/issues/188)) ([e1901cd](https://github.com/cedricziel/hermes-app/commit/e1901cd434f0fd4005f78f52ff1678e439d58f86))
* **chat:** start on the new chat screen instead of the first thread ([#187](https://github.com/cedricziel/hermes-app/issues/187)) ([7ba5791](https://github.com/cedricziel/hermes-app/commit/7ba5791b63e43d0fdc4966765287cf2499441eec))

## [0.1.18](https://github.com/cedricziel/hermes-app/compare/v0.1.17...v0.1.18) (2026-09-20)


### Features

* **chat:** let the user stop a reply that is running ([#178](https://github.com/cedricziel/hermes-app/issues/178)) ([8120dad](https://github.com/cedricziel/hermes-app/commit/8120dad32292a6e53272ccaab731320221877826))

## [0.1.17](https://github.com/cedricziel/hermes-app/compare/v0.1.16...v0.1.17) (2026-09-20)


### Bug Fixes

* **chat:** refuse unhandled requests only in sessions this app replies in ([#174](https://github.com/cedricziel/hermes-app/issues/174)) ([0707cce](https://github.com/cedricziel/hermes-app/commit/0707cce05bdeb5eecadd128a134093284412f552))
* **chat:** say that attached files are sent by name only ([#183](https://github.com/cedricziel/hermes-app/issues/183)) ([d607e74](https://github.com/cedricziel/hermes-app/commit/d607e74e5da470f47d0a63c640e856a6821ffb88))
* **shell:** dismiss screens pushed over Kanban and put Chat in front on a launch tap ([#181](https://github.com/cedricziel/hermes-app/issues/181)) ([87535dc](https://github.com/cedricziel/hermes-app/commit/87535dc348473defe909ae24413de77451d2200d))

## [0.1.16](https://github.com/cedricziel/hermes-app/compare/v0.1.15...v0.1.16) (2026-09-20)


### Features

* **chat:** let the user skip a secret or sudo request ([#161](https://github.com/cedricziel/hermes-app/issues/161)) ([e4537e1](https://github.com/cedricziel/hermes-app/commit/e4537e1ee54df956f55dede655f47c130c6a3cb9))


### Bug Fixes

* **auth:** verify the new token before storing it after sign-in ([#173](https://github.com/cedricziel/hermes-app/issues/173)) ([59f86ca](https://github.com/cedricziel/hermes-app/commit/59f86cab4f40f1e0f9c22bd6d59a02effc943c84))
* **chat:** do not list or send unscoped when the active profile lookup fails ([#172](https://github.com/cedricziel/hermes-app/issues/172)) ([4eb098c](https://github.com/cedricziel/hermes-app/commit/4eb098cdea270fb31af2f6849c0df3a7bcf9d819))
* **chat:** explain when the selected profile no longer exists ([#166](https://github.com/cedricziel/hermes-app/issues/166)) ([5df3f0d](https://github.com/cedricziel/hermes-app/commit/5df3f0d564a1fb0badc5310ded5d7b494fddcefb))
* **kanban:** show the unavailable page when a refresh answers 404 ([#171](https://github.com/cedricziel/hermes-app/issues/171)) ([c6546b3](https://github.com/cedricziel/hermes-app/commit/c6546b3ba36533e44feccd1f775e56f999b7da35))
* **shell:** switch to Chat for taps and shares, and reset the Kanban tab state ([#165](https://github.com/cedricziel/hermes-app/issues/165)) ([5a3983d](https://github.com/cedricziel/hermes-app/commit/5a3983df2b81a5a6bd14125bd74f4dde162fa147))
* **watch:** show a note instead of an empty bubble for a reply without text ([#170](https://github.com/cedricziel/hermes-app/issues/170)) ([519a8a3](https://github.com/cedricziel/hermes-app/commit/519a8a36578ab5db6e24e0a8fbf84045340a5f6c))

## [0.1.15](https://github.com/cedricziel/hermes-app/compare/v0.1.14...v0.1.15) (2026-09-20)


### Features

* **app-lock:** lock the app behind Face ID, Touch ID or the device passcode ([#158](https://github.com/cedricziel/hermes-app/issues/158)) ([e83f664](https://github.com/cedricziel/hermes-app/commit/e83f664b24ed6bd4bc5719abb20248dcac30b509))
* **chat:** answer prompts the gateway sends as server-to-client requests ([#145](https://github.com/cedricziel/hermes-app/issues/145)) ([8677ce8](https://github.com/cedricziel/hermes-app/commit/8677ce8867345b90bd5eaa5ead197515d3dd5dc4))
* **kanban:** runs, worker log and attachments on a task ([#76](https://github.com/cedricziel/hermes-app/issues/76)) ([131831c](https://github.com/cedricziel/hermes-app/commit/131831c9fb9c55101e43e40a85bf148b4e3a56e6))
* **watch:** announce watch-sent replies with a notification ([#159](https://github.com/cedricziel/hermes-app/issues/159)) ([18673ed](https://github.com/cedricziel/hermes-app/commit/18673ed03c8756b9d24bb6cbec0bb3753085edc1))


### Documentation

* **openspec:** archive the notifications and Kanban designs and remove docs/superpowers ([#154](https://github.com/cedricziel/hermes-app/issues/154)) ([01f9921](https://github.com/cedricziel/hermes-app/commit/01f992189cac9a86f9244bd908e8c8e8e19487d7))

## [0.1.14](https://github.com/cedricziel/hermes-app/compare/v0.1.13...v0.1.14) (2026-09-20)


### Features

* **chat:** show a card for secret and sudo requests the app cannot answer ([#127](https://github.com/cedricziel/hermes-app/issues/127)) ([a0a08e7](https://github.com/cedricziel/hermes-app/commit/a0a08e782d7fa983abc2468365dc18da76d2301c))
* **kanban:** manage boards ([#74](https://github.com/cedricziel/hermes-app/issues/74)) ([9606cb4](https://github.com/cedricziel/hermes-app/commit/9606cb441ef8d805440aa238f7f6172d2d2f71b7))
* **update:** prompt to update when a newer release exists ([#150](https://github.com/cedricziel/hermes-app/issues/150)) ([5aebb42](https://github.com/cedricziel/hermes-app/commit/5aebb428d9529946d3dc90675f2715b5ec072b57))


### Bug Fixes

* **auth:** prefill the saved server address on the setup screen ([#151](https://github.com/cedricziel/hermes-app/issues/151)) ([7e7c5ea](https://github.com/cedricziel/hermes-app/commit/7e7c5ea900e16bfe67a4a9f3131425eb76a46dac))
* **auth:** show a connection error for a malformed status or identity response ([#146](https://github.com/cedricziel/hermes-app/issues/146)) ([b40896e](https://github.com/cedricziel/hermes-app/commit/b40896ee4204113f09739118c8e7c74c72ff0b8f))
* **auth:** stay on the splash while restoring the saved server ([#132](https://github.com/cedricziel/hermes-app/issues/132)) ([475e7e7](https://github.com/cedricziel/hermes-app/commit/475e7e780d9bbf3086b900f60c2701ddb2bf4c33))
* **auth:** stop refreshing on every request when the server omits expires_at ([#141](https://github.com/cedricziel/hermes-app/issues/141)) ([b0f822b](https://github.com/cedricziel/hermes-app/commit/b0f822ba8d6cb8036252979b8ebb2ecbe1e86ecc))
* **telemetry:** only export to https endpoints ([#139](https://github.com/cedricziel/hermes-app/issues/139)) ([6322cfa](https://github.com/cedricziel/hermes-app/commit/6322cfa35f486e8a7438703a668e6bcab9e68a1d))
* **telemetry:** restore the two-segment route and align span and log status ([#144](https://github.com/cedricziel/hermes-app/issues/144)) ([03856f2](https://github.com/cedricziel/hermes-app/commit/03856f2008adfc02352ccacebd3283858e1b5b51))
* **watch:** clear the reply field after a message is sent ([#152](https://github.com/cedricziel/hermes-app/issues/152)) ([a89df4e](https://github.com/cedricziel/hermes-app/commit/a89df4ecee200b932156f550058fc5dc0e8673c5))


### Documentation

* add screenshots to the README and the App Store listing ([#136](https://github.com/cedricziel/hermes-app/issues/136)) ([26c8406](https://github.com/cedricziel/hermes-app/commit/26c8406c0151dcfd47338bda2312a7bfd87daf02))
* tidy the README, retake the Mac screenshots wide, add a screenshots skill ([#147](https://github.com/cedricziel/hermes-app/issues/147)) ([309648a](https://github.com/cedricziel/hermes-app/commit/309648a2d564007b8bb3f93321b5ca118b767b7b))

## [0.1.13](https://github.com/cedricziel/hermes-app/compare/v0.1.12...v0.1.13) (2026-09-20)


### Features

* human-readable app name and a launch screen ([#93](https://github.com/cedricziel/hermes-app/issues/93)) ([2c79bd7](https://github.com/cedricziel/hermes-app/commit/2c79bd7758b546ba29dce53bd1bbdf1e8c60a59c))
* **kanban:** open, create and edit tasks ([#66](https://github.com/cedricziel/hermes-app/issues/66)) ([dab4e9d](https://github.com/cedricziel/hermes-app/commit/dab4e9d74673d1435e1ba8703266d0ac6b911761))
* **kanban:** triage helpers, bulk changes, dispatcher and orchestration ([#68](https://github.com/cedricziel/hermes-app/issues/68)) ([4cd0949](https://github.com/cedricziel/hermes-app/commit/4cd0949be0e329211b789e3b08280846c26d4498))


### Bug Fixes

* **auth:** treat an unreadable stored session as signed out ([#126](https://github.com/cedricziel/hermes-app/issues/126)) ([68a39dd](https://github.com/cedricziel/hermes-app/commit/68a39dd399efb6cc5efb4d37dd9a3da8c9503785))
* **bots:** let an unconfigured but enabled bot be switched off ([#121](https://github.com/cedricziel/hermes-app/issues/121)) ([cb50875](https://github.com/cedricziel/hermes-app/commit/cb50875a47e30c4077bdba162ec3d79ec19b3158))
* **chat:** give an approval request without choices a way to answer ([#122](https://github.com/cedricziel/hermes-app/issues/122)) ([fb327fa](https://github.com/cedricziel/hermes-app/commit/fb327fa8a86d6b5152c2eb1596443b382363f392))
* **chat:** scope gateway sessions to the selected profile ([#115](https://github.com/cedricziel/hermes-app/issues/115)) ([7b3d390](https://github.com/cedricziel/hermes-app/commit/7b3d39056364d076da1d58dd36ae57d142b10db2))
* **chat:** send one prompt at a time on a thread ([#124](https://github.com/cedricziel/hermes-app/issues/124)) ([d1d2b5a](https://github.com/cedricziel/hermes-app/commit/d1d2b5aaf38590ed75db27081ea127ff998f832b))
* **chat:** show a message when a reply fails with no text ([#125](https://github.com/cedricziel/hermes-app/issues/125)) ([e9fadab](https://github.com/cedricziel/hermes-app/commit/e9fadab3a896e1ab1314d4402ee3bbecff22aecb))


### Documentation

* guide the agent on skills and pub.dev plugins ([#133](https://github.com/cedricziel/hermes-app/issues/133)) ([d7e0e42](https://github.com/cedricziel/hermes-app/commit/d7e0e4230d1e8612b745e9fa778bebf517745a4b))
* **openspec:** sync telemetry and notifications specs with main ([#117](https://github.com/cedricziel/hermes-app/issues/117)) ([7b937f9](https://github.com/cedricziel/hermes-app/commit/7b937f9d1fa9c60f6eec36b02901f5443189a0bb))

## [0.1.12](https://github.com/cedricziel/hermes-app/compare/v0.1.11...v0.1.12) (2026-09-20)


### Bug Fixes

* **auth:** never leave sign-in spinning after a cancel ([#111](https://github.com/cedricziel/hermes-app/issues/111)) ([5752339](https://github.com/cedricziel/hermes-app/commit/575233910997496ab074cd4aa0412efd6869ad5f))
* **telemetry:** record a route template instead of raw paths ([#112](https://github.com/cedricziel/hermes-app/issues/112)) ([7fbfb12](https://github.com/cedricziel/hermes-app/commit/7fbfb1261c6f17d68a14038ac3369bd5dbc0831a))

## [0.1.11](https://github.com/cedricziel/hermes-app/compare/v0.1.10...v0.1.11) (2026-09-20)


### Features

* **notifications:** announce broken turns and tidy up notification taps ([#71](https://github.com/cedricziel/hermes-app/issues/71)) ([2aadae8](https://github.com/cedricziel/hermes-app/commit/2aadae80fe188c90eeb5e3cb6491d80af83da4a7))
* **telemetry:** report the hardware model and more device facts ([#69](https://github.com/cedricziel/hermes-app/issues/69)) ([bce0bf7](https://github.com/cedricziel/hermes-app/commit/bce0bf750b5bd6f655f4f510175ce3115bfa222b))
* **telemetry:** trace the gateway socket as an upgrade plus linked messages ([#77](https://github.com/cedricziel/hermes-app/issues/77)) ([81aeb4c](https://github.com/cedricziel/hermes-app/commit/81aeb4c556db6f96e97f6648ef24e580edb4e7df))
* **watch:** thread list and conversation screens on the watch ([#60](https://github.com/cedricziel/hermes-app/issues/60)) ([f2b56b1](https://github.com/cedricziel/hermes-app/commit/f2b56b1e442e31dbbae09ce7f53870ee6877441b))


### Bug Fixes

* **watch:** archive the watch app with the watchOS SDK in Release ([#73](https://github.com/cedricziel/hermes-app/issues/73)) ([ca8346d](https://github.com/cedricziel/hermes-app/commit/ca8346dfdcb8b24c1a39dbc28fffb9b9fd882411))


### Documentation

* **openspec:** add baseline auth spec ([#79](https://github.com/cedricziel/hermes-app/issues/79)) ([207d291](https://github.com/cedricziel/hermes-app/commit/207d2912665c360e0bf8a438b85b7b25b438ec8a))
* **openspec:** add baseline chat, profiles and bots specs ([#101](https://github.com/cedricziel/hermes-app/issues/101)) ([6ade765](https://github.com/cedricziel/hermes-app/commit/6ade7650f5fae3f24260020885d1202f2ddf1543))
* **openspec:** add baseline kanban, notifications, sharing and appearance specs ([#92](https://github.com/cedricziel/hermes-app/issues/92)) ([c4b96a7](https://github.com/cedricziel/hermes-app/commit/c4b96a75856f242ff93d4cd833658889a120684e))
* **openspec:** add baseline telemetry spec ([#78](https://github.com/cedricziel/hermes-app/issues/78)) ([8429a71](https://github.com/cedricziel/hermes-app/commit/8429a7126ced26fce95f31cc4009be9fe6d640cd))
* **openspec:** archive the agent input requests design and retire docs/superpowers ([#80](https://github.com/cedricziel/hermes-app/issues/80)) ([ede92ed](https://github.com/cedricziel/hermes-app/commit/ede92ed063310596f6e5ba5fe8ace91a6bb49310))

## [0.1.10](https://github.com/cedricziel/hermes-app/compare/v0.1.9...v0.1.10) (2026-09-20)


### Features

* **kanban:** detect the Kanban plugin and add a Chat/Kanban navigation shell ([#64](https://github.com/cedricziel/hermes-app/issues/64)) ([9f3ddde](https://github.com/cedricziel/hermes-app/commit/9f3ddded02c7bd7775e1abb0437d0cdc98efc907))
* **kanban:** show the board and keep it live ([#65](https://github.com/cedricziel/hermes-app/issues/65)) ([799907c](https://github.com/cedricziel/hermes-app/commit/799907c763a78a0d5faf9720503384a3f221a1f7))
* **notifications:** notify when a reply finishes or the agent needs you ([#56](https://github.com/cedricziel/hermes-app/issues/56)) ([22a4c7b](https://github.com/cedricziel/hermes-app/commit/22a4c7b0adc499dc4dc8f36271e5bed90b36d800))
* **telemetry:** tag telemetry with the system, its version and the form factor ([#63](https://github.com/cedricziel/hermes-app/issues/63)) ([ec57b39](https://github.com/cedricziel/hermes-app/commit/ec57b396dac4a9795f1b0e5718207c9640d126cf))
* **watch:** add an empty watchOS app target embedded in the iOS app ([#57](https://github.com/cedricziel/hermes-app/issues/57)) ([70199fd](https://github.com/cedricziel/hermes-app/commit/70199fd1cf8ac21f9418923d44a3b7d01cdbe760))
* **watch:** relay watch requests to Hermes through the phone ([#59](https://github.com/cedricziel/hermes-app/issues/59)) ([70e892f](https://github.com/cedricziel/hermes-app/commit/70e892fe70779b349dd26d7c4782f4e8dede9ca6))


### Documentation

* add CLAUDE.md and initialize OpenSpec ([#70](https://github.com/cedricziel/hermes-app/issues/70)) ([97c796a](https://github.com/cedricziel/hermes-app/commit/97c796a76ff0c6a82ccf7b506f1d072216954336))

## [0.1.9](https://github.com/cedricziel/hermes-app/compare/v0.1.8...v0.1.9) (2026-09-20)


### Bug Fixes

* **auth:** listen for the sign-in redirect before opening the browser ([#61](https://github.com/cedricziel/hermes-app/issues/61)) ([c6a736e](https://github.com/cedricziel/hermes-app/commit/c6a736e65d463d7de9fc16742624846cbf2eea8a))

## [0.1.8](https://github.com/cedricziel/hermes-app/compare/v0.1.7...v0.1.8) (2026-09-20)


### Features

* **chat:** answer agent approval and clarify requests ([#55](https://github.com/cedricziel/hermes-app/issues/55)) ([519e534](https://github.com/cedricziel/hermes-app/commit/519e534b2edeb25357675c1ba7681c36760d909f))
* dark mode with a system default and a setting to override it ([#53](https://github.com/cedricziel/hermes-app/issues/53)) ([57061d1](https://github.com/cedricziel/hermes-app/commit/57061d1b25d5ad0a7a0940f4a8a147f2e3794bc2))


### Bug Fixes

* **auth:** stop signing users out on concurrent 401s and never leave sign-in spinning ([#58](https://github.com/cedricziel/hermes-app/issues/58)) ([5eb9650](https://github.com/cedricziel/hermes-app/commit/5eb96505f0531029fad6092a8959d914824e68e3))

## [0.1.7](https://github.com/cedricziel/hermes-app/compare/v0.1.6...v0.1.7) (2026-09-19)


### Features

* **bots:** set a bot up from the app ([#50](https://github.com/cedricziel/hermes-app/issues/50)) ([37f309e](https://github.com/cedricziel/hermes-app/commit/37f309e0503b3b8176349fb32428ef0b715c9ae9))
* **chat:** rename, pin, archive and delete threads, and page the thread list ([#52](https://github.com/cedricziel/hermes-app/issues/52)) ([10e70ab](https://github.com/cedricziel/hermes-app/commit/10e70abac2d570420d50dc3e0d816bd5791c3a6d))
* **chat:** send messages through the dashboard gateway ([#48](https://github.com/cedricziel/hermes-app/issues/48)) ([1cbc1be](https://github.com/cedricziel/hermes-app/commit/1cbc1be38d67bafd61f97e9ba99563dd59e9a95e))
* **chat:** show the threads of the selected profile ([#46](https://github.com/cedricziel/hermes-app/issues/46)) ([a7cdce8](https://github.com/cedricziel/hermes-app/commit/a7cdce81f0917e7ceadc458bac689a93a69d25b6))
* **chat:** stream replies from the Hermes dashboard gateway ([#47](https://github.com/cedricziel/hermes-app/issues/47)) ([dc57ee1](https://github.com/cedricziel/hermes-app/commit/dc57ee1b00f1efcf4134c0919c652891b45d0602))
* **chat:** stream the reply from a transport into the chat screen ([#45](https://github.com/cedricziel/hermes-app/issues/45)) ([a6c4606](https://github.com/cedricziel/hermes-app/commit/a6c4606bd836317c5aac8fa267f40241add745cb))
* **telemetry:** emit logs for HTTP requests and uncaught errors ([#43](https://github.com/cedricziel/hermes-app/issues/43)) ([2a5fef0](https://github.com/cedricziel/hermes-app/commit/2a5fef0918fc2c62778580edf107efadc1b1a6ad))


### Bug Fixes

* **auth:** send the page session token to a dashboard without the gate ([#51](https://github.com/cedricziel/hermes-app/issues/51)) ([1c570cc](https://github.com/cedricziel/hermes-app/commit/1c570cc4d33017b47a1a34a302897c223b21afd7))

## [0.1.6](https://github.com/cedricziel/hermes-app/compare/v0.1.5...v0.1.6) (2026-09-19)


### Features

* **bots:** list messaging platforms and switch them on or off ([#40](https://github.com/cedricziel/hermes-app/issues/40)) ([71b8a8b](https://github.com/cedricziel/hermes-app/commit/71b8a8b9e531d8a5beb615121fbfbfe3acb5d2dd))
* **chat:** load threads and messages from the Hermes dashboard ([#35](https://github.com/cedricziel/hermes-app/issues/35)) ([92f1c71](https://github.com/cedricziel/hermes-app/commit/92f1c7117f31132fe1eacaa6f7dcce098ec4b52d))
* **profiles:** list Hermes profiles and switch the active one ([#39](https://github.com/cedricziel/hermes-app/issues/39)) ([736a4ba](https://github.com/cedricziel/hermes-app/commit/736a4bacff19bc7a2b447f9c6648cddf302284f9))


### Bug Fixes

* **api-client:** decode JSON bodies for routes without a response schema ([#34](https://github.com/cedricziel/hermes-app/issues/34)) ([ddee478](https://github.com/cedricziel/hermes-app/commit/ddee4785a987916d9fae87f967a485fc3fabd473))
* **api-client:** find the deserialize default case regardless of whitespace ([#38](https://github.com/cedricziel/hermes-app/issues/38)) ([c057b7f](https://github.com/cedricziel/hermes-app/commit/c057b7f03de5cc109f0342b99ef5f82c0a8269ef))

## [0.1.5](https://github.com/cedricziel/hermes-app/compare/v0.1.4...v0.1.5) (2026-09-19)


### Features

* **android:** accept shares of text, links and files ([#23](https://github.com/cedricziel/hermes-app/issues/23)) ([c93334e](https://github.com/cedricziel/hermes-app/commit/c93334e5119e24b9017eb95ee9beb990c4b6318a))
* **chat:** render the thread with flutter_chat_ui ([#26](https://github.com/cedricziel/hermes-app/issues/26)) ([d96203f](https://github.com/cedricziel/hermes-app/commit/d96203f6caf09368e21f9b0003a3064008bbd735))
* **ios:** add share extension that hands content to the app ([#21](https://github.com/cedricziel/hermes-app/issues/21)) ([42c4fea](https://github.com/cedricziel/hermes-app/commit/42c4feae42d511ec806ad679cf055ef186760ea0))
* **macos:** add share extension that hands content to the app ([#25](https://github.com/cedricziel/hermes-app/issues/25)) ([6a6727e](https://github.com/cedricziel/hermes-app/commit/6a6727e1497cb0c48ef8e0f8092ab97a2e870124))
* **share:** receive shared text and files in the chat composer ([#19](https://github.com/cedricziel/hermes-app/issues/19)) ([f0ff09f](https://github.com/cedricziel/hermes-app/commit/f0ff09ff527fe65a7a563a036c08234224498963))
* **telemetry:** export logs and traces to SignalDB via flutter_otel ([#30](https://github.com/cedricziel/hermes-app/issues/30)) ([09576da](https://github.com/cedricziel/hermes-app/commit/09576da533fb80d40c897a3e1c742226b0f643c2))


### Bug Fixes

* **auth:** explain when the server lacks native app sign-in ([#24](https://github.com/cedricziel/hermes-app/issues/24)) ([3da66ac](https://github.com/cedricziel/hermes-app/commit/3da66aca29687d8653e10fd8a0fb05579470c046))


### Documentation

* link the TestFlight beta in the README ([#28](https://github.com/cedricziel/hermes-app/issues/28)) ([46a55af](https://github.com/cedricziel/hermes-app/commit/46a55afd5472b9eaa331a02eb45ec0fc088ded0b))

## [0.1.4](https://github.com/cedricziel/hermes-app/compare/v0.1.3...v0.1.4) (2026-09-19)


### Bug Fixes

* **auth:** keep app foregrounded during iOS OIDC login ([#17](https://github.com/cedricziel/hermes-app/issues/17)) ([6347a75](https://github.com/cedricziel/hermes-app/commit/6347a7577d6b22ad39a8859e7e61baf06339979e))

## [0.1.3](https://github.com/cedricziel/hermes-app/compare/v0.1.2...v0.1.3) (2026-09-19)


### Features

* Add assistant-ui-style chat screen design preview ([#10](https://github.com/cedricziel/hermes-app/issues/10)) ([9315699](https://github.com/cedricziel/hermes-app/commit/9315699eca3c0ab7953c70eaa78b85b0d8024265))
* app icons and App Store listing text ([#16](https://github.com/cedricziel/hermes-app/issues/16)) ([95a553b](https://github.com/cedricziel/hermes-app/commit/95a553b444921f2aa9dcf084a6c7277f8a4f35e0))
* Hook up pre-commit for Flutter ([#14](https://github.com/cedricziel/hermes-app/issues/14)) ([74c428e](https://github.com/cedricziel/hermes-app/commit/74c428e3177a9e19323de7cddf9a88a9f2321e38))

## [0.1.2](https://github.com/cedricziel/hermes-app/compare/v0.1.1...v0.1.2) (2026-09-19)


### Bug Fixes

* set signing before flutter build so CI needs no development cert ([#12](https://github.com/cedricziel/hermes-app/issues/12)) ([25e90db](https://github.com/cedricziel/hermes-app/commit/25e90db8451b81b1e9c1961fc848e4077f5dd38f))

## [0.1.1](https://github.com/cedricziel/hermes-app/compare/v0.1.0...v0.1.1) (2026-09-19)


### Features

* generate a Dart client from the Hermes Agent OpenAPI spec ([#6](https://github.com/cedricziel/hermes-app/issues/6)) ([f6791fa](https://github.com/cedricziel/hermes-app/commit/f6791fa1c2e24c896c1cf869d3713959e0c6717c))


### Documentation

* add Hermes Agent OpenAPI spec ([63784ae](https://github.com/cedricziel/hermes-app/commit/63784aed0d68eba068a59782307a1fd721d45c1c))
* add Hermes Agent OpenAPI spec ([a5eafd7](https://github.com/cedricziel/hermes-app/commit/a5eafd73fef83b6526b16d4f336e11337533503c))
