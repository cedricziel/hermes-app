# Changelog

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
