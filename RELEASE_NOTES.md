IslandQuestAlert can now flag possible enemy sources for your remaining Tale quests.

- Automatically compares observed enemy clues with incomplete achievement criteria.
- Recognizes the supplied farming leads for eleven items, including Pirates, Icetusk, Jinyu, Mantid and Hozen.
- Recognizes Vorus'arak by creature ID across languages.
- Shows a possible-source warning once per group/item per run; `/iqa prospects` lists the clues.
- Saves clues alongside each expedition, separately from actual needed-item receipts.

Update through WowUp from `https://github.com/teegles/IslandQuestAlert`.

A name clue is not loot eligibility or a guaranteed drop. The addon sees exposed attackable NPCs and visible positioned vignettes, not a full island roster. English name-fragment coverage is limited; no clue means unknown. Makrura are excluded from the unverified carapace association. Unknown achievement progress does not trigger missing-item source hints.

Lua 5.1/LuaJIT mock tests pass. Current Retail gameplay and UI behavior still require in-game validation.
