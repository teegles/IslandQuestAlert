Achievement progress is now read automatically—no setup required.

- Completed Helping Hand rescue criteria no longer cause recognized rescue alerts.
- Completed Tell Me a Tale quest criteria no longer cause item alerts.
- Earning criterion credit stops repeat alerts automatically.
- Whole-achievement completion silences its recognized objectives; expedition timing remains active.
- `/iqa status` includes completed/loaded criterion counts.

Update through WowUp using `https://github.com/teegles/IslandQuestAlert`.

Missing progress data or an unlinked generic marker remains eligible for an alert, to avoid hiding a needed objective. Criterion matching uses localized names, with English item-name fallbacks. Receiving an item is not treated as quest completion. Lua 5.1 and LuaJIT mock tests pass; in-game achievement and marker behavior still needs Retail validation.
