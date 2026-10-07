# Third-party notices

Quest Flow's own code, documentation and art are released under the MIT License (see `LICENSE`). This file lists everything else that is distributed with Quest Flow, or that Quest Flow reads, and the notices that go with it.

## Distributed with the addon

### AllTheThings (ATT): quest, flight-path and zone data
The files `Data/Pack_ATT_Kalimdor.lua`, `Data/Pack_ATT_EasternKingdoms.lua`, `Data/Pack_ATT_Other.lua` and `Data/Pack_ATT_FlightPaths.lua` are generated from the AllTheThings "forever" database
(https://github.com/ATTWoWAddon/AllTheThings, commit `8e25511677df4ea5c3d0322009eafc18f203ffd3`), reduced to the fields Quest Flow uses. AllTheThings is licensed under the MIT License:

```
MIT License

Copyright (c) 2026 AllTheThings WoW Addon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Quest Flow labels everything it takes from these files as unverified (`src=att, verified=false`) and never presents it as confirmed on WoW Forever. Each file's header records its source and commit, and `Data/MANIFEST.txt` lists their checksums.

### Observed Forever data
`Data/Pack_Observed.lua` holds quest facts that were observed on a live WoW Forever client by this project's own recorder. It is the project's own data (MIT). Quest names and text in it belong to Blizzard Entertainment.

### Quest Flow art
`Media/*.tga` (the logo, the arrow and the small icons) were made for this project (MIT). The reward icons are drawn in code.

## Read at runtime, never distributed

### QuestieDB (optional)
If the player has the separate QuestieDB addon installed, Quest Flow can read quest information from it through its public API, and labels that information unverified. Nothing from QuestieDB is copied into, bundled with or redistributed by Quest Flow, and nothing from it is saved. It is optional and can be turned off (Quest Flow Options, "Use QuestieDB quest data if installed", or `/qflow questiedb off`). QuestieDB and Questie belong to their authors and keep their own license terms.

### The game client
Quest Flow reads the player's own character, quest log, item and map information from the game client while playing. It is stored only on the player's computer (in the addon's saved variables) and is never uploaded.

## Trademarks
World of Warcraft and Blizzard Entertainment are trademarks or registered trademarks of Blizzard Entertainment, Inc. Quest Flow is an independent fan-made addon. It is not affiliated with, endorsed by or supported by Blizzard Entertainment or by the WoW Forever project. Game fonts and textures are used in place from the game and are not included.
