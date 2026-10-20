Track your island farming automatically with `/iqa` or `/iqa stats`.

- Persistent per-character history of every observed expedition, difficulty, result and time.
- Clear NEEDED ITEM markers when a received Tale item matches an incomplete criterion.
- Completed-run dry streak and needed/unknown/already-completed item receipt totals.
- Item details beside each run, with personal-loot/inventory source labels.
- Late return rewards linked within two minutes of completion and marked as inferred.
- Older/Newer pages, reload-safe run IDs and explicit offline-interruption records.

Update through WowUp using `https://github.com/teegles/IslandQuestAlert`.

Tracking starts with this update; earlier runs cannot be reconstructed. Unknown progress is labeled separately. Receipt statistics are not drop odds, and inventory increases may include bank/mail retrievals. Existing automatic alerts, achievement filtering and timing continue without configuration.

Lua 5.1/LuaJIT mock tests pass, including persistence, reward attribution, streaks, pagination and stats UI construction. In-game UI and legacy expedition behavior still require Retail validation.
