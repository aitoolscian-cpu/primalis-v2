# Event and Petition Framework

This subsystem is an isolated data and runtime foundation. It is not connected to the current game scene, does not pause simulation, and does not apply gameplay changes. A future integration layer may translate emitted declarative effects into commands for approved gameplay systems.

## Authored data

`EventDefinition` is a typed `Resource` containing a stable ID, presentation text, tags, integer priority, repeatability, trigger mode, conditions, one or more choices, participant keys, an optional camera-focus key, and memory tags. Those keys are strings—not scene-node references.

`EventChoice` contains its stable ID and text plus optional choice conditions, immediate effects, delayed effects and their simulation delay, and an optional follow-up event ID and delay. The number of choices is unrestricted above the validated minimum of one.

`EventCondition` compares a named context value with an authored serialization-safe value. Supported comparisons are equal, not equal, greater than, greater or equal, less than, and less or equal. Ordered comparisons require numbers. The manager augments supplied context with `event_seen.<EVENT_ID>` and `event_resolved.<EVENT_ID>` boolean keys, allowing history conditions without an expression language.

`EventEffect` is data only: a target key, an explicit `ADD`, `SET`, or `MULTIPLY` operation, and a serialization-safe value. Neither a definition nor the manager mutates settlement, Primalis, villager, relationship, or flag state.

Test-authored `.tres` definitions live under `data/events/test`. Their IDs and writing are deliberately marked as test content.

## Registry and validation

`EventRegistry` has explicit ownership and is not an autoload. Registration rejects null, malformed, blank-ID, or duplicate-ID definitions. Local validation covers choices, conditions, and effects. Once all definitions are registered, `validate_all()` additionally verifies that every follow-up ID exists. Errors are returned as useful strings rather than being silently ignored.

## Runtime flow

An explicitly owned `EventManager` receives a registry, supplied context dictionaries, and simulation-time deltas:

1. `evaluate_and_activate(context)` finds context-triggered eligible definitions.
2. Eligible definitions are ordered by priority descending, then `event_id` ascending.
3. The first definition activates when the manager is free. Remaining eligible definitions enter one deterministic queue.
4. Reevaluation may add eligible events to that queue, but never replaces the one active event.
5. `resolve_choice(choice_id)` validates the active choice, emits its immediate effect data, records history, schedules delayed work, clears the active event, and advances the queue.
6. `advance_time(delta)` processes compact scheduled lists. It creates no per-event `Timer` nodes and uses no wall-clock time.

Scheduled-only definitions are excluded from normal context evaluation. They enter the same queue only when a choice-created schedule reaches its trigger time. Simultaneous scheduled work is processed by trigger time and insertion sequence. The manager never changes `Engine.time_scale`; events remain interruptions inside a continuously running simulation.

Events fire once by default. A repeatable definition may become eligible again immediately after resolution; cooldown rules are intentionally left for a later design.

## History and future saves

The manager records unique seen IDs, unique resolved IDs, every selected choice ID, and chronological resolution records containing order, event ID, choice ID, and simulation time. `get_state_snapshot()` exports only simple Variant-compatible containers and primitives. `restore_state(snapshot)` validates and restores equivalent in-memory state, including active, queued, and scheduled work. This proves a future save boundary; it does not read or write files.

## Integration boundary

Future game code should own a registry and manager, build context from approved simulation state, feed simulation deltas, and subscribe to the manager signals. It may then interpret effect data through a separate adapter. UI, camera focus, notifications, Love/Fear/Bond logic, memory logic, and live gameplay mutation are deliberately outside this subsystem.
