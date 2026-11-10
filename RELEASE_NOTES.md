Fixes two enemy-detection coverage gaps and adds direct target diagnostics.

- Mantid rules now include Zara'thik, Wall-Breaker Ha'vik and Wingleader Srak'ik.
- Verified NPC IDs 139537, 139538 and 138843 work independently of client language.
- Nameplates already visible after reload are scanned, even without a new-plate event.
- `/iqa inspect` prints the current target's ID, match, achievement state and suppression reason, including a Sonic Stone check.
- Debug logs explain changed prospect decisions and non-attackable/dead unit exclusions.

Update through WowUp from `https://github.com/teegles/IslandQuestAlert`. If an enemy still produces no hint, target it and share `/iqa inspect` output.

Needed criteria are still required, and hints remain possible-source clues rather than promised drops. Lua 5.1/LuaJIT mock tests cover Mantid names/IDs, pre-existing nameplates, duplicate suppression, completed Sonic Stone and read-only inspection. The user's particular missed NPC is not yet confirmed without in-game target data.
