# Changelog

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
