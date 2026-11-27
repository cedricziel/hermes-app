# Changelog

## [0.1.86](https://github.com/cedricziel/hermes-app/compare/v0.1.85...v0.1.86) (2026-11-26)


### Features

* **chat:** code view for read_file and write_file ([#1395](https://github.com/cedricziel/hermes-app/issues/1395)) ([bf19a31](https://github.com/cedricziel/hermes-app/commit/bf19a319bfbca1dad7c0cc45e697e1afa91d0de2))
* **chat:** image gallery for found and generated images ([#1419](https://github.com/cedricziel/hermes-app/issues/1419)) ([4089e7f](https://github.com/cedricziel/hermes-app/commit/4089e7f5c49393bfaecfe4de221dd8927b7f8ff6))
* **chat:** link preview cards for pages the agent opened ([#1414](https://github.com/cedricziel/hermes-app/issues/1414)) ([8aea662](https://github.com/cedricziel/hermes-app/commit/8aea662ea271cc462fe68db9e3806715b5bc953a))
* **chat:** mark regenerated replies and test jump to latest while streaming ([#1381](https://github.com/cedricziel/hermes-app/issues/1381)) ([7f5de37](https://github.com/cedricziel/hermes-app/commit/7f5de37f7ba7679f40ba488794d6cd97b2a37482))
* **chat:** sources row under a reply ([#1420](https://github.com/cedricziel/hermes-app/issues/1420)) ([7dd3e49](https://github.com/cedricziel/hermes-app/commit/7dd3e4917352043c8bb0374a6f6d5acb19b5c070))
* **chat:** table for a result that is a list of rows ([#1416](https://github.com/cedricziel/hermes-app/issues/1416)) ([088111e](https://github.com/cedricziel/hermes-app/commit/088111e3236695905662bd30562b8f45c20c93f4))


### Bug Fixes

* **chat:** translate the Stopped label and keep the reply actions on a narrow screen ([#1413](https://github.com/cedricziel/hermes-app/issues/1413)) ([5eb1e16](https://github.com/cedricziel/hermes-app/commit/5eb1e16ceb1e1a57e7008938fd2e49b3faf352aa))
* **l10n:** translate the reply action tooltips ([#1415](https://github.com/cedricziel/hermes-app/issues/1415)) ([322774d](https://github.com/cedricziel/hermes-app/commit/322774d8aea61e670d6152010e7d43a326138ce7))
* **l10n:** translate the strings the wider string scan found ([#1417](https://github.com/cedricziel/hermes-app/issues/1417)) ([01108c3](https://github.com/cedricziel/hermes-app/commit/01108c3898dbc468a7d4395eae8f736478773871))

## [0.1.85](https://github.com/cedricziel/hermes-app/compare/v0.1.84...v0.1.85) (2026-11-25)


### Features

* **auth:** ask once about a saved public http:// server ([#1383](https://github.com/cedricziel/hermes-app/issues/1383)) ([fa8216a](https://github.com/cedricziel/hermes-app/commit/fa8216a216d3e33a73e48b8f9b29023cfb6cdd8f))
* **chat:** mark branches in the chat list ([#1402](https://github.com/cedricziel/hermes-app/issues/1402)) ([1fee7fa](https://github.com/cedricziel/hermes-app/commit/1fee7fa802505f24928821d2c7b1f9c0181f4327))
* **chat:** open the original chat from a branch ([#1401](https://github.com/cedricziel/hermes-app/issues/1401)) ([c1d0f88](https://github.com/cedricziel/hermes-app/commit/c1d0f883c87a31c324668ec8a01ed111da8a169d))
* **chat:** read the branch parent from session rows ([#1394](https://github.com/cedricziel/hermes-app/issues/1394)) ([7cb8515](https://github.com/cedricziel/hermes-app/commit/7cb851555f67828a7a18de7c3d6152b91f80835d))
* **chat:** send an idempotency key with every branch and hide Branch when the server lacks it ([#1409](https://github.com/cedricziel/hermes-app/issues/1409)) ([ee822c8](https://github.com/cedricziel/hermes-app/commit/ee822c8ab923c07beebbaf328232c3441f798201))
* **chat:** the branched-from notice and branch glyph in the catalog ([#1389](https://github.com/cedricziel/hermes-app/issues/1389)) ([2e8ba28](https://github.com/cedricziel/hermes-app/commit/2e8ba28c95b56521d7d828134ab41e10e8ded657))
* **messaging:** a controller for linking WhatsApp ([#1174](https://github.com/cedricziel/hermes-app/issues/1174)) ([7c5b5a3](https://github.com/cedricziel/hermes-app/commit/7c5b5a3141193e2cff4bbd5de1122de981eda709))
* **messaging:** link WhatsApp by QR code ([#1400](https://github.com/cedricziel/hermes-app/issues/1400)) ([aba2137](https://github.com/cedricziel/hermes-app/commit/aba2137d7327333eefab713d48f425924e54fadf))
* **messaging:** the WhatsApp link widgets in the catalog ([#1182](https://github.com/cedricziel/hermes-app/issues/1182)) ([f500a08](https://github.com/cedricziel/hermes-app/commit/f500a0870f283e62886f225c6eabf30076b72729))
* **navigation:** optional menu bar on Windows and Linux ([#1345](https://github.com/cedricziel/hermes-app/issues/1345)) ([3d40a5f](https://github.com/cedricziel/hermes-app/commit/3d40a5f056f927978c232893ed653b0f2e7e0033))
* **profile-soul:** edit a profile's personality ([#1119](https://github.com/cedricziel/hermes-app/issues/1119)) ([fd5acea](https://github.com/cedricziel/hermes-app/commit/fd5aceadc49f5f02e2889cc4dfd7806a112abf43))


### Bug Fixes

* **api:** retry GETs that could not connect, with a jittered backoff ([#1376](https://github.com/cedricziel/hermes-app/issues/1376)) ([245b19a](https://github.com/cedricziel/hermes-app/commit/245b19a0e71238b266f6d086b21b41f202bd72da))
* **chat:** close abandoned message lookups on resume and explain a 409 on delete ([#1377](https://github.com/cedricziel/hermes-app/issues/1377)) ([3150180](https://github.com/cedricziel/hermes-app/commit/31501809909b5f001e43750bb8126f411e5afcc8))
* **chat:** drop a missing chat that arrives after the profile changed ([#1411](https://github.com/cedricziel/hermes-app/issues/1411)) ([346753f](https://github.com/cedricziel/hermes-app/commit/346753f071c0d7bfa909e92369251b6d59177edd))
* **chat:** report a tool body builder bug, and tighten three tests ([#1396](https://github.com/cedricziel/hermes-app/issues/1396)) ([abb40fc](https://github.com/cedricziel/hermes-app/commit/abb40fc894a3a08cf95c32e4c3b4c83c0e4ae2bd))
* **chat:** report bugs caught by chat catch-alls, with a guard for silent ones ([#1407](https://github.com/cedricziel/hermes-app/issues/1407)) ([0b8832c](https://github.com/cedricziel/hermes-app/commit/0b8832c04065f667ac77bc5bd7b385716ce1eb7f))
* **gateway:** end every request span by its deadline and join overlapping waiting-count reads ([#1382](https://github.com/cedricziel/hermes-app/issues/1382)) ([86cf7bf](https://github.com/cedricziel/hermes-app/commit/86cf7bf3760b1f4b7657b806ac77b0d72e09a5a3))
* **gateway:** stop and back off ticket mints after the server refuses one ([#1404](https://github.com/cedricziel/hermes-app/issues/1404)) ([b23db7f](https://github.com/cedricziel/hermes-app/commit/b23db7f0e9ccc827bf36b4a5e48005031df86eea))
* **harness:** close the import guard's blind spots and split the catalog test in the trial merge ([#1365](https://github.com/cedricziel/hermes-app/issues/1365)) ([f813b8e](https://github.com/cedricziel/hermes-app/commit/f813b8e6f07c4bbc29b7de04067f72e57997e6af))
* **ios:** close a chat photo with a swipe, as in Photos ([#1379](https://github.com/cedricziel/hermes-app/issues/1379)) ([b654934](https://github.com/cedricziel/hermes-app/commit/b65493469d29a1cbf1e834a3a054028323dfd02e))
* **l10n:** correct three count messages and guard plurals and literal fallbacks ([#1368](https://github.com/cedricziel/hermes-app/issues/1368)) ([b226352](https://github.com/cedricziel/hermes-app/commit/b2263528dd8e7b88fd0d252fdc80ee0f905ddaf9))
* **l10n:** German workers count and the Mac toolbar's English labels ([#1364](https://github.com/cedricziel/hermes-app/issues/1364)) ([7a7bcc2](https://github.com/cedricziel/hermes-app/commit/7a7bcc27c61feb29823b8c4975a0a4dd41b6fd2b))
* **l10n:** localize the Kanban assign and priority pickers and the plugin install report ([#1342](https://github.com/cedricziel/hermes-app/issues/1342)) ([aecc9e2](https://github.com/cedricziel/hermes-app/commit/aecc9e28cb597b26a4d08aacbdcd29483f63d504))
* **l10n:** localize the Mac chat toolbar and the Kanban workers screen ([#1355](https://github.com/cedricziel/hermes-app/issues/1355)) ([48c57a7](https://github.com/cedricziel/hermes-app/commit/48c57a788fe6db3a4d684ac2e6af17f98275b390))
* **l10n:** localize the recipient picker and the skills screen ([#1357](https://github.com/cedricziel/hermes-app/issues/1357)) ([05a5607](https://github.com/cedricziel/hermes-app/commit/05a56079e3966e2ad8af80322e7bf3d007dd1bc3))
* **l10n:** memory change failure and hub skill page text through l10n ([#1406](https://github.com/cedricziel/hermes-app/issues/1406)) ([4d149f4](https://github.com/cedricziel/hermes-app/commit/4d149f496e889b0fe76bcaa9c33451eef590028c))
* **l10n:** read helper defaults from localizations, emptying the English-default baseline ([#1346](https://github.com/cedricziel/hermes-app/issues/1346)) ([97d0fe1](https://github.com/cedricziel/hermes-app/commit/97d0fe1e7efd5182dfc620aa2dfa4579d67b100e))
* **l10n:** translate the English fallbacks the guard had baselined ([#1373](https://github.com/cedricziel/hermes-app/issues/1373)) ([1b3395f](https://github.com/cedricziel/hermes-app/commit/1b3395fafd54d5f8efae3a5a947def1998f481c8))
* **l10n:** translate the five label helpers and close two gaps of their guard ([#1384](https://github.com/cedricziel/hermes-app/issues/1384)) ([8bb27b1](https://github.com/cedricziel/hermes-app/commit/8bb27b18e976b86499e9a782747827fa716816b4))
* **l10n:** translate the Kanban strings that were still English ([#1369](https://github.com/cedricziel/hermes-app/issues/1369)) ([7486853](https://github.com/cedricziel/hermes-app/commit/7486853fa1016ea5fdd211229c0eb70a0509cd4a))
* **l10n:** translate the Memory learning section, skill usage and Discover Installed ([#1397](https://github.com/cedricziel/hermes-app/issues/1397)) ([e9b7429](https://github.com/cedricziel/hermes-app/commit/e9b7429a5e7821e8064ebfae0e05553a2a31a948))
* **l10n:** translate the remaining Kanban screens and the status and effort labels ([#1371](https://github.com/cedricziel/hermes-app/issues/1371)) ([b5edc58](https://github.com/cedricziel/hermes-app/commit/b5edc58e6add3315126c297455c1cb80fe1d653f))
* **macos:** stop the crash on every quit ([#1391](https://github.com/cedricziel/hermes-app/issues/1391)) ([c98b1e6](https://github.com/cedricziel/hermes-app/commit/c98b1e6ce969a1d50654241f1799a423a0f8f1ee))
* **navigation:** keep desktop chords from running commands behind a dialog ([#1356](https://github.com/cedricziel/hermes-app/issues/1356)) ([ebd1570](https://github.com/cedricziel/hermes-app/commit/ebd1570688a9cc7eea60630f59192e837a02e150))
* **settings:** fall back to defaults when the other saved settings cannot be read ([#1398](https://github.com/cedricziel/hermes-app/issues/1398)) ([e29f1e3](https://github.com/cedricziel/hermes-app/commit/e29f1e37528d37a2e317e44a8baa0c8dbf79341a))
* **settings:** fall back to defaults when the saved theme, dictation engine or App Lock choice cannot be read ([#1387](https://github.com/cedricziel/hermes-app/issues/1387)) ([1a608a1](https://github.com/cedricziel/hermes-app/commit/1a608a1fb81bb171dbd4c12253fdcd92f04b9acb))
* **telemetry:** end a suspended snapshot build's span at its budget and name each failed source's error type ([#1375](https://github.com/cedricziel/hermes-app/issues/1375)) ([4eb0acc](https://github.com/cedricziel/hermes-app/commit/4eb0acc543479c83b181b01993d589f3705db089))
* **widgetbook:** build use cases in a material_ui app, and test them in the catalog itself ([#1362](https://github.com/cedricziel/hermes-app/issues/1362)) ([e606e4c](https://github.com/cedricziel/hermes-app/commit/e606e4c9dd9ad66d132069933f93e2a08b8f1a3a))
* **widgets:** keep the form action on screen at the largest text ([#1180](https://github.com/cedricziel/hermes-app/issues/1180)) ([aa90881](https://github.com/cedricziel/hermes-app/commit/aa90881e90070bffe40139f2d09ef6b7fd89cee3))


### Performance

* **chat:** reuse a code block's subtree when nothing it shows has changed ([#1348](https://github.com/cedricziel/hermes-app/issues/1348)) ([6f2b1cd](https://github.com/cedricziel/hermes-app/commit/6f2b1cdee73b74ea34c57aeaaffa1d8600695d2d))


### Documentation

* **design:** branched-from notice and branch marker in the chat list ([#1386](https://github.com/cedricziel/hermes-app/issues/1386)) ([9a37321](https://github.com/cedricziel/hermes-app/commit/9a37321be549f2782763e513b20970ca7c5573a5))
* **design:** tool views and the sources row ([#1388](https://github.com/cedricziel/hermes-app/issues/1388)) ([c249cb6](https://github.com/cedricziel/hermes-app/commit/c249cb634008d60004b1a76e544fa54d70604ef6))
* drop the trial merge as a merge gate ([#1353](https://github.com/cedricziel/hermes-app/issues/1353)) ([ab5061e](https://github.com/cedricziel/hermes-app/commit/ab5061e5599ce67da9cda9e44d009200325f8158))
* **fleet-rules:** run every test that names what a change touches ([#1367](https://github.com/cedricziel/hermes-app/issues/1367)) ([738bf91](https://github.com/cedricziel/hermes-app/commit/738bf91f4b027ff73dfc4be21d9aca286621bcf9))
* **roadmap:** Flutter 3.50 landed through the import migration ([#1358](https://github.com/cedricziel/hermes-app/issues/1358)) ([69047a2](https://github.com/cedricziel/hermes-app/commit/69047a231e416c8683f60e5af65ebad20c1d0965))
* **roadmap:** update 23, release 0.1.84, seven merges, trial merge dropped ([#1352](https://github.com/cedricziel/hermes-app/issues/1352)) ([10a4c93](https://github.com/cedricziel/hermes-app/commit/10a4c93eb4211bd010e1cb383cc51eb725d2a93d))
* **roadmap:** update 24, the evening's merges, the unenforced check, four sessions archived ([#1361](https://github.com/cedricziel/hermes-app/issues/1361)) ([534c879](https://github.com/cedricziel/hermes-app/commit/534c87937d00b2633ae04a246332f37bf67a7f36))
* **roadmap:** update 25, the catalog fix, the last sessions archived and main on Flutter 3.50.1 ([#1363](https://github.com/cedricziel/hermes-app/issues/1363)) ([0dfac3a](https://github.com/cedricziel/hermes-app/commit/0dfac3a11e4626a989a598d4bca53ef7065c0304))
* **roadmap:** update 26, the strings and tooling fixes and the plural guard ([#1366](https://github.com/cedricziel/hermes-app/issues/1366)) ([45dc9c4](https://github.com/cedricziel/hermes-app/commit/45dc9c43fb7bf1bed3e52941c8ad8eaed69ac8ba))
* **roadmap:** update 27, the plural guard, the Kanban strings and the Mac runner wait ([#1370](https://github.com/cedricziel/hermes-app/issues/1370)) ([39b5068](https://github.com/cedricziel/hermes-app/commit/39b5068c00f4f610e547e7b81d502149adf98aa9))
* **roadmap:** update 28, the rest of the Kanban strings and the cancelled run on main ([#1372](https://github.com/cedricziel/hermes-app/issues/1372)) ([7bb33a8](https://github.com/cedricziel/hermes-app/commit/7bb33a898d90d1ed91acef57373cbf9d636919de))
* **roadmap:** update 29, the English fallbacks, the label-helper guard and what holds main's builds ([#1380](https://github.com/cedricziel/hermes-app/issues/1380)) ([9de771e](https://github.com/cedricziel/hermes-app/commit/9de771e468692202410776da5bc74907f1656af3))
* **roadmap:** update 30, the moved pull requests, the archived sessions and the design pass that blocks the settings bar ([#1390](https://github.com/cedricziel/hermes-app/issues/1390)) ([feb63c5](https://github.com/cedricziel/hermes-app/commit/feb63c59f77e3268ebc3d2f2291a117b98f57f25))
* **roadmap:** update 31, the owner's decisions, three merges, the second quit-crash fix and the review gate ([#1392](https://github.com/cedricziel/hermes-app/issues/1392)) ([e8c84b2](https://github.com/cedricziel/hermes-app/commit/e8c84b2bb2b5d77b903d240fef820d682efb6bd0))
* **roadmap:** update 32, the review gate merged and the two Mac pull requests waiting for a runner ([#1393](https://github.com/cedricziel/hermes-app/issues/1393)) ([38c754a](https://github.com/cedricziel/hermes-app/commit/38c754ac3ef9e479146f6144e51be29a82b76698))
* **roadmap:** update 33, the Link WhatsApp screen and two pull requests on rows without an owner ([#1403](https://github.com/cedricziel/hermes-app/issues/1403)) ([a0ee5b2](https://github.com/cedricziel/hermes-app/commit/a0ee5b2985b7810361781ac8a1f2936419a6f6c4))
* **roadmap:** update 34, the wider label guard and the guard for silent catch-alls in chat ([#1408](https://github.com/cedricziel/hermes-app/issues/1408)) ([220d8b5](https://github.com/cedricziel/hermes-app/commit/220d8b5b54cf8fe1c84f5af2c6526397edf3c8f4))
* **verify:** name Node 22, make and g++, and how to run it from a Mac ([#1399](https://github.com/cedricziel/hermes-app/issues/1399)) ([80625f7](https://github.com/cedricziel/hermes-app/commit/80625f7eee87eb0ec99d68edca8ea70aeb033ecf))

## [0.1.84](https://github.com/cedricziel/hermes-app/compare/v0.1.83...v0.1.84) (2026-11-24)


### Features

* **widgetbook:** add Markdown and chat text use cases ([#1329](https://github.com/cedricziel/hermes-app/issues/1329)) ([a0ab091](https://github.com/cedricziel/hermes-app/commit/a0ab0915bbc09d85317a96c578a8252b494b8f1f))


### Bug Fixes

* **bot-screen:** keep the viewer header inside its bar at large text ([#1333](https://github.com/cedricziel/hermes-app/issues/1333)) ([6fc9c12](https://github.com/cedricziel/hermes-app/commit/6fc9c12f10fba65730d814eaccb02a6d31697eae))
* **harness:** warn at session start when the Bash guard is not active ([#1335](https://github.com/cedricziel/hermes-app/issues/1335)) ([c853b4f](https://github.com/cedricziel/hermes-app/commit/c853b4fb357fdff8178902aee9291c9f5b09b383))
* **l10n:** localize the Inspect dialog, install confirmation and toolbar menu strings ([#1331](https://github.com/cedricziel/hermes-app/issues/1331)) ([54052a6](https://github.com/cedricziel/hermes-app/commit/54052a66064f35f3e27dd6db3379634e23b19303))
* **widgets:** share a narrow grouped row between title and value ([#1332](https://github.com/cedricziel/hermes-app/issues/1332)) ([13094a0](https://github.com/cedricziel/hermes-app/commit/13094a0432ef5c99648110aa1e0486fb63447362))
* **widgets:** show the keyboard focus ring on the Mac pop-up of a GroupedMenuRow ([#1336](https://github.com/cedricziel/hermes-app/issues/1336)) ([9d77755](https://github.com/cedricziel/hermes-app/commit/9d777557f0627cd15c07d7bb91b35a15d2ff6117))


### Documentation

* **roadmap:** record pre-release 0.1.83, the missing focus indication and the stale guards ([#1339](https://github.com/cedricziel/hermes-app/issues/1339)) ([962bc1a](https://github.com/cedricziel/hermes-app/commit/962bc1a8e19ce6e40545dc4c178b6d9e6b3f08dd))
* **roadmap:** update 22, six merges, [#1321](https://github.com/cedricziel/hermes-app/issues/1321) closed, shortcut decisions ([#1340](https://github.com/cedricziel/hermes-app/issues/1340)) ([debc76d](https://github.com/cedricziel/hermes-app/commit/debc76dd922fb2678bd90ae43c014027cc03ae95))

## [0.1.83](https://github.com/cedricziel/hermes-app/compare/v0.1.82...v0.1.83) (2026-11-24)


### Features

* **files:** zoom, reset and pan the image viewers from the keyboard ([#1323](https://github.com/cedricziel/hermes-app/issues/1323)) ([163e098](https://github.com/cedricziel/hermes-app/commit/163e098a43a5450a0e6351db56793250a37de9dc))
* **harness:** check that new widgets reach the catalog ([#1310](https://github.com/cedricziel/hermes-app/issues/1310)) ([11341be](https://github.com/cedricziel/hermes-app/commit/11341be765ecc4a6ec45f1f2a1c89bc5358af080))
* **widgetbook:** add use cases for four UI changes ([#1326](https://github.com/cedricziel/hermes-app/issues/1326)) ([c50269c](https://github.com/cedricziel/hermes-app/commit/c50269ceaea2da6fd896525fd318a0b687e1ecc9))
* **widgets:** draw the keyboard focus ring inside sidebar rows ([#1311](https://github.com/cedricziel/hermes-app/issues/1311)) ([e181b67](https://github.com/cedricziel/hermes-app/commit/e181b67230e7eca70c05cc83a9366b9f41f50d12))
* **widgets:** keyboard focus and ring for the iOS popup menu trigger ([#1320](https://github.com/cedricziel/hermes-app/issues/1320)) ([f9d5707](https://github.com/cedricziel/hermes-app/commit/f9d5707e6d0c5ad630e509f41f8a7c2caac4e034))
* **widgets:** make the search clear, section header and thumbnail controls keyboard-focusable ([#1315](https://github.com/cedricziel/hermes-app/issues/1315)) ([dfcdd15](https://github.com/cedricziel/hermes-app/commit/dfcdd15d4a98716675ffd15d920d2fc8e7d3a6e7))


### Bug Fixes

* **chat:** keep the code block header inside its width at large text ([#1302](https://github.com/cedricziel/hermes-app/issues/1302)) ([e8b9019](https://github.com/cedricziel/hermes-app/commit/e8b90194c244a8d1308328142742bf1ae27a8cd6))
* **l10n:** localize the Kanban bulk bar and the Kanban Cancel buttons ([#1312](https://github.com/cedricziel/hermes-app/issues/1312)) ([9a53dfc](https://github.com/cedricziel/hermes-app/commit/9a53dfc6366a8917127d7d0d4dd9a715d36e485f))


### Documentation

* **design:** record eight UI changes after the fact ([#1325](https://github.com/cedricziel/hermes-app/issues/1325)) ([ead0db8](https://github.com/cedricziel/hermes-app/commit/ead0db8218626d803afc6dba86f480698dca4c4e))
* **design:** record the focus ring of the iOS popup trigger ([#1313](https://github.com/cedricziel/hermes-app/issues/1313)) ([0b00777](https://github.com/cedricziel/hermes-app/commit/0b00777f05167be2699e1b8460c95ae27738f4db))
* **release:** merge a clean release PR directly with its head pinned ([#1317](https://github.com/cedricziel/hermes-app/issues/1317)) ([b1124b4](https://github.com/cedricziel/hermes-app/commit/b1124b4d20222f018fd22aa1f88354c94bc59fe3))
* **review:** ask UI PRs for a Design line the reviewer confirms ([#1324](https://github.com/cedricziel/hermes-app/issues/1324)) ([57048cd](https://github.com/cedricziel/hermes-app/commit/57048cd58e0477b89b16f6ca74adae1e43bc0e09))
* **roadmap:** record pre-release 0.1.82, seven merges, the standstill and the new findings ([#1316](https://github.com/cedricziel/hermes-app/issues/1316)) ([a5fb1f0](https://github.com/cedricziel/hermes-app/commit/a5fb1f0ac6480c7bd6d9a96fc7c96480c45eb33f))
* **roadmap:** record seven merges, the grouped row pick and the closed policy-script fix ([#1322](https://github.com/cedricziel/hermes-app/issues/1322)) ([825d6a1](https://github.com/cedricziel/hermes-app/commit/825d6a18fcdc133d51e010880a5f3f06ef6acb81))
* **roadmap:** record the design audit, its remedies and the blocked thread-row design pass ([#1327](https://github.com/cedricziel/hermes-app/issues/1327)) ([4833c20](https://github.com/cedricziel/hermes-app/commit/4833c20c7018d6aec58a2f1513983e4d0a756eef))

## [0.1.82](https://github.com/cedricziel/hermes-app/compare/v0.1.81...v0.1.82) (2026-11-22)


### Features

* **chat:** show tool call inputs and results as coloured text with a tree view ([#1222](https://github.com/cedricziel/hermes-app/issues/1222)) ([e03fe35](https://github.com/cedricziel/hermes-app/commit/e03fe354ee492d4e69a97596bd4ca9f3b001a7fb))
* **kanban:** open the bulk picker as the grouped choice dialog ([#1304](https://github.com/cedricziel/hermes-app/issues/1304)) ([9e6f8f4](https://github.com/cedricziel/hermes-app/commit/9e6f8f44301ae1186003dcb9fb1140d1847edf4d))
* **navigation:** bind the menu commands to Ctrl chords on Windows and Linux ([#1293](https://github.com/cedricziel/hermes-app/issues/1293)) ([e746ee1](https://github.com/cedricziel/hermes-app/commit/e746ee1f140a67b69a69edb06f0fa679fd0ecf58))
* **scripts:** premerge check runs the tests a PR can break, takes --stack, and ties a pass to a base ([#1231](https://github.com/cedricziel/hermes-app/issues/1231)) ([2a69d09](https://github.com/cedricziel/hermes-app/commit/2a69d09e82c51088869b772d7541955944d376fd))
* **skills:** show Hermes' own text in the curator section and match the canvas on Mac and desktop ([#1239](https://github.com/cedricziel/hermes-app/issues/1239)) ([3428e9a](https://github.com/cedricziel/hermes-app/commit/3428e9ab465a6c112af348c5bd25437e688d94e7))
* **telemetry:** diagnose why a reply is lost or fails ([#1202](https://github.com/cedricziel/hermes-app/issues/1202)) ([9d39e20](https://github.com/cedricziel/hermes-app/commit/9d39e206c5fe96bd9fc2d0b5f25020145bdee2e8))
* **voice:** last turn lines, Speak replies switch, tts-lease and a flutter_soloud build guard ([#1223](https://github.com/cedricziel/hermes-app/issues/1223)) ([4241a66](https://github.com/cedricziel/hermes-app/commit/4241a662cdb6bb5dd19dc26f866784fc3a68cf80))
* **widgets:** draw the keyboard focus ring inside rows and cards ([#1300](https://github.com/cedricziel/hermes-app/issues/1300)) ([7eef767](https://github.com/cedricziel/hermes-app/commit/7eef767dd77d1288b6b897d9e2552dce39bf90e1))
* **widgets:** draw the keyboard focus ring outside tap targets ([#1307](https://github.com/cedricziel/hermes-app/issues/1307)) ([39e3c54](https://github.com/cedricziel/hermes-app/commit/39e3c5498b5d8195abcfb813b4c592ab3f864f09))


### Bug Fixes

* **catalog:** build the theme per platform in platform previews ([#1295](https://github.com/cedricziel/hermes-app/issues/1295)) ([644ef8b](https://github.com/cedricziel/hermes-app/commit/644ef8be38e96436c2f98cb0e2d7beddaf092018))
* **chat:** hold Retry and Edit while the server may still run the turn ([#1224](https://github.com/cedricziel/hermes-app/issues/1224)) ([d7fe820](https://github.com/cedricziel/hermes-app/commit/d7fe8205b4293c6ab7c0a562f5d935c933fe5325))
* **chat:** move the Android chat title below the bar at large text ([#1219](https://github.com/cedricziel/hermes-app/issues/1219)) ([4b170ac](https://github.com/cedricziel/hermes-app/commit/4b170ac95f022994828a0dafd317c6eb4d50e4cb))
* **chat:** open chat-row actions as a popover on iPad ([#1221](https://github.com/cedricziel/hermes-app/issues/1221)) ([7637a3e](https://github.com/cedricziel/hermes-app/commit/7637a3e62d6b286f60ecb3266f69516c2e94d00a))
* **chat:** open Memory from a profile-less chat on the launch profile ([#1264](https://github.com/cedricziel/hermes-app/issues/1264)) ([0d5d956](https://github.com/cedricziel/hermes-app/commit/0d5d956544c00285931ff4374f5055ebf8a701a1))
* **chat:** pull to refresh the chat list ([#1220](https://github.com/cedricziel/hermes-app/issues/1220)) ([2a4d570](https://github.com/cedricziel/hermes-app/commit/2a4d570f93d878b2cb2d6f65fda59440ffb2b874))
* **harness:** apply the git bans to find -exec actions ([#1298](https://github.com/cedricziel/hermes-app/issues/1298)) ([af3db9c](https://github.com/cedricziel/hermes-app/commit/af3db9c7f62e24b06feb3c43914b66a8026568f6))
* **harness:** make a capped premerge pass impossible to misread ([#1245](https://github.com/cedricziel/hermes-app/issues/1245)) ([f27592d](https://github.com/cedricziel/hermes-app/commit/f27592d779a61f458eec3b41f55d58c56e7f0867))
* **kanban:** keep each status column's scroll position on a phone ([#1230](https://github.com/cedricziel/hermes-app/issues/1230)) ([6b45071](https://github.com/cedricziel/hermes-app/commit/6b450712e70e6e73e3b3040da328244e689ff807))
* keep Esc working after a click moves focus off a dialog's field ([#1287](https://github.com/cedricziel/hermes-app/issues/1287)) ([323fbea](https://github.com/cedricziel/hermes-app/commit/323fbea4b56c7171adeb3757f84884a2ab44a2bf))
* **l10n:** localize the Kanban dialogs and the chat thread menu ([#1303](https://github.com/cedricziel/hermes-app/issues/1303)) ([d8e4022](https://github.com/cedricziel/hermes-app/commit/d8e4022f0a280a14e1b85ca2ead64bfa2f762f3c))
* **linux:** give the window a minimum size and a default that fits the screen ([#1206](https://github.com/cedricziel/hermes-app/issues/1206)) ([bb7e255](https://github.com/cedricziel/hermes-app/commit/bb7e2551d951cebce7c69f263ea990ba0fbcb040))
* **linux:** keep the install prefix inside the build tree ([#1258](https://github.com/cedricziel/hermes-app/issues/1258)) ([1f6afad](https://github.com/cedricziel/hermes-app/commit/1f6afadfd7d83e5b92db9438db18cec2e0be679d))
* **linux:** make the app single instance and register hermes:// links ([#1249](https://github.com/cedricziel/hermes-app/issues/1249)) ([fadf0b1](https://github.com/cedricziel/hermes-app/commit/fadf0b1427325b3579629cb798d7ee95edccc95b))
* **macos:** enable the Edit menu items only when they apply ([#1266](https://github.com/cedricziel/hermes-app/issues/1266)) ([16bc9f5](https://github.com/cedricziel/hermes-app/commit/16bc9f51d66d2a07faad754b04b49fe20eb5ee25))
* **macos:** give the main window a minimum and a wide default size ([#1132](https://github.com/cedricziel/hermes-app/issues/1132)) ([2247bd2](https://github.com/cedricziel/hermes-app/commit/2247bd2c8039c08cc2bc05ce8e11405e0e535759))
* **network:** stop the Linux app touching NetworkManager when there is no system bus ([#1211](https://github.com/cedricziel/hermes-app/issues/1211)) ([4f204f9](https://github.com/cedricziel/hermes-app/commit/4f204f913a1919ac712c13b1b99c92632d5941b9))
* **notifications:** skip notifications on Linux when there is no session bus ([#1212](https://github.com/cedricziel/hermes-app/issues/1212)) ([c899b74](https://github.com/cedricziel/hermes-app/commit/c899b747e14c7312d720591648067130e8a427b2))
* **scripts:** scan only tracked files in the HERMES_HOME guard ([#1269](https://github.com/cedricziel/hermes-app/issues/1269)) ([0126342](https://github.com/cedricziel/hermes-app/commit/01263425e450589f412d4e02cf996f2b023d5128))
* **theme:** make Mac push buttons 28 pt tall ([#1240](https://github.com/cedricziel/hermes-app/issues/1240)) ([8f0e873](https://github.com/cedricziel/hermes-app/commit/8f0e8733c3803d0c73ebc758a091f3bcba169f09))
* **theme:** make the Android switch visible when off ([#1254](https://github.com/cedricziel/hermes-app/issues/1254)) ([c7fcd18](https://github.com/cedricziel/hermes-app/commit/c7fcd18600007cb0c680b754e42752b70863be57))
* **tool:** judge tap targets by the theme platform ([#1259](https://github.com/cedricziel/hermes-app/issues/1259)) ([164bc31](https://github.com/cedricziel/hermes-app/commit/164bc312a562a395584f69163e5a3b7d3da0f605))
* **ui:** keep the update and set-up buttons on screen at large text ([#1278](https://github.com/cedricziel/hermes-app/issues/1278)) ([d9f7772](https://github.com/cedricziel/hermes-app/commit/d9f7772975516fc54db694bac6589c261b0f0ca5))
* **ui:** show a keyboard focus ring on interactive controls ([#1268](https://github.com/cedricziel/hermes-app/issues/1268)) ([c04b9fc](https://github.com/cedricziel/hermes-app/commit/c04b9fce8c03a9fbbf24341d266c04138a79014e))
* **ui:** show the keyboard focus ring on checked menu items, list tiles and chips ([#1281](https://github.com/cedricziel/hermes-app/issues/1281)) ([b68d716](https://github.com/cedricziel/hermes-app/commit/b68d716b25f0be6844aefaf93d30679e28be948c))
* **ui:** show the keyboard focus ring on segmented controls, tap targets, floating buttons, disclosure tiles and Mac menus ([#1284](https://github.com/cedricziel/hermes-app/issues/1284)) ([1df30f1](https://github.com/cedricziel/hermes-app/commit/1df30f1bf55c825de2e7138437b548f69eae8640))
* **watch:** reuse one gateway connection for watch list refreshes ([#1217](https://github.com/cedricziel/hermes-app/issues/1217)) ([4aa59ba](https://github.com/cedricziel/hermes-app/commit/4aa59babe11b66dc229d88890ef5f161a152d3ef))
* **widgets:** let search fields grow with large text ([#1250](https://github.com/cedricziel/hermes-app/issues/1250)) ([50317d9](https://github.com/cedricziel/hermes-app/commit/50317d98980d728c53695f8a0afb4fba4b77eaaa))


### Performance

* **chat:** stop rebuilding unchanged tool-call groups while a reply streams ([#1274](https://github.com/cedricziel/hermes-app/issues/1274)) ([8a9236b](https://github.com/cedricziel/hermes-app/commit/8a9236bec8897d3491603eef0f4ee5c404486650))


### Documentation

* **design:** record the focus ring decisions for rows and tap targets (F.427) ([#1296](https://github.com/cedricziel/hermes-app/issues/1296)) ([9d85ecd](https://github.com/cedricziel/hermes-app/commit/9d85ecd7cc45a70d0df647a997c6ec032e3e836e))
* let the orchestrator cut pre-releases at its discretion ([#1309](https://github.com/cedricziel/hermes-app/issues/1309)) ([c517a28](https://github.com/cedricziel/hermes-app/commit/c517a282439e6b150512b69d6110172c6d19a2d4))
* **openspec:** note how to validate an OpenSpec change ([#1297](https://github.com/cedricziel/hermes-app/issues/1297)) ([751260d](https://github.com/cedricziel/hermes-app/commit/751260d77af4373a044c69d585fad252d9c2b7fc))
* **openspec:** propose a Mac Settings window, a Mac toast and sub-pages that keep the sidebar ([#1291](https://github.com/cedricziel/hermes-app/issues/1291)) ([d1c4fb0](https://github.com/cedricziel/hermes-app/commit/d1c4fb01561565f343542ac54265eab16e06e776))
* **openspec:** propose phone and tablet navigation, iOS large titles and detent sheets ([#1294](https://github.com/cedricziel/hermes-app/issues/1294)) ([aa43373](https://github.com/cedricziel/hermes-app/commit/aa433738c988c0dafc3e231229ea1fb250220fb6))
* **openspec:** propose splitting the Android notification channels ([#1290](https://github.com/cedricziel/hermes-app/issues/1290)) ([828d580](https://github.com/cedricziel/hermes-app/commit/828d5807ba5371c77a36556de9a2ad2874567d5b))
* record the closed macOS quit-crash fix as blocked and the Flutter 3.50 options ([#1262](https://github.com/cedricziel/hermes-app/issues/1262)) ([6ee2461](https://github.com/cedricziel/hermes-app/commit/6ee2461ca2d298373c5072f6e041cf78f79ed9d1))
* roadmap update after the standstill, with the day's merges and findings ([#1243](https://github.com/cedricziel/hermes-app/issues/1243)) ([e4bc089](https://github.com/cedricziel/hermes-app/commit/e4bc08983200a954a968da9e6f46fc7bb8f36e1f))
* roadmap update with the afternoon's merges, the three new gates and new findings ([#1251](https://github.com/cedricziel/hermes-app/issues/1251)) ([18fb61f](https://github.com/cedricziel/hermes-app/commit/18fb61f7086a51e5ff0be335102ee9e21d52c213))
* roadmap update with the evening's merges, the macOS quit crash and the tool-card mechanism ([#1261](https://github.com/cedricziel/hermes-app/issues/1261)) ([a89e60c](https://github.com/cedricziel/hermes-app/commit/a89e60c020f0d52fc5afe890d1db507b14331f07))
* **roadmap:** close the flaky scripts test row and record the style-score gap ([#1271](https://github.com/cedricziel/hermes-app/issues/1271)) ([21a8a1d](https://github.com/cedricziel/hermes-app/commit/21a8a1d8b628dec5dd289afb683ee961270d4875))
* **roadmap:** record four merges, the analyzer finding and the decisions [#1294](https://github.com/cedricziel/hermes-app/issues/1294) leaves open ([#1305](https://github.com/cedricziel/hermes-app/issues/1305)) ([89751e2](https://github.com/cedricziel/hermes-app/commit/89751e298a7279c1d89d375a8718aedc603d1d3e))
* **roadmap:** record four merges, the owner's release decision and the under-colouring defect ([#1308](https://github.com/cedricziel/hermes-app/issues/1308)) ([99c9d66](https://github.com/cedricziel/hermes-app/commit/99c9d669e2d11de268c26b877634ba1003087d9a))
* **roadmap:** record the evening merges and the open owner decisions ([#1267](https://github.com/cedricziel/hermes-app/issues/1267)) ([167a840](https://github.com/cedricziel/hermes-app/commit/167a840425681a77a116207f9c7fb7a92e6ca717))
* **roadmap:** record the merges around midnight and close the render-cost question ([#1282](https://github.com/cedricziel/hermes-app/issues/1282)) ([106c21b](https://github.com/cedricziel/hermes-app/commit/106c21bbc5225326c850c1b7389f2b6c54b6fae9))
* **roadmap:** record the midnight merges, the benchmark baseline and the new findings ([#1280](https://github.com/cedricziel/hermes-app/issues/1280)) ([4028a61](https://github.com/cedricziel/hermes-app/commit/4028a611bbf18cd0f3d6c43d9598af672253f6aa))
* **roadmap:** record the morning merges, the Esc defect and the pre-release recommendation ([#1289](https://github.com/cedricziel/hermes-app/issues/1289)) ([393637b](https://github.com/cedricziel/hermes-app/commit/393637bcc02291a8eff985f67600648ee9b3aec8))
* **roadmap:** record the morning's seven merges and the decisions the proposals leave open ([#1299](https://github.com/cedricziel/hermes-app/issues/1299)) ([3e17f4a](https://github.com/cedricziel/hermes-app/commit/3e17f4ae2db001b4c4e61db7df305a4cb2d59615))
* **roadmap:** record the night merges and list the held pull requests as blocked ([#1286](https://github.com/cedricziel/hermes-app/issues/1286)) ([4da49b7](https://github.com/cedricziel/hermes-app/commit/4da49b736d7542aa276f6dbd5ee3651db6b507b2))
* **roadmap:** record the night merges and list the owner-held checks as blocked ([#1275](https://github.com/cedricziel/hermes-app/issues/1275)) ([54fabfe](https://github.com/cedricziel/hermes-app/commit/54fabfe68eea047c35bfa37f0d4a7cb373213a4d))
* **skills:** build the theme per platform in tests that depend on tap-target size ([#1288](https://github.com/cedricziel/hermes-app/issues/1288)) ([85e7f67](https://github.com/cedricziel/hermes-app/commit/85e7f673ccb7fe74a59a774ad6eb2f856e18abe1))
* the trial check is premerge_check.sh, tied to the base and heads it checked ([#1238](https://github.com/cedricziel/hermes-app/issues/1238)) ([294e5dc](https://github.com/cedricziel/hermes-app/commit/294e5dc6c1f1a49a557ac72deb86b97fdfbdc830))

## [0.1.81](https://github.com/cedricziel/hermes-app/compare/v0.1.80...v0.1.81) (2026-11-15)


### Features

* **chat:** add the tool value view with its label row and catalog use cases ([#1207](https://github.com/cedricziel/hermes-app/issues/1207)) ([f241765](https://github.com/cedricziel/hermes-app/commit/f241765b7d4d73e8b314372f7078fa2a4962cf74))
* **scripts:** add premerge_check.sh, a trial merge with current main before arming ([#1209](https://github.com/cedricziel/hermes-app/issues/1209)) ([3d67900](https://github.com/cedricziel/hermes-app/commit/3d679008f1dd9fb799a3e4a798b375bd9bbce861))
* **skills:** see, pause and run the skill curator on the Skills screen ([#1225](https://github.com/cedricziel/hermes-app/issues/1225)) ([4ddc651](https://github.com/cedricziel/hermes-app/commit/4ddc6510dbc596b9e7fd158dffcde92f115aadf2))
* **voice:** voice calls on Android and desktop ([#1111](https://github.com/cedricziel/hermes-app/issues/1111)) ([2a56be1](https://github.com/cedricziel/hermes-app/commit/2a56be123fe56f36df02a6c0765ff5068d5f81f9))


### Bug Fixes

* **chat:** settle a reply the server no longer has, with a notice that says why ([#1187](https://github.com/cedricziel/hermes-app/issues/1187)) ([b8fb191](https://github.com/cedricziel/hermes-app/commit/b8fb1912f6516be795082bb69fc9396d5980e63b))
* **kanban:** keep the last cards clear of the New task button ([#1213](https://github.com/cedricziel/hermes-app/issues/1213)) ([fb9dc4c](https://github.com/cedricziel/hermes-app/commit/fb9dc4cd0950d06809f24aa376290ae0a9e04f0c))
* **linux:** show the Hermes icon in the window title bar ([#1205](https://github.com/cedricziel/hermes-app/issues/1205)) ([2432175](https://github.com/cedricziel/hermes-app/commit/24321758735937c376e1ca1a92a6a79d06833947))
* **macos:** translate the menu bar ([#1208](https://github.com/cedricziel/hermes-app/issues/1208)) ([4e4363a](https://github.com/cedricziel/hermes-app/commit/4e4363aaa110433a419b39b698f2952cd10413e5))
* **notifications:** offer to open settings after notifications were denied ([#1155](https://github.com/cedricziel/hermes-app/issues/1155)) ([fbda629](https://github.com/cedricziel/hermes-app/commit/fbda629c94c915e13e27a9f8ad5bffc63fd7f971))


### Documentation

* **openspec:** match the android-home-widgets tasks 1.3 and 1.7 to the code ([#1204](https://github.com/cedricziel/hermes-app/issues/1204)) ([6933dfd](https://github.com/cedricziel/hermes-app/commit/6933dfdfab4d3cc73e4c80d4993826ff71b1c1d6))
* roadmap update for 0.1.80, the second main break and new findings ([#1229](https://github.com/cedricziel/hermes-app/issues/1229)) ([abd47aa](https://github.com/cedricziel/hermes-app/commit/abd47aad1c6253b00bf1326d14a7600608ef79ec))
* **roadmap:** record the main break, the day's merges and new findings ([#1210](https://github.com/cedricziel/hermes-app/issues/1210)) ([123d4bb](https://github.com/cedricziel/hermes-app/commit/123d4bb2846bbba0b2172681acdd07436bbd37a6))

## [0.1.80](https://github.com/cedricziel/hermes-app/compare/v0.1.79...v0.1.80) (2026-11-15)


### Features

* **chat:** Export chat as JSON ([#1112](https://github.com/cedricziel/hermes-app/issues/1112)) ([254a05e](https://github.com/cedricziel/hermes-app/commit/254a05e8fd5ff473ef7252d79f087af2685f0d1a))
* **chat:** offer Retry for earlier messages that failed to load ([#1160](https://github.com/cedricziel/hermes-app/issues/1160)) ([7879c72](https://github.com/cedricziel/hermes-app/commit/7879c7257951a9436105483d26714ddff1989c69))
* **chat:** show a loading state while a chat's messages load ([#1122](https://github.com/cedricziel/hermes-app/issues/1122)) ([5e22534](https://github.com/cedricziel/hermes-app/commit/5e22534cb42487167b5b9d457ae5a73e8819869a))
* **macos:** show reload, enclosing folder and change navigation in the menu ([#1139](https://github.com/cedricziel/hermes-app/issues/1139)) ([ce26b62](https://github.com/cedricziel/hermes-app/commit/ce26b6258ac722ef1bd8b3cbc246aab5ef864c60))
* **messaging:** talk to the WhatsApp pairing routes ([#1159](https://github.com/cedricziel/hermes-app/issues/1159)) ([79687ba](https://github.com/cedricziel/hermes-app/commit/79687ba20614c1b9a41390d8bdda41572382f20b))
* **skills:** curator run confirmation sheet body for the catalog ([#1201](https://github.com/cedricziel/hermes-app/issues/1201)) ([c03d431](https://github.com/cedricziel/hermes-app/commit/c03d431d0c2b79a9e29c2942051c8c59117096f1))
* **skills:** follow and control the skill curator ([#1177](https://github.com/cedricziel/hermes-app/issues/1177)) ([c144ee1](https://github.com/cedricziel/hermes-app/commit/c144ee1c52a0a1dfc5a465d0adb10c9463ff39fc))
* **skills:** read and drive the skill curator routes ([#1158](https://github.com/cedricziel/hermes-app/issues/1158)) ([ca8b283](https://github.com/cedricziel/hermes-app/commit/ca8b283bc4b87ba28017449dbd34a0fb129469ff))
* **skills:** Skill curator section catalog widget ([#1190](https://github.com/cedricziel/hermes-app/issues/1190)) ([516a239](https://github.com/cedricziel/hermes-app/commit/516a2397a3505e01befdfc68401a595c5e9eaa3e))
* **theme:** move the code palette to the canvas colours ([#1192](https://github.com/cedricziel/hermes-app/issues/1192)) ([947db7a](https://github.com/cedricziel/hermes-app/commit/947db7a43afe13520b625884440dfd196f1b068c))
* **widgets:** touch-target action row and capped output tile for the skill curator ([#1186](https://github.com/cedricziel/hermes-app/issues/1186)) ([ee0ef59](https://github.com/cedricziel/hermes-app/commit/ee0ef59f40c64309d3b63a8d9bf7782694513aac))


### Bug Fixes

* **android:** add a monochrome layer for themed icons ([#1134](https://github.com/cedricziel/hermes-app/issues/1134)) ([567232c](https://github.com/cedricziel/hermes-app/commit/567232c5813d3a932eb3bc6a05ae604ad5cbae97))
* **android:** opt in to predictive back ([#1130](https://github.com/cedricziel/hermes-app/issues/1130)) ([76f78c7](https://github.com/cedricziel/hermes-app/commit/76f78c79da39022a8489b33a47cd7a7f47de0ab6))
* **chat:** a reply that lost its connection is not failed while the server may still run it ([#1123](https://github.com/cedricziel/hermes-app/issues/1123)) ([d1aa36b](https://github.com/cedricziel/hermes-app/commit/d1aa36ba8dbc338e67ee9c9d4850e17f8748f97d))
* **chat:** gateway reconnect waits for the network and stops on a gone session ([#1116](https://github.com/cedricziel/hermes-app/issues/1116)) ([8867cc0](https://github.com/cedricziel/hermes-app/commit/8867cc05d52fa5da00dcda1edd87a1b445c39fb1))
* **chat:** give Android touch-sized rows and message actions ([#1163](https://github.com/cedricziel/hermes-app/issues/1163)) ([df59da3](https://github.com/cedricziel/hermes-app/commit/df59da3d5d89dac12abbe18c87e94dedec85faaf))
* **chat:** keep a stop command's words reliably and say it was another chat ([#1115](https://github.com/cedricziel/hermes-app/issues/1115)) ([1b2b876](https://github.com/cedricziel/hermes-app/commit/1b2b876c315cc5ed8175bd8b99029121f08127a7))
* **chat:** keep opened tool calls open across list remounts and scrolling ([#1135](https://github.com/cedricziel/hermes-app/issues/1135)) ([be92826](https://github.com/cedricziel/hermes-app/commit/be928262d26256ead2de1eddfa2b1ceb0c8becc3))
* **chat:** name the default model in the model picker ([#1129](https://github.com/cedricziel/hermes-app/issues/1129)) ([e032951](https://github.com/cedricziel/hermes-app/commit/e03295156ed100c9fcd5c1174f53451e29b76476))
* **chat:** show the attach menu and skill status adaptively on wide screens ([#1137](https://github.com/cedricziel/hermes-app/issues/1137)) ([4396f8c](https://github.com/cedricziel/hermes-app/commit/4396f8c84630eb4be53236e4808f09df883b8166))
* **chat:** show the server's current default model in a new chat ([#1118](https://github.com/cedricziel/hermes-app/issues/1118)) ([c96cc03](https://github.com/cedricziel/hermes-app/commit/c96cc0305ae3fcab253ffa9077db0fb5f2b9ecfc))
* **chat:** use the app link colour for links in chat messages ([#1198](https://github.com/cedricziel/hermes-app/issues/1198)) ([8cd2209](https://github.com/cedricziel/hermes-app/commit/8cd2209791d0d8bd80dbc93dad4a7f95d925d139))
* **files:** render Markdown task lists in the preview ([#1121](https://github.com/cedricziel/hermes-app/issues/1121)) ([5d1af7b](https://github.com/cedricziel/hermes-app/commit/5d1af7bec71cc9676ea3c9249524287a44fc8279))
* **files:** replace lone surrogates before painting file and tool text ([#1191](https://github.com/cedricziel/hermes-app/issues/1191)) ([17ff5df](https://github.com/cedricziel/hermes-app/commit/17ff5dfff4f9d17bba252ad7e5f22e99ca932f64))
* **kanban:** make the hovered drop strip label readable ([#1175](https://github.com/cedricziel/hermes-app/issues/1175)) ([3e69e7c](https://github.com/cedricziel/hermes-app/commit/3e69e7c78c93d0adc8a6a5e2a88daf888e5d3679))
* **macos:** drop pull to refresh and the phone task sheet on the Mac ([#1131](https://github.com/cedricziel/hermes-app/issues/1131)) ([5c046a4](https://github.com/cedricziel/hermes-app/commit/5c046a479c706943b8198c6cebac6a56697f5f70))
* **macos:** match the model popover to its design (surface, focus, gutter, search) ([#1194](https://github.com/cedricziel/hermes-app/issues/1194)) ([eace3db](https://github.com/cedricziel/hermes-app/commit/eace3db956496a02ea3ca2192020ba1dafef6718))
* **macos:** mount the app's theme scopes in every engine and in pumpScreen ([#1183](https://github.com/cedricziel/hermes-app/issues/1183)) ([b7c1b44](https://github.com/cedricziel/hermes-app/commit/b7c1b448b38dba1f6b0fa4ddef618a9ddb70bc3e))
* **macos:** open the model picker as a popover on desktop at any width ([#1162](https://github.com/cedricziel/hermes-app/issues/1162)) ([73b618b](https://github.com/cedricziel/hermes-app/commit/73b618be2c20195b7e0dcb09b91c9bcc0439014f))
* **memory:** translate the leave and delete confirmations ([#1136](https://github.com/cedricziel/hermes-app/issues/1136)) ([e1a7cc3](https://github.com/cedricziel/hermes-app/commit/e1a7cc3234afdf867f88453a9a9f7d258e61ac82))
* **models:** cap the model setup dialog width on wide screens ([#1138](https://github.com/cedricziel/hermes-app/issues/1138)) ([90e1dce](https://github.com/cedricziel/hermes-app/commit/90e1dce907ca535deb6c74242867d47e698328e2))
* **notifications:** use a monochrome status bar icon on Android ([#1133](https://github.com/cedricziel/hermes-app/issues/1133)) ([3f5bfd8](https://github.com/cedricziel/hermes-app/commit/3f5bfd8c8b30b52bb87bc577cbeab6599c57272a))
* **settings:** keep the dialog title clear of Done at large text ([#1165](https://github.com/cedricziel/hermes-app/issues/1165)) ([6392f53](https://github.com/cedricziel/hermes-app/commit/6392f532b3bb03e930794e066ffab289133e90d9))
* **skills:** make the trust badges readable ([#1151](https://github.com/cedricziel/hermes-app/issues/1151)) ([c8683c9](https://github.com/cedricziel/hermes-app/commit/c8683c95b9e3286b2e27cca8717521ea56db032f))
* **skills:** use the app's link colour in markdown previews ([#1176](https://github.com/cedricziel/hermes-app/issues/1176)) ([bf126a6](https://github.com/cedricziel/hermes-app/commit/bf126a6863de7a4aa921408b129886eee544f4c8))
* stop four screens overflowing at large text ([#1156](https://github.com/cedricziel/hermes-app/issues/1156)) ([1eef1ca](https://github.com/cedricziel/hermes-app/commit/1eef1ca006c666a2e48549920462778036096641))
* **theme:** remove the duplicate wifiOff icon that broke the build on main ([#1197](https://github.com/cedricziel/hermes-app/issues/1197)) ([f481fee](https://github.com/cedricziel/hermes-app/commit/f481feeb04e0708d1ddc1e5fb4dd7086386cacbc))
* **voice:** stop taking over other apps' audio at launch and after a recording ([#1125](https://github.com/cedricziel/hermes-app/issues/1125)) ([2bc3c00](https://github.com/cedricziel/hermes-app/commit/2bc3c004257a4f8f0bac503fca18858f101dfe43))
* **watch:** drop stale complication keys from the application context ([#1128](https://github.com/cedricziel/hermes-app/issues/1128)) ([ee5f3d9](https://github.com/cedricziel/hermes-app/commit/ee5f3d9231dd91510c555a4c56139ffa3e22e4cf))
* **watch:** stop gating the watch on the phone's App Lock ([#1148](https://github.com/cedricziel/hermes-app/issues/1148)) ([5ce96ee](https://github.com/cedricziel/hermes-app/commit/5ce96eeb0ff3fe7803383697e61089e363d5b492))
* **widgets:** centre alert message text on Apple platforms ([#1173](https://github.com/cedricziel/hermes-app/issues/1173)) ([1939d2c](https://github.com/cedricziel/hermes-app/commit/1939d2c94c898f8345de6696c8e03eeefbf7b690))


### Documentation

* check in the fleet rules, reviewer and status-reader agents ([#1142](https://github.com/cedricziel/hermes-app/issues/1142)) ([6b23cb0](https://github.com/cedricziel/hermes-app/commit/6b23cb0997836673afcb86894ebfbc73283dfc6c))
* **design:** record the Android platform fix pass ([#1149](https://github.com/cedricziel/hermes-app/issues/1149)) ([3e4b775](https://github.com/cedricziel/hermes-app/commit/3e4b77501afcea1fab41b014165fc4c5c1e7af6e))
* **design:** record the iPhone and iPad platform fix pass ([#1153](https://github.com/cedricziel/hermes-app/issues/1153)) ([863a2e0](https://github.com/cedricziel/hermes-app/commit/863a2e0c2dfc1cd46a6f96d75d33d91e77dd418e))
* **design:** record the macOS menu and window pass ([#1146](https://github.com/cedricziel/hermes-app/issues/1146)) ([a853e7f](https://github.com/cedricziel/hermes-app/commit/a853e7f1ddeea4c864c3af71e7e203e6a0d44900))
* **design:** record the trust badge and Windows/Linux passes ([#1141](https://github.com/cedricziel/hermes-app/issues/1141)) ([3bb10e4](https://github.com/cedricziel/hermes-app/commit/3bb10e4781571fd4b22c19d5f21731f0c9108c86))
* **roadmap:** record the 0.1.79 cut, merges, baselines and new findings ([#1181](https://github.com/cedricziel/hermes-app/issues/1181)) ([d58c90f](https://github.com/cedricziel/hermes-app/commit/d58c90f53715429e5e80f5ec4bfe4fac276320f2))
* **roadmap:** record the iPhone, style, harness and test findings and fix the delivery rules ([#1154](https://github.com/cedricziel/hermes-app/issues/1154)) ([03b14bc](https://github.com/cedricziel/hermes-app/commit/03b14bc4e41bbf5e8d2af85061a2e8b325616fba))
* **roadmap:** record the morning's merges, new findings and rule changes ([#1193](https://github.com/cedricziel/hermes-app/issues/1193)) ([d8d5954](https://github.com/cedricziel/hermes-app/commit/d8d5954556b509698134b2d22554c043c145e263))
* tighten reviewer, status-reader and stacked-PR wording ([#1199](https://github.com/cedricziel/hermes-app/issues/1199)) ([c81c8a2](https://github.com/cedricziel/hermes-app/commit/c81c8a261d1fa8df1586f1c436205e0da86f9ffe))

## [0.1.79](https://github.com/cedricziel/hermes-app/compare/v0.1.78...v0.1.79) (2026-11-15)


### Features

* **chat:** fetch a session export ([#1106](https://github.com/cedricziel/hermes-app/issues/1106)) ([d597bed](https://github.com/cedricziel/hermes-app/commit/d597bed80ab9b6239bdb2aa1e902d8c1532fbe02))
* **chat:** session export controller ([#1109](https://github.com/cedricziel/hermes-app/issues/1109)) ([70797c4](https://github.com/cedricziel/hermes-app/commit/70797c477794a9a5807cb4ebd7335e82af1fc3b6))
* **chat:** session export dialog in the catalog ([#1104](https://github.com/cedricziel/hermes-app/issues/1104)) ([28f7c3e](https://github.com/cedricziel/hermes-app/commit/28f7c3e9f06fbf2a35f3af5be6b9cd0cfcf1c411))
* **chat:** voice turn flags and outcomes ([#1101](https://github.com/cedricziel/hermes-app/issues/1101)) ([af9cb18](https://github.com/cedricziel/hermes-app/commit/af9cb184bdea8c78137dafc836d1894b00ef5efd))
* **files:** code colours and Markdown polish ([#1089](https://github.com/cedricziel/hermes-app/issues/1089)) ([de7ac3b](https://github.com/cedricziel/hermes-app/commit/de7ac3b35b9f3be9eea074af53cbb2778acf530c))
* **notifications:** reply to a finished reply from the notification ([#1079](https://github.com/cedricziel/hermes-app/issues/1079)) ([97bce9a](https://github.com/cedricziel/hermes-app/commit/97bce9a273859bbdb7a5eab59e63c5ad3d48a861))
* **profile-soul:** a controller for editing a profile's personality ([#1103](https://github.com/cedricziel/hermes-app/issues/1103)) ([8c86616](https://github.com/cedricziel/hermes-app/commit/8c866164981f47c86c5f4c827f8435aff73e7e78))
* **profile-soul:** Personality widgets in the catalog ([#1110](https://github.com/cedricziel/hermes-app/issues/1110)) ([6c05887](https://github.com/cedricziel/hermes-app/commit/6c05887f5def82ddccf3deec8c1aa667a357bb46))
* **profile-soul:** read and write a profile's SOUL.md through a repository ([#1102](https://github.com/cedricziel/hermes-app/issues/1102)) ([55a6074](https://github.com/cedricziel/hermes-app/commit/55a60742da98a0554e105c3c5b2293243cfecb50))
* **profile-soul:** stack the banner action at large text ([#1107](https://github.com/cedricziel/hermes-app/issues/1107)) ([9067faf](https://github.com/cedricziel/hermes-app/commit/9067faf39a839e28f41b161f7876526c3a8176c9))
* **server-care:** attention on the status span, polls wake on resume ([#1086](https://github.com/cedricziel/hermes-app/issues/1086)) ([5396b0e](https://github.com/cedricziel/hermes-app/commit/5396b0ea4033281518ea625f90488621bb35c80c))
* **voice:** call widgets in the catalog ([#1078](https://github.com/cedricziel/hermes-app/issues/1078)) ([eb028c6](https://github.com/cedricziel/hermes-app/commit/eb028c6f0386e093efb11fee83f194afef8dd390))
* **voice:** consent, safe stopping and teardown for the iOS call ([#1087](https://github.com/cedricziel/hermes-app/issues/1087)) ([0c88c52](https://github.com/cedricziel/hermes-app/commit/0c88c52004cae28f633574d953ae7dfba4a4fd8c))


### Bug Fixes

* **chat:** bound the render cost of code blocks ([#1105](https://github.com/cedricziel/hermes-app/issues/1105)) ([d04c5a9](https://github.com/cedricziel/hermes-app/commit/d04c5a9f6ef436115703ed424c8d281f192d64d0))
* **chat:** copy picked files out of the plugin directory ([#1113](https://github.com/cedricziel/hermes-app/issues/1113)) ([a41f3a2](https://github.com/cedricziel/hermes-app/commit/a41f3a21755bd90543244f21242b637691913cf8))
* **chat:** drop a chat's agent roster when its session is retired ([#1085](https://github.com/cedricziel/hermes-app/issues/1085)) ([ad538e9](https://github.com/cedricziel/hermes-app/commit/ad538e94c6b1a0e84a7263658b9cecf8c72b3ee0))
* **chat:** hide the recipient chip once a chat has messages ([#1114](https://github.com/cedricziel/hermes-app/issues/1114)) ([3e0348f](https://github.com/cedricziel/hermes-app/commit/3e0348ff892f52e5d9006d4b5db9c173893f1b2c))
* **chat:** keep an opened tool call open when the next tool starts ([#1117](https://github.com/cedricziel/hermes-app/issues/1117)) ([a0c63ee](https://github.com/cedricziel/hermes-app/commit/a0c63ee1ea83277942c45f610d5555fa0f6087ca))
* **chat:** say so when Hermes takes a typed message as a stop command, and tidy a withdrawn voice turn ([#1108](https://github.com/cedricziel/hermes-app/issues/1108)) ([2fc5d8c](https://github.com/cedricziel/hermes-app/commit/2fc5d8c5aa9c44031419bfe96fb1b8fcbef75046))
* **files:** start a new chat's Files at the profile's folder; a refusal inside a listed folder is "not allowed" ([#1080](https://github.com/cedricziel/hermes-app/issues/1080)) ([92c5a78](https://github.com/cedricziel/hermes-app/commit/92c5a78d51bcabf421910978bd7f4c9b4e71ad03))
* **voice:** retry a failed speech connection once and log per-turn timings ([#1095](https://github.com/cedricziel/hermes-app/issues/1095)) ([114558e](https://github.com/cedricziel/hermes-app/commit/114558e6d7e8a1f8e567b17d19e1762ebaafd7a1)), closes [#882](https://github.com/cedricziel/hermes-app/issues/882)


### Documentation

* **design:** record the personality canvas ([#1097](https://github.com/cedricziel/hermes-app/issues/1097)) ([33aad36](https://github.com/cedricziel/hermes-app/commit/33aad366373c6e73c99c6f424cc48ad9ab2eb28f))
* **design:** record the session export canvas ([#1099](https://github.com/cedricziel/hermes-app/issues/1099)) ([2449b30](https://github.com/cedricziel/hermes-app/commit/2449b30121af556a77c255197006bd495d8ca1fb))
* **design:** record the skills curator canvas ([#1098](https://github.com/cedricziel/hermes-app/issues/1098)) ([9831ccd](https://github.com/cedricziel/hermes-app/commit/9831ccd2c2c57d08a87976ef2b53eb82d57a3cd1))
* **design:** record the WhatsApp onboarding canvas ([#1100](https://github.com/cedricziel/hermes-app/issues/1100)) ([703f19d](https://github.com/cedricziel/hermes-app/commit/703f19da2271399e0a5a29d8c9fb2d67a780c134))
* **providers:** catalog screenshots of the provider screens (task 4.4) ([#1090](https://github.com/cedricziel/hermes-app/issues/1090)) ([f0cfc1e](https://github.com/cedricziel/hermes-app/commit/f0cfc1e55b9ef9040d3d63fe4ed5845566bf2863))
* **roadmap:** record merges since [#1084](https://github.com/cedricziel/hermes-app/issues/1084), owner-reported bugs and the platform audits ([#1126](https://github.com/cedricziel/hermes-app/issues/1126)) ([7ce045a](https://github.com/cedricziel/hermes-app/commit/7ce045a6c99e22f3158f81428a5c332e7fa8cd4f))
* **roadmap:** record merges through [#1081](https://github.com/cedricziel/hermes-app/issues/1081), the 0.1.78 cut and the real-backend findings ([#1084](https://github.com/cedricziel/hermes-app/issues/1084)) ([401d215](https://github.com/cedricziel/hermes-app/commit/401d215dc0abb92395368cfefdb520a55cbcba44))
* **toolsets:** close 4.0a, BotChatBanner stays separate from AppBanner ([#1091](https://github.com/cedricziel/hermes-app/issues/1091)) ([47d9f09](https://github.com/cedricziel/hermes-app/commit/47d9f095ba8b99931943df59962b5db7e1c8cefd))
* **watch:** match the spec and change records to what ships ([#1127](https://github.com/cedricziel/hermes-app/issues/1127)) ([1a4b330](https://github.com/cedricziel/hermes-app/commit/1a4b33026a5a3aaaa5166860ff019a54a6f15c57))

## [0.1.78](https://github.com/cedricziel/hermes-app/compare/v0.1.77...v0.1.78) (2026-11-14)


### Features

* **chat:** add Needs-you dock widgets to the catalog ([#1000](https://github.com/cedricziel/hermes-app/issues/1000)) ([c3d09ff](https://github.com/cedricziel/hermes-app/commit/c3d09ffecabcfc0099a1ebd384d843e9a5f8e8e9))
* **chat:** agent rows, detail and program cards in the catalog ([#1017](https://github.com/cedricziel/hermes-app/issues/1017)) ([9e0c305](https://github.com/cedricziel/hermes-app/commit/9e0c305cb9f4d7508c1c2ce347bea928575c4a7c))
* **chat:** agents and their detail in the Activity panel ([#1027](https://github.com/cedricziel/hermes-app/issues/1027)) ([2b6e5b1](https://github.com/cedricziel/hermes-app/commit/2b6e5b1a94e24224aed2bdb6f1fe7a6ddbe2bc1f))
* **chat:** checkpoint and context controllers ([#982](https://github.com/cedricziel/hermes-app/issues/982)) ([b90d787](https://github.com/cedricziel/hermes-app/commit/b90d7872667a2d6146f17f71dc33d9f22b2c1132))
* **chat:** checkpoint and context gateway calls ([#964](https://github.com/cedricziel/hermes-app/issues/964)) ([914270a](https://github.com/cedricziel/hermes-app/commit/914270ae142b5fc6489abc883a009c4c6a36d196))
* **chat:** checkpoint and context widgets in the catalog ([#1019](https://github.com/cedricziel/hermes-app/issues/1019)) ([f79ed36](https://github.com/cedricziel/hermes-app/commit/f79ed36bc722c4a3a0e6b31bd828c5f952352655))
* **chat:** checkpoints and context in the Activity panel (4.5 wiring) ([#1031](https://github.com/cedricziel/hermes-app/issues/1031)) ([f0205c8](https://github.com/cedricziel/hermes-app/commit/f0205c8e7d0234a863712d76f8d053dd1b59279e))
* **chat:** create chats in a chosen folder and move them ([#1008](https://github.com/cedricziel/hermes-app/issues/1008)) ([691d106](https://github.com/cedricziel/hermes-app/commit/691d10629f73f445e0d418c44d92571765fdbcda))
* **chat:** dock Needs-you items above the composer and confirm answers ([#1010](https://github.com/cedricziel/hermes-app/issues/1010)) ([a98e86e](https://github.com/cedricziel/hermes-app/commit/a98e86e4f618c9f37b68412cd30fd05d354249b2))
* **chat:** lead a server without a model to provider setup ([#1051](https://github.com/cedricziel/hermes-app/issues/1051)) ([45cbc6c](https://github.com/cedricziel/hermes-app/commit/45cbc6c49560a4e0e6e8313a3acd62289da89e9e))
* **chat:** list and stop a chat's background programs (state and gateway) ([#1042](https://github.com/cedricziel/hermes-app/issues/1042)) ([f1cad0c](https://github.com/cedricziel/hermes-app/commit/f1cad0ccfd809e9c3c1019ce94c01852ac4e0a3a))
* **chat:** read and control subagents over the gateway ([#967](https://github.com/cedricziel/hermes-app/issues/967)) ([a60ecc9](https://github.com/cedricziel/hermes-app/commit/a60ecc949af73842641e83b3d17aceea657b7bcd))
* **chat:** show and choose where a chat runs (working-folder screen) ([#1056](https://github.com/cedricziel/hermes-app/issues/1056)) ([fc78ea8](https://github.com/cedricziel/hermes-app/commit/fc78ea890cb0d702ed95d607a11096876f2b1b4a))
* **chat:** show working activity in one line ([#1028](https://github.com/cedricziel/hermes-app/issues/1028)) ([af81115](https://github.com/cedricziel/hermes-app/commit/af811155bbea541e063da906636a6c01e291135f))
* **chat:** stop a chat's background programs from the Activity panel ([#1054](https://github.com/cedricziel/hermes-app/issues/1054)) ([e075f2b](https://github.com/cedricziel/hermes-app/commit/e075f2b213b8bd38cd89bce80c18733866e32ef8))
* **chat:** stop, redirect and read one agent ([#980](https://github.com/cedricziel/hermes-app/issues/980)) ([66bb20d](https://github.com/cedricziel/hermes-app/commit/66bb20de5bbc2b3f1165be7a662d0200e195c867))
* **chat:** summarize working activity ([#1013](https://github.com/cedricziel/hermes-app/issues/1013)) ([088da1c](https://github.com/cedricziel/hermes-app/commit/088da1ce2fa270fda220e8e7e80e2684ae32af5b))
* **chat:** track a chat's agents ([#989](https://github.com/cedricziel/hermes-app/issues/989)) ([2df281c](https://github.com/cedricziel/hermes-app/commit/2df281cfa9d8f044ebd53a007d0abfd251a43239))
* **chat:** type a queued send's failure by step and signal the submit ([#1070](https://github.com/cedricziel/hermes-app/issues/1070)) ([ab59d83](https://github.com/cedricziel/hermes-app/commit/ab59d83912f22004cbba4c910d98f3e79428e0b8))
* **chat:** wire a chat's agent roster into ChatController ([#996](https://github.com/cedricziel/hermes-app/issues/996)) ([20a8f34](https://github.com/cedricziel/hermes-app/commit/20a8f3460c9ba31da821e2e566230035051828b3))
* **files:** add ServerPath and secret-looking name checks ([#979](https://github.com/cedricziel/hermes-app/issues/979)) ([ca25e93](https://github.com/cedricziel/hermes-app/commit/ca25e9351c0ff0df94e4338b3edfa7eadff3e633))
* **files:** add the Files controller, staged downloads and the session cwd ([#997](https://github.com/cedricziel/hermes-app/issues/997)) ([d1f1f26](https://github.com/cedricziel/hermes-app/commit/d1f1f266e02d1be68835fed3c55651ca0496fcf1))
* **files:** add the Files widgets and their catalog use cases ([#1020](https://github.com/cedricziel/hermes-app/issues/1020)) ([698ac3e](https://github.com/cedricziel/hermes-app/commit/698ac3e346de55106af7c313594f856d33e5f02d))
* **files:** open Files from a chat ([#1026](https://github.com/cedricziel/hermes-app/issues/1026)) ([35cf751](https://github.com/cedricziel/hermes-app/commit/35cf7510416391481fba49a200862721667f7edf))
* **files:** read a chat's working folder from the server ([#981](https://github.com/cedricziel/hermes-app/issues/981)) ([7044d2c](https://github.com/cedricziel/hermes-app/commit/7044d2cbf92bfb78d781c27ccecfd04ec03889a3))
* **files:** save a file by path on every platform, Windows open rules, lock cleanup ([#1025](https://github.com/cedricziel/hermes-app/issues/1025)) ([32d4e7d](https://github.com/cedricziel/hermes-app/commit/32d4e7d525504c19e1350409b854fad44d7a6746))
* **notifications:** carry a draft and withdraw replyable notifications ([#1064](https://github.com/cedricziel/hermes-app/issues/1064)) ([f46d707](https://github.com/cedricziel/hermes-app/commit/f46d7077be19ad29af848910e2a92bf96e37bcf1))
* **notifications:** hand a notification reply to the sender in both isolates and on macOS ([#1076](https://github.com/cedricziel/hermes-app/issues/1076)) ([16cffc9](https://github.com/cedricziel/hermes-app/commit/16cffc9fda7fec00b92f30f2a54f2a831e9a5567))
* **notifications:** local notifications on Windows and Linux, App Lock wording per platform ([#988](https://github.com/cedricziel/hermes-app/issues/988)) ([3db8635](https://github.com/cedricziel/hermes-app/commit/3db8635e8603d550f883fd30fb4cb75de97d023e))
* **notifications:** send a reply typed in a notification, once ([#1074](https://github.com/cedricziel/hermes-app/issues/1074)) ([5d5da21](https://github.com/cedricziel/hermes-app/commit/5d5da21367f14b7e6f321d05b2a05d0bd0f222ee))
* **providers:** controllers for provider setup and account sign-in ([#991](https://github.com/cedricziel/hermes-app/issues/991)) ([ac6f92e](https://github.com/cedricziel/hermes-app/commit/ac6f92ed18a6c72cba6602f5659e8150e6293e97))
* **providers:** model providers screen and entry points ([#1033](https://github.com/cedricziel/hermes-app/issues/1033)) ([a1f3f8e](https://github.com/cedricziel/hermes-app/commit/a1f3f8e7c0e265991b8e494b78c5b164e470cf9c))
* **providers:** models and repository for the provider routes ([#966](https://github.com/cedricziel/hermes-app/issues/966)) ([a35ee7d](https://github.com/cedricziel/hermes-app/commit/a35ee7df9e868bcb96430e4d0b9a8adcccc571a4))
* **providers:** provider list and detail widgets in the catalog ([#1016](https://github.com/cedricziel/hermes-app/issues/1016)) ([80d7860](https://github.com/cedricziel/hermes-app/commit/80d786035be56da7cd34568a83f143e4e7d24a9b))
* **providers:** provider setup forms, sign-in and default model widgets in the catalog ([#1022](https://github.com/cedricziel/hermes-app/issues/1022)) ([5568e82](https://github.com/cedricziel/hermes-app/commit/5568e82b8b22e5f162e0d82b8d5b54b6eb247bba))
* **server-care:** add the plain-model widgets and their catalog use cases ([#941](https://github.com/cedricziel/hermes-app/issues/941)) ([d39a3b7](https://github.com/cedricziel/hermes-app/commit/d39a3b71434ec22eb7a625d2028515a274a38957))
* **server-care:** add the Server screen, Update page and Usage ([#954](https://github.com/cedricziel/hermes-app/issues/954)) ([32f69fa](https://github.com/cedricziel/hermes-app/commit/32f69fa912bcf00d5698781938562cd35fecdbf8))
* **server-care:** localize the catalog widgets, sizes and numbers follow the language ([#1001](https://github.com/cedricziel/hermes-app/issues/1001)) ([d8e6a7f](https://github.com/cedricziel/hermes-app/commit/d8e6a7fa1d109bac7084aeabfb2d243bc3d636ef))
* **server-care:** read the server's logs ([#1045](https://github.com/cedricziel/hermes-app/issues/1045)) ([6d74984](https://github.com/cedricziel/hermes-app/commit/6d74984de8c996232a369630415804de5e4d4725))
* **server-care:** restart and start the gateway from the Server screen ([#1003](https://github.com/cedricziel/hermes-app/issues/1003)) ([a1e34ef](https://github.com/cedricziel/hermes-app/commit/a1e34ef0a5b85b012027421643eea7dd7811a47d))
* **server-care:** run a server check ([#1055](https://github.com/cedricziel/hermes-app/issues/1055)) ([8e1162d](https://github.com/cedricziel/hermes-app/commit/8e1162d51cb54317360e7071661c7233e293d5b2))
* **server-care:** show the Server list beside its page on wide windows ([#1071](https://github.com/cedricziel/hermes-app/issues/1071)) ([f572d57](https://github.com/cedricziel/hermes-app/commit/f572d57fe29eff6fe49b2d9dd6477f0f3131e4f4))
* **server-care:** track server status and attention ([#943](https://github.com/cedricziel/hermes-app/issues/943)) ([fd9a626](https://github.com/cedricziel/hermes-app/commit/fd9a62648b28d6b7bd1d23639ec7c7a0c25fb184))
* **server-care:** update Hermes from the app ([#1030](https://github.com/cedricziel/hermes-app/issues/1030)) ([e503a07](https://github.com/cedricziel/hermes-app/commit/e503a0773507cd133726a1eb4566ae6cd1662037))
* **skills:** verify against a throwaway backend and the Linux app in cloud sessions ([#928](https://github.com/cedricziel/hermes-app/issues/928)) ([a1e5cf4](https://github.com/cedricziel/hermes-app/commit/a1e5cf41976adc14ac0ab4cc73859bd1f4fd99a9))
* **theme:** add a link colour to the Hermes theme ([#975](https://github.com/cedricziel/hermes-app/issues/975)) ([214b51e](https://github.com/cedricziel/hermes-app/commit/214b51e79cc431d035337ef767afe60a2ce82da7))
* **tools:** add availability, install, terminal and computer use controllers ([#1032](https://github.com/cedricziel/hermes-app/issues/1032)) ([fe8fb2b](https://github.com/cedricziel/hermes-app/commit/fe8fb2b6d80c70c9a40e2c8f2e86d1a777046081))
* **tools:** add the provider row, key form, install, readiness and confirmations ([#1024](https://github.com/cedricziel/hermes-app/issues/1024)) ([39afb14](https://github.com/cedricziel/hermes-app/commit/39afb1482b67b2c1d5ba2c51c282ddb679dffa75))
* **tools:** add the Tools screen and its entries ([#1044](https://github.com/cedricziel/hermes-app/issues/1044)) ([7419495](https://github.com/cedricziel/hermes-app/commit/7419495be4d48e96b0542106f7042720d82c12ca))
* **tools:** add the toolset row, header, risk note and status chip ([#1018](https://github.com/cedricziel/hermes-app/issues/1018)) ([7432a01](https://github.com/cedricziel/hermes-app/commit/7432a010e8b0e21db0f7fddb2f27437f866a4667))
* **tools:** link "What's the difference?" from Skills, Plugins, MCP servers and Helper models ([#1063](https://github.com/cedricziel/hermes-app/issues/1063)) ([aaf3ee9](https://github.com/cedricziel/hermes-app/commit/aaf3ee9eb6724636198e617b5d7168b68a7a38c8))
* **tools:** read toolsets and their setup ([#957](https://github.com/cedricziel/hermes-app/issues/957)) ([351351e](https://github.com/cedricziel/hermes-app/commit/351351e82e4c114dc75e84e7bdfeab26829983ee))
* **tools:** set toolsets up from their details ([#1053](https://github.com/cedricziel/hermes-app/issues/1053)) ([a6bc816](https://github.com/cedricziel/hermes-app/commit/a6bc8162954684b73fe3c1aca78ec2892c1605ad))
* **tools:** switch toolsets and save keys in plain controllers ([#965](https://github.com/cedricziel/hermes-app/issues/965)) ([76a1f38](https://github.com/cedricziel/hermes-app/commit/76a1f38fc438436ff25e69c681096e61ce47ac6d))
* **widgets:** add DestructiveTintButton and share LoadingSkeleton and CommandRow ([#992](https://github.com/cedricziel/hermes-app/issues/992)) ([b218372](https://github.com/cedricziel/hermes-app/commit/b218372dca35de573debdf969f1f7930f3bbe92b))
* **widgets:** add SecretFieldRow for typed keys, tokens and passwords ([#987](https://github.com/cedricziel/hermes-app/issues/987)) ([a52b9c1](https://github.com/cedricziel/hermes-app/commit/a52b9c1e0788dea366a83e13afa46681822f055d))
* **widgets:** share one AppBanner with a neutral tone ([#956](https://github.com/cedricziel/hermes-app/issues/956)) ([537d379](https://github.com/cedricziel/hermes-app/commit/537d379b4a10ecb8ee97cf68b90e6d00882db3b5))
* **workspaces:** add the working-folder widgets and their catalog use cases ([#1046](https://github.com/cedricziel/hermes-app/issues/1046)) ([c55737e](https://github.com/cedricziel/hermes-app/commit/c55737ea5d078fd16cfa35d0624fb45ae1e5d98c))
* **workspaces:** repository, path rules and thread folder fields ([#999](https://github.com/cedricziel/hermes-app/issues/999)) ([dfbbfe4](https://github.com/cedricziel/hermes-app/commit/dfbbfe40077ddbcf85f771c090ca10f4fa42de5d))


### Bug Fixes

* **auth,schedules:** stop swallowing real failures in broad catches (P.5, 1/6) ([#969](https://github.com/cedricziel/hermes-app/issues/969)) ([7e461ea](https://github.com/cedricziel/hermes-app/commit/7e461eac06583389b0fda1b4883bc2696b19f5d2))
* **auth:** close pushed pages and dialogs when the connection ends ([#1052](https://github.com/cedricziel/hermes-app/issues/1052)) ([3333b25](https://github.com/cedricziel/hermes-app/commit/3333b25e799ece32e6c7162eb12a80cc599e9a7b))
* **auth:** end the session on a refresh 403 only with Hermes' error body ([#970](https://github.com/cedricziel/hermes-app/issues/970)) ([8a055e5](https://github.com/cedricziel/hermes-app/commit/8a055e50dc9e71ca53171326b0e7a6e00ae76f4a))
* **auth:** keep a session without a recorded server off new addresses ([#978](https://github.com/cedricziel/hermes-app/issues/978)) ([7f7be77](https://github.com/cedricziel/hermes-app/commit/7f7be77ee02c2c925572e386e50b39d98f4ff477))
* **background:** lock and order announced-request marks ([#951](https://github.com/cedricziel/hermes-app/issues/951)) ([6487a29](https://github.com/cedricziel/hermes-app/commit/6487a29d540e7e656d1ab46d08ce6861582751e9))
* **bot-mode,watch,macos,widgets:** narrow link and probe catches, trim logs (P.5, 4/6) ([#998](https://github.com/cedricziel/hermes-app/issues/998)) ([b02119d](https://github.com/cedricziel/hermes-app/commit/b02119d2e9058b24ece1d7a52e79e05b8e48c01d))
* **bot-screen:** notify on viewer id let-go and keep a reopened viewer's lease ([#952](https://github.com/cedricziel/hermes-app/issues/952)) ([0c50bbc](https://github.com/cedricziel/hermes-app/commit/0c50bbce95aadc997689d6d728bfc7c1d50f534e))
* **chat,skills,voice:** report bugs caught by broad catches (P.5, 5/6) ([#1005](https://github.com/cedricziel/hermes-app/issues/1005)) ([8e4504c](https://github.com/cedricziel/hermes-app/commit/8e4504cd0f6c36a81bc6bf492569267a03b6efb5))
* **chat:** do not take a stop gate's checkpoint for a final answer ([#976](https://github.com/cedricziel/hermes-app/issues/976)) ([faafc53](https://github.com/cedricziel/hermes-app/commit/faafc53ed18710630cbc98c8241a54854985283e))
* **chat:** keep the running turn when the chat list is read again ([#963](https://github.com/cedricziel/hermes-app/issues/963)) ([6a2b82b](https://github.com/cedricziel/hermes-app/commit/6a2b82b784bb9e6840034a40d3277c22d73f1e93))
* **chat:** keep the title of a stored chat whose page has not landed ([#968](https://github.com/cedricziel/hermes-app/issues/968)) ([958c925](https://github.com/cedricziel/hermes-app/commit/958c925eda34b87af1308b98f2d4bb14c6dd6f08))
* **chat:** keep working-summary stamps for repeated status text and queued turns ([#1041](https://github.com/cedricziel/hermes-app/issues/1041)) ([20d3a07](https://github.com/cedricziel/hermes-app/commit/20d3a07d1074759186625e785964ea692665435d))
* **chat:** merge a command's re-read with the rows held here ([#959](https://github.com/cedricziel/hermes-app/issues/959)) ([a53fd17](https://github.com/cedricziel/hermes-app/commit/a53fd1706e92922da5ee227ff0c6365855072d3c))
* **files:** serialise sink flushes in the fs download so a cancel cannot race them ([#1043](https://github.com/cedricziel/hermes-app/issues/1043)) ([9c09fef](https://github.com/cedricziel/hermes-app/commit/9c09fefa42c74cd64ddfb14de52a1650c7c3798f))
* **kanban,messaging,plugins:** report bugs caught by broad catches (P.5, 2/6) ([#984](https://github.com/cedricziel/hermes-app/issues/984)) ([c20ecaa](https://github.com/cedricziel/hermes-app/commit/c20ecaa142c5dd11a78244435ab9b7c6a40bc1c8))
* **l10n:** declare iOS and macOS bundle localizations ([#960](https://github.com/cedricziel/hermes-app/issues/960)) ([2a1a08e](https://github.com/cedricziel/hermes-app/commit/2a1a08e984f9fe42c1360506bcf06d900bd47026))
* **mcp,memory:** report bugs caught by broad catches (P.5, 3/6) ([#994](https://github.com/cedricziel/hermes-app/issues/994)) ([635f419](https://github.com/cedricziel/hermes-app/commit/635f419964972ededd68852f480cfd1367ceaeac))
* **plugins:** keep plugin and provider names out of app events ([#1007](https://github.com/cedricziel/hermes-app/issues/1007)) ([b07e459](https://github.com/cedricziel/hermes-app/commit/b07e4591074699e03ec06e36faaae0406c29e665))
* **profiles:** set a profile's default model with POST /api/model/set ([#973](https://github.com/cedricziel/hermes-app/issues/973)) ([b7baf6a](https://github.com/cedricziel/hermes-app/commit/b7baf6a3e924e2e33d3490ae2eb4f40173d8c6c2))
* **server-care:** follow up the gateway run review ([#1023](https://github.com/cedricziel/hermes-app/issues/1023)) ([ff0a25b](https://github.com/cedricziel/hermes-app/commit/ff0a25b1612b790e2ea3ac3e3c5901e765666f2d))
* **server-care:** import LoadingSkeleton from the shared widgets folder ([#1009](https://github.com/cedricziel/hermes-app/issues/1009)) ([c3f82e4](https://github.com/cedricziel/hermes-app/commit/c3f82e41115615a947103d026009bdee3d05eb67))
* **server-care:** read a real doctor run cleanly and show no "unknown" version ([#1073](https://github.com/cedricziel/hermes-app/issues/1073)) ([34dcd38](https://github.com/cedricziel/hermes-app/commit/34dcd382150ad27174718d44a66dadb50e37efc3))
* **shell:** follow the owner generation instead of fixing it at initState ([#1057](https://github.com/cedricziel/hermes-app/issues/1057)) ([322e191](https://github.com/cedricziel/hermes-app/commit/322e19108eec1840de479ff9a31fd5904ff74b7e))
* **skills:** keep a finished toggle against a stale reload, drop the toggle chain per profile ([#950](https://github.com/cedricziel/hermes-app/issues/950)) ([5694a4e](https://github.com/cedricziel/hermes-app/commit/5694a4e7c3c3243bbe9f006607a037847ed5c39f))
* **surfaces:** Android reload, widget usage report and backup exclusion ([#993](https://github.com/cedricziel/hermes-app/issues/993)) ([3628bf9](https://github.com/cedricziel/hermes-app/commit/3628bf9dd27ace277f2dc752a0431dc6bdbac9f8))
* **theme:** make dark dialogs and sheets stand out from the scrim ([#1039](https://github.com/cedricziel/hermes-app/issues/1039)) ([6fabf70](https://github.com/cedricziel/hermes-app/commit/6fabf708d212913acd3be94321b119bcd9955f62))
* **tools:** keep setup writes and results safe across panel rebuilds and installs ([#1067](https://github.com/cedricziel/hermes-app/issues/1067)) ([6743c76](https://github.com/cedricziel/hermes-app/commit/6743c76c63f460faf45da8c0fe12060e127fc457))
* **voice:** close the microphone on every dictation path ([#949](https://github.com/cedricziel/hermes-app/issues/949)) ([e38c7c2](https://github.com/cedricziel/hermes-app/commit/e38c7c2cdad8ee2fdd75442855f8a88aa731c11c))
* **voice:** let CallKit start iOS calls and report why one failed ([#1061](https://github.com/cedricziel/hermes-app/issues/1061)) ([11ad057](https://github.com/cedricziel/hermes-app/commit/11ad057c4668197e11bab4762898526ffd72c4be))
* **widgets:** keep GroupedRow line limits once its value stacks ([#986](https://github.com/cedricziel/hermes-app/issues/986)) ([fe8ebf1](https://github.com/cedricziel/hermes-app/commit/fe8ebf1a19ed067dc6402e9b4939da3a98f530d5))
* **workspaces:** address review of the working-folder widgets ([#1049](https://github.com/cedricziel/hermes-app/issues/1049)) ([313b69d](https://github.com/cedricziel/hermes-app/commit/313b69def0780956189666e0c55fb942ece84924))


### Documentation

* **chat:** tick the finished checkpoint tasks, note them in CLAUDE.md and the verify skill ([#1058](https://github.com/cedricziel/hermes-app/issues/1058)) ([afe26df](https://github.com/cedricziel/hermes-app/commit/afe26dfd0fd76a409fa7824fbf22382f962b228c))
* **design:** add the skill curator design brief ([#1037](https://github.com/cedricziel/hermes-app/issues/1037)) ([01cb687](https://github.com/cedricziel/hermes-app/commit/01cb68729f55287b400246787ae8baafe766a6ca))
* **design:** design pass for linking WhatsApp by QR code ([#1036](https://github.com/cedricziel/hermes-app/issues/1036)) ([3c81526](https://github.com/cedricziel/hermes-app/commit/3c81526eb1c9815e0c189579f5fefb02aedb4a48))
* **design:** Personality screen design pass for profile-soul ([#1034](https://github.com/cedricziel/hermes-app/issues/1034)) ([fcc7d71](https://github.com/cedricziel/hermes-app/commit/fcc7d71fb50ce31947a80ae7d749bc8409aedb88))
* **design:** session export design pass ([#1035](https://github.com/cedricziel/hermes-app/issues/1035)) ([ecc48ad](https://github.com/cedricziel/hermes-app/commit/ecc48adae57a031e6b3089b02796a5984e3b01f9))
* **openspec:** archive the chat activity changes ([#1040](https://github.com/cedricziel/hermes-app/issues/1040)) ([b7ec592](https://github.com/cedricziel/hermes-app/commit/b7ec59277c65447fd4c1849b27b5607e9427dd03))
* **openspec:** design record for the chat activity line and Needs-you dock ([#985](https://github.com/cedricziel/hermes-app/issues/985)) ([9abcc17](https://github.com/cedricziel/hermes-app/commit/9abcc17641015b3a15a259e2fe7fdc2e9a5cf8a3))
* **openspec:** propose Android home screen widgets ([#974](https://github.com/cedricziel/hermes-app/issues/974)) ([a06bbe1](https://github.com/cedricziel/hermes-app/commit/a06bbe17e2caaaa76b1972cf77fe1ae88c4d90bc))
* **openspec:** propose SOUL editing, session export, WhatsApp onboarding and the skills curator ([#972](https://github.com/cedricziel/hermes-app/issues/972)) ([d662d0d](https://github.com/cedricziel/hermes-app/commit/d662d0d03a714a5d40cc7744441adbd697c947da))
* **openspec:** record bot-mode change status ([#961](https://github.com/cedricziel/hermes-app/issues/961)) ([3d6769f](https://github.com/cedricziel/hermes-app/commit/3d6769f4719d7711a0f6113e696ec66f8827cb7c))
* **openspec:** record the chat working directory design ([#947](https://github.com/cedricziel/hermes-app/issues/947)) ([2e3284c](https://github.com/cedricziel/hermes-app/commit/2e3284ceff07df5c5fe0b53b364ec8f9fcec041b))
* **openspec:** record the checkpoints and context design ([#942](https://github.com/cedricziel/hermes-app/issues/942)) ([068a6b6](https://github.com/cedricziel/hermes-app/commit/068a6b6b095c13bf6fe0474b38e5cd485afdd49a))
* **openspec:** record the hands-free voice conversation design ([#995](https://github.com/cedricziel/hermes-app/issues/995)) ([c79cc2d](https://github.com/cedricziel/hermes-app/commit/c79cc2d0c0af5f2104037b71242e647cfd92730a))
* **openspec:** record the notification inline reply design ([#983](https://github.com/cedricziel/hermes-app/issues/983)) ([354fdc1](https://github.com/cedricziel/hermes-app/commit/354fdc1f2eef6d8425d07589c1be7c5aa144067a))
* **openspec:** record the provider setup design ([#939](https://github.com/cedricziel/hermes-app/issues/939)) ([b530755](https://github.com/cedricziel/hermes-app/commit/b53075575caa5a8800179076ae5b7d64d30a7c41))
* **openspec:** record the server files design ([#944](https://github.com/cedricziel/hermes-app/issues/944)) ([c21453a](https://github.com/cedricziel/hermes-app/commit/c21453a59bb665a9834a300cde3882f018868b2e))
* **openspec:** record the subagent control design ([#938](https://github.com/cedricziel/hermes-app/issues/938)) ([6b46490](https://github.com/cedricziel/hermes-app/commit/6b464900a90747ebc9cfa3d3931b6dd2aa2fa85c))
* **openspec:** record the toolsets design ([#936](https://github.com/cedricziel/hermes-app/issues/936)) ([fac0772](https://github.com/cedricziel/hermes-app/commit/fac07728ad5ab11d99b021b0f700f12435b909b2))
* **providers:** record where each provider setup task was done and what is still open ([#1059](https://github.com/cedricziel/hermes-app/issues/1059)) ([f7cc6f8](https://github.com/cedricziel/hermes-app/commit/f7cc6f845e4e813a9692b23c8a480d9c53ad08f0))
* **roadmap:** record merged server-care controller and started work ([#958](https://github.com/cedricziel/hermes-app/issues/958)) ([a0999ed](https://github.com/cedricziel/hermes-app/commit/a0999ed8cb3ebd752a533a3891084bd6a5b5d7ae))
* **roadmap:** record merged wave 4 layers, review states and new findings ([#1004](https://github.com/cedricziel/hermes-app/issues/1004)) ([700bba7](https://github.com/cedricziel/hermes-app/commit/700bba79ea3dbada4e639616ca474ddd2d3861df))
* **roadmap:** record merges and findings up to [#1020](https://github.com/cedricziel/hermes-app/issues/1020) ([#1021](https://github.com/cedricziel/hermes-app/issues/1021)) ([579e0ab](https://github.com/cedricziel/hermes-app/commit/579e0ab1ac95dc4be02ae730e09f98b13a4521f5))
* **roadmap:** record merges and findings up to [#1028](https://github.com/cedricziel/hermes-app/issues/1028) ([#1029](https://github.com/cedricziel/hermes-app/issues/1029)) ([696c5cf](https://github.com/cedricziel/hermes-app/commit/696c5cf7e080bf0b02cb71234e874646c564cbe4))
* **roadmap:** record merges and findings up to [#1047](https://github.com/cedricziel/hermes-app/issues/1047) ([#1048](https://github.com/cedricziel/hermes-app/issues/1048)) ([30fb72d](https://github.com/cedricziel/hermes-app/commit/30fb72dfe43d54e2403b54ee5d5175c5bb9dee84))
* **roadmap:** record merges through [#1054](https://github.com/cedricziel/hermes-app/issues/1054) and new findings ([#1062](https://github.com/cedricziel/hermes-app/issues/1062)) ([1fdd8a3](https://github.com/cedricziel/hermes-app/commit/1fdd8a3584fe580ce2f599873c359b129a6ffa99))
* **roadmap:** record release 0.1.77, the wave 4 design records and new findings ([#948](https://github.com/cedricziel/hermes-app/issues/948)) ([8b0f56b](https://github.com/cedricziel/hermes-app/commit/8b0f56b9d58de042ef7650b59e118fac7921a9a1))
* **roadmap:** record the wave 4 layers on main, closed fixes and new findings ([#1015](https://github.com/cedricziel/hermes-app/issues/1015)) ([c9c209b](https://github.com/cedricziel/hermes-app/commit/c9c209b13141e39b2c8e4b80870d7ebcd23878c6))
* **roadmap:** record wave 4 design records and running builds ([#953](https://github.com/cedricziel/hermes-app/issues/953)) ([948431d](https://github.com/cedricziel/hermes-app/commit/948431d3de460aaeed952aeaf422d739a980fdda))
* say gen-l10n or pub get is needed after a pull with ARB changes ([#971](https://github.com/cedricziel/hermes-app/issues/971)) ([9010a49](https://github.com/cedricziel/hermes-app/commit/9010a49ab81da678e2bb9e0f2523c9b3b1d1b5d7))
* **skills:** add the design-pass skill and update the rollout rules ([#955](https://github.com/cedricziel/hermes-app/issues/955)) ([a1cf57e](https://github.com/cedricziel/hermes-app/commit/a1cf57e2c9ed0e148563ea9e493c9195d98d8457))
* state Windows and Linux support in the README ([#962](https://github.com/cedricziel/hermes-app/issues/962)) ([e0b4fe4](https://github.com/cedricziel/hermes-app/commit/e0b4fe48348ea5cb5ca46aa7dca244d3ae89c0c0))
* **telemetry:** state the rule for catching errors (P.5, 6/6) ([#1006](https://github.com/cedricziel/hermes-app/issues/1006)) ([17a0db2](https://github.com/cedricziel/hermes-app/commit/17a0db20c71a26f222532fb8cd13189893a39af2))

## [0.1.77](https://github.com/cedricziel/hermes-app/compare/v0.1.76...v0.1.77) (2026-11-14)


### Features

* **l10n:** add localization scaffolding with English and German for settings ([#919](https://github.com/cedricziel/hermes-app/issues/919)) ([8b0e672](https://github.com/cedricziel/hermes-app/commit/8b0e672ba1296f984e6a14f3f2982ebece8d9598))
* **notifications:** answer agent requests from Android notifications ([#914](https://github.com/cedricziel/hermes-app/issues/914)) ([d3f5b18](https://github.com/cedricziel/hermes-app/commit/d3f5b180627d65cb3476888dff235ba5c58fbed9))
* **server-care:** read server status, updates, logs, checks and usage ([#935](https://github.com/cedricziel/hermes-app/issues/935)) ([c87ae05](https://github.com/cedricziel/hermes-app/commit/c87ae05a39151f7edd65c0c41ed785d0a2105ddc))


### Bug Fixes

* **auth:** harden the sign-in listener and keep stored sessions on their host ([#908](https://github.com/cedricziel/hermes-app/issues/908)) ([d3886ff](https://github.com/cedricziel/hermes-app/commit/d3886ffcb483ef74d3c812f392e998c9b1f0d5ab))
* background request alerts, widget reload budget, suspension marks and App Lock check ([#906](https://github.com/cedricziel/hermes-app/issues/906)) ([87b2ad3](https://github.com/cedricziel/hermes-app/commit/87b2ad30c20be2d5fca075e849e12198e06f31f4))
* **background:** renew the marks of requests that stay open ([#934](https://github.com/cedricziel/hermes-app/issues/934)) ([bcd6f56](https://github.com/cedricziel/hermes-app/commit/bcd6f5693dcb3585b4c5d858a5a2dd5286d66518))
* **bot-screen:** keep the control lease consistent across shut down, take over retries and old broadcasts ([#905](https://github.com/cedricziel/hermes-app/issues/905)) ([fe94515](https://github.com/cedricziel/hermes-app/commit/fe945158f265a1e6a9e17417d969ff5b7cdbf3b0))
* **bot-screen:** offer Hand back after a release that missed the shut-down budget ([#933](https://github.com/cedricziel/hermes-app/issues/933)) ([3f90121](https://github.com/cedricziel/hermes-app/commit/3f90121397fcf6aa8386f824a485ae3ad503e72d))
* **chat:** keep history in order when pages race a send or a refresh ([#902](https://github.com/cedricziel/hermes-app/issues/902)) ([297342d](https://github.com/cedricziel/hermes-app/commit/297342d2d5b520241632f38c44382779110b59d0))
* **chat:** show a prompt once when its receipt follows the page ([#937](https://github.com/cedricziel/hermes-app/issues/937)) ([d7fe56d](https://github.com/cedricziel/hermes-app/commit/d7fe56d5d4d97fa094adc8cbc1da5b2945ddd820))
* early window calls, an unawaited panel toggle and malformed native arguments ([#911](https://github.com/cedricziel/hermes-app/issues/911)) ([1939a51](https://github.com/cedricziel/hermes-app/commit/1939a51910a4be9036651663fb625706c99c574b))
* **gateway:** keep live streaming/resuming turns and settle oddly shaped answers ([#897](https://github.com/cedricziel/hermes-app/issues/897)) ([c7f83cb](https://github.com/cedricziel/hermes-app/commit/c7f83cb37a6a32febc35cfa0460a5050d129f667))
* **schedules:** save edits of past one-shot jobs and keep mutes on incomplete listings ([#900](https://github.com/cedricziel/hermes-app/issues/900)) ([427ba73](https://github.com/cedricziel/hermes-app/commit/427ba73a7639fcee1eba3e159c889f479ed562ca))
* settle controller state races in skills, kanban, memory settings and avatars ([#901](https://github.com/cedricziel/hermes-app/issues/901)) ([fc2c2e6](https://github.com/cedricziel/hermes-app/commit/fc2c2e6f373dad97f41a2b9cc1dac4db35624ea1))
* **skills:** keep toggles and their rollback value across a list reload ([#930](https://github.com/cedricziel/hermes-app/issues/930)) ([b7f49d6](https://github.com/cedricziel/hermes-app/commit/b7f49d6e5626b9da7c6873e5f5d26a6d05f04fe5))
* **surfaces:** record the widget reload time only after a reload succeeded ([#932](https://github.com/cedricziel/hermes-app/issues/932)) ([4d923cb](https://github.com/cedricziel/hermes-app/commit/4d923cbd1e6a27b627a33c511b3ac21b056bc9bb))
* **telemetry:** name failed snapshot sources, stop counting time-outs as errors, mark failed proposal reads ([#896](https://github.com/cedricziel/hermes-app/issues/896)) ([50f416a](https://github.com/cedricziel/hermes-app/commit/50f416a107d2ee225b994f1837c39d81173ae050))
* **voice:** guard dictation start against a throwing connector ([#931](https://github.com/cedricziel/hermes-app/issues/931)) ([6dff6f5](https://github.com/cedricziel/hermes-app/commit/6dff6f5126df61d46ed8589b5c770ee58a5ae362))
* **voice:** handle platform errors, late sockets and double notices ([#904](https://github.com/cedricziel/hermes-app/issues/904)) ([1f40a83](https://github.com/cedricziel/hermes-app/commit/1f40a832e3079bcebb49721a6f047dacdeaf0e2e))


### Documentation

* add the roadmap and what the agent run taught the rollout skill ([#909](https://github.com/cedricziel/hermes-app/issues/909)) ([6524e6f](https://github.com/cedricziel/hermes-app/commit/6524e6fb9dc8f227d0aa7b26a655426b610567ec))
* move architecture detail out of CLAUDE.md ([#899](https://github.com/cedricziel/hermes-app/issues/899)) ([cffded7](https://github.com/cedricziel/hermes-app/commit/cffded7d83ef4851702688cbb29ecabe97bbd78f))
* **openspec:** archive implemented changes and list what is open ([#903](https://github.com/cedricziel/hermes-app/issues/903)) ([0cf08af](https://github.com/cedricziel/hermes-app/commit/0cf08af3b97451613bc38c1d1b93848f586d6511))
* **openspec:** propose chat checkpoints and context ([#921](https://github.com/cedricziel/hermes-app/issues/921)) ([1e1c1a0](https://github.com/cedricziel/hermes-app/commit/1e1c1a0bcf6ad8f5bb224670e3887d8fed7123e1))
* **openspec:** propose chat working directory ([#922](https://github.com/cedricziel/hermes-app/issues/922)) ([ad2e75b](https://github.com/cedricziel/hermes-app/commit/ad2e75b02a8462aee5749e57cef5b3470d83f6b1))
* **openspec:** propose provider setup ([#913](https://github.com/cedricziel/hermes-app/issues/913)) ([40c2a67](https://github.com/cedricziel/hermes-app/commit/40c2a67b778e9dd1e3c266596a1f1470ca7dd370))
* **openspec:** propose server care ([#915](https://github.com/cedricziel/hermes-app/issues/915)) ([3491731](https://github.com/cedricziel/hermes-app/commit/34917317edf4e2baba7681a1940cb64cf001b029))
* **openspec:** propose server files (browse and open what the agent wrote) ([#917](https://github.com/cedricziel/hermes-app/issues/917)) ([71a856a](https://github.com/cedricziel/hermes-app/commit/71a856afaa1f0d52519df726c92770acbde1e9d0))
* **openspec:** propose subagent control ([#912](https://github.com/cedricziel/hermes-app/issues/912)) ([0e4fa51](https://github.com/cedricziel/hermes-app/commit/0e4fa513cb121cda3a80854fe387db1464a2cc6b))
* **openspec:** propose toolsets ([#920](https://github.com/cedricziel/hermes-app/issues/920)) ([16941c9](https://github.com/cedricziel/hermes-app/commit/16941c9bff48586cf3388330afc3a1198634c986))
* **openspec:** record the Server care design and its decisions ([#927](https://github.com/cedricziel/hermes-app/issues/927)) ([f2b17c6](https://github.com/cedricziel/hermes-app/commit/f2b17c6985fe9f6d5f9dd44d41602e91b14a8125))
* **roadmap:** record merged work and what the work itself turned up ([#916](https://github.com/cedricziel/hermes-app/issues/916)) ([d392b7a](https://github.com/cedricziel/hermes-app/commit/d392b7aa2b9d0ca646e143c7aba4436ccb73c452))
* **roadmap:** record the merged fixes and what their reviews left open ([#940](https://github.com/cedricziel/hermes-app/issues/940)) ([fec24ee](https://github.com/cedricziel/hermes-app/commit/fec24ee89d0536fbeca7ded077868dea9862b392))
* **roadmap:** record the merged proposals, [#901](https://github.com/cedricziel/hermes-app/issues/901), [#914](https://github.com/cedricziel/hermes-app/issues/914) and the CI changes ([#929](https://github.com/cedricziel/hermes-app/issues/929)) ([bc7d6c6](https://github.com/cedricziel/hermes-app/commit/bc7d6c64b130ce1dbddcbd45e73cfa2c16abeaf3))

## [0.1.76](https://github.com/cedricziel/hermes-app/compare/v0.1.75...v0.1.76) (2026-11-09)


### Features

* **chat:** branch a chat from a reply into a new chat ([#880](https://github.com/cedricziel/hermes-app/issues/880)) ([006dc11](https://github.com/cedricziel/hermes-app/commit/006dc116f418c83e5784c332c547c9d30204c059))


### Bug Fixes

* **chat:** show reasoning sent with the completion, drop empty blocks ([#876](https://github.com/cedricziel/hermes-app/issues/876)) ([5802ec9](https://github.com/cedricziel/hermes-app/commit/5802ec9f0fc32c2b0c6e923584e319aa9253efe1))
* **chat:** try again resends only the last prompt the user wrote ([#875](https://github.com/cedricziel/hermes-app/issues/875)) ([06bf118](https://github.com/cedricziel/hermes-app/commit/06bf118c1eefdae18587d10a2e2ff485d60b91ba))
* **ci:** read store metadata from the dispatched branch on manual App Store runs ([#879](https://github.com/cedricziel/hermes-app/issues/879)) ([208131b](https://github.com/cedricziel/hermes-app/commit/208131be4ade80d7ab6b40dae98ec38ed07477e5))
* **mcp:** don't hold the Add spinner on the server list reload ([#881](https://github.com/cedricziel/hermes-app/issues/881)) ([ee1ac5b](https://github.com/cedricziel/hermes-app/commit/ee1ac5b2544e475dca3273ee8fef375d9815d4a1))
* **release:** answer App Store Connect's social media age rating question ([#874](https://github.com/cedricziel/hermes-app/issues/874)) ([9565ef8](https://github.com/cedricziel/hermes-app/commit/9565ef85e6f15d29d59f64d4ff4ed9f09453e065))
* **voice:** log why a voice call fails ([#878](https://github.com/cedricziel/hermes-app/issues/878)) ([c148404](https://github.com/cedricziel/hermes-app/commit/c148404bb4ad62898fd300f4150f228a494ccef8))

## [0.1.75](https://github.com/cedricziel/hermes-app/compare/v0.1.74...v0.1.75) (2026-10-31)


### Features

* **chat:** read replies aloud with Hermes text to speech ([#869](https://github.com/cedricziel/hermes-app/issues/869)) ([cdf2056](https://github.com/cedricziel/hermes-app/commit/cdf2056eb8f6058b901552bd3479531eec9d34d6))


### Bug Fixes

* **auth:** keep cleartext HTTP to local and tailnet hosts ([#870](https://github.com/cedricziel/hermes-app/issues/870)) ([b55277a](https://github.com/cedricziel/hermes-app/commit/b55277a79a79d230c6c1093f3e7da19a84ebbed4)), closes [#866](https://github.com/cedricziel/hermes-app/issues/866)
* **auth:** open the sign-in page when the sheet refuses to start ([#863](https://github.com/cedricziel/hermes-app/issues/863)) ([1d7e3b8](https://github.com/cedricziel/hermes-app/commit/1d7e3b8d90d6eb71b639b7994b4e93ed4da06d67))
* **chat:** keep a tapped tool group in view instead of jumping to the end ([#864](https://github.com/cedricziel/hermes-app/issues/864)) ([968e8f1](https://github.com/cedricziel/hermes-app/commit/968e8f1d52b374e8935d254297af50854094f19a))
* **telemetry:** back off failing polls, fold log bursts, mark suspended spans ([#871](https://github.com/cedricziel/hermes-app/issues/871)) ([5b7e24c](https://github.com/cedricziel/hermes-app/commit/5b7e24c732c81f3305f6c9f66060e796657d364e))
* **telemetry:** bump dart_otel_instrumentation_messaging to 0.1.3 ([#873](https://github.com/cedricziel/hermes-app/issues/873)) ([ab8ad51](https://github.com/cedricziel/hermes-app/commit/ab8ad5139df41151600d25d1de49e693b79419bb))


### Documentation

* **skills:** use the Latest release as the release notes baseline ([#813](https://github.com/cedricziel/hermes-app/issues/813)) ([072f2e0](https://github.com/cedricziel/hermes-app/commit/072f2e0176ea721342c37c511cae0852eeb15c50))

## [0.1.74](https://github.com/cedricziel/hermes-app/compare/v0.1.73...v0.1.74) (2026-10-30)


### Features

* **bot-screen:** hold the screen's control lease ([#854](https://github.com/cedricziel/hermes-app/issues/854)) ([4a74e26](https://github.com/cedricziel/hermes-app/commit/4a74e267ebce89da6c9a05bfd95d2f838ca2803f))
* **bot-screen:** install the desktop on the server ([#853](https://github.com/cedricziel/hermes-app/issues/853)) ([d43b805](https://github.com/cedricziel/hermes-app/commit/d43b8051feaa39b34683cc3bef45d9b6575a8f94))
* **bot-screen:** preview the bot's screen in the transcript ([#851](https://github.com/cedricziel/hermes-app/issues/851)) ([9630d24](https://github.com/cedricziel/hermes-app/commit/9630d242f713a3431707df05e9b611c4e723ecc6))
* **bot-screen:** send input over RFB ([#844](https://github.com/cedricziel/hermes-app/issues/844)) ([4363d96](https://github.com/cedricziel/hermes-app/commit/4363d967af5b8d8bb1b3fd0fc27e31db97741825))
* **bot-screen:** show the bot's screen in the Activity panel ([#848](https://github.com/cedricziel/hermes-app/issues/848)) ([c971385](https://github.com/cedricziel/hermes-app/commit/c97138594fd902b9bc755f9d6876438d148d59eb))
* **bot-screen:** take over and hand back the bot's screen ([#855](https://github.com/cedricziel/hermes-app/issues/855)) ([5f0917f](https://github.com/cedricziel/hermes-app/commit/5f0917f1a3cb7ac02a08af325fff91ef00578984))
* **bot-screen:** watch the bot's screen live ([#852](https://github.com/cedricziel/hermes-app/issues/852)) ([ec9bfc5](https://github.com/cedricziel/hermes-app/commit/ec9bfc550f2a6299c1c3b07ebe4870552f1f1421))


### Bug Fixes

* **api:** end a request that outlasts an overall deadline ([#861](https://github.com/cedricziel/hermes-app/issues/861)) ([ff1f438](https://github.com/cedricziel/hermes-app/commit/ff1f43849532bff28e77462013e948c0204cdb33))
* **macos:** register native channels even after the window is wrapped ([#850](https://github.com/cedricziel/hermes-app/issues/850)) ([84e3649](https://github.com/cedricziel/hermes-app/commit/84e3649a08b6c5dc2cf4ab416314aa659d07cafc))

## [0.1.73](https://github.com/cedricziel/hermes-app/compare/v0.1.72...v0.1.73) (2026-10-26)


### Bug Fixes

* **auth:** preserve sessions when refresh recovery cannot read keychain ([#845](https://github.com/cedricziel/hermes-app/issues/845)) ([f7ec132](https://github.com/cedricziel/hermes-app/commit/f7ec132fca4f9355e02c484da2171352525309a3))
* **auth:** serialize session mutations and retry token persistence ([#847](https://github.com/cedricziel/hermes-app/issues/847)) ([6a8d3b3](https://github.com/cedricziel/hermes-app/commit/6a8d3b30c5fdd87b512efe562eaae586086df0c2))

## [0.1.72](https://github.com/cedricziel/hermes-app/compare/v0.1.71...v0.1.72) (2026-10-25)


### Features

* **bot-screen:** add an RFB client for the bot's screen ([#842](https://github.com/cedricziel/hermes-app/issues/842)) ([5e193f1](https://github.com/cedricziel/hermes-app/commit/5e193f1e4710c59b112e93315a84c379a735813b))
* **bot-screen:** read the bot's screen state over the gateway ([#841](https://github.com/cedricziel/hermes-app/issues/841)) ([1958cc0](https://github.com/cedricziel/hermes-app/commit/1958cc0f639cc300c295a77bf5a6f9d4d010e910))


### Bug Fixes

* **auth:** preserve valid OIDC sessions ([#843](https://github.com/cedricziel/hermes-app/issues/843)) ([85b9786](https://github.com/cedricziel/hermes-app/commit/85b9786fd8454ea4bcdfac97b356886bff09e68f))


### Documentation

* **memory:** record in-app verification ([#838](https://github.com/cedricziel/hermes-app/issues/838)) ([6311b39](https://github.com/cedricziel/hermes-app/commit/6311b39687a676c7536cb375d32ebd5561d11a45))
* **openspec:** propose the Bot Screen changes ([#840](https://github.com/cedricziel/hermes-app/issues/840)) ([6f182bd](https://github.com/cedricziel/hermes-app/commit/6f182bde73d95dc9298b0a5c6c7bcd3e18b40126))

## [0.1.71](https://github.com/cedricziel/hermes-app/compare/v0.1.70...v0.1.71) (2026-10-24)


### Features

* **background:** announce messages from Hermes ([#837](https://github.com/cedricziel/hermes-app/issues/837)) ([51026d2](https://github.com/cedricziel/hermes-app/commit/51026d2e2b886aaba580a905a68a0f24f9578711))
* **chat:** add a Yesterday section to the Mac sidebar ([#817](https://github.com/cedricziel/hermes-app/issues/817)) ([2ff0695](https://github.com/cedricziel/hermes-app/commit/2ff0695c7fa720584888afaaf851c7274fe22e4f))
* **chat:** mark opened chats read ([#818](https://github.com/cedricziel/hermes-app/issues/818)) ([f3221d9](https://github.com/cedricziel/hermes-app/commit/f3221d9587ab079526aec5c49eca485c925375bc))
* **chat:** show memory saves, approvals and full memory in the tool card ([#825](https://github.com/cedricziel/hermes-app/issues/825)) ([39337ef](https://github.com/cedricziel/hermes-app/commit/39337efa3a78cda5daaa352a20f30a6f3d3d7613))
* **memory:** add learning settings to the Memory screen ([#830](https://github.com/cedricziel/hermes-app/issues/830)) ([93cca56](https://github.com/cedricziel/hermes-app/commit/93cca56f982b60c28e54c6e3f7e33d82adde488a))
* **memory:** add the waiting-for-you inbox ([#836](https://github.com/cedricziel/hermes-app/issues/836)) ([400dd53](https://github.com/cedricziel/hermes-app/commit/400dd53bc1300f8a8f8fd27b06981c13c97fdcbf))
* **memory:** read and decide pending memory proposals ([#832](https://github.com/cedricziel/hermes-app/issues/832)) ([d9f5cb0](https://github.com/cedricziel/hermes-app/commit/d9f5cb0289753188e73d1a679bda70414766439b))
* **memory:** read entry text and character limits per memory file ([#823](https://github.com/cedricziel/hermes-app/issues/823)) ([862014a](https://github.com/cedricziel/hermes-app/commit/862014a4b1fceb72e0698be16796890e1da13eae))
* **memory:** show memory per file with its fill level ([#824](https://github.com/cedricziel/hermes-app/issues/824)) ([de07deb](https://github.com/cedricziel/hermes-app/commit/de07debd2a0e941cb109220ebeec009354d77416))
* **memory:** show the memory provider and reset memory from the Memory screen ([#831](https://github.com/cedricziel/hermes-app/issues/831)) ([77b58bd](https://github.com/cedricziel/hermes-app/commit/77b58bd951e3d701715c1bf8e10900026cf9a0df))
* **messaging:** add Hermes App messenger plugin ([#804](https://github.com/cedricziel/hermes-app/issues/804)) ([a1279f8](https://github.com/cedricziel/hermes-app/commit/a1279f8ea886262392932744be45f61bc7594571))
* **navigation:** open Memory from the sidebar and the Profiles page ([#826](https://github.com/cedricziel/hermes-app/issues/826)) ([de9783d](https://github.com/cedricziel/hermes-app/commit/de9783df9ad0413fc5ba5a46f754035c135c9d1f))
* **notifications:** add the Messages from Hermes setting ([#833](https://github.com/cedricziel/hermes-app/issues/833)) ([1b5f09e](https://github.com/cedricziel/hermes-app/commit/1b5f09e6c1a4573c9ba0fec22c4a762540f9d017))
* **notifications:** announce messages from Hermes in the app ([#835](https://github.com/cedricziel/hermes-app/issues/835)) ([94eb412](https://github.com/cedricziel/hermes-app/commit/94eb412e8e3fba24c680c547770fc94b528d37af))
* **notifications:** compose notifications for messages from Hermes ([#828](https://github.com/cedricziel/hermes-app/issues/828)) ([5404b36](https://github.com/cedricziel/hermes-app/commit/5404b36f46c116e277a690469e092354188320d2))
* **notifications:** find new messages from Hermes ([#827](https://github.com/cedricziel/hermes-app/issues/827)) ([7aa2055](https://github.com/cedricziel/hermes-app/commit/7aa2055e05b9a7aed257a9d54cfd3c2847214ac2))
* **notifications:** open the chat of a message from Hermes ([#829](https://github.com/cedricziel/hermes-app/issues/829)) ([cd8bab4](https://github.com/cedricziel/hermes-app/commit/cd8bab4ebc4a22dda4332ae77bffd053054f97f3))
* **notifications:** watch for messages from Hermes ([#834](https://github.com/cedricziel/hermes-app/issues/834)) ([4b6e867](https://github.com/cedricziel/hermes-app/commit/4b6e867f5ed330dbb72c533379f58e3ae0915ec5))
* **release:** attach macOS DMG, Android and Windows downloads to releases ([#820](https://github.com/cedricziel/hermes-app/issues/820)) ([0a34d9a](https://github.com/cedricziel/hermes-app/commit/0a34d9a7e75fbb1f50eae9527c9e8400433c711b))


### Bug Fixes

* **auth:** explain untrusted certificates and trust user CAs on Android ([#805](https://github.com/cedricziel/hermes-app/issues/805)) ([e880857](https://github.com/cedricziel/hermes-app/commit/e880857df35c43f2327c39da33a05f5f5faa62ef))
* **chat:** focus the composer of the new chat the app opens on ([#814](https://github.com/cedricziel/hermes-app/issues/814)) ([5a8f196](https://github.com/cedricziel/hermes-app/commit/5a8f19671c8fe98da8f1f226bbf9af52c5abe455))
* **chat:** mark read on every path that opens a chat ([#821](https://github.com/cedricziel/hermes-app/issues/821)) ([d8e33e4](https://github.com/cedricziel/hermes-app/commit/d8e33e464bc786787f09e6ee999d9e8b0c5aa0af))
* **windows:** build the plugins that use the deprecated coroutine header ([#822](https://github.com/cedricziel/hermes-app/issues/822)) ([3ba69c2](https://github.com/cedricziel/hermes-app/commit/3ba69c2572f00773e5d737b580ce90539674dd7b))


### Documentation

* **design:** port the chat Activity panel and cards to the design recreation ([#807](https://github.com/cedricziel/hermes-app/issues/807)) ([2d1bb82](https://github.com/cedricziel/hermes-app/commit/2d1bb82d09466510171c9a725b4bd498f777f098))
* **openspec:** propose agent-messages ([#816](https://github.com/cedricziel/hermes-app/issues/816)) ([b0ebdd2](https://github.com/cedricziel/hermes-app/commit/b0ebdd2b424c0c303b0236924fdea377e3a3c3e4))
* **openspec:** propose memory hub changes ([#819](https://github.com/cedricziel/hermes-app/issues/819)) ([ebe6c8f](https://github.com/cedricziel/hermes-app/commit/ebe6c8fc47cc17308f3ad263bc944caace82628d))
* **skills:** add a release skill ([#808](https://github.com/cedricziel/hermes-app/issues/808)) ([28d2287](https://github.com/cedricziel/hermes-app/commit/28d2287f8e8173bd65777ee6bac5b88229ef1918))

## [0.1.70](https://github.com/cedricziel/hermes-app/compare/v0.1.69...v0.1.70) (2026-10-19)


### Bug Fixes

* **voice:** play Piper and other TTS fallback audio through CallKit ([#802](https://github.com/cedricziel/hermes-app/issues/802)) ([c5c5551](https://github.com/cedricziel/hermes-app/commit/c5c55510467d62a596925a9008b83403fe9689a3))

## [0.1.69](https://github.com/cedricziel/hermes-app/compare/v0.1.68...v0.1.69) (2026-10-18)


### Features

* **voice:** check call prerequisites and offer setup through chat ([#798](https://github.com/cedricziel/hermes-app/issues/798)) ([bd5d4c8](https://github.com/cedricziel/hermes-app/commit/bd5d4c838686cb8c6d55b8a54cbef29fc97eff47))

## [0.1.68](https://github.com/cedricziel/hermes-app/compare/v0.1.67...v0.1.68) (2026-10-18)


### Features

* **chat:** hold Send to record a voice attachment before sending ([#786](https://github.com/cedricziel/hermes-app/issues/786)) ([6c8e396](https://github.com/cedricziel/hermes-app/commit/6c8e396b7fc4ed7b3c59d2d28f8ed7e9d1cc0ed6))
* **ios:** show completed reply previews on system surfaces ([#791](https://github.com/cedricziel/hermes-app/issues/791)) ([0b594c0](https://github.com/cedricziel/hermes-app/commit/0b594c0dc0dfc41badc7375806c453b8cb459a3b))


### Bug Fixes

* **chat:** keep activity and queued messages compact ([#789](https://github.com/cedricziel/hermes-app/issues/789)) ([60eaf82](https://github.com/cedricziel/hermes-app/commit/60eaf82f0e683de6cbe7f22097e62f51b647db17))
* **chat:** move memory recall and review events into the inspector ([#787](https://github.com/cedricziel/hermes-app/issues/787)) ([4b7f491](https://github.com/cedricziel/hermes-app/commit/4b7f49101c6ebed33ac5ad1dc61e6861f1caca84))
* **chat:** resume fresh queues after recovered work is handled ([#793](https://github.com/cedricziel/hermes-app/issues/793)) ([bd4168a](https://github.com/cedricziel/hermes-app/commit/bd4168a5b54e7f1a2c4f00ae0e21b262232e2d34))
* **chat:** show underlying tool names and readable command arguments ([#790](https://github.com/cedricziel/hermes-app/issues/790)) ([684a9f8](https://github.com/cedricziel/hermes-app/commit/684a9f83dd5eca39331a99d7ce42b9a3cf628ae9))

## [0.1.67](https://github.com/cedricziel/hermes-app/compare/v0.1.66...v0.1.67) (2026-10-18)


### Bug Fixes

* **build:** keep Apple audio libraries on Swift Package Manager ([#785](https://github.com/cedricziel/hermes-app/issues/785)) ([e7ed577](https://github.com/cedricziel/hermes-app/commit/e7ed577231342fef6bdb8451b668341f07406af6))
* **iOS:** preview chat photos with native sharing and swipe dismissal ([#783](https://github.com/cedricziel/hermes-app/issues/783)) ([f14c444](https://github.com/cedricziel/hermes-app/commit/f14c4443cd3687d7d046323bf2ec7233d47b5538))

## [0.1.66](https://github.com/cedricziel/hermes-app/compare/v0.1.65...v0.1.66) (2026-10-18)


### Features

* **chat:** add a themed new-chat shortcut to the iPhone list ([#777](https://github.com/cedricziel/hermes-app/issues/777)) ([e4924de](https://github.com/cedricziel/hermes-app/commit/e4924de69bf0083b38e28ff87f014587e6891a74))
* **chat:** play agent voice messages with collapsed transcripts ([#781](https://github.com/cedricziel/hermes-app/issues/781)) ([21e394c](https://github.com/cedricziel/hermes-app/commit/21e394c182078d5d592bb6c9cde0562b7a29af85))
* **iOS:** add native CallKit voice conversations ([#782](https://github.com/cedricziel/hermes-app/issues/782)) ([00ba149](https://github.com/cedricziel/hermes-app/commit/00ba149a93663aed039a608a6ee10c5eea46d112))


### Bug Fixes

* **chat:** dismiss the iOS keyboard when dragging short chats ([#780](https://github.com/cedricziel/hermes-app/issues/780)) ([e2bc241](https://github.com/cedricziel/hermes-app/commit/e2bc2413a5ddc65cd8ff03e204e80e901f28e8d6))
* **chat:** keep thinking expandable during and after streaming ([#778](https://github.com/cedricziel/hermes-app/issues/778)) ([56cd1a7](https://github.com/cedricziel/hermes-app/commit/56cd1a7dbb3a85cd8427fde6178a29e13e26e507))

## [0.1.65](https://github.com/cedricziel/hermes-app/compare/v0.1.64...v0.1.65) (2026-10-16)


### Features

* **chat:** add messenger navigation and selector recovery ([#770](https://github.com/cedricziel/hermes-app/issues/770)) ([da645ce](https://github.com/cedricziel/hermes-app/commit/da645ce63d8c41877f703f397762d2ba1e0e8beb))

## [0.1.64](https://github.com/cedricziel/hermes-app/compare/v0.1.63...v0.1.64) (2026-10-14)


### Features

* **chat:** add the Activity panel ([#769](https://github.com/cedricziel/hermes-app/issues/769)) ([e6593d7](https://github.com/cedricziel/hermes-app/commit/e6593d75415e5c390c95ee45d53500721e629e4e))


### Bug Fixes

* **chat:** draw nothing for empty activity states ([#768](https://github.com/cedricziel/hermes-app/issues/768)) ([a729203](https://github.com/cedricziel/hermes-app/commit/a729203b90cb2c087e65befa1fea3c5bb8fa35ec))


### Documentation

* **design:** sync chat suggestions and task choice previews ([#764](https://github.com/cedricziel/hermes-app/issues/764)) ([cbf6296](https://github.com/cedricziel/hermes-app/commit/cbf6296f7953f8920de161cf450d071829baad99))
* **openspec:** archive 23 completed changes ([#766](https://github.com/cedricziel/hermes-app/issues/766)) ([8bd94eb](https://github.com/cedricziel/hermes-app/commit/8bd94eb02995e3e2ce6a3f72eb5a1f9ab7b8b0a2))
* **openspec:** archive 67 delivered changes ([#767](https://github.com/cedricziel/hermes-app/issues/767)) ([5c73852](https://github.com/cedricziel/hermes-app/commit/5c73852965e509541856831f05049ea171c2d076))

## [0.1.63](https://github.com/cedricziel/hermes-app/compare/v0.1.62...v0.1.63) (2026-10-14)


### Bug Fixes

* **app:** stop the white screen after unlock on iOS and Android ([#762](https://github.com/cedricziel/hermes-app/issues/762)) ([51c99bb](https://github.com/cedricziel/hermes-app/commit/51c99bb6abde5d2e5c38faead4c068844c7277ec))

## [0.1.62](https://github.com/cedricziel/hermes-app/compare/v0.1.61...v0.1.62) (2026-10-14)


### Features

* **app:** refresh visible resources from scoped change hints ([#746](https://github.com/cedricziel/hermes-app/issues/746)) ([2485c54](https://github.com/cedricziel/hermes-app/commit/2485c54a2806d1715e9bf084e0ebf402742bc8a7))
* **auth:** add verified-owner activity suspension ([#683](https://github.com/cedricziel/hermes-app/issues/683)) ([493f569](https://github.com/cedricziel/hermes-app/commit/493f5699929bfe4076ba3cd70fc4bed0a9e0b6a4))
* **chat:** add a renewable session transport boundary ([#679](https://github.com/cedricziel/hermes-app/issues/679)) ([4212472](https://github.com/cedricziel/hermes-app/commit/421247253aa291575bd760697c9f7f78744c599c))
* **chat:** add guarded connector operation controls ([#741](https://github.com/cedricziel/hermes-app/issues/741)) ([0811c4c](https://github.com/cedricziel/hermes-app/commit/0811c4c1b8727515138f73c0d187b870777102f3))
* **chat:** add guarded device verification controls ([#742](https://github.com/cedricziel/hermes-app/issues/742)) ([165aeb2](https://github.com/cedricziel/hermes-app/commit/165aeb2f3df2a0ea4b028f9c13fd4587717f9b48))
* **chat:** add protected durable queue storage ([#723](https://github.com/cedricziel/hermes-app/issues/723)) ([1de2991](https://github.com/cedricziel/hermes-app/commit/1de2991466cc8438963a3168474f62d2bc0edfe6))
* **chat:** add protected queue storage foundation ([#722](https://github.com/cedricziel/hermes-app/issues/722)) ([fc2f2ee](https://github.com/cedricziel/hermes-app/commit/fc2f2eeef329fd4e277f09cf82bb41cb107014cb))
* **chat:** bind live reactions to canonical message receipts ([#743](https://github.com/cedricziel/hermes-app/issues/743)) ([ef00508](https://github.com/cedricziel/hermes-app/commit/ef0050843ad9d641112eed654285d6849abeda61))
* **chat:** broker protected queue storage through the main engine ([#733](https://github.com/cedricziel/hermes-app/issues/733)) ([a740929](https://github.com/cedricziel/hermes-app/commit/a740929a7c2615522b4a8b1719f0e2d87d8a5f53))
* **chat:** coalesce refresh hints within verified scopes ([#740](https://github.com/cedricziel/hermes-app/issues/740)) ([8050a1d](https://github.com/cedricziel/hermes-app/commit/8050a1d44623b6dd21676f1151daf2a8e1fe0bff))
* **chat:** display scoped background and side results ([#731](https://github.com/cedricziel/hermes-app/issues/731)) ([3584d20](https://github.com/cedricziel/hermes-app/commit/3584d208105d3d210f8cbacfe536cb022ea00e36))
* **chat:** expose optional prompt acceptance receipt ([#693](https://github.com/cedricziel/hermes-app/issues/693)) ([721ff3f](https://github.com/cedricziel/hermes-app/commit/721ff3fb3fab6f3c6c0f872b377a4a2b8b323f02))
* **chat:** expose scoped advisor progress ([#736](https://github.com/cedricziel/hermes-app/issues/736)) ([2f9ee37](https://github.com/cedricziel/hermes-app/commit/2f9ee3730bb33860730e8d4b822643dbe2e7ad5c))
* **chat:** model verified connector operation snapshots ([#738](https://github.com/cedricziel/hermes-app/issues/738)) ([1162647](https://github.com/cedricziel/hermes-app/commit/1162647718d12494bfc6b75d34265c9c59f2cc56))
* **chat:** preserve canonical reaction snapshots ([#739](https://github.com/cedricziel/hermes-app/issues/739)) ([d4eac57](https://github.com/cedricziel/hermes-app/commit/d4eac573e0ca72a4107af47eae6d3083ed6d548a))
* **chat:** protect queued prompt submission boundaries ([#730](https://github.com/cedricziel/hermes-app/issues/730)) ([e208ef6](https://github.com/cedricziel/hermes-app/commit/e208ef641d6fae37bfaa2a1f1f196196198931f5))
* **chat:** recover queued prompts for review ([#735](https://github.com/cedricziel/hermes-app/issues/735)) ([5f5f86f](https://github.com/cedricziel/hermes-app/commit/5f5f86f9fc4c780aa28a5dc2f3a2329a0143efd3))
* **chat:** show agent notices and tool output risks ([#702](https://github.com/cedricziel/hermes-app/issues/702)) ([368e001](https://github.com/cedricziel/hermes-app/commit/368e00102cac3bdbecbe2f321729c0f338e08268))
* **chat:** show guarded live connector operations ([#745](https://github.com/cedricziel/hermes-app/issues/745)) ([ff44b92](https://github.com/cedricziel/hermes-app/commit/ff44b9259f8c7068b713c8a0c16d7ff21f2d2577))
* **chat:** show owned agent todo plans ([#729](https://github.com/cedricziel/hermes-app/issues/729)) ([c298768](https://github.com/cedricziel/hermes-app/commit/c298768ac514de9ed7fc3fb2580fcdb35b56f38e))
* **chat:** show protected billing verification ([#747](https://github.com/cedricziel/hermes-app/issues/747)) ([d79a29f](https://github.com/cedricziel/hermes-app/commit/d79a29f24e09d797fb872b576709241f7bef2ce8))
* **chat:** show scoped background process output ([#732](https://github.com/cedricziel/hermes-app/issues/732)) ([747eeb9](https://github.com/cedricziel/hermes-app/commit/747eeb9be2584c689d358cc16b329c04023147de))
* **chat:** show scoped session usage ([#727](https://github.com/cedricziel/hermes-app/issues/727)) ([8db3412](https://github.com/cedricziel/hermes-app/commit/8db34122e37273f91bec136b2f6c2e0848e24a81))
* **chat:** show session progress and reclaim recovery ([#721](https://github.com/cedricziel/hermes-app/issues/721)) ([b850a6b](https://github.com/cedricziel/hermes-app/commit/b850a6b03c087afde2119a5ce6edf216cf04886c))
* **gateway:** fence connection events and operation dispatch ([#737](https://github.com/cedricziel/hermes-app/issues/737)) ([98c14f2](https://github.com/cedricziel/hermes-app/commit/98c14f279e467bd8a87d2c0d7e0654aecb236b71))
* **memory:** edit and delete learned memories ([#725](https://github.com/cedricziel/hermes-app/issues/725)) ([9b8b71a](https://github.com/cedricziel/hermes-app/commit/9b8b71a4775d20b1cb29204ed2ab5fb37bb9640b))
* **memory:** inspect learned memories by profile ([#724](https://github.com/cedricziel/hermes-app/issues/724)) ([c9215e4](https://github.com/cedricziel/hermes-app/commit/c9215e4830dd3431ffe19e21c2f81dd109ebd973))
* **navigation:** add guarded desktop workers history ([#699](https://github.com/cedricziel/hermes-app/issues/699)) ([95dc4fc](https://github.com/cedricziel/hermes-app/commit/95dc4fc2b804a6d0c28f1af0f0e3881c349c276f))
* **notifications:** show mobile background check status ([#726](https://github.com/cedricziel/hermes-app/issues/726)) ([1fd3a0b](https://github.com/cedricziel/hermes-app/commit/1fd3a0b6cfc8e6c3aa413e70dda8f866fd6cc588))
* **watch:** activate durable send recovery across phone restarts ([#707](https://github.com/cedricziel/hermes-app/issues/707)) ([89a76d3](https://github.com/cedricziel/hermes-app/commit/89a76d3891c4d35d87a65e7feaf4dd3f2f966d77))
* **watch:** add protected owner context and scoped thread IDs ([#689](https://github.com/cedricziel/hermes-app/issues/689)) ([6157386](https://github.com/cedricziel/hermes-app/commit/61573868b3a179fd2b84438eaf967c6b83c7e31e))
* **watch:** add scoped request review models ([#712](https://github.com/cedricziel/hermes-app/issues/712)) ([fb71a31](https://github.com/cedricziel/hermes-app/commit/fb71a31bfb45ada02b96f0b1deff07a888eda8f0))
* **watch:** add transient structured request helper ([#713](https://github.com/cedricziel/hermes-app/issues/713)) ([53e7d33](https://github.com/cedricziel/hermes-app/commit/53e7d3329be45d9ec2cd5477d5ba479776944d4c))
* **watch:** answer approvals and questions inline ([#714](https://github.com/cedricziel/hermes-app/issues/714)) ([1a83619](https://github.com/cedricziel/hermes-app/commit/1a8361969e7a835ced7703b7327a89ea5bac0346))
* **watch:** clarify request waiting and phone answer paths ([#710](https://github.com/cedricziel/hermes-app/issues/710)) ([0da5e44](https://github.com/cedricziel/hermes-app/commit/0da5e44dc65532f91af2352f00c850e6c1b424b4))
* **watch:** offer editable starters and relevant follow-ups ([#718](https://github.com/cedricziel/hermes-app/issues/718)) ([3a4b0a2](https://github.com/cedricziel/hermes-app/commit/3a4b0a21d77daa1c4eced68a49d1b0c53e7bf9d6))
* **watch:** persist chat freshness atomically ([#715](https://github.com/cedricziel/hermes-app/issues/715)) ([ec7b5b1](https://github.com/cedricziel/hermes-app/commit/ec7b5b193545b2e3bdcf113139fea34060bf6c41))
* **watch:** persist scoped send evidence before dispatch ([#691](https://github.com/cedricziel/hermes-app/issues/691)) ([477f4d2](https://github.com/cedricziel/hermes-app/commit/477f4d245765d3b9fe32a9d0c03afd2030ff39a3))
* **watch:** preserve conversation reading and delivery evidence ([#709](https://github.com/cedricziel/hermes-app/issues/709)) ([3472642](https://github.com/cedricziel/hermes-app/commit/347264255ae329e35397a1f710df2fe89fdc52fe))
* **watch:** retain pending sends in protected local storage ([#694](https://github.com/cedricziel/hermes-app/issues/694)) ([0961169](https://github.com/cedricziel/hermes-app/commit/0961169ef89ed7c13a9290c5f140185e4ea895dd))
* **watch:** review voice transcripts before sending ([#708](https://github.com/cedricziel/hermes-app/issues/708)) ([7c6bd2c](https://github.com/cedricziel/hermes-app/commit/7c6bd2c742357c5d4e416fd582eb8f61f42813fd))
* **watch:** scope relay and private state to verified owners ([#706](https://github.com/cedricziel/hermes-app/issues/706)) ([0ae175d](https://github.com/cedricziel/hermes-app/commit/0ae175d187292b0cd342f089e7fb9baef1851bf2))
* **watch:** show chat profiles status and freshness ([#717](https://github.com/cedricziel/hermes-app/issues/717)) ([9cca0f5](https://github.com/cedricziel/hermes-app/commit/9cca0f529aad801c696186309ccb03366c06898d))
* **watch:** track freshly read chat updates ([#716](https://github.com/cedricziel/hermes-app/issues/716)) ([63c7e80](https://github.com/cedricziel/hermes-app/commit/63c7e80eba4cf3e6eca822e22e303a7ea627fc2b))
* **windows:** coordinate scoped queue access with the main engine ([#734](https://github.com/cedricziel/hermes-app/issues/734)) ([1b0c5e6](https://github.com/cedricziel/hermes-app/commit/1b0c5e605084a69357017dd6b81e4fde005abfd3))


### Bug Fixes

* **chat:** keep sidebar usable in short Mac windows ([#756](https://github.com/cedricziel/hermes-app/issues/756)) ([8264189](https://github.com/cedricziel/hermes-app/commit/82641896032c1b150a391c1ce0c45d84579c1893))
* **chat:** retire activity state after listener delivery ([#744](https://github.com/cedricziel/hermes-app/issues/744)) ([9a98932](https://github.com/cedricziel/hermes-app/commit/9a98932f85b777ba6c83f867a1d919412644579d))
* **chat:** suspend controller work with session activity ([#692](https://github.com/cedricziel/hermes-app/issues/692)) ([d5df2dc](https://github.com/cedricziel/hermes-app/commit/d5df2dcc0623046d7d86f1ccb51a5d142d648e0e))
* **dialogs:** use restrained macOS modal presentation ([#674](https://github.com/cedricziel/hermes-app/issues/674)) ([541433f](https://github.com/cedricziel/hermes-app/commit/541433f2b9335813747ebd0b1e6492ce1a96938e))
* **kanban:** ignore action errors after caller disposal ([#677](https://github.com/cedricziel/hermes-app/issues/677)) ([8afacae](https://github.com/cedricziel/hermes-app/commit/8afacaee1960ec90831d53d9ebeb44f4f94f84cb))
* **kanban:** suspend board work with session activity ([#690](https://github.com/cedricziel/hermes-app/issues/690)) ([1011b79](https://github.com/cedricziel/hermes-app/commit/1011b79a01572d1815d37aa4eb6b65d1bb9d7d2b))
* **mcp:** use desktop dialog for catalog installs ([#697](https://github.com/cedricziel/hermes-app/issues/697)) ([851116a](https://github.com/cedricziel/hermes-app/commit/851116a8c851a024371ea7e9d1e90c9d5e9ff069))
* **navigation:** guard bot chat handoffs ([#705](https://github.com/cedricziel/hermes-app/issues/705)) ([493cc42](https://github.com/cedricziel/hermes-app/commit/493cc42a686ed2606992891620d1a533ae7572d1))
* **navigation:** guard chat handoffs and queued session authorization ([#680](https://github.com/cedricziel/hermes-app/issues/680)) ([4f264a9](https://github.com/cedricziel/hermes-app/commit/4f264a9bacbe9f233e8d7ca2e9eaf73159606897))
* **notifications:** retry unaccepted background request alerts ([#688](https://github.com/cedricziel/hermes-app/issues/688)) ([252d775](https://github.com/cedricziel/hermes-app/commit/252d7756ed377bee97ee7d4f34a60081b894a46a))
* **notifications:** suspend announcements with session activity ([#695](https://github.com/cedricziel/hermes-app/issues/695)) ([b10107c](https://github.com/cedricziel/hermes-app/commit/b10107c268b9ddaaf10159cd2aa60c0af275b837))
* **plugins:** use desktop dialogs for compact Mac details ([#687](https://github.com/cedricziel/hermes-app/issues/687)) ([1355a62](https://github.com/cedricziel/hermes-app/commit/1355a628b4c432410e616ba3fbdd98adcb0f3f8c))
* **schedules:** suspend alerts with session authorization ([#684](https://github.com/cedricziel/hermes-app/issues/684)) ([de34e07](https://github.com/cedricziel/hermes-app/commit/de34e0751a3a62fc61ab360f8f0905856c2ab319))
* **schedules:** suspend protected page activity ([#700](https://github.com/cedricziel/hermes-app/issues/700)) ([6dad897](https://github.com/cedricziel/hermes-app/commit/6dad89775c3df76de926abe7cb19ebcf5b6a24c4))
* **schedules:** suspend protected schedule form activity ([#704](https://github.com/cedricziel/hermes-app/issues/704)) ([045592c](https://github.com/cedricziel/hermes-app/commit/045592c7eb690e04188f9c0e42475a8769d160fc))
* **shell:** keep navigation reachable in short windows ([#759](https://github.com/cedricziel/hermes-app/issues/759)) ([96a717e](https://github.com/cedricziel/hermes-app/commit/96a717e72abeffa7381a204c740c0120f60f412a))
* **skills:** present job status as desktop dialogs on macOS ([#676](https://github.com/cedricziel/hermes-app/issues/676)) ([08a9589](https://github.com/cedricziel/hermes-app/commit/08a9589135da5be9e14bc40f9ac69a1a3cee2fda))
* **surfaces:** bound partial snapshot builds ([#665](https://github.com/cedricziel/hermes-app/issues/665)) ([60160e8](https://github.com/cedricziel/hermes-app/commit/60160e838a2a2f82542b4f6477f76e2f8771dbcd))
* **tooling:** preserve client dependencies during regeneration ([#728](https://github.com/cedricziel/hermes-app/issues/728)) ([d27f056](https://github.com/cedricziel/hermes-app/commit/d27f05678bbf55487493e493614b03952358ecb5))
* **voice:** suspend dictation with session activity ([#685](https://github.com/cedricziel/hermes-app/issues/685)) ([496f5be](https://github.com/cedricziel/hermes-app/commit/496f5beefabd27eb9421be9b09ce0b596c496312))
* **watch:** allowlist persisted relay diagnostics ([#711](https://github.com/cedricziel/hermes-app/issues/711)) ([5eb1265](https://github.com/cedricziel/hermes-app/commit/5eb1265c3708c03b430a2c697f745061bfea060d))
* **watch:** authorize replies and secure session publication ([#696](https://github.com/cedricziel/hermes-app/issues/696)) ([c726925](https://github.com/cedricziel/hermes-app/commit/c726925f5cfa90427366baa163e558c8f5e03bb5))
* **watch:** clear private state across session departures ([#698](https://github.com/cedricziel/hermes-app/issues/698)) ([2c4edd6](https://github.com/cedricziel/hermes-app/commit/2c4edd6aad728c83365a1a6ce9a512c1dda45e8c))
* **watch:** ignore replies from stopped send attempts ([#686](https://github.com/cedricziel/hermes-app/issues/686)) ([0f03592](https://github.com/cedricziel/hermes-app/commit/0f03592d0293bc6353f1884cacab82143b1c1913))
* **windows:** bind auxiliary windows to verified session owners ([#670](https://github.com/cedricziel/hermes-app/issues/670)) ([021272a](https://github.com/cedricziel/hermes-app/commit/021272aff60e726dd2ed44fe21b2d3af98ffbb1f))
* **windows:** fence native inventory and close failures ([#672](https://github.com/cedricziel/hermes-app/issues/672)) ([b67e443](https://github.com/cedricziel/hermes-app/commit/b67e443dea4170f77070d8f93551c68e09a2086c))


### Documentation

* **agent:** record gap delivery and verification limits ([#749](https://github.com/cedricziel/hermes-app/issues/749)) ([aff975c](https://github.com/cedricziel/hermes-app/commit/aff975cb81638b407fb26b63b6d4edbfb08dfe9a))
* **navigation:** close merged sharing and session specifications ([#671](https://github.com/cedricziel/hermes-app/issues/671)) ([495a2ba](https://github.com/cedricziel/hermes-app/commit/495a2ba7442339d7c9ec3ddfafa132c997265281))
* **navigation:** reconcile completed adaptive components ([#675](https://github.com/cedricziel/hermes-app/issues/675)) ([9949837](https://github.com/cedricziel/hermes-app/commit/9949837adebac1e666a411855529576c5c6d24ba))
* **navigation:** reconcile merged activity and modal changes ([#701](https://github.com/cedricziel/hermes-app/issues/701)) ([def3a69](https://github.com/cedricziel/hermes-app/commit/def3a69e06b567e8a0530b8645fb1a634cb893d4))
* **navigation:** sync merged window and modal requirements ([#678](https://github.com/cedricziel/hermes-app/issues/678)) ([3b14c05](https://github.com/cedricziel/hermes-app/commit/3b14c05cfb270410e1cafbe06c01909c7506a03e))
* record bounded authenticated app verification ([#760](https://github.com/cedricziel/hermes-app/issues/760)) ([144d5c1](https://github.com/cedricziel/hermes-app/commit/144d5c1734a8d52b8ee5e97446f04d30de82424d))
* **spec:** add stale menu pick scenario ([#751](https://github.com/cedricziel/hermes-app/issues/751)) ([ffc32d7](https://github.com/cedricziel/hermes-app/commit/ffc32d7fa9c389a24475eb36eaa19d7bf18f9630))
* **spec:** reconcile advisory verification evidence ([#754](https://github.com/cedricziel/hermes-app/issues/754)) ([ab35880](https://github.com/cedricziel/hermes-app/commit/ab358804cc517cc9245579eed216df1c762ecc35))
* **spec:** reconcile shipped invalidation tasks ([#752](https://github.com/cedricziel/hermes-app/issues/752)) ([4a717ef](https://github.com/cedricziel/hermes-app/commit/4a717ef883ca1f6d7e8661275171c018859127f1))
* **specs:** archive completed plugin and MCP modal changes ([#703](https://github.com/cedricziel/hermes-app/issues/703)) ([e282933](https://github.com/cedricziel/hermes-app/commit/e2829331d7965749eb401c1534454c5899cb1ac3))
* **verification:** require isolated macOS client state ([#668](https://github.com/cedricziel/hermes-app/issues/668)) ([3cd5ac9](https://github.com/cedricziel/hermes-app/commit/3cd5ac9674924425b83ccf28a01fdc27f845cf9d))
* **verify:** document scoped asynchronous regression checks ([#748](https://github.com/cedricziel/hermes-app/issues/748)) ([669faa7](https://github.com/cedricziel/hermes-app/commit/669faa7aff3b821f5a572635ce4d2e747c3938c0))
* **verify:** require authenticated isolated native readiness ([#758](https://github.com/cedricziel/hermes-app/issues/758)) ([482bc8e](https://github.com/cedricziel/hermes-app/commit/482bc8e4397a67dc3106446009cb622fd286fa91))
* **watch:** reconcile staged specs and verification evidence ([#720](https://github.com/cedricziel/hermes-app/issues/720)) ([4a357af](https://github.com/cedricziel/hermes-app/commit/4a357af5c6342979431001952e4527c3206c4894))

## [0.1.61](https://github.com/cedricziel/hermes-app/compare/v0.1.60...v0.1.61) (2026-10-12)


### Features

* **chat:** adapt teammate and command suggestions ([#662](https://github.com/cedricziel/hermes-app/issues/662)) ([8dbd966](https://github.com/cedricziel/hermes-app/commit/8dbd9669db127f2bf851dfb78bf7a5cad8d2a6c9))
* **connection:** align setup and details screens ([#661](https://github.com/cedricziel/hermes-app/issues/661)) ([852dcb4](https://github.com/cedricziel/hermes-app/commit/852dcb4d188d0981e4b5820157d2844b987b4881))


### Bug Fixes

* **app-store:** refresh the listing for 0.1.61 ([#658](https://github.com/cedricziel/hermes-app/issues/658)) ([f7f9245](https://github.com/cedricziel/hermes-app/commit/f7f92457f17899941acb6e8926b00a534fac6e2c))
* **auth:** bind protected clients to verified session lifetimes ([#659](https://github.com/cedricziel/hermes-app/issues/659)) ([9f50ea7](https://github.com/cedricziel/hermes-app/commit/9f50ea74e81a036b33742daa715f1760304600db))
* **chat:** refetch a thread after a turn another client streamed ends ([#663](https://github.com/cedricziel/hermes-app/issues/663)) ([22fc12a](https://github.com/cedricziel/hermes-app/commit/22fc12afc88816560408fe7319b416612ac36a02))
* **navigation:** guard warm and launch notification delivery ([#653](https://github.com/cedricziel/hermes-app/issues/653)) ([090151d](https://github.com/cedricziel/hermes-app/commit/090151d6099b0cf81fc44e62a465a298fd7b6f3b))
* **navigation:** preserve guarded editors during deep links ([#646](https://github.com/cedricziel/hermes-app/issues/646)) ([ce5d604](https://github.com/cedricziel/hermes-app/commit/ce5d604307389a9ae40b186d64dda45dc4f51160))
* **navigation:** retain guarded shares until safe Chat entry ([#657](https://github.com/cedricziel/hermes-app/issues/657)) ([fb8a301](https://github.com/cedricziel/hermes-app/commit/fb8a301c03d6bb046a231783709ebc230188d763))
* **navigation:** use restrained macOS page transitions ([#654](https://github.com/cedricziel/hermes-app/issues/654)) ([aa5c1f8](https://github.com/cedricziel/hermes-app/commit/aa5c1f86bddee804c1b57c069db7e5e4cdd7eb8f))
* **screenshots:** finalize the 0.1.61 task captures ([#666](https://github.com/cedricziel/hermes-app/issues/666)) ([7d191df](https://github.com/cedricziel/hermes-app/commit/7d191dfbc1b36113ef1d02e30603821de9b4d405))


### Documentation

* **navigation:** close merged notification and page policies ([#656](https://github.com/cedricziel/hermes-app/issues/656)) ([d28c30f](https://github.com/cedricziel/hermes-app/commit/d28c30f4aa955bb0442aecba2760da0a28b3ea73))
* **navigation:** publish backlog and completed guard spec ([#651](https://github.com/cedricziel/hermes-app/issues/651)) ([c65b117](https://github.com/cedricziel/hermes-app/commit/c65b117e346af91eb57a4a05ea5cf8951ea75a71))
* **ui:** complete adaptive UI series tracking ([#664](https://github.com/cedricziel/hermes-app/issues/664)) ([5605946](https://github.com/cedricziel/hermes-app/commit/5605946731f73e0a719e3b0f88acdb84a04e10a2))

## [0.1.60](https://github.com/cedricziel/hermes-app/compare/v0.1.59...v0.1.60) (2026-10-11)


### Features

* **bots:** simplify adaptive bot creation ([#627](https://github.com/cedricziel/hermes-app/issues/627)) ([b7c93e5](https://github.com/cedricziel/hermes-app/commit/b7c93e5351e228c4f5c96573a13f9477e0ae5cbe))
* **spotlight:** enable recent chat indexing on Apple platforms ([#634](https://github.com/cedricziel/hermes-app/issues/634)) ([e46f6e7](https://github.com/cedricziel/hermes-app/commit/e46f6e79c433555a4a2ac2b5de991c40a2af07a5))


### Bug Fixes

* **bots:** align management forms with grouped settings ([#629](https://github.com/cedricziel/hermes-app/issues/629)) ([3f8df15](https://github.com/cedricziel/hermes-app/commit/3f8df156f5f50459b74eeb440fa9049104c6922f))
* **kanban:** align forms with grouped settings ([#632](https://github.com/cedricziel/hermes-app/issues/632)) ([96ca04c](https://github.com/cedricziel/hermes-app/commit/96ca04ceb05f8342d503289bbc141c939b0c0416))
* **mcp:** keep the catalog after install sheet dismissal ([#639](https://github.com/cedricziel/hermes-app/issues/639)) ([0e9af39](https://github.com/cedricziel/hermes-app/commit/0e9af3954d1f9fe161d42d412a9b49b01caded3e))
* **navigation:** dismiss only the originating route on completion ([#641](https://github.com/cedricziel/hermes-app/issues/641)) ([526164d](https://github.com/cedricziel/hermes-app/commit/526164ddbdf7eab7890f931c439a3bfbede9adc7))
* **notifications:** strip Markdown from notification previews ([#638](https://github.com/cedricziel/hermes-app/issues/638)) ([4507640](https://github.com/cedricziel/hermes-app/commit/4507640e334d14e0da337b207abb1d33e3079621))
* **plugins:** keep the list after dismissing details ([#635](https://github.com/cedricziel/hermes-app/issues/635)) ([b21688f](https://github.com/cedricziel/hermes-app/commit/b21688f1a0606c2af3f3a0b597fa7d078dc26027))
* **plugins:** use grouped Git installation form ([#631](https://github.com/cedricziel/hermes-app/issues/631)) ([b21d1b5](https://github.com/cedricziel/hermes-app/commit/b21d1b509745ca44bf0f90dd76e78f62ea6fe199))
* **profiles:** use grouped creation form ([#630](https://github.com/cedricziel/hermes-app/issues/630)) ([7f6f3a5](https://github.com/cedricziel/hermes-app/commit/7f6f3a5e69326d8801875e81e2c7da0dabbe9e78))
* **schedules:** avoid closing the list during detail dismissal ([#637](https://github.com/cedricziel/hermes-app/issues/637)) ([de4598c](https://github.com/cedricziel/hermes-app/commit/de4598c1cb268be62ad11cd08d8d6a77cb41cc21))


### Documentation

* **forms:** finalize grouped form verification ([#633](https://github.com/cedricziel/hermes-app/issues/633)) ([57363c8](https://github.com/cedricziel/hermes-app/commit/57363c8a4686b1ff42c5c7be791f95d4e64e10b4))

## [0.1.59](https://github.com/cedricziel/hermes-app/compare/v0.1.58...v0.1.59) (2026-10-11)


### Features

* **background:** update the badge and Siri's chat list in the background ([#624](https://github.com/cedricziel/hermes-app/issues/624)) ([f95acdf](https://github.com/cedricziel/hermes-app/commit/f95acdf8bcef67a7d2a214e3848da9cd90bb2bcd))
* **ios:** answer Ask Hermes from Siri and Shortcuts in place ([#622](https://github.com/cedricziel/hermes-app/issues/622)) ([cf8e55d](https://github.com/cedricziel/hermes-app/commit/cf8e55dd7bfde7fd0c2c9ee2149695faf205d701))
* **ios:** list pending requests and answer approvals from Siri and Shortcuts ([#623](https://github.com/cedricziel/hermes-app/issues/623)) ([eb2caf0](https://github.com/cedricziel/hermes-app/commit/eb2caf0193cc7e48e171b51059e2dc5453403a7c))


### Bug Fixes

* small follow-ups from the iOS surfaces reviews ([#625](https://github.com/cedricziel/hermes-app/issues/625)) ([321cf15](https://github.com/cedricziel/hermes-app/commit/321cf15c542fa73714efed37f59d3cc5f2f87119))

## [0.1.58](https://github.com/cedricziel/hermes-app/compare/v0.1.57...v0.1.58) (2026-10-11)


### Features

* **app:** add app icon quick actions ([#611](https://github.com/cedricziel/hermes-app/issues/611)) ([b59326b](https://github.com/cedricziel/hermes-app/commit/b59326b174e181eedc64967f212771f9df4d689b))
* **background:** announce finished replies and scheduled runs in the background ([#620](https://github.com/cedricziel/hermes-app/issues/620)) ([c9dc876](https://github.com/cedricziel/hermes-app/commit/c9dc876bcc44b9a6ec85b90fa5273ff46a42726f))
* **background:** refresh requests and the snapshot in the background ([#614](https://github.com/cedricziel/hermes-app/issues/614)) ([875f6d2](https://github.com/cedricziel/hermes-app/commit/875f6d2484a934886618cf7280f049e20cbb2545))
* **background:** run Hermes work without a screen ([#605](https://github.com/cedricziel/hermes-app/issues/605)) ([69729e2](https://github.com/cedricziel/hermes-app/commit/69729e2171c3c29b0e409175f09403e395b48dfe))
* **chat:** drag message text and chats out of the Mac app ([#600](https://github.com/cedricziel/hermes-app/issues/600)) ([84875d9](https://github.com/cedricziel/hermes-app/commit/84875d94037587dd1e4d1bd8170e3d2fe2c91e8b))
* **chat:** keep Connection details in the wide chat header ([#583](https://github.com/cedricziel/hermes-app/issues/583)) ([1e89c45](https://github.com/cedricziel/hermes-app/commit/1e89c456a7943cb79c8cc84a6b89976d51196983))
* **chat:** put New Chat in the header's top-right corner ([#581](https://github.com/cedricziel/hermes-app/issues/581)) ([9ac974e](https://github.com/cedricziel/hermes-app/commit/9ac974e725056fd3fb900e14f27225c1430cc8a5))
* **chat:** show retry and edit progress and failures on the reply ([#574](https://github.com/cedricziel/hermes-app/issues/574)) ([5351e9c](https://github.com/cedricziel/hermes-app/commit/5351e9cda8e0e5abe85d006ee3e44753a84c4caa))
* **deep-links:** open hermes:// links ([#607](https://github.com/cedricziel/hermes-app/issues/607)) ([29f7a1e](https://github.com/cedricziel/hermes-app/commit/29f7a1e41ee9d659c733968fd9df4f5553151aa4))
* **ios:** add Hermes commands to the iPad menu bar ([#609](https://github.com/cedricziel/hermes-app/issues/609)) ([033fe1c](https://github.com/cedricziel/hermes-app/commit/033fe1c437f453c1b575a64a55c2ed965e11c458))
* **ios:** add Lock Screen and StandBy widgets ([#616](https://github.com/cedricziel/hermes-app/issues/616)) ([052822f](https://github.com/cedricziel/hermes-app/commit/052822f0e064ed92aa7b6a6408eaf399280a8f31))
* **ios:** add Recent chats, Needs you and Board widgets ([#613](https://github.com/cedricziel/hermes-app/issues/613)) ([181bf85](https://github.com/cedricziel/hermes-app/commit/181bf85abe2bcfc7ecaf5bf31caa126f1643f798))
* **ios:** open chats, new chats and dictation from Siri, Shortcuts and controls ([#617](https://github.com/cedricziel/hermes-app/issues/617)) ([4d0aee4](https://github.com/cedricziel/hermes-app/commit/4d0aee43aa6efe88afe27739a279dcddb7a82675))
* **ios:** show a running reply on the watch Smart Stack ([#586](https://github.com/cedricziel/hermes-app/issues/586)) ([0a4a4e5](https://github.com/cedricziel/hermes-app/commit/0a4a4e540e7986a34f659fa49c7d4941a5548f23))
* **macos:** add Ask Hermes to the Services menu ([#591](https://github.com/cedricziel/hermes-app/issues/591)) ([454a1bf](https://github.com/cedricziel/hermes-app/commit/454a1bf7e370f7690dc7ac73b1a1facf4a23fe1c))
* **macos:** add New Chat and recent chats to the Dock menu ([#596](https://github.com/cedricziel/hermes-app/issues/596)) ([936c55a](https://github.com/cedricziel/hermes-app/commit/936c55a90513341ea6535a46d2bebc803bc8ecb7))
* **macos:** chat in the quick panel ([#597](https://github.com/cedricziel/hermes-app/issues/597)) ([a858b19](https://github.com/cedricziel/hermes-app/commit/a858b19e23d06b4cb0952d5bca87d7c1e6442cf9))
* **macos:** drag attachments out as files ([#594](https://github.com/cedricziel/hermes-app/issues/594)) ([315c9b7](https://github.com/cedricziel/hermes-app/commit/315c9b74e7e1499efcc3e7bc309b2cc5a7998f98))
* **macos:** keep running after the last window closes ([#590](https://github.com/cedricziel/hermes-app/issues/590)) ([93fb946](https://github.com/cedricziel/hermes-app/commit/93fb9467ca9907101f3eea2b4333d3d8c9356a07))
* **macos:** open a quick panel with a global shortcut ([#592](https://github.com/cedricziel/hermes-app/issues/592)) ([c6cf7e7](https://github.com/cedricziel/hermes-app/commit/c6cf7e7249f4e861c1a75e098f5fe5081d209ff4))
* **macos:** preview attachments with Quick Look ([#602](https://github.com/cedricziel/hermes-app/issues/602)) ([99ab4bb](https://github.com/cedricziel/hermes-app/commit/99ab4bb6deb0cca5b0bf133ee14e9617256dbc65))
* **macos:** show running replies and approvals in the menu bar ([#595](https://github.com/cedricziel/hermes-app/issues/595)) ([445b71b](https://github.com/cedricziel/hermes-app/commit/445b71b1b8b784bf7922e20e5eb6d28903650ab4))
* **notifications:** answer approvals and questions from the notification ([#587](https://github.com/cedricziel/hermes-app/issues/587)) ([033a2f7](https://github.com/cedricziel/hermes-app/commit/033a2f7a715ebd38e9df6e773e1067cbb72a3155))
* **notifications:** group per chat, time-sensitive requests, badge open requests ([#615](https://github.com/cedricziel/hermes-app/issues/615)) ([734b681](https://github.com/cedricziel/hermes-app/commit/734b6810d6899ea7eb35e3219fe6a542df17d3a9))
* **spotlight:** index recent chats in Spotlight on iOS ([#612](https://github.com/cedricziel/hermes-app/issues/612)) ([13a3d93](https://github.com/cedricziel/hermes-app/commit/13a3d93729bdc913c6780c336bd6de2cfcd7e340))
* **spotlight:** refresh the index in the background run ([#621](https://github.com/cedricziel/hermes-app/issues/621)) ([e8067d1](https://github.com/cedricziel/hermes-app/commit/e8067d1b73c7534646ccf1e6a59a0ba8142fe089))
* **surfaces:** keep a snapshot for widgets and system surfaces ([#604](https://github.com/cedricziel/hermes-app/issues/604)) ([7857ff0](https://github.com/cedricziel/hermes-app/commit/7857ff08b8e422bfaf71bdcffc3e1b3ecaeb39fc))
* **telemetry:** log the step a chat send failed at ([#576](https://github.com/cedricziel/hermes-app/issues/576)) ([0b7030e](https://github.com/cedricziel/hermes-app/commit/0b7030e897f19cd6aceb739fcba0d64a3b7af1af))
* **watch:** add complications and a Smart Stack widget ([#599](https://github.com/cedricziel/hermes-app/issues/599)) ([1649d85](https://github.com/cedricziel/hermes-app/commit/1649d85b16829a2c7eeb4307031d58de425c2396))
* **watch:** add quick replies and double tap to a chat ([#585](https://github.com/cedricziel/hermes-app/issues/585)) ([caecc19](https://github.com/cedricziel/hermes-app/commit/caecc19b2c16282fd9b327309a978a73852e6126))
* **watch:** hand a watch chat off to the iPhone or Mac ([#593](https://github.com/cedricziel/hermes-app/issues/593)) ([a0216a6](https://github.com/cedricziel/hermes-app/commit/a0216a63d2f4de877c1018db6b0afa16e2946f99))
* **watch:** render replies as Markdown and show what Hermes used ([#582](https://github.com/cedricziel/hermes-app/issues/582)) ([25617d1](https://github.com/cedricziel/hermes-app/commit/25617d1b9387137273c92bae2ef6dc4c4f962ce9))
* **watch:** show saved chats at once and report requests that never reached the phone ([#584](https://github.com/cedricziel/hermes-app/issues/584)) ([4d9187a](https://github.com/cedricziel/hermes-app/commit/4d9187af52b6d6aade0c18f5216ed93e2c515bb3))
* **watch:** transcribe voice messages on the phone ([#573](https://github.com/cedricziel/hermes-app/issues/573)) ([fc94472](https://github.com/cedricziel/hermes-app/commit/fc94472fb60a8ac6c6e89386997cabf6bf23ff12))


### Bug Fixes

* **app-lock:** hide content as soon as the app goes inactive on phones ([#570](https://github.com/cedricziel/hermes-app/issues/570)) ([8e20745](https://github.com/cedricziel/hermes-app/commit/8e20745d2586e3c713ecc498bf36ab0ec0d62f5f))
* **chat:** retry a send whose socket or session would not open ([#579](https://github.com/cedricziel/hermes-app/issues/579)) ([80917c3](https://github.com/cedricziel/hermes-app/commit/80917c3393c672db739b6ba2a28d8b7aa08e780c))
* **chat:** retry on a gateway that predates the undo intent ([#569](https://github.com/cedricziel/hermes-app/issues/569)) ([20ba846](https://github.com/cedricziel/hermes-app/commit/20ba846283086309e86cf563b54d7f7a70a2d1f0))
* **chat:** say plainly why Try again or Edit failed ([#572](https://github.com/cedricziel/hermes-app/issues/572)) ([c4e3f87](https://github.com/cedricziel/hermes-app/commit/c4e3f87102e6d4e60d8503bbbffb07becd5873f4))
* **live-activity:** end every turn it shows and ignore the turn ahead of a prompt ([#610](https://github.com/cedricziel/hermes-app/issues/610)) ([87fc8b1](https://github.com/cedricziel/hermes-app/commit/87fc8b1cb9461e224ba7f323dc9f4c6ef4e221df))
* **live-activity:** say Open Hermes on a stale watch Smart Stack card ([#598](https://github.com/cedricziel/hermes-app/issues/598)) ([a17b318](https://github.com/cedricziel/hermes-app/commit/a17b3186173ef0a0b9d52ed925e8b4ae81328de3))
* **notifications:** harden answering requests from notifications ([#589](https://github.com/cedricziel/hermes-app/issues/589)) ([8fb69c1](https://github.com/cedricziel/hermes-app/commit/8fb69c10a3ef86d965c97f536ceda7aac141ecad))
* **surfaces:** address review findings on the surface snapshot ([#608](https://github.com/cedricziel/hermes-app/issues/608)) ([ff06db0](https://github.com/cedricziel/hermes-app/commit/ff06db00f8175e88e4df824d8b22a94924efe650))
* **watch:** give a watch voice message as long to transcribe as dictation ([#580](https://github.com/cedricziel/hermes-app/issues/580)) ([b58575b](https://github.com/cedricziel/hermes-app/commit/b58575b65b715aaf349203846219226d027d4a1b))
* **watch:** keep a watch chat working after a profile switch ([#578](https://github.com/cedricziel/hermes-app/issues/578)) ([bbe4134](https://github.com/cedricziel/hermes-app/commit/bbe413411112163399ed9cd9e8c601a549d309cd))
* **watch:** never send a retried watch message twice ([#577](https://github.com/cedricziel/hermes-app/issues/577)) ([ef60ad8](https://github.com/cedricziel/hermes-app/commit/ef60ad825bc5420e843f3a2121445c34639baad8))
* **watch:** show what a turn that used tools said ([#575](https://github.com/cedricziel/hermes-app/issues/575)) ([0792d47](https://github.com/cedricziel/hermes-app/commit/0792d471c30be1add916c894270df4b1bea2a5d0))


### Documentation

* **openspec:** propose iOS system surfaces ([#601](https://github.com/cedricziel/hermes-app/issues/601)) ([5d59d1a](https://github.com/cedricziel/hermes-app/commit/5d59d1ab09e48932b549b7bed3f12dd1928057e7))
* **openspec:** propose macOS integration changes ([#588](https://github.com/cedricziel/hermes-app/issues/588)) ([ed4020c](https://github.com/cedricziel/hermes-app/commit/ed4020c77c643d7b0f91eef61778d4993dc622de))

## [0.1.57](https://github.com/cedricziel/hermes-app/compare/v0.1.56...v0.1.57) (2026-10-10)


### Features

* **chat:** paste images and files into the composer on iOS and Android ([#564](https://github.com/cedricziel/hermes-app/issues/564)) ([71010b3](https://github.com/cedricziel/hermes-app/commit/71010b3103db0b6f13804815952379969a5aefb7))
* **voice:** dictate into the field, with send beside the waveform ([#566](https://github.com/cedricziel/hermes-app/issues/566)) ([29238b8](https://github.com/cedricziel/hermes-app/commit/29238b8993782ee6ee4d3f6f52efe3c8f27468e6))
* **voice:** dictate on the device by default ([#563](https://github.com/cedricziel/hermes-app/issues/563)) ([c84bddc](https://github.com/cedricziel/hermes-app/commit/c84bddc9c1c2c6a8052d750725517e7aa2345d3f))


### Bug Fixes

* **auth:** keep the session when a refresh answer is lost ([#568](https://github.com/cedricziel/hermes-app/issues/568)) ([3762442](https://github.com/cedricziel/hermes-app/commit/376244210cdbf943abab62558af09013f21521da))
* **design:** fix the design-sync grading defects ([#555](https://github.com/cedricziel/hermes-app/issues/555)) ([2aa45af](https://github.com/cedricziel/hermes-app/commit/2aa45af9ddf95c6c7473071107912a4511d3c0e1))
* **design:** key grouped rows by id and confirm destructive bot actions ([#559](https://github.com/cedricziel/hermes-app/issues/559)) ([1d10632](https://github.com/cedricziel/hermes-app/commit/1d106327eeb7139351a4ecca1bc5670b076be700))
* **settings:** restore lost details and fix search on the restyled screens ([#562](https://github.com/cedricziel/hermes-app/issues/562)) ([2aca7c8](https://github.com/cedricziel/hermes-app/commit/2aca7c89aa131fa9d10cfbcb443d895bf382c132))
* **voice:** send only a finished dictation, and let other edits win ([#567](https://github.com/cedricziel/hermes-app/issues/567)) ([14ccab7](https://github.com/cedricziel/hermes-app/commit/14ccab798648e2c2456258ff52d41ab6d371a864))
* **widgets:** announce choice and checkbox state, and stop cutting off error text ([#560](https://github.com/cedricziel/hermes-app/issues/560)) ([ba8fd3f](https://github.com/cedricziel/hermes-app/commit/ba8fd3fe222b48f46e035b040393f54a8532789d))


### Documentation

* **openspec:** ask every change for fitting observability ([#565](https://github.com/cedricziel/hermes-app/issues/565)) ([35c9877](https://github.com/cedricziel/hermes-app/commit/35c9877757229ee36de675e4c37612a4090f2178))
* **skills:** treat the PR body as shared in parallel rollouts ([#558](https://github.com/cedricziel/hermes-app/issues/558)) ([8bc4f4e](https://github.com/cedricziel/hermes-app/commit/8bc4f4e3bbc59ff083a3f8632d7227345c9ad51b))

## [0.1.56](https://github.com/cedricziel/hermes-app/compare/v0.1.55...v0.1.56) (2026-10-09)


### Features

* **design:** add the Bots screens to Claude Design ([#550](https://github.com/cedricziel/hermes-app/issues/550)) ([0de65ef](https://github.com/cedricziel/hermes-app/commit/0de65ef46efafbcb31267e044448e9261729246e))
* **design:** add the grouped settings components to Claude Design ([#540](https://github.com/cedricziel/hermes-app/issues/540)) ([957f6f6](https://github.com/cedricziel/hermes-app/commit/957f6f6ad210914ace4eb3ec4387fabf19882725))
* **design:** add the model picker to Claude Design ([#548](https://github.com/cedricziel/hermes-app/issues/548)) ([9cd9aa7](https://github.com/cedricziel/hermes-app/commit/9cd9aa759ee75e5b4eb9ddeb6a05eaa7c6b3b70f))
* **design:** add the settings dialogs to Claude Design ([#543](https://github.com/cedricziel/hermes-app/issues/543)) ([6d8ef33](https://github.com/cedricziel/hermes-app/commit/6d8ef3385531d1f0d97ff3fdae870c59effe9e47))
* **design:** port the clean MCP screens to Claude Design ([#546](https://github.com/cedricziel/hermes-app/issues/546)) ([327f9fd](https://github.com/cedricziel/hermes-app/commit/327f9fdeb9914c88dc75188666f70941dea9e1d1))
* **design:** port the clean Messaging screen to Claude Design ([#542](https://github.com/cedricziel/hermes-app/issues/542)) ([0aa38b1](https://github.com/cedricziel/hermes-app/commit/0aa38b1a1405109e47d95d605393f2fbc20edfa0))
* **design:** port the clean Plugins, Skills and Helper models screens to Claude Design ([#547](https://github.com/cedricziel/hermes-app/issues/547)) ([164ec1f](https://github.com/cedricziel/hermes-app/commit/164ec1fe188d791b1e61366193277c9dd1ae7b76))
* **design:** port the clean Profiles and Kanban lists to Claude Design ([#545](https://github.com/cedricziel/hermes-app/issues/545)) ([2a4586e](https://github.com/cedricziel/hermes-app/commit/2a4586ee3f1c148340aa14a8dbee1e956e8058cf))
* **design:** port the clean Schedules restyle to Claude Design ([#549](https://github.com/cedricziel/hermes-app/issues/549)) ([7db046c](https://github.com/cedricziel/hermes-app/commit/7db046c66bd5989715d3a9f1e64ea3b005092c3a))
* **voice:** add an on-device speech recognizer plugin ([#552](https://github.com/cedricziel/hermes-app/issues/552)) ([08677ea](https://github.com/cedricziel/hermes-app/commit/08677eaafbfdebb098265d368b160f1731d79c4f))
* **voice:** choose on-device dictation ([#554](https://github.com/cedricziel/hermes-app/issues/554)) ([3a4f573](https://github.com/cedricziel/hermes-app/commit/3a4f573b33beffd57434b0dbc3143df7ef72e85e))
* **voice:** on-device dictation engine ([#553](https://github.com/cedricziel/hermes-app/issues/553)) ([0258068](https://github.com/cedricziel/hermes-app/commit/025806888e52ae736cca888f0e224e0eb6649d10))


### Documentation

* **openspec:** propose on-device dictation ([#551](https://github.com/cedricziel/hermes-app/issues/551)) ([71953aa](https://github.com/cedricziel/hermes-app/commit/71953aa4e89a35608f57d5ed408b2b39ac879920))
* **skills:** record how to roll out a UI change with parallel agents ([#544](https://github.com/cedricziel/hermes-app/issues/544)) ([d509c26](https://github.com/cedricziel/hermes-app/commit/d509c260773288df7b083b09a61d3fbcf0b8860c))

## [0.1.55](https://github.com/cedricziel/hermes-app/compare/v0.1.54...v0.1.55) (2026-10-09)


### Features

* **bots:** restyle the Bots screens to the clean design ([#531](https://github.com/cedricziel/hermes-app/issues/531)) ([5e5612d](https://github.com/cedricziel/hermes-app/commit/5e5612d8cb3d0760efca4b8901c744573f35c2d6))
* **kanban:** restyle the boards and workers lists to the clean design ([#530](https://github.com/cedricziel/hermes-app/issues/530)) ([22b8742](https://github.com/cedricziel/hermes-app/commit/22b874249ebe165c3c94b86f8c96fdbe93f8c5ca))
* **kanban:** restyle the new task form to the clean design ([#537](https://github.com/cedricziel/hermes-app/issues/537)) ([3fd520b](https://github.com/cedricziel/hermes-app/commit/3fd520b85559bbdbbe014b14c2979f2c005db3d4))
* **mcp:** give the MCP sub-screens the clean settings design ([#527](https://github.com/cedricziel/hermes-app/issues/527)) ([18e635f](https://github.com/cedricziel/hermes-app/commit/18e635fbcec69e585bf9cdfa6b91e679fcf0147e))
* **mcp:** list servers in an inset group under the settings bar ([#519](https://github.com/cedricziel/hermes-app/issues/519)) ([8548b3d](https://github.com/cedricziel/hermes-app/commit/8548b3d0d481bdd532d208026290520c95b9ca16))
* **models:** give the model picker the clean grouped design ([#533](https://github.com/cedricziel/hermes-app/issues/533)) ([528870a](https://github.com/cedricziel/hermes-app/commit/528870ac63310d9aa66720acea9f917a23078c6e))
* **profiles:** restyle the Profiles screens to the clean design ([#529](https://github.com/cedricziel/hermes-app/issues/529)) ([e1a0557](https://github.com/cedricziel/hermes-app/commit/e1a0557d4244c7dc91612592778e47849e0e50a4))
* **schedules:** list jobs in an inset group with the filter in the bar ([#535](https://github.com/cedricziel/hermes-app/issues/535)) ([4d3d78a](https://github.com/cedricziel/hermes-app/commit/4d3d78ab674449399689fedd0c05c75577f7c229))
* **schedules:** restyle the blueprint gallery and form to the clean design ([#536](https://github.com/cedricziel/hermes-app/issues/536)) ([309cf61](https://github.com/cedricziel/hermes-app/commit/309cf6193cbbf0812a527dc081e4c177645f6652))
* **schedules:** restyle the job form to the clean design ([#534](https://github.com/cedricziel/hermes-app/issues/534)) ([469d7d8](https://github.com/cedricziel/hermes-app/commit/469d7d8dd813e24a522c18e1d03baca6dd1d4156))
* **schedules:** show a job's detail as grouped sections ([#539](https://github.com/cedricziel/hermes-app/issues/539)) ([3698708](https://github.com/cedricziel/hermes-app/commit/3698708b99c7c3ec0a22e168ad1482e9cfb3bfe2))
* **settings:** group the settings dialogs in the clean design ([#532](https://github.com/cedricziel/hermes-app/issues/532)) ([7dd0607](https://github.com/cedricziel/hermes-app/commit/7dd0607a820e05a29e41f6ceb8cfa6c2754396d5))


### Documentation

* **openspec:** archive finished changes ([#525](https://github.com/cedricziel/hermes-app/issues/525)) ([8bc2b6b](https://github.com/cedricziel/hermes-app/commit/8bc2b6bc98de75482c817362aa52e259c67b3768))

## [0.1.54](https://github.com/cedricziel/hermes-app/compare/v0.1.53...v0.1.54) (2026-10-08)


### Features

* **chat:** ask before adding the app's prompt hint to Hermes ([#522](https://github.com/cedricziel/hermes-app/issues/522)) ([3d533c9](https://github.com/cedricziel/hermes-app/commit/3d533c9cae9c84ed0e7c018f89a7787b7630d997))
* **chat:** dictate into the composer ([#521](https://github.com/cedricziel/hermes-app/issues/521)) ([a3f0444](https://github.com/cedricziel/hermes-app/commit/a3f0444c53e933c16d14e535fc67bb6ed7a221f3))
* **ios:** show a running reply as a Live Activity ([#513](https://github.com/cedricziel/hermes-app/issues/513)) ([bd0eccc](https://github.com/cedricziel/hermes-app/commit/bd0eccc7aa5b36a112b9384566e49ccbc2f76811))
* **messaging:** list platforms in an inset group with a Set Up control ([#516](https://github.com/cedricziel/hermes-app/issues/516)) ([f42e1f1](https://github.com/cedricziel/hermes-app/commit/f42e1f1183e3432fa0baa8c81845fac290b4652c))
* **plugins:** restyle the Plugins screen as grouped settings lists ([#520](https://github.com/cedricziel/hermes-app/issues/520)) ([42ffaff](https://github.com/cedricziel/hermes-app/commit/42ffaff278312aa063c3b4a8b41e4fc83c92d163))
* **settings:** restyle Helper models to the clean design ([#515](https://github.com/cedricziel/hermes-app/issues/515)) ([db8d7a8](https://github.com/cedricziel/hermes-app/commit/db8d7a88f76bfdc6c3cc38af9e7f462673ed980a))
* **skills:** restyle the Skills screen to the clean settings design ([#517](https://github.com/cedricziel/hermes-app/issues/517)) ([a374b65](https://github.com/cedricziel/hermes-app/commit/a374b65db156668902fca8d6b884e15bd02fc016))
* **telemetry:** describe the Hermes server on HTTP and auth telemetry ([#507](https://github.com/cedricziel/hermes-app/issues/507)) ([9ce8e1a](https://github.com/cedricziel/hermes-app/commit/9ce8e1a4ad400fa2d3dcd47f4cc2e9b485a301d6))
* **telemetry:** describe the Hermes server on socket and feature telemetry ([#509](https://github.com/cedricziel/hermes-app/issues/509)) ([9a91da7](https://github.com/cedricziel/hermes-app/commit/9a91da7a5b8523c1b9c803fec5d5c35ddef54305))
* **ui:** add a leading tile, caption and error line to grouped rows ([#512](https://github.com/cedricziel/hermes-app/issues/512)) ([ef9d6cb](https://github.com/cedricziel/hermes-app/commit/ef9d6cbdc4a23520864326ae15cff24157dd316c))
* **ui:** add shared widgets for clean settings pages ([#511](https://github.com/cedricziel/hermes-app/issues/511)) ([3621042](https://github.com/cedricziel/hermes-app/commit/362104271d6708e6a6eb17e3798b8acead5c4b4b))
* **voice:** transcribe dictation through Hermes ([#514](https://github.com/cedricziel/hermes-app/issues/514)) ([685390a](https://github.com/cedricziel/hermes-app/commit/685390a1ab5f715dba1c8dd5ada49f9d6344fc6e))


### Bug Fixes

* **chat:** finish a background subagent that completes after its reply ([#504](https://github.com/cedricziel/hermes-app/issues/504)) ([76ac903](https://github.com/cedricziel/hermes-app/commit/76ac903c8ee0b77a762afb7fadb18075c68b223e))
* **chat:** name the app as the session source instead of the TUI ([#508](https://github.com/cedricziel/hermes-app/issues/508)) ([9b1d3e0](https://github.com/cedricziel/hermes-app/commit/9b1d3e07ff04ca470c45dc33c94ebe1e655fbefa))
* get main green after the settings restyle merges ([#523](https://github.com/cedricziel/hermes-app/issues/523)) ([6887c7e](https://github.com/cedricziel/hermes-app/commit/6887c7ec8794dafab65c25c6f99be337ff5c523b))
* **macos:** stop the menu bar from rebuilding during the first build ([#510](https://github.com/cedricziel/hermes-app/issues/510)) ([745fb9d](https://github.com/cedricziel/hermes-app/commit/745fb9d79d9c798d3d4578abab163dbd4171671b))
* **ui:** keep a grouped row's switch reachable when the row opens details ([#518](https://github.com/cedricziel/hermes-app/issues/518)) ([574d784](https://github.com/cedricziel/hermes-app/commit/574d78451571f540c69ce2da7ec53e386818cd53))


### Documentation

* **openspec:** archive voice-dictation ([#524](https://github.com/cedricziel/hermes-app/issues/524)) ([18d23db](https://github.com/cedricziel/hermes-app/commit/18d23db5bb5712b12f1623eda95e94df6549c204))

## [0.1.53](https://github.com/cedricziel/hermes-app/compare/v0.1.52...v0.1.53) (2026-10-08)


### Features

* **design:** port Edit prompt, the review note and per-profile plugin counts to Claude Design ([#498](https://github.com/cedricziel/hermes-app/issues/498)) ([9d0b18b](https://github.com/cedricziel/hermes-app/commit/9d0b18b4abe188f3bc88622a653e57071a1a482d))
* **telemetry:** record navigation and chat breadcrumbs for crash reports ([#500](https://github.com/cedricziel/hermes-app/issues/500)) ([f48fa78](https://github.com/cedricziel/hermes-app/commit/f48fa78d099347f368bbac9760beae1921e1318a))


### Bug Fixes

* **chat:** stop the transcript from painting children it never laid out ([#502](https://github.com/cedricziel/hermes-app/issues/502)) ([3e6ceb3](https://github.com/cedricziel/hermes-app/commit/3e6ceb380159c6479bfad8497107dae75365b431))
* **telemetry:** collapse repeating crashes and keep their stack traces ([#501](https://github.com/cedricziel/hermes-app/issues/501)) ([f955fdb](https://github.com/cedricziel/hermes-app/commit/f955fdb592f14477d5440ad4042a0436253147cf))

## [0.1.52](https://github.com/cedricziel/hermes-app/compare/v0.1.51...v0.1.52) (2026-10-08)


### Features

* **chat:** edit the last prompt and regenerate in place ([#463](https://github.com/cedricziel/hermes-app/issues/463)) ([e4c05ee](https://github.com/cedricziel/hermes-app/commit/e4c05eea92870e3b39d04764cd0c216c658986a3))
* **chat:** gateway heartbeat, replay ledger and reconnect backoff ([#466](https://github.com/cedricziel/hermes-app/issues/466)) ([de72a0c](https://github.com/cedricziel/hermes-app/commit/de72a0c38dba693f8e4598b652d1a8c1e43580fd))
* **chat:** replay missed events after a dropped socket ([#474](https://github.com/cedricziel/hermes-app/issues/474)) ([78e7477](https://github.com/cedricziel/hermes-app/commit/78e7477899e4319e29624d9efe1030337aa1a2f8))
* **chat:** route turns nobody submitted, probe silent chained turns, and log gateway telemetry ([#477](https://github.com/cedricziel/hermes-app/issues/477)) ([1413268](https://github.com/cedricziel/hermes-app/commit/141326837be7e539d7b3870e9d888700e8be7af5))
* **chat:** show the auto-continue turn live in its own reply ([#488](https://github.com/cedricziel/hermes-app/issues/488)) ([ad53c87](https://github.com/cedricziel/hermes-app/commit/ad53c875855bc3a84b8d7ed19af9c219b0a476dc))
* **chat:** show what the background review saved under the reply ([#495](https://github.com/cedricziel/hermes-app/issues/495)) ([6c65225](https://github.com/cedricziel/hermes-app/commit/6c652254c6fc053430b0ce582891136439189e22))
* scope plugin and schedule requests to the shown profile ([#497](https://github.com/cedricziel/hermes-app/issues/497)) ([f8618f2](https://github.com/cedricziel/hermes-app/commit/f8618f22be1dc9210d0f95f75f6d4288fce12662))
* **screenshots:** render the README screenshots on Linux ([#496](https://github.com/cedricziel/hermes-app/issues/496)) ([6f5707b](https://github.com/cedricziel/hermes-app/commit/6f5707bbdacaadd5c0035638085cc343eef63c8f))
* **screenshots:** take the wide Mac screenshots unattended ([#487](https://github.com/cedricziel/hermes-app/issues/487)) ([05c81d3](https://github.com/cedricziel/hermes-app/commit/05c81d3d148a057bcf3b7cd9e98ecd759e175743))


### Bug Fixes

* **auth:** clear the session before the token store on sign-out ([#473](https://github.com/cedricziel/hermes-app/issues/473)) ([c68c3db](https://github.com/cedricziel/hermes-app/commit/c68c3dba2d54263bd52f8f2a1f121de396660d16))
* **chat:** apply completion flags, settling and status to streamed replies ([#465](https://github.com/cedricziel/hermes-app/issues/465)) ([b622adb](https://github.com/cedricziel/hermes-app/commit/b622adb7295e2949e9b90976322d288d03bfa82a))
* **chat:** close reconnect edge cases from [#476](https://github.com/cedricziel/hermes-app/issues/476) ([#481](https://github.com/cedricziel/hermes-app/issues/481)) ([1fafc0c](https://github.com/cedricziel/hermes-app/commit/1fafc0c99b8e34504524a200d2b889841938b3f6))
* **chat:** don't show the turn ahead's reply on a queued prompt after a drop ([#482](https://github.com/cedricziel/hermes-app/issues/482)) ([5f95468](https://github.com/cedricziel/hermes-app/commit/5f95468ec99a43b248e8d762bd47112b71776e57))
* **chat:** keep a rebuilt reply from repeating rewritten text, and mark a stop before the interrupt answers ([#479](https://github.com/cedricziel/hermes-app/issues/479)) ([565ad94](https://github.com/cedricziel/hermes-app/commit/565ad94f340d5d4b4a2e438cb2cd52f665728756))
* **chat:** keep auto-continue turns and their requests straight across drops ([#485](https://github.com/cedricziel/hermes-app/issues/485)) ([73ae3dd](https://github.com/cedricziel/hermes-app/commit/73ae3dda4af37b9f48435934b58d6a24ee654d68))
* **chat:** keep Stop and the queue in step around folded sends and late answers ([#486](https://github.com/cedricziel/hermes-app/issues/486)) ([a0bfa38](https://github.com/cedricziel/hermes-app/commit/a0bfa382cd2dd044c734d63db715d418782b63a2))
* **chat:** load history whose tool-call arguments are not a string ([#471](https://github.com/cedricziel/hermes-app/issues/471)) ([688d896](https://github.com/cedricziel/hermes-app/commit/688d896982d0278b483957ef1f55332b2130eb03))
* **chat:** probe a late-waking socket and ping only while it is in use ([#480](https://github.com/cedricziel/hermes-app/issues/480)) ([1a2b859](https://github.com/cedricziel/hermes-app/commit/1a2b859d8accbc6b562e364b32beb6e3280b774c))
* **chat:** refetch a queued prompt's reply after a drop instead of guessing from the stored thread ([#483](https://github.com/cedricziel/hermes-app/issues/483)) ([900d40e](https://github.com/cedricziel/hermes-app/commit/900d40e63db826ee4e9794c46c27b5008bca3d3f))
* **chat:** settle silent turns, read the submit outcome and drain the queue on settle ([#470](https://github.com/cedricziel/hermes-app/issues/470)) ([4aee117](https://github.com/cedricziel/hermes-app/commit/4aee1178348ff8724ae2edbea3ead6f8a924f7b1))
* **chat:** settle, queue and rotate turns correctly after review of [#470](https://github.com/cedricziel/hermes-app/issues/470) ([#475](https://github.com/cedricziel/hermes-app/issues/475)) ([50d5c50](https://github.com/cedricziel/hermes-app/commit/50d5c50d5da8673d4de3c4d331d795aefbb78051))
* **chat:** share the stale-socket probe and drop a dead socket without waiting ([#484](https://github.com/cedricziel/hermes-app/issues/484)) ([f41017c](https://github.com/cedricziel/hermes-app/commit/f41017cfb856721674908409b74d2f1e6b0bc383))
* **chat:** time out a gateway socket that never finishes opening ([#472](https://github.com/cedricziel/hermes-app/issues/472)) ([1296bca](https://github.com/cedricziel/hermes-app/commit/1296bca47a370ef4390c9414e960d26069e1ab57))


### Documentation

* **openspec:** archive gateway-stream-parity and sync its chat spec ([#478](https://github.com/cedricziel/hermes-app/issues/478)) ([1255fe5](https://github.com/cedricziel/hermes-app/commit/1255fe5428463b48a3e774ea024082d3a757c656))

## [0.1.51](https://github.com/cedricziel/hermes-app/compare/v0.1.50...v0.1.51) (2026-10-07)


### Features

* **telemetry:** report a vendor-scoped installation ID ([#453](https://github.com/cedricziel/hermes-app/issues/453)) ([b921720](https://github.com/cedricziel/hermes-app/commit/b9217201ec430f7594f7f9c690d51a9f26faaddb))


### Bug Fixes

* **auth:** connect at the address the server redirects to ([#456](https://github.com/cedricziel/hermes-app/issues/456)) ([d9bc6e9](https://github.com/cedricziel/hermes-app/commit/d9bc6e935d8e05ada7a5ac00de1017e30e2e1c29))
* **chat:** show a reasoning-only reply once, as reasoning ([#451](https://github.com/cedricziel/hermes-app/issues/451)) ([d1a3bcd](https://github.com/cedricziel/hermes-app/commit/d1a3bcd91834b26c5bd2da4608dee329568c7c6a))
* **ios:** stop the share extension stalling on shared images ([#450](https://github.com/cedricziel/hermes-app/issues/450)) ([3229805](https://github.com/cedricziel/hermes-app/commit/32298059f67cfbce2008b2ef63f6c88d4e8af642))


### Documentation

* **openspec:** propose gateway-stream-parity ([#454](https://github.com/cedricziel/hermes-app/issues/454)) ([81bca1d](https://github.com/cedricziel/hermes-app/commit/81bca1d048c5fb5ef63687bc3b851ac586618670))

## [0.1.50](https://github.com/cedricziel/hermes-app/compare/v0.1.49...v0.1.50) (2026-10-06)


### Features

* **design:** add MacToolbar, the Mac unified toolbar ([#409](https://github.com/cedricziel/hermes-app/issues/409)) ([0a715b5](https://github.com/cedricziel/hermes-app/commit/0a715b5bf6e98f5d887056178f7d551dbb8da3d8))
* **design:** add MCP servers and Plugins screen cards ([#411](https://github.com/cedricziel/hermes-app/issues/411)) ([c56f44a](https://github.com/cedricziel/hermes-app/commit/c56f44a9cbb58e2069b6848750eefbf8c8213b05))
* **design:** add profile, messaging, skill and helper model screen cards ([#438](https://github.com/cedricziel/hermes-app/issues/438)) ([720192f](https://github.com/cedricziel/hermes-app/commit/720192faf185b6fe9261dee92e87ba305ad22a04))
* **design:** add screen cards for the shell, chat and onboarding ([#410](https://github.com/cedricziel/hermes-app/issues/410)) ([83cc2a6](https://github.com/cedricziel/hermes-app/commit/83cc2a6cc46e1f13f59ff3293d6866e6c0ebdf35))
* **design:** add shared screen parts for the screen cards ([#405](https://github.com/cedricziel/hermes-app/issues/405)) ([fc059dd](https://github.com/cedricziel/hermes-app/commit/fc059dd694e2d6578261a5cbe3808bcc6e5338d9))
* **design:** add the Kanban and Schedules screen cards ([#441](https://github.com/cedricziel/hermes-app/issues/441)) ([293b1ae](https://github.com/cedricziel/hermes-app/commit/293b1ae29621a18ca489968338c09271d344a0e5))
* **design:** add the Mac conversation window screen card ([#446](https://github.com/cedricziel/hermes-app/issues/446)) ([9aa5015](https://github.com/cedricziel/hermes-app/commit/9aa5015494ad98e7548a1c521be1a22486fd3578))
* **design:** port the Mac main window's search, compact layout, profile scope and folder grouping ([#447](https://github.com/cedricziel/hermes-app/issues/447)) ([b3510a0](https://github.com/cedricziel/hermes-app/commit/b3510a0962a188a77322edb529a0e0657b72ca18))
* **design:** port the Mac sign-out confirmation, per-profile messaging counts and window drafts ([#448](https://github.com/cedricziel/hermes-app/issues/448)) ([2319999](https://github.com/cedricziel/hermes-app/commit/2319999818b6a58327463a60c236e1efa3a522d6))
* **macos:** add account commands to the menu bar and count messaging per profile ([#445](https://github.com/cedricziel/hermes-app/issues/445)) ([a19099d](https://github.com/cedricziel/hermes-app/commit/a19099d2932113b43975879f71d28fb954f156f9))
* **macos:** open a chat in its own conversation window ([#398](https://github.com/cedricziel/hermes-app/issues/398)) ([83ab572](https://github.com/cedricziel/hermes-app/commit/83ab572ebbe00428c7e4ac20ef9928bf31f01927))
* **macos:** route Kanban and Schedules shortcuts through the menu bar ([#439](https://github.com/cedricziel/hermes-app/issues/439)) ([1c47b5f](https://github.com/cedricziel/hermes-app/commit/1c47b5f6e5c8478af6565ed843b07900f8c33f9c))
* **macos:** scope the sidebar to a profile, with a Profiles page and account footer ([#402](https://github.com/cedricziel/hermes-app/issues/402)) ([b49bf13](https://github.com/cedricziel/hermes-app/commit/b49bf131e1a917cdd680f24c44ebf0e5a46af211))


### Bug Fixes

* **macos:** hand a chat and its draft to its window, and close windows before they show ([#444](https://github.com/cedricziel/hermes-app/issues/444)) ([cc02dc6](https://github.com/cedricziel/hermes-app/commit/cc02dc606bbc4cd28d8cf64eaada8c47083b6294))
* **shell:** keep hidden pages' floating buttons out of route heroes ([#443](https://github.com/cedricziel/hermes-app/issues/443)) ([19ed8cd](https://github.com/cedricziel/hermes-app/commit/19ed8cdf64d7df09ecb280d9e4faacad46bf29ce))
* **watch:** show long chats instead of a blank screen ([#442](https://github.com/cedricziel/hermes-app/issues/442)) ([43526e7](https://github.com/cedricziel/hermes-app/commit/43526e7eaf7f3d0df394fb721e563c125d9611e1))

## [0.1.49](https://github.com/cedricziel/hermes-app/compare/v0.1.48...v0.1.49) (2026-10-05)


### Features

* **chat:** add folder grouping to chat lists ([#434](https://github.com/cedricziel/hermes-app/issues/434)) ([fd08e67](https://github.com/cedricziel/hermes-app/commit/fd08e671080c17005519914a4af0aa1cf11f64f5))
* **handoff:** continue saved chats across Apple devices ([#436](https://github.com/cedricziel/hermes-app/issues/436)) ([aa1a3d7](https://github.com/cedricziel/hermes-app/commit/aa1a3d7d36916af83c723946cab64827284a450b))
* **watch:** add relay and session restoration diagnostics ([#433](https://github.com/cedricziel/hermes-app/issues/433)) ([973ab15](https://github.com/cedricziel/hermes-app/commit/973ab15272c6b9ddd597b0093ca0d14294fb17b8))


### Bug Fixes

* **chat:** scope text selection to each message ([#431](https://github.com/cedricziel/hermes-app/issues/431)) ([9199772](https://github.com/cedricziel/hermes-app/commit/9199772e20517136b303a160c78e61c87bfb94c0))
* **tests:** drain chained HTTP timeouts during workflow cleanup ([#432](https://github.com/cedricziel/hermes-app/issues/432)) ([d5c7627](https://github.com/cedricziel/hermes-app/commit/d5c7627c22f63c97b83b779e14df087c3c56cea5))


### Documentation

* **readme:** add App Store and TestFlight buttons ([#435](https://github.com/cedricziel/hermes-app/issues/435)) ([58aa4ef](https://github.com/cedricziel/hermes-app/commit/58aa4efa8cd331990e6006945e09c884fbe66ca5))

## [0.1.48](https://github.com/cedricziel/hermes-app/compare/v0.1.47...v0.1.48) (2026-10-05)


### Features

* **bots:** add Bot Mode roster, chats, and hosted groups ([#429](https://github.com/cedricziel/hermes-app/issues/429)) ([4ccf7b8](https://github.com/cedricziel/hermes-app/commit/4ccf7b8cc2cc6c431e24d20263676e5aeb177ca5))
* **chat:** mark working threads and pick up remote turns ([#421](https://github.com/cedricziel/hermes-app/issues/421)) ([032be9d](https://github.com/cedricziel/hermes-app/commit/032be9df9663a463c685381a8bb711e5351e25c8))


### Bug Fixes

* **chat:** paste only file URLs as attachments on macOS ([#417](https://github.com/cedricziel/hermes-app/issues/417)) ([d59f39b](https://github.com/cedricziel/hermes-app/commit/d59f39b843c356960c05c8506e0a82d97f248f7e))
* **chat:** render GFM tables that interrupt a paragraph ([#415](https://github.com/cedricziel/hermes-app/issues/415)) ([9667381](https://github.com/cedricziel/hermes-app/commit/96673817206c361a0a7a039fa6bcbf772fd17d15))

## [0.1.47](https://github.com/cedricziel/hermes-app/compare/v0.1.46...v0.1.47) (2026-10-05)


### Features

* **chat:** support Hermes slash commands ([#425](https://github.com/cedricziel/hermes-app/issues/425)) ([6ee9b0a](https://github.com/cedricziel/hermes-app/commit/6ee9b0a4127a452ca846f9548e07f766112c986c))


### Bug Fixes

* **chat:** clear phantom replies after reconnect ([#423](https://github.com/cedricziel/hermes-app/issues/423)) ([16c0f48](https://github.com/cedricziel/hermes-app/commit/16c0f488a837d0b3e411ebb679b002bb79e7ee1a))
* **chat:** focus composer when starting a new chat ([#428](https://github.com/cedricziel/hermes-app/issues/428)) ([a5774e1](https://github.com/cedricziel/hermes-app/commit/a5774e1a96de5217c240db52497b8b56ebb4a77e))


### Documentation

* add Hermes observability skill ([#426](https://github.com/cedricziel/hermes-app/issues/426)) ([48ffde9](https://github.com/cedricziel/hermes-app/commit/48ffde95f2b7f464819118c7a086a91e0aa6bd4c))
* plan Bot Mode and refresh OpenSpec integrations ([#427](https://github.com/cedricziel/hermes-app/issues/427)) ([6e9ca04](https://github.com/cedricziel/hermes-app/commit/6e9ca04834d713138b11bf092e25f119a717170a))

## [0.1.46](https://github.com/cedricziel/hermes-app/compare/v0.1.45...v0.1.46) (2026-10-04)


### Features

* **chat:** render delegated subagents as cards in the thread ([#420](https://github.com/cedricziel/hermes-app/issues/420)) ([d49decc](https://github.com/cedricziel/hermes-app/commit/d49deccc749734d7e54eee7bd42d1ef6dc884f6a))


### Bug Fixes

* **chat:** recover the blank transcript while a reply streams ([#414](https://github.com/cedricziel/hermes-app/issues/414)) ([f4aa4c4](https://github.com/cedricziel/hermes-app/commit/f4aa4c4d6994ee1c61e3f6834d73d51fc21f4eb6))
* **chat:** render interactive vault prompts ([#422](https://github.com/cedricziel/hermes-app/issues/422)) ([0407972](https://github.com/cedricziel/hermes-app/commit/04079729a30abf52f2137f7d61d58f1cd0356dcf))

## [0.1.45](https://github.com/cedricziel/hermes-app/compare/v0.1.44...v0.1.45) (2026-10-04)


### Features

* **design:** add FormSection, SelectField and ListRow for forms and plain lists ([#404](https://github.com/cedricziel/hermes-app/issues/404)) ([6257532](https://github.com/cedricziel/hermes-app/commit/6257532419eabb510ba8ced9e3cd2cc5d3f86ae5))
* **design:** add SegmentedButton for single choices in forms ([#407](https://github.com/cedricziel/hermes-app/issues/407)) ([cf88ebf](https://github.com/cedricziel/hermes-app/commit/cf88ebfef7e5941dae80ae85d1da05c8656ed9fb))
* **design:** add shared platform controls and iOS row swipes ([#400](https://github.com/cedricziel/hermes-app/issues/400)) ([68345cc](https://github.com/cedricziel/hermes-app/commit/68345ccc3d9bb94565facee5f9e723d5920e0de5))
* **design:** draw the app's CupertinoIcons on Apple ([#397](https://github.com/cedricziel/hermes-app/issues/397)) ([6e87161](https://github.com/cedricziel/hermes-app/commit/6e8716153fecd1947440f6b71f7401d313a97cf0))
* **design:** give ListDetailLayout a close button and an explicit device ([#403](https://github.com/cedricziel/hermes-app/issues/403)) ([a9ee5f1](https://github.com/cedricziel/hermes-app/commit/a9ee5f15ac582e76aac1ea141ee1f949d5fae307))
* **design:** mirror the Apple platform look in the Claude Design recreation ([#387](https://github.com/cedricziel/hermes-app/issues/387)) ([3cc910d](https://github.com/cedricziel/hermes-app/commit/3cc910def571ab7334fa0817ca9be478f04f65b9))
* **kanban:** Mac toolbar and task inspector on macOS ([#396](https://github.com/cedricziel/hermes-app/issues/396)) ([54f7d4e](https://github.com/cedricziel/hermes-app/commit/54f7d4e7fe7dedc1548766ea4b7e6e355122b616))
* **macos:** add a native menu bar with a command registry ([#392](https://github.com/cedricziel/hermes-app/issues/392)) ([68f6a65](https://github.com/cedricziel/hermes-app/commit/68f6a65bda5abd9b36d296cf02a0424efd499dc3))
* **macos:** add shared toolbar button, title and bar ([#389](https://github.com/cedricziel/hermes-app/issues/389)) ([f6b4df0](https://github.com/cedricziel/hermes-app/commit/f6b4df08bb1fca102de3e2cac99e913a810551b8))
* **macos:** give Schedules the Mac toolbar, scope and split layout ([#401](https://github.com/cedricziel/hermes-app/issues/401)) ([9733dcf](https://github.com/cedricziel/hermes-app/commit/9733dcf79a1eadbe900fd54219ea4fedb4af35db))
* **macos:** search from a unified toolbar, across profiles ([#399](https://github.com/cedricziel/hermes-app/issues/399)) ([5bc2534](https://github.com/cedricziel/hermes-app/commit/5bc2534685224a393a83b957f3e2d389b0d43a2a))
* **macos:** show the sidebar as a source list with recency sections ([#391](https://github.com/cedricziel/hermes-app/issues/391)) ([574df2b](https://github.com/cedricziel/hermes-app/commit/574df2b2abf71f6a49765673a46f0c7afa84ec5d))
* **widgetbook:** give every screen a catalog use case ([#395](https://github.com/cedricziel/hermes-app/issues/395)) ([c7205d9](https://github.com/cedricziel/hermes-app/commit/c7205d9f959412e2096000c48fb43906995e8487))


### Bug Fixes

* **auth:** keep the session readable on iOS while the phone is locked ([#408](https://github.com/cedricziel/hermes-app/issues/408)) ([c585fc1](https://github.com/cedricziel/hermes-app/commit/c585fc1af1e73be0129fbf3a388b6d3ec040ec91))
* **design:** fix the Apple preview cells left over from [#387](https://github.com/cedricziel/hermes-app/issues/387) ([#390](https://github.com/cedricziel/hermes-app/issues/390)) ([9a89cde](https://github.com/cedricziel/hermes-app/commit/9a89cde16d2d5cab99bca06e5ab6392d00301456))
* **watch:** load chats when the watch wakes the phone app ([#394](https://github.com/cedricziel/hermes-app/issues/394)) ([03c2118](https://github.com/cedricziel/hermes-app/commit/03c2118947ced526b9993c0b45cb14cc5e55c809))


### Documentation

* **design-sync:** record the follow-ups after the Apple re-sync ([#393](https://github.com/cedricziel/hermes-app/issues/393)) ([0b0f9d7](https://github.com/cedricziel/hermes-app/commit/0b0f9d7e92c9027d4997cbb9e06427f5d8a2d7f3))

## [0.1.44](https://github.com/cedricziel/hermes-app/compare/v0.1.43...v0.1.44) (2026-10-03)


### Features

* **chat:** swipe actions and 44pt thread rows on iOS ([#376](https://github.com/cedricziel/hermes-app/issues/376)) ([f5e1751](https://github.com/cedricziel/hermes-app/commit/f5e175128c808d7ea608ca4a6ade784776ce8a46))
* **chat:** use a 44pt navigation bar and respect the status bar on iOS ([#375](https://github.com/cedricziel/hermes-app/issues/375)) ([044fe4f](https://github.com/cedricziel/hermes-app/commit/044fe4fc02dea6b52fab0b47582f26e4f2467903))
* **kanban:** follow iOS touch conventions in selection, drag and search ([#378](https://github.com/cedricziel/hermes-app/issues/378)) ([d25526d](https://github.com/cedricziel/hermes-app/commit/d25526d327cc900285152331f7b92d3b84d4ca53))
* **kanban:** present a task as a detent sheet or form sheet on Apple platforms ([#379](https://github.com/cedricziel/hermes-app/issues/379)) ([c4feb20](https://github.com/cedricziel/hermes-app/commit/c4feb20f47631c1312369de9ad4faed478af5061))
* **macos:** use a source-list sidebar and a unified toolbar ([#384](https://github.com/cedricziel/hermes-app/issues/384)) ([e75a920](https://github.com/cedricziel/hermes-app/commit/e75a920972ec4784fed8940a3a517a32f9c8546c))
* **profiles:** follow iOS conventions on the connect, login and profile screens ([#369](https://github.com/cedricziel/hermes-app/issues/369)) ([eb409ea](https://github.com/cedricziel/hermes-app/commit/eb409ea4392bb80f90ad0fdf15a798056679d435))
* **schedules:** inset grouped job rows and row actions on Apple platforms ([#385](https://github.com/cedricziel/hermes-app/issues/385)) ([3b13611](https://github.com/cedricziel/hermes-app/commit/3b136115349524a9790a4e404b2202c72c87e5ad))
* **shell:** use the wide layout for a full-screen iPad in portrait ([#371](https://github.com/cedricziel/hermes-app/issues/371)) ([9d8b993](https://github.com/cedricziel/hermes-app/commit/9d8b993cf9cc62764fcc2cdf081fa71697aa7783))
* **telemetry:** tag the service namespace and the backend peer ([#374](https://github.com/cedricziel/hermes-app/issues/374)) ([09c52ce](https://github.com/cedricziel/hermes-app/commit/09c52ce4978f22084309d01eb5e3a7ec43136b48))
* **theme:** add a platform chrome helper for Apple conventions ([#367](https://github.com/cedricziel/hermes-app/issues/367)) ([c08ae43](https://github.com/cedricziel/hermes-app/commit/c08ae4342fd16bccd2f886c274607ea9a6eb63bc))
* **theme:** follow the HIG for back buttons, add actions and tabs on Apple platforms ([#377](https://github.com/cedricziel/hermes-app/issues/377)) ([7922a50](https://github.com/cedricziel/hermes-app/commit/7922a50e5df721046af794568d1d037c395d3416))
* **theme:** use Apple-style dialogs, menus, spinners and pickers on iOS and macOS ([#383](https://github.com/cedricziel/hermes-app/issues/383)) ([efd7979](https://github.com/cedricziel/hermes-app/commit/efd7979296868302aa638c6313a409a35652c04c))
* **theme:** use Apple's type ramp on iOS and cap the chat column at 680 points ([#380](https://github.com/cedricziel/hermes-app/issues/380)) ([38d3770](https://github.com/cedricziel/hermes-app/commit/38d37708174da355cfde8b7f8a8ba0ac6f709e18))
* **theme:** use SF-style icons on Apple platforms ([#386](https://github.com/cedricziel/hermes-app/issues/386)) ([11a8506](https://github.com/cedricziel/hermes-app/commit/11a85061bd9a07a468d000f0b0fbaf66266e1b09))
* **theme:** use the platform toggle for switches on iOS and macOS ([#370](https://github.com/cedricziel/hermes-app/issues/370)) ([ba0d114](https://github.com/cedricziel/hermes-app/commit/ba0d1142ed36476000edced5beec083ecf2aaead))


### Bug Fixes

* **chat:** give chat actions and disclosure rows a 44-point tap target on iOS ([#372](https://github.com/cedricziel/hermes-app/issues/372)) ([d4701f5](https://github.com/cedricziel/hermes-app/commit/d4701f5d87a54cad1f206f7574b44faea0a7ad4a))
* **theme:** meet 4.5:1 text contrast and respect Reduce Motion ([#368](https://github.com/cedricziel/hermes-app/issues/368)) ([932a9fa](https://github.com/cedricziel/hermes-app/commit/932a9fa1e924bd3ea4dddda86ff7f9b109a7f710))


### Documentation

* **design-sync:** describe the phone drawer and cloud-container quirks ([#365](https://github.com/cedricziel/hermes-app/issues/365)) ([e348cfc](https://github.com/cedricziel/hermes-app/commit/e348cfc65f7bba690eaf29e59e95132e9eafb268))

## [0.1.43](https://github.com/cedricziel/hermes-app/compare/v0.1.42...v0.1.43) (2026-10-03)


### Features

* **chat:** search chats from the sidebar ([#349](https://github.com/cedricziel/hermes-app/issues/349)) ([448893a](https://github.com/cedricziel/hermes-app/commit/448893a7cc44f2ebb9089217568ad1d82cbfb3bf))
* **kanban:** pause the board's event stream while it is not on screen ([#352](https://github.com/cedricziel/hermes-app/issues/352)) ([7ba08ad](https://github.com/cedricziel/hermes-app/commit/7ba08ad3956d24c98f7d5379f1e3c479524154aa))
* **kanban:** trace the live event stream ([#343](https://github.com/cedricziel/hermes-app/issues/343)) ([e593c65](https://github.com/cedricziel/hermes-app/commit/e593c65306fcbd14dea95906a1775864f6d3eaef))
* **shell:** move Chat, Kanban and Schedules from the bottom bar into the drawer ([#364](https://github.com/cedricziel/hermes-app/issues/364)) ([78d0fe5](https://github.com/cedricziel/hermes-app/commit/78d0fe50c00d33487ef1580f4f9b6c1166bd72e0))


### Bug Fixes

* **a11y:** give nav items and icon buttons proper roles and names ([#350](https://github.com/cedricziel/hermes-app/issues/350)) ([cec298e](https://github.com/cedricziel/hermes-app/commit/cec298e582635d35784248e11be973a5a6863a2d))
* **chat:** name icon buttons, menus and tool call headers for screen readers ([#361](https://github.com/cedricziel/hermes-app/issues/361)) ([c91e885](https://github.com/cedricziel/hermes-app/commit/c91e885478fad7196b15802805de56c18c652d89))
* **kanban:** let All tenants and All assignees clear the filter ([#360](https://github.com/cedricziel/hermes-app/issues/360)) ([1621775](https://github.com/cedricziel/hermes-app/commit/1621775aa3a4ab3792de4f8dcbde5663464e6527))
* **kanban:** name the remaining icon buttons and sections in kanban, schedules, login and search ([#363](https://github.com/cedricziel/hermes-app/issues/363)) ([87c3354](https://github.com/cedricziel/hermes-app/commit/87c3354496120e0a05dc84c9ec53c929e29b8ac6))
* **schedules:** count a run with a queued delivery as succeeded ([#355](https://github.com/cedricziel/hermes-app/issues/355)) ([2498803](https://github.com/cedricziel/hermes-app/commit/2498803e3e2c627251004ce2c7775c136e9c490c))
* **schedules:** explain why a blocked job has no runs ([#345](https://github.com/cedricziel/hermes-app/issues/345)) ([572047e](https://github.com/cedricziel/hermes-app/commit/572047e7ca749fa455e6faf198dcc80c01bb7c40))
* **schedules:** wrap the filter chips so Paused stays visible ([#344](https://github.com/cedricziel/hermes-app/issues/344)) ([984f31c](https://github.com/cedricziel/hermes-app/commit/984f31cddfbce3a81f8afce426db19b955ea7882))
* **settings:** name icon buttons, switches and sections in bots, plugins, MCP, skills and profiles ([#362](https://github.com/cedricziel/hermes-app/issues/362)) ([3c9e0f0](https://github.com/cedricziel/hermes-app/commit/3c9e0f01e12c961d60f369e7c0e9f5d545d91f83))
* **theme:** left-align page titles on every platform ([#342](https://github.com/cedricziel/hermes-app/issues/342)) ([d104ea5](https://github.com/cedricziel/hermes-app/commit/d104ea57fc0f5e68a0cfd1fd782bd58e69e774aa)), closes [#319](https://github.com/cedricziel/hermes-app/issues/319)


### Documentation

* **chat:** record that batch clarify retries rely on per-question overwrites ([#348](https://github.com/cedricziel/hermes-app/issues/348)) ([5a4b34d](https://github.com/cedricziel/hermes-app/commit/5a4b34dfb939a76610fcf80b34a928021f161793))

## [0.1.42](https://github.com/cedricziel/hermes-app/compare/v0.1.41...v0.1.42) (2026-10-03)


### Features

* **design:** sync a React recreation of the app UI to Claude Design ([#339](https://github.com/cedricziel/hermes-app/issues/339)) ([bebea87](https://github.com/cedricziel/hermes-app/commit/bebea8768f0e8848736ff268c899f9a05e98eb69))


### Bug Fixes

* **auth:** finish sign-in in macOS debug builds and say why saving failed ([#337](https://github.com/cedricziel/hermes-app/issues/337)) ([16531a5](https://github.com/cedricziel/hermes-app/commit/16531a5b9caebb431fb722db023108ded7187c3e))

## [0.1.41](https://github.com/cedricziel/hermes-app/compare/v0.1.40...v0.1.41) (2026-10-01)


### Bug Fixes

* **chat:** tool calls as Hermes really reports them ([#334](https://github.com/cedricziel/hermes-app/issues/334)) ([298e0bd](https://github.com/cedricziel/hermes-app/commit/298e0bd0043d65ce5acf02a374fe91e17471231d))

## [0.1.40](https://github.com/cedricziel/hermes-app/compare/v0.1.39...v0.1.40) (2026-10-01)


### Features

* **chat:** render tool calls the way assistant-ui does ([#333](https://github.com/cedricziel/hermes-app/issues/333)) ([5700f7a](https://github.com/cedricziel/hermes-app/commit/5700f7a198c6d1a4aff3694b5417fe379e1182f7))


### Bug Fixes

* **auth:** sign in through ASWebAuthenticationSession on iOS and macOS ([#329](https://github.com/cedricziel/hermes-app/issues/329)) ([eabe85d](https://github.com/cedricziel/hermes-app/commit/eabe85dcf16e6fcfb838a6f5699919a5f4483212))
* **chat:** keep reasoning that streamed and render it after input requests ([#332](https://github.com/cedricziel/hermes-app/issues/332)) ([ecb433a](https://github.com/cedricziel/hermes-app/commit/ecb433aee1e2b0415ac2f0de4b9c62f9333f0c63))
* **chat:** read interim and final reply text the way Hermes sends it ([#331](https://github.com/cedricziel/hermes-app/issues/331)) ([67ea7e7](https://github.com/cedricziel/hermes-app/commit/67ea7e7d149bf3998af0a61d089e7058d0cf8c64))

## [0.1.39](https://github.com/cedricziel/hermes-app/compare/v0.1.38...v0.1.39) (2026-09-29)


### Features

* **chat:** show starter prompts with a source icon ([#324](https://github.com/cedricziel/hermes-app/issues/324)) ([baca99b](https://github.com/cedricziel/hermes-app/commit/baca99b7d46cb6ef410fcf54397ca5881dfeebf2))
* **chat:** suggest starter prompts from the user's context ([#325](https://github.com/cedricziel/hermes-app/issues/325)) ([4a281af](https://github.com/cedricziel/hermes-app/commit/4a281af25f499453c86da8c84693e221fe886a06))


### Bug Fixes

* **chat:** let the empty chat's greeting scroll above the composer ([#323](https://github.com/cedricziel/hermes-app/issues/323)) ([78deca2](https://github.com/cedricziel/hermes-app/commit/78deca25337cfd9c7896d38a8763f8838bd52640))


### Documentation

* **openspec:** archive context-based starter prompts ([#327](https://github.com/cedricziel/hermes-app/issues/327)) ([7e2aa57](https://github.com/cedricziel/hermes-app/commit/7e2aa57ae0248a49e87cbd114e8dbe83ad3d0c37))
* **skills:** drive the macOS app through its accessibility tree ([#321](https://github.com/cedricziel/hermes-app/issues/321)) ([8b1bac9](https://github.com/cedricziel/hermes-app/commit/8b1bac95a5347e2a17cf589f4ae1890ef27a268a))

## [0.1.38](https://github.com/cedricziel/hermes-app/compare/v0.1.37...v0.1.38) (2026-09-26)


### Features

* **chat:** add a composer card with attach, model and send below the field ([#307](https://github.com/cedricziel/hermes-app/issues/307)) ([4459f6d](https://github.com/cedricziel/hermes-app/commit/4459f6d0d2729132cb9bf94374fbc7944cbef2a6))
* **chat:** add a model pill to the composer ([#302](https://github.com/cedricziel/hermes-app/issues/302)) ([71f4c9c](https://github.com/cedricziel/hermes-app/commit/71f4c9c955af591f724de2e68fc8a04787f8d66f))
* **chat:** queue prompts sent while Hermes replies ([#297](https://github.com/cedricziel/hermes-app/issues/297)) ([ca07101](https://github.com/cedricziel/hermes-app/commit/ca07101886e21dd78eac71f25a5a156ffd8d3f4c))
* **chat:** send a per-chat model choice to Hermes ([#300](https://github.com/cedricziel/hermes-app/issues/300)) ([8cafa79](https://github.com/cedricziel/hermes-app/commit/8cafa79c2621f55215787d226147adb38444b507))
* **chat:** use the composer card in the chat ([#308](https://github.com/cedricziel/hermes-app/issues/308)) ([9da65a6](https://github.com/cedricziel/hermes-app/commit/9da65a6a5c9f4e4ac60c621f886bc24ef2af63be))
* **kanban:** change a task's model from its panel and bulk-set effort ([#309](https://github.com/cedricziel/hermes-app/issues/309)) ([f1932f5](https://github.com/cedricziel/hermes-app/commit/f1932f551ce255a01a06619f28734e824aadfd67))
* **kanban:** choose a model and effort when creating a task ([#304](https://github.com/cedricziel/hermes-app/issues/304)) ([ce0a742](https://github.com/cedricziel/hermes-app/commit/ce0a742e7a6ff41c6a59da66790a647fe8219d87))
* **models:** add a model pill and picker ([#301](https://github.com/cedricziel/hermes-app/issues/301)) ([d6fdfd6](https://github.com/cedricziel/hermes-app/commit/d6fdfd694e7d363628a023e7a12c66aaeb4ae76b))
* **profiles:** change a profile's default model ([#303](https://github.com/cedricziel/hermes-app/issues/303)) ([4ae0c43](https://github.com/cedricziel/hermes-app/commit/4ae0c43ba585fda467c04f1a9f3b336ac9886de7))
* **schedules:** choose a job's model from the profile's list ([#305](https://github.com/cedricziel/hermes-app/issues/305)) ([51371f9](https://github.com/cedricziel/hermes-app/commit/51371f94ceb4b0551f65ee6696e73be68213942c))
* **settings:** add a helper models screen ([#306](https://github.com/cedricziel/hermes-app/issues/306)) ([6d810ab](https://github.com/cedricziel/hermes-app/commit/6d810abbf74908ff6ddaf5bf7edca746df54dc7d))
* **settings:** change the mixture-of-agents models ([#311](https://github.com/cedricziel/hermes-app/issues/311)) ([161a659](https://github.com/cedricziel/hermes-app/commit/161a6592367740ad32304e1fa7c773f496c444fe))


### Bug Fixes

* **chat:** complete a reply Hermes finished while disconnected ([#310](https://github.com/cedricziel/hermes-app/issues/310)) ([c4018d0](https://github.com/cedricziel/hermes-app/commit/c4018d0b9087df96e148c6447aa119bdea0b8a25))
* **chat:** decode HTML entities in replies ([#312](https://github.com/cedricziel/hermes-app/issues/312)) ([628434b](https://github.com/cedricziel/hermes-app/commit/628434b8980065082ef1c9b095001a714fce0f6d))
* **chat:** keep a mid-chat model switch on the session ([#314](https://github.com/cedricziel/hermes-app/issues/314)) ([6b895b0](https://github.com/cedricziel/hermes-app/commit/6b895b06132ca027475b363568b6bc9b8e4bc61e))
* **chat:** keep a streaming reply in view ([#299](https://github.com/cedricziel/hermes-app/issues/299)) ([80a0eb9](https://github.com/cedricziel/hermes-app/commit/80a0eb97a9a7a7d10e0f7530dd2da45980b5bf91))
* **chat:** mark a reply the user stopped after it had text ([#316](https://github.com/cedricziel/hermes-app/issues/316)) ([e072868](https://github.com/cedricziel/hermes-app/commit/e07286895a4dfc900f5b9d31c62553b83ac0a44a))
* **chat:** show why a reply failed under the text it kept ([#315](https://github.com/cedricziel/hermes-app/issues/315)) ([5937aa1](https://github.com/cedricziel/hermes-app/commit/5937aa1a41caad5b1e3a2696c76feefbe9a03180))
* **chat:** stop the transcript freezing past its end on iOS ([#313](https://github.com/cedricziel/hermes-app/issues/313)) ([cbae19d](https://github.com/cedricziel/hermes-app/commit/cbae19d053923b8eb4b750ffe4481d59e2209043))

## [0.1.37](https://github.com/cedricziel/hermes-app/compare/v0.1.36...v0.1.37) (2026-09-26)


### Features

* **watch:** add Action button shortcuts for voice and new chat ([#291](https://github.com/cedricziel/hermes-app/issues/291)) ([a50af19](https://github.com/cedricziel/hermes-app/commit/a50af19d17ee427b7572f892be4d6f69fb011f37))


### Bug Fixes

* **chat:** open markdown links when tapped ([#295](https://github.com/cedricziel/hermes-app/issues/295)) ([c256aa3](https://github.com/cedricziel/hermes-app/commit/c256aa37c4aa3f7069555a285c43de3a1fca6637))

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
