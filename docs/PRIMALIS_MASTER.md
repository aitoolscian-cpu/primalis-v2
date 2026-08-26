# PRIMALIS — MASTER SOURCE OF TRUTH

> **Project root:** `C:\Primalis`  
> **Project state:** Brand new. Clean slate. No previous game, prototype, codebase, model, scene, asset, animation, or implementation is assumed to exist.  
> **Engine:** Godot 4.x, GDScript-first.  
> **Document role:** This is the north-star document for the project. If a later prompt, agent, script, asset, or implementation conflicts with this document, this document wins unless the Creative Director explicitly changes it.  
> **Core production rule:** Build the game, play the game, capture the game, score the result, fix only what failed, repeat.  
> **Creative Director:** The human player/developer. AI assists with planning, implementation, art production, integration, criticism, and QA. AI does not silently redefine the game.

---

# 0. THE ONE-SENTENCE GAME

> **PRIMALIS is a cinematic survival city-builder / RTS / god-game / third-person action hybrid in which a vulnerable settlement raises Primalis from a needy young creature into the colossal protector it eventually cannot survive without.**

The emotional arc is:

> **At first, the village protects Primalis. Eventually, Primalis becomes the thing protecting the village.**

The final question of the game is:

> **What did we raise?**

---

# 1. NON-NEGOTIABLE NORTH-STAR RULES

These rules outrank individual mechanics.

## 1.1 This is a game that the player actively plays

PRIMALIS is **not** a slideshow, a collection of generated images, or a sequence of cinematics triggered by clicking dialogue boxes.

Most playtime is spent inside a continuously running real-time simulation.

The player:

- moves an RTS/god-view camera around the settlement;
- selects villagers and military units;
- assigns work and priorities;
- gathers and manages resources;
- places buildings manually;
- expands roads and infrastructure;
- constructs walls, gates, towers, workshops, farms and Primalis-specific structures;
- prepares for threats;
- reacts to crises;
- watches villagers live their lives;
- raises and teaches Primalis;
- calls, directs, praises, restrains or disciplines Primalis;
- deals with Primalis refusing orders or acting on his own;
- switches directly into Primalis;
- moves him in third person;
- runs, knuckle-walks, climbs, smashes, grabs, throws, protects, rescues and fights;
- switches back to RTS view at any time;
- manages battles that are actually occurring in the simulated world.

Events, petitions, dramatic shots and cinematic transitions exist to **punctuate gameplay**, not replace it.

### Permanent design test

Whenever a new idea sounds cool, ask:

> **What does the player actually DO?**

If the answer is only “watch it happen,” then either:

1. turn it into gameplay;
2. make it interactive;
3. use it sparingly as a short payoff to gameplay.

### Activity rule

> **The player should be making an interesting decision, solving a problem, directing the simulation, or physically controlling something almost constantly.**

---

# 2. WHAT PLAYING PRIMALIS SHOULD FEEL LIKE

Imagine approximately twenty minutes of normal play.

You are expanding a farm because food is running low.

Primalis is hungry and keeps hanging around the storehouse.

You assign builders to reinforce the western gate.

A villager reports that Primalis frightened her child. You must decide how to respond.

While dealing with that, a scout reports enemy troops.

You cancel construction on a temple because you need its timber for the wall.

Primalis gets annoyed because he has not been fed.

Enemy scouts appear.

You move militia onto the wall.

The attack starts.

Primalis initially does something foolish because he is still young.

You call him back.

He listens because you have developed a strong Bond with him.

Then you switch into him.

**Now you are Primalis.**

You run through your own village.

Civilians scatter around your feet.

You shoulder through the gate.

You knuckle-run toward the attackers.

You grab a soldier.

You throw him into a formation.

You smash the ground.

Primalis takes damage, so you retreat.

You switch back to RTS view.

You order medics toward casualties.

The eastern farm has caught fire.

Your food stockpile is collapsing.

Then someone tells you that three villagers are trapped outside the wall.

That is PRIMALIS.

The systems are not separate minigames. They collide with one another continuously.

---

# 3. THE FOUR INFLUENCE PILLARS

PRIMALIS takes inspiration from several games, but it is not a clone of any of them.

## 3.1 Frostpunk — pressure and consequences

Borrow the feeling of:

- scarcity;
- mounting pressure;
- events that demand attention;
- petitions;
- impossible trade-offs;
- survival under worsening conditions;
- the city visibly reacting to decisions;
- deciding what kind of society survives.

Do **not** copy Frostpunk's exact UI, laws, setting, resource chains, or structure.

## 3.2 Black & White — raising a living god-creature

Borrow the feeling of:

- a creature that exists in the world;
- praise and punishment;
- learned behaviour;
- affection;
- fear;
- worship;
- disobedience;
- personality;
- unpredictable behaviour;
- a relationship formed through actions rather than a simple upgrade screen.

Primalis must feel like a character with agency, not a giant selectable tank.

## 3.3 Classic RTS — building and defending

Borrow the feeling of:

- direct construction;
- resource allocation;
- units;
- walls;
- towers;
- troop positioning;
- defenses;
- attack preparation;
- real-time battles.

## 3.4 Third-person Primalis — fantasy payoff

At any suitable point, the player can stop looking down on the world and physically become the creature the settlement has raised.

This mode provides:

- movement;
- traversal;
- environmental interaction;
- combat;
- rescue;
- scale;
- intimacy with the village;
- the feeling that Primalis is a physical inhabitant of the same world.

These four pillars are not four unrelated games.

They all feed one fantasy:

> **Raise a god, build a society around him, survive together, and eventually experience the world through him.**

---

# 4. CORE PLAYER FANTASY

The village and Primalis must grow together.

Primalis must not simply gain `+10 Strength`.

The **entire settlement visibly changes because Primalis exists.**

When he is young:

- he has a den;
- food is brought to him;
- normal streets still fit him;
- villagers can physically approach him.

Later:

- his den becomes larger;
- a sanctuary is built;
- roads are widened because he no longer fits;
- feeding platforms become enormous;
- gates become Primalis-scale;
- walls gain areas designed for him to stand, brace or climb;
- soldiers gain positions from which they can fight beside him;
- temples become monumental;
- old scratches and damage remain;
- statues appear;
- children play near old footprints;
- buildings destroyed by tantrums or battles may be rebuilt differently;
- defensive architecture assumes that Primalis is part of the defense plan.

By the late game, an outsider should be able to look at the city and immediately understand:

> **This civilization evolved around living with a god-sized ape.**

---

# 5. FULL-GAME DESIGN TARGET

These are current planning targets, not promises to expand scope before the vertical slice is proven.

| Item | Target |
|---|---|
| Main campaign | One handcrafted valley/region |
| Campaign length | Roughly 8–12 hours |
| Main Hero | Primalis only |
| Primalis stages | Child → Juvenile → Adult → Titan |
| Major enemy structure | One human coalition that evolves tactics |
| Major bosses/set pieces | Approximately 4–5 |
| Endings | Approximately 3–4 |
| Named villagers | ~30 initially, potentially ~60–80 late game |
| Army scale | Tens of important simulated units; larger forces may be visually supplemented |
| Main player modes | RTS/god view + direct third-person Primalis |
| Core emotional arc | They protect him → fight beside him → he protects them |
| Art target | Cinematic stylized naturalism with AAA discipline, not photorealism |
| World design | Handcrafted, not a giant procedural open world |
| Development strategy | Prove one excellent vertical slice before expanding |

---

# 6. FIRST PRODUCTION GOAL — THE VERTICAL SLICE

The first real game we build is a **60–90 minute vertical slice** that proves the entire fantasy.

It contains:

1. one handcrafted valley sector;
2. one functioning village;
3. approximately 20–30 named villagers;
4. Child Primalis;
5. Juvenile Primalis;
6. Food;
7. Timber;
8. Stone;
9. Faith;
10. Houses;
11. Farm;
12. Storehouse;
13. Shrine;
14. Primalis Den;
15. Barracks / Training Yard;
16. Walls;
17. Gate;
18. one village soldier type;
19. one enemy infantry type;
20. a reusable event/petition system;
21. approximately twelve authored crises/events;
22. three escalating attacks;
23. Primalis needs;
24. Primalis mood;
25. Love;
26. Fear;
27. Bond;
28. praise / punishment / reinforcement;
29. one major growth sequence;
30. approximately five Primalis skills;
31. full RTS camera and command interaction;
32. direct third-person Primalis control;
33. one authored climbing/traversal sequence;
34. one boss/set-piece encounter;
35. one serious moral decision;
36. one consequence/ending sequence.

If the vertical slice is not compelling, we **fix the vertical slice**.

We do not solve weakness by adding more continents, factions, gods, buildings, technologies or systems.

---

# 7. VERTICAL-SLICE STORY

## 7.1 Opening — The Foundling

Approximately twenty people occupy a precarious settlement in a mountain valley.

Primalis is approximately 1.8 m tall.

He is not yet a weapon.

He is:

- hungry;
- playful;
- curious;
- sleepy;
- intrusive;
- capable of stealing food;
- capable of forming attachments;
- capable of accidentally damaging things;
- capable of frightening people without meaning to.

His oversized stone/log den communicates immediately that the settlement has reorganized part of its life around him.

The tutorial should not be a wall of popups.

The player learns because situations naturally require action.

Example:

- a farmer needs labour;
- Primalis becomes hungry;
- food must be gathered;
- someone feeds him;
- he performs a useful action;
- the player praises him;
- villagers visibly react.

The village begins to feel alive before the first major threat arrives.

---

## 7.2 First Crisis — Someone Knows

A scout reports outsiders.

Someone has discovered Primalis.

A serious petition appears:

> **Hide Primalis, or show them what protects the settlement?**

The decision can affect:

- Love;
- Fear;
- Bond;
- Primalis's learned behaviour;
- villager attitudes;
- enemy intelligence;
- later event conditions.

The event should have consequences without requiring the campaign to branch into two completely separate games.

---

## 7.3 Attack One — Protect Him

The attackers are not primarily coming to conquer the village.

They are coming for **Primalis**.

He can contribute, but he is vulnerable.

The militia and villagers are still protecting him.

This is essential.

The emotional arc fails if Primalis becomes an unstoppable monster immediately.

The first attack must communicate:

> **We are responsible for keeping him alive.**

---

## 7.4 Growth — Child to Juvenile

Food + care + Faith + narrative milestone unlock the first major growth stage.

Primalis physically changes.

The change is not just numerical.

The player should perceive:

- larger silhouette;
- lower-feeling camera when standing near him;
- deeper footsteps;
- heavier locomotion;
- new idle behaviour;
- changed voice;
- stronger interaction with objects;
- a den that suddenly looks too small;
- villagers reacting to his new size.

Desired reaction:

> **“Oh shit. He's actually growing.”**

---

## 7.5 Attack Two — Fight Beside Him

Primalis can now fight effectively.

A signature ability such as Stonefist becomes available.

The player can possess him directly.

He is dangerous, but the militia remains relevant.

This stage should feel like:

> **The village no longer only protects Primalis. They are beginning to fight together.**

---

## 7.6 Major Crisis — The Climb

A waterfall, cliff, ice wall, collapsed route, fortress face, or similar authored traversal space becomes central to a crisis.

Example:

Enemy raiders collapse the normal route above the village.

Several villagers are trapped.

The normal path is blocked.

Enemy forces are approaching.

Primalis can reach them only by climbing.

The player possesses Primalis and physically performs the traversal.

The sequence may include:

- choosing a route;
- hand and foot placement;
- authored handholds;
- falling debris;
- arrows/projectiles;
- breakable ice;
- slipping;
- recovering;
- ripping a handhold into a surface;
- saving villagers;
- pursuing an enemy commander;
- deciding which objective matters more.

This must be **gameplay**, not merely a cinematic.

---

## 7.7 Final Attack — He Protects Them

The enemy brings a weapon designed specifically to kill or neutralize Primalis.

The walls begin failing.

The village is in genuine danger.

Primalis must now take the larger role.

His learned behaviour matters.

Possible emergent/autonomous behaviours:

- shielding an injured villager;
- intercepting an incoming attack;
- returning when called;
- ignoring an order;
- pursuing fleeing enemies;
- protecting a bonded villager;
- attacking the anti-Primalis weapon;
- becoming enraged by a villager's death.

A compassionate Primalis and a ruthless Primalis may solve the same battle differently.

The vertical slice ends with the realization:

> **The creature the village once protected has become the reason the village is still standing.**

---

# 8. PRIMALIS — LIFE STAGES

The full game uses four canonical forms.

| Stage | Approximate Height | Character |
|---|---:|---|
| Child | ~1.8 m | curious, playful, dependent |
| Juvenile | ~2.7 m | energetic, impulsive, increasingly useful |
| Adult | ~4.5–5.5 m | powerful settlement guardian |
| Titan | ~9–12 m initially | genuinely architectural in scale |

Major shape changes happen at milestone stages.

Minor scaling may happen inside a stage, but we should not attempt a technically fragile continuous morph from child to Titan.

All canonical forms should share compatible skeleton naming wherever practical.

---

# 9. PRIMALIS — VISUAL DNA

Primalis should read as an original intelligent great-ape god-creature.

Core visual language:

- great-ape proportions;
- long functional arms;
- heavy shoulders;
- relatively short powerful legs;
- head carried low between the shoulders;
- large functional hands;
- broad functional feet;
- pronounced knuckles;
- near-black fur;
- readable fur mass rather than expensive strand-by-strand realism;
- stone-like plates/armour integrated into his silhouette;
- moss/vegetation in selected stone seams;
- amber/warm eyes;
- restrained natural adornment where useful;
- proportions that still read from the RTS camera.

He must not read as:

- a human in an ape suit;
- a fantasy orc;
- a random boulder monster;
- a gorilla copied literally from nature;
- a glossy videogame superhero;
- a giant whose detail only works in a close-up render.

---

# 10. PRIMALIS — MOVEMENT PHILOSOPHY

Animation is one of the project's highest quality bars.

Primalis should feel:

- heavy;
- grounded;
- animal;
- intelligent;
- physically powerful;
- capable of tenderness;
- increasingly monumental as he ages.

His normal locomotion should be informed by great-ape movement:

- knuckle-supported movement;
- heavy shoulder involvement;
- forelimbs visibly bearing weight;
- brief bent-knee/bent-trunk bipedal moments when appropriate;
- powerful hands and feet during climbing;
- less perfectly symmetrical movement than a generic humanoid rig.

Child/Juvenile Primalis can be more agile and playful.

Adult/Titan Primalis becomes heavier, more deliberate and less casually acrobatic.

---

# 11. PRIMALIS MOTION BIBLE — MASTER ANIMATION CATALOG

The final game may contain roughly 100 Primalis clips. The vertical slice only needs the subset required to make the first 60–90 minutes feel complete.

## 11.1 Core locomotion

| ID | Animation |
|---|---|
| PRI_LOC_001 | Neutral idle |
| PRI_LOC_002 | Breathing idle |
| PRI_LOC_003 | Curious idle |
| PRI_LOC_004 | Alert idle |
| PRI_LOC_005 | Angry idle |
| PRI_LOC_006 | Exhausted idle |
| PRI_LOC_007 | Injured idle |
| PRI_LOC_010 | Knuckle-walk start |
| PRI_LOC_011 | Knuckle-walk loop |
| PRI_LOC_012 | Knuckle-walk stop |
| PRI_LOC_013 | Slow stalk |
| PRI_LOC_014 | Knuckle-run |
| PRI_LOC_015 | Sprint / charge |
| PRI_LOC_016 | Move backwards |
| PRI_LOC_017 | Side movement left |
| PRI_LOC_018 | Side movement right |
| PRI_LOC_019 | Turn 45° left |
| PRI_LOC_020 | Turn 45° right |
| PRI_LOC_021 | Turn 90° left |
| PRI_LOC_022 | Turn 90° right |
| PRI_LOC_023 | Turn 180° |
| PRI_LOC_024 | Brief upright walk |
| PRI_LOC_025 | Quadruped → upright |
| PRI_LOC_026 | Upright → quadruped |

## 11.2 Child-specific behaviour

| ID | Animation |
|---|---|
| PRI_CHD_001 | Sit and inspect hands |
| PRI_CHD_002 | Play with rock |
| PRI_CHD_003 | Play with log |
| PRI_CHD_004 | Roll / play |
| PRI_CHD_005 | Chase villager |
| PRI_CHD_006 | Curious sniff |
| PRI_CHD_007 | Beg for food |
| PRI_CHD_008 | Excited jump |
| PRI_CHD_009 | Sulk |
| PRI_CHD_010 | Small tantrum |
| PRI_CHD_011 | Hide / cower |
| PRI_CHD_012 | Sleep curled |
| PRI_CHD_013 | Wake / stretch |

## 11.3 Social interaction

| ID | Animation |
|---|---|
| PRI_SOC_001 | Receive food |
| PRI_SOC_002 | Eat small food |
| PRI_SOC_003 | Eat large food |
| PRI_SOC_004 | Drink |
| PRI_SOC_005 | Accept affection |
| PRI_SOC_006 | Lean toward villager |
| PRI_SOC_007 | Gently inspect villager |
| PRI_SOC_008 | Pick up villager safely |
| PRI_SOC_009 | Put villager down |
| PRI_SOC_010 | Carry villager |
| PRI_SOC_011 | Protect villager |
| PRI_SOC_012 | Reject interaction |
| PRI_SOC_013 | Shove villager away |
| PRI_SOC_014 | Celebrate with crowd |
| PRI_SOC_015 | React to worship |
| PRI_SOC_016 | Enjoy worship |
| PRI_SOC_017 | Become overwhelmed by worship |
| PRI_SOC_018 | Grieve |
| PRI_SOC_019 | Rage at death |
| PRI_SOC_020 | Kneel toward village |

## 11.4 Emotional / display

| ID | Animation |
|---|---|
| PRI_EMO_001 | Content rumble |
| PRI_EMO_002 | Curious head tilt |
| PRI_EMO_003 | Frustration |
| PRI_EMO_004 | Snarl |
| PRI_EMO_005 | Threat display |
| PRI_EMO_006 | Chest beat |
| PRI_EMO_007 | Short roar |
| PRI_EMO_008 | Full roar |
| PRI_EMO_009 | Victory roar |
| PRI_EMO_010 | Fear |
| PRI_EMO_011 | Pain |
| PRI_EMO_012 | Defiance |
| PRI_EMO_013 | Sorrow |
| PRI_EMO_014 | Affection |

## 11.5 Combat

| ID | Animation |
|---|---|
| PRI_CBT_001 | Light swipe left |
| PRI_CBT_002 | Light swipe right |
| PRI_CBT_003 | Backhand |
| PRI_CBT_004 | Double-arm shove |
| PRI_CBT_005 | Stonefist windup |
| PRI_CBT_006 | Stonefist impact |
| PRI_CBT_007 | Ground smash |
| PRI_CBT_008 | Overhead smash |
| PRI_CBT_009 | Stomp |
| PRI_CBT_010 | Charge start |
| PRI_CBT_011 | Charge loop |
| PRI_CBT_012 | Charge impact |
| PRI_CBT_013 | Grab infantry |
| PRI_CBT_014 | Throw infantry |
| PRI_CBT_015 | Pick up boulder |
| PRI_CBT_016 | Boulder throw |
| PRI_CBT_017 | Brace / block |
| PRI_CBT_018 | Protect head |
| PRI_CBT_019 | Hit front |
| PRI_CBT_020 | Hit rear |
| PRI_CBT_021 | Hit left |
| PRI_CBT_022 | Hit right |
| PRI_CBT_023 | Heavy stagger |
| PRI_CBT_024 | Knockdown |
| PRI_CBT_025 | Recover from ground |
| PRI_CBT_026 | Low-health collapse |
| PRI_CBT_027 | Death |
| PRI_CBT_028 | Boss finisher |

## 11.6 Climbing

| ID | Animation |
|---|---|
| PRI_CLM_001 | Enter climb |
| PRI_CLM_002 | Hanging idle |
| PRI_CLM_003 | Reach high left |
| PRI_CLM_004 | Reach high right |
| PRI_CLM_005 | Push with left foot |
| PRI_CLM_006 | Push with right foot |
| PRI_CLM_007 | Vertical climb loop |
| PRI_CLM_008 | Traverse left |
| PRI_CLM_009 | Traverse right |
| PRI_CLM_010 | Break handhold |
| PRI_CLM_011 | Slip |
| PRI_CLM_012 | Recover from slip |
| PRI_CLM_013 | Ledge grab |
| PRI_CLM_014 | Pull over ledge |
| PRI_CLM_015 | Drop from ledge |
| PRI_CLM_016 | Ice-wall punch / grip |

## 11.7 Growth / cinematic motion

Potential bespoke animations:

- `GROWTH_CHILD_JUVENILE`
- `GROWTH_JUVENILE_ADULT`
- `GROWTH_ADULT_TITAN`
- `TITAN_KNEEL_VILLAGE`
- `TITAN_FINAL_SACRIFICE` — only if that ending remains in the final design

---

# 12. THE “MORE GORILLA” RULE

Creative feedback may be informal.

Example:

> “It's good, but he needs to move more like a gorilla.”

The pipeline converts that into a bounded repair task.

Example:

```text
ASSET: PRI_LOC_011_KNUCKLE_WALK

DO NOT CHANGE:
- model proportions
- stone armour
- movement speed
- camera
- environment

CHANGE:
- lower pelvis
- increase forward trunk angle
- increase arm weight-bearing
- increase forelimb contact duration
- make knuckle contact visibly carry mass
- reduce human-like hip rotation
- increase shoulder roll
- reduce perfectly mirrored gait
- improve hand/foot planting

REFERENCE:
PRI_REF_MOV_GORILLA_01

ACCEPTANCE:
- clearly quadrupedal at silhouette distance
- forelimbs visibly carry weight
- no obvious foot sliding
- no obvious hand sliding
- responsive under player control
```

Then:

1. animation is changed;
2. model is not casually replaced;
3. Godot is run;
4. A/B footage is captured;
5. the critic scores it;
6. only failed categories are revised;
7. the Creative Director approves or rejects it.

The important principle:

> **“AAA” is not an acceptance criterion. Measurable visual and gameplay behaviour is.**

---

# 13. PRIMALIS PERSONALITY AND RELATIONSHIP MODEL

Primalis must not be reduced to Good/Evil.

Internally, track:

| Value | Purpose |
|---|---|
| Hunger | immediate physical need |
| Fatigue | physical need |
| Attention | social need |
| Mood | immediate emotional state |
| Bond | how strongly Primalis considers the village “his” |
| Love | genuine positive relationship from villagers |
| Fear | intimidated reverence |
| Compassion ↔ Ruthlessness | moral tendency |
| Discipline ↔ Impulsiveness | learned behavioural tendency |
| Confidence | willingness to confront danger |
| Growth Progress | biological / supernatural development |

The player should not stare at eleven bars.

The primary understandable relationship values are:

- **Mood**
- **Bond**
- **Love**
- **Fear**

The hidden values drive behaviour.

---

# 14. LOVE, FEAR, BOND AND TEMPERAMENT

These axes must permit interesting combinations.

## High Love + High Bond

Beloved protector.

Primalis genuinely values the people and they genuinely value him.

## High Fear + High Bond

**Our monster.**

He may be terrifying and ruthless toward enemies, but he identifies the village as *his* people.

This is a core fantasy.

## High Fear + Low Bond

Tyrant.

The settlement survives under something it fears but does not truly own emotionally.

## High Love + Low Bond

Spoiled god.

Primalis enjoys adoration but may not sacrifice himself for the people.

## Temperament

Compassionate ↔ Ruthless is not identical to Love or Fear.

A ruthless Primalis can still possess extremely high loyalty.

A compassionate Primalis can still be feared because of his scale and power.

---

# 15. TEACHING, PRAISE, PUNISHMENT AND MEMORY

Primalis learns from how the player treats him.

Possible reinforcement:

- praise after protecting someone;
- praise after completing a task;
- affection;
- feeding;
- attention;
- withholding praise;
- discipline;
- interruption;
- restraint;
- anger from villagers;
- celebration;
- fear reactions.

He should remember meaningful events.

Examples:

- accidentally hurting a child;
- being chained;
- being celebrated;
- being starved so villagers could eat;
- being fed while villagers went hungry;
- a beloved elder dying;
- a particular villager repeatedly caring for him;
- being ordered to stop attacking;
- being allowed to keep attacking;
- saving people during a crisis.

Memories influence later autonomous decisions.

---

# 16. DISOBEDIENCE

Disobedience is not a bug.

It is one of the game's sources of personality and fun.

Primalis can:

- ignore a command;
- delay obeying;
- stop midway;
- pursue something more interesting;
- become angry;
- seek food;
- protect a bonded villager;
- attack someone the player wanted spared;
- refuse danger;
- act bravely without being ordered;
- become jealous or attention-seeking.

Disobedience must be understandable from his needs, training, relationships and personality.

It should not feel like random input failure.

---

# 17. PRIMALIS SKILL TREE

The full game target is approximately twenty meaningful abilities.

The vertical slice exposes only a small subset.

## BODY

### Stonefist
Heavy ground impact.

### Stonehide
Increased resistance.

### Crushing Grip
Enables larger object/enemy grabs.

### Colossal Charge
Charge through infantry and weak structures.

### Titan's Reach
Unlocks Titan-scale interaction and greater environmental manipulation.

## GUARDIAN

### Protective Instinct
Primalis may autonomously intercept threats near bonded villagers.

### Gentle Hands
Safer villager rescue and carrying.

### Wallkeeper
Brace gates/walls and reduce siege damage.

### Rallying Roar
Boost friendly morale.

### Last Guardian
Major defensive bonus when the settlement is critically threatened.

## INSTINCT

### Keen Senses
Detect ambushes, scouts or hidden danger.

### Cliffborn
Improves authored traversal/climbing options.

### Forager
Discover food/resources.

### Rapid Recovery
Faster recovery from wounds/exhaustion.

### Unbreakable Will
Resistance to panic, suppression and anti-Primalis effects.

## PRESENCE

### Revered
Greater Love-based Faith generation.

### Dread Roar
Stronger enemy fear.

### Commanding Presence
Villagers react more strongly to him.

### Sacred Ground
Bonuses near his den, shrine, resting place, or chosen sacred location.

### Our God
Final Presence ability. Its exact behaviour changes according to how Primalis was raised.

Do not reduce the tree to glowing “good abilities” versus flaming “evil abilities.”

Love/Fear and temperament should alter context and outcome.

---

# 18. CITY EVOLUTION AROUND PRIMALIS

## Child Era

- small den;
- ordinary roads;
- low shrine;
- villagers carry food directly;
- architecture is mostly human-scaled.

## Juvenile Era

- larger feeding area;
- wider route to den;
- first reinforced gate;
- scratch/damage marks;
- training/play area;
- buildings begin acknowledging his scale.

## Adult Era

- Primalis-scale avenue;
- elevated pedestrian solutions where useful;
- giant feeding platform;
- wall sections designed for him;
- oversized gate;
- soldier platforms positioned for combined fighting;
- temple expansion.

## Titan Era

- architecture unmistakably shaped around him;
- huge gate;
- massive wall platform;
- Titan ritual plaza;
- deliberate movement corridors;
- giant defensive footholds;
- structures Primalis can brace or operate;
- monumental visual relationship between city and god.

End-state visual rule:

> **The settlement itself tells the history of raising Primalis.**

---

# 19. BUILDING CATALOG

The first commercial-sized campaign should stay disciplined.

| ID | Building |
|---|---|
| BLD_001 | Central Hearth / Town Square |
| BLD_002 | House A |
| BLD_003 | House B |
| BLD_004 | Communal Kitchen |
| BLD_005 | Farm |
| BLD_006 | Storehouse / Granary |
| BLD_007 | Lumber Yard |
| BLD_008 | Quarry |
| BLD_009 | Workshop |
| BLD_010 | Infirmary |
| BLD_011 | Shrine |
| BLD_012 | Temple |
| BLD_013 | Primalis Den |
| BLD_014 | Primalis Feeding Platform |
| BLD_015 | Barracks / Training Yard |
| BLD_016 | Watchtower |
| BLD_017 | Wall |
| BLD_018 | Gate |

Every important building should eventually support:

- construction state;
- intact state;
- damaged state;
- destroyed state.

Important buildings may also gain authored upgrade states.

Use authored destruction states rather than attempting fully simulated physics destruction everywhere.

---

# 20. RESOURCES AND CITY STATISTICS

The vertical slice starts with four core resources.

| Resource | Function |
|---|---|
| Food | feeds villagers and Primalis |
| Timber | construction |
| Stone | stronger construction and defenses |
| Faith | worship, rituals, progression and Primalis-related systems |

Separate city statistics may include:

- Population;
- Health;
- Resolve;
- Security.

Love and Fear are **not currencies spent like gold**.

They represent relationships and social state.

Additional resources such as Metal or Medicine are not added until the core game proves that they improve decision-making.

---

# 21. VILLAGERS

Villagers must feel like inhabitants, not anonymous worker dots.

Desired features:

- names;
- homes;
- jobs;
- health;
- relationships;
- current activity;
- reactions to Primalis;
- reactions to crises;
- fear/panic;
- celebrations;
- grief;
- worship;
- injury;
- death.

The player should be able to zoom in and watch them live.

The exact depth of family/age simulation is deliberately constrained until the vertical slice is proven.

The emotional target is that at least some villagers become recognizable enough that losing them matters.

---

# 22. VILLAGER ANIMATION NEEDS

Approximate humanoid animation library:

- idle;
- walk;
- run;
- carry;
- hammer;
- saw;
- farm;
- dig;
- lift;
- push;
- eat;
- drink;
- sit;
- talk gesture ×3;
- cheer;
- worship;
- kneel;
- pray;
- panic;
- flee;
- basic fight;
- injured walk;
- fall;
- death ×2;
- sleep;
- wake;
- hug;
- grieve;
- point;
- wave.

Reuse/retarget high-quality licensed humanoid animation where practical.

Do not waste bespoke animation budget on generic motions that already exist legally.

---

# 23. MILITARY

## Vertical slice

### Village Militia

- one base body/skeleton;
- one core weapon family;
- a few head/face variations;
- one clear village-defense clothing/armour language.

### Enemy Infantry

- compatible animation approach where practical;
- clearly different silhouette;
- different palette;
- different weapon language.

The first playable game does not require twenty-seven military unit classes.

## Potential later expansion

- village guard;
- medic;
- engineer;
- heavy soldier;
- enemy hunter;
- enemy heavy;
- anti-Primalis crew.

Only add them if the gameplay earns the complexity.

---

# 24. EVENTS AND PETITIONS

Events are a core system, but they are interruptions **inside a running game**.

They are not the main mode of play.

Each event should support structured data such as:

```text
event_id
title
trigger
participants
conditions
body_text
choice_A
choice_B
optional_choice_C
immediate_effects
delayed_effects
primalis_memory_tag
villager_memory_tag
love_delta
fear_delta
bond_delta
temperament_delta
followup_event
camera_focus_target
```

## Vertical-slice event set

1. Primalis steals emergency food.
2. A child approaches him.
3. Primalis accidentally injures someone.
4. Workers demand a larger food ration.
5. Priests demand a ritual.
6. Soldiers request restraints/chaining procedures.
7. An enemy scout is captured.
8. A beloved elder becomes seriously ill.
9. Primalis refuses a command.
10. Refugees arrive.
11. Someone killed during an attack receives a funeral.
12. Primalis pursues retreating enemies.

Other important future event concepts:

- enough food exists either to feed the city or trigger Primalis's growth;
- military requests priority over a monument;
- priests request priority over fortifications;
- refugees fear Primalis;
- Primalis becomes jealous of a celebrated general;
- Primalis wants to play while fortifications urgently need stone moved;
- Primalis kills surrendering enemies;
- villagers disagree over whether his violence is protection or monstrosity.

Events should create consequences, memories and future gameplay conditions.

---

# 25. SIGNATURE CRISIS DESIGN

Example late-game crisis:

> The western wall has collapsed. Villagers are trapped beyond it. Enemy forces will reach them before the army can. Primalis can climb a frozen cliff to rescue them, but abandoning the eastern gate may expose the settlement.

This is the standard to aim for.

It combines:

- RTS defense;
- population risk;
- geography;
- Primalis traversal;
- direct control;
- emotional attachment;
- resource consequences;
- strategic trade-off.

A strong event creates gameplay rather than merely describing a choice.

---

# 26. CAMPAIGN STRUCTURE

## PROLOGUE — THE CHILD

- village building;
- care;
- basic Primalis teaching;
- minor local problems;
- first discovery by outsiders.

## ACT I — THE HUNT

- raids begin;
- enemy specifically seeks Primalis;
- Juvenile growth;
- first major moral decisions;
- first serious third-person combat.

Potential boss:
- specialized hunter commander/team.

## ACT II — THE WALL

- village fortifies;
- Adult Primalis emerges;
- enemy army size and coordination increase;
- Primalis participates directly in defense.

Potential boss:
- anti-Primalis siege weapon.

## ACT III — THE WINTER

- worsening weather;
- food pressure;
- ice/waterfall/cliff traversal;
- civilian rescue;
- hard allocation decisions;
- relationship stress outside combat.

Potential boss:
- combined environmental crisis + coordinated assault rather than a simple health-bar monster.

## ACT IV — THEIR GOD

- enemies view Primalis as an existential threat;
- city architecture visibly revolves around him;
- largest assault;
- Titan growth.

Potential boss:
- final anti-Titan war machine / commander / siege plan.

## FINALE — WHAT DID WE RAISE?

Potential outcomes:

### Guardian
A deeply bonded Primalis willingly sacrifices himself.

### Our Monster
Primalis survives by doing something horrifying but effective to save his people.

### Exodus
Primalis saves the population but the settlement itself is lost.

### Tyrant
The settlement survives under the rule of the being it created.

These are possibilities, not fixed final answers.

The final ending should emerge from the system and character we actually build.

---

# 27. ART DIRECTION — CINEMATIC STYLIZED NATURALISM

The target is:

> **Cinematic Stylized Naturalism**

It is:

- not cartoon;
- not photoreal;
- not generic medieval;
- not steampunk;
- not generic low-poly;
- not an asset-store collage.

Geometry may be simplified for performance, but:

- proportion;
- silhouette;
- animation;
- lighting;
- composition;
- material consistency;
- camera;
- sound;
- responsiveness

are treated seriously.

Visual progression:

> **Warm fragile settlement → fortified settlement → cold threatened settlement → monumental city of Primalis.**

---

# 28. WHAT “AAA” MEANS FOR PRIMALIS

AAA does **not** mean:

- Red Dead Redemption realism;
- individual realistic fur strands;
- 4K textures on everything;
- millions of polygons;
- giant expensive simulation systems;
- every object being custom-made.

AAA discipline means:

- consistent silhouettes;
- excellent animation;
- excellent lighting;
- readable composition;
- beautiful camera behaviour;
- coherent material language;
- strong sound;
- responsive input;
- polished UI;
- no floating props;
- no obvious AI geometry errors;
- no six unrelated art styles;
- no unnecessary detail invisible to the player;
- meticulous screenshot-by-screenshot polish;
- consistency across every screen.

A visually simple game can feel premium if every decision appears intentional.

---

# 29. COLOR BIBLE

This palette is a starting north-star palette and may be tuned through visual Gauntlet passes.

## 29.1 Village / landscape

| Role | HEX |
|---|---|
| Grass | `#6F7E55` |
| Light Grass | `#7D8C5F` |
| Deep Vegetation | `#3F5236` |
| Dark Vegetation | `#506442` |
| Path | `#B59A72` |
| Soil | `#8A673F` |
| Light Plaster | `#D9D2C3` |
| Concrete / Pale Stone | `#B7B9B8` |
| Timber | `#7A5B3A` |
| Dark Timber | `#5C452C` |
| Slate | `#4B5663` |
| Rock | `#7B8085` |
| Sacred Gold | `#D6B15D` |

## 29.2 Primalis

| Role | HEX |
|---|---|
| Primary Fur | `#252725` |
| Warm Fur Highlight | `#34342F` |
| Deep Fur Shadow | `#181A19` |
| Stone Plate | `#68716B` |
| Stone Highlight | `#89928A` |
| Moss | `#55704A` |
| Bone | `#D2C4A4` |
| Hide | `#76573D` |
| Eye Amber | `#D5A243` |

## 29.3 Threat / winter

| Role | HEX |
|---|---|
| Cold Shadow | `#4A5D6B` |
| Ice | `#A9C3CD` |
| Snow | `#DDE3E3` |
| Storm | `#66727C` |
| Enemy Iron | `#484E53` |
| Enemy Banner Red | `#7A302F` |
| Danger Highlight | `#A9433D` |

## 29.4 Love language

- warm amber;
- soft gold;
- firelight;
- healthy vegetation;
- natural cloth;
- comfortable visual density.

## 29.5 Fear language

- burnt crimson;
- smoky violet-black;
- harder contrast;
- longer shadows;
- lower vegetation saturation;
- more severe architectural treatment.

Do **not** simply turn cruel Primalis into a glowing red demon.

Morality should alter appearance gradually and believably.

---

# 30. LIGHTING BIBLE

## Morning

- cool environment;
- warm low sun;
- long readable shadows.

## Midday

- neutral;
- clean visibility;
- least dramatic;
- useful for gameplay readability and QA.

## Golden Hour

Primary beauty-shot state.

- warm architecture;
- long shadow shapes;
- Primalis rim lighting;
- village looks worth protecting.

## Night

- moonlit blue-grey environment;
- localized fire/window emissives;
- strong silhouettes;
- limited realtime-light cost.

## Storm

- desaturated;
- cold sky;
- settlement warmth becomes visually precious.

## Final Siege

- cold / ash environment;
- fire and Primalis become major sources of visual warmth and focus.

---

# 31. TREE BIBLE

Yes: every tree family is planned.

First biome:

| Family | Variants | Purpose |
|---|---:|---|
| Alpine Spruce | 3 | main forest mass |
| Silver Birch | 3 | lighter contrast near village |
| Mountain Pine | 3 | windswept ridges |
| Ancient Cedar | 2 | hero / landmark trees |
| Dead Snag | 3 | winter / damage dressing |

Additional:

- fallen logs ×4;
- stump sizes ×2;
- chopped stump states ×2;
- wood pile family ×1.

Live trees should receive appropriate LOD strategy.

Variation should come from:

- rotation;
- controlled scale;
- material variation;
- variant selection;

not from authoring 100 unrelated tree models.

---

# 32. VEGETATION BIBLE

Vertical slice target:

- 5 tree families;
- 3 bushes;
- 3 scrub clumps;
- 4 grass clumps;
- 3 flower clumps;
- 2 reed variants;
- 4 crop growth stages;
- 2 moss decals;
- 3 fallen-leaf/debris ground patches.

Enough diversity to feel natural without burying development in plant production.

---

# 33. ROCK AND TERRAIN KIT

Target kit:

- small rocks ×4;
- medium boulders ×4;
- large boulders ×4;
- cliff modules ×3;
- cliff corners ×2;
- cliff caps ×2;
- scree patches ×3;
- moss variants ×2;
- Primalis climbing-wall kit ×1;
- frozen climbing-wall variant ×1;
- waterfall cliff set ×1.

Terrain material families:

- grass;
- dry grass;
- dirt;
- mud;
- stone;
- scree;
- sand/gravel;
- snow;
- ice;
- worn path.

---

# 34. ASSET SOURCING PHILOSOPHY

We do not need to model every barrel, rock, tree or generic villager from scratch.

Originality budget goes primarily to:

- Primalis;
- the relationship between Primalis and the settlement;
- settlement architecture shaped around Primalis;
- signature enemies/bosses;
- important set pieces;
- major UI identity;
- art direction;
- character moments;
- world-specific props.

Generic assets may be reused when legally safe and visually integrated.

A reused asset must not make the game look like an asset flip.

---

# 35. LICENSE RULES

Every third-party asset is individually documented.

“Free download” does not mean “commercially safe.”

## GREEN — preferred

Sources/assets with permissive commercial-use licensing such as properly verified CC0 assets.

Likely first places to investigate:

- Poly Haven;
- Quaternius;
- Kenney.

Licensing must still be verified and recorded at acquisition time.

## YELLOW — inspect each item

Examples:

- CGTrader;
- Sketchfab;
- itch.io asset creators;
- other marketplaces.

Each individual asset may have different terms.

## RED — never ship

Do not use:

- no-license assets;
- non-commercial assets;
- editorial-only assets;
- no-derivatives assets when modification is required;
- ripped game assets;
- copyrighted fan models from unrelated franchises;
- unlicensed real-brand content;
- random download mirrors;
- assets whose origin cannot be proven.

---

# 36. AI-PROCESSING LICENSE RULE

An asset may be legal to include in a game but prohibited from being uploaded to a generative AI service.

The asset ledger therefore contains:

```text
AI_PROCESSING_ALLOWED = YES / NO / UNKNOWN
```

Unknown means do not upload it to external AI generation systems until checked.

---

# 37. ASSET LEDGER — REQUIRED FIELDS

Every production asset gets a ledger entry.

```text
asset_id
name
category
description
priority
source_type
source_url
creator
license
license_snapshot
download_date
commercial_ok
derivatives_ok
attribution_required
AI_processing_allowed
original_filename
original_hash
master_blend
export_glb
scale_m
pivot_rule
LOD0_tris
LOD1_tris
LOD2_tris
texture_budget
material_family
collision_type
rig
animation_set
godot_scene
status
RTS_QA_score
close_QA_score
thirdperson_QA_score
performance_score
notes
```

Status progression:

```text
NEEDED
REFERENCE
SOURCED
MODEL
MATERIAL
RIG
ANIMATION
INTEGRATION
QA
APPROVED
SHIPPED
```

---

# 38. ASSET CREATION PIPELINE

For every required visual asset:

## Stage A — Search

Ask:

> Does a legally usable asset already exist?

Search preferred safe libraries first.

## Stage B — Adapt

If sourced:

- import;
- normalize dimensions;
- apply transforms;
- clean unnecessary geometry;
- remap materials;
- adjust silhouette;
- make LODs;
- create collision;
- export;
- test in game.

## Stage C — Procedural / scripted Blender

Ideal candidates:

- houses;
- walls;
- gates;
- watchtowers;
- feeding platforms;
- crates;
- barrels;
- benches;
- architecture modules;
- some rocks/cliffs.

Scripted source is valuable because proportions remain editable and families stay consistent.

## Stage D — Custom organic production

Reserved for:

- Primalis;
- signature creatures;
- major bosses;
- assets that generic generation cannot produce cleanly.

Potential path:

> approved concept → generated/base geometry if useful → Blender cleanup → canonical mesh → canonical rig → game export

Once accepted, the canonical `.blend` source is authoritative.

## Stage E — In-game test

Never approve an asset because it looks good only in Blender.

The actual Godot gameplay camera is the referee.

---

# 39. PRIMALIS ASSET PIPELINE

Primalis must not be regenerated casually after production begins.

Pipeline:

1. visual brief;
2. front/side/rear/three-quarter references;
3. silhouette approval;
4. base mesh;
5. anatomy/proportion Gauntlet;
6. hands/feet Gauntlet;
7. stone/fur/material Gauntlet;
8. canonical Blender source;
9. canonical skeleton;
10. rig test;
11. locomotion test;
12. animation library;
13. Godot AnimationTree;
14. third-person gameplay;
15. combat integration;
16. growth-stage integration;
17. ongoing animation-only revisions where possible.

Once the canonical skeleton exists:

> **Do not casually replace it.**

Animation investment compounds over time.

---

# 40. REFERENCE IMAGE LIBRARY

References belong in the repository, not scattered through chats.

## 40.1 World

- `REF_WORLD_001` — RTS north-star village
- `REF_WORLD_002` — same village close zoom
- `REF_WORLD_003` — same village at Primalis third-person height
- `REF_WORLD_004` — dawn
- `REF_WORLD_005` — golden hour
- `REF_WORLD_006` — night
- `REF_WORLD_007` — rain
- `REF_WORLD_008` — winter
- `REF_WORLD_009` — siege
- `REF_WORLD_010` — post-battle damaged settlement

## 40.2 Primalis

For each life stage:

- front;
- rear;
- side;
- three-quarter;
- silhouette;
- hand;
- foot;
- neutral face;
- angry face;
- content face.

Four stages × ten images = approximately forty canonical Primalis reference images.

## 40.3 Architecture

- village house;
- farm;
- storehouse;
- workshop;
- infirmary;
- shrine;
- temple;
- Den Stage 1;
- Den Stage 2;
- Den Stage 3;
- feeding platform;
- wall;
- gate;
- watchtower;
- barracks.

## 40.4 Set pieces

- waterfall;
- ice wall;
- Primalis climbing;
- Primalis protecting gate;
- Primalis sheltering villagers;
- Primalis fighting an army;
- Titan from village street level;
- final siege;
- possible sacrifice scene.

## 40.5 Clothing

- worker;
- farmer;
- builder;
- priest;
- militia;
- officer;
- child;
- elder;
- enemy infantry;
- anti-Primalis crew.

## 40.6 Materials

- timber;
- slate;
- plaster;
- pale stone/concrete;
- rock;
- moss;
- iron;
- cloth;
- leather;
- snow;
- ice;
- mud.

---

# 41. PERMANENT GAMEPLAY QA CAPTURE SUITE

Important visual changes are judged from repeatable in-game views.

Target captures:

- `QA_RTS_VILLAGE_DAY`
- `QA_RTS_VILLAGE_NIGHT`
- `QA_RTS_ATTACK`
- `QA_RTS_WINTER`
- `QA_CLOSE_MARKET`
- `QA_CLOSE_PRIMALIS_CHILD`
- `QA_CLOSE_PRIMALIS_ADULT`
- `QA_TP_VILLAGE`
- `QA_TP_COMBAT`
- `QA_TP_CLIMB`
- `QA_TITAN_SCALE`
- `QA_DAMAGE_AFTER_BATTLE`

As development progresses, automation should capture these where practical.

---

# 42. VISUAL SHIPPING SCORECARD

Major visual passes are scored.

| Category | Target |
|---|---:|
| Composition | ≥ 8/10 |
| Silhouette | ≥ 8/10 |
| Scale | ≥ 8/10 |
| Animation | ≥ 8/10 |
| Material Consistency | ≥ 8/10 |
| Lighting | ≥ 8/10 |
| Environmental Logic | ≥ 8/10 |
| UI Readability | ≥ 8/10 |
| Camera | ≥ 8/10 |
| Performance | PASS |

High texture quality cannot compensate for poor animation.

A large amount of changed work is not evidence that something improved.

---

# 43. THE GAUNTLET LOOP — PERMANENT PRODUCTION LAW

Every meaningful feature, system, visual asset, animation, UI screen or set piece must use the Gauntlet Loop.

## Step 1 — Goal

State exactly what we are trying to improve.

Bad:

> Make it AAA.

Good:

> Make Primalis's juvenile knuckle-run feel heavy, ape-like and responsive at third-person gameplay speed.

## Step 2 — Lock

State what must not change.

Examples:

- camera;
- environment;
- model proportions;
- working combat code;
- approved buildings;
- approved palette.

## Step 3 — Criteria

Define measurable acceptance criteria **before** implementation.

Example:

- silhouette reads as quadrupedal;
- forelimbs carry visible weight;
- no hand sliding;
- no foot sliding;
- turn response remains under the agreed threshold;
- camera does not clip;
- FPS remains within target.

## Step 4 — Build

Implement only the requested task.

## Step 5 — Run

Run the real Godot game.

A script compiling is not enough.

## Step 6 — Capture

Capture:

- screenshots;
- video;
- performance numbers;
- relevant logs.

Use the real gameplay camera.

## Step 7 — Blind Critique Where Useful

For major visual comparisons, the critic should not automatically be told which version is newer.

This reduces “we changed it, therefore it must be better” bias.

## Step 8 — Score

Score every predefined criterion.

## Step 9 — Fail

Identify only the categories below threshold.

## Step 10 — Fix

Change only the failed areas unless a dependency requires broader work.

## Step 11 — Repeat

Run → capture → score again.

## Step 12 — Approve

The task ships only when:

- functional criteria pass;
- visual criteria pass;
- performance criteria pass;
- no protected area regressed;
- Creative Director approves.

### Permanent Gauntlet principle

> **Screenshots and gameplay footage are the referee.**

Not code volume.

Not token usage.

Not agent confidence.

Not how complicated the implementation was.

---

# 44. DECISION OWNERSHIP

Every important design decision should be tagged.

Recommended tags:

```text
[USER-LOCKED]
[AI-PROPOSED]
[TESTING]
[DEFERRED]
[REJECTED]
```

Rules:

- `[USER-LOCKED]` is not changed by an agent.
- `[AI-PROPOSED]` is a suggestion, not canon.
- `[TESTING]` is deliberately provisional.
- `[DEFERRED]` is not part of current scope.
- `[REJECTED]` should not quietly return later.

If a locked decision changes, record the change in `DECISIONS.md`.

This prevents AI suggestions from later being quoted as if the Creative Director asked for them.

---

# 45. GODOT TECHNICAL DIRECTION

Current default:

- Godot 4.x stable;
- GDScript-first;
- 3D;
- desktop-first;
- third-person + RTS camera;
- metre-scale world;
- glTF/GLB for production 3D interchange where practical;
- modular scripts;
- Godot `Resource` definitions for data-heavy systems;
- profile early.

Do not engine-hop unless a proven blocking technical issue exists.

---

# 46. GODOT ARCHITECTURE

Avoid a giant monolithic `primalis.gd`.

Suggested structure:

```text
scripts/
├── core/
│   ├── game_state.gd
│   ├── time_manager.gd
│   ├── event_bus.gd
│   ├── save_manager.gd
│   └── audio_manager.gd
│
├── primalis/
│   ├── primalis_controller.gd
│   ├── primalis_needs.gd
│   ├── primalis_mood.gd
│   ├── primalis_bond.gd
│   ├── primalis_learning.gd
│   ├── primalis_growth.gd
│   ├── primalis_abilities.gd
│   ├── primalis_autonomy.gd
│   ├── primalis_combat.gd
│   └── primalis_animation.gd
│
├── villagers/
│   ├── villager.gd
│   ├── villager_needs.gd
│   ├── villager_jobs.gd
│   ├── villager_relationships.gd
│   └── villager_ai.gd
│
├── settlement/
│   ├── resources.gd
│   ├── construction.gd
│   ├── population.gd
│   ├── faith.gd
│   └── defense.gd
│
├── combat/
├── events/
├── rts/
└── ui/
```

Balancing values should live in data/resources where practical rather than being buried throughout scripts.

---

# 47. CAMERA SYSTEM

## RTS / God View

The player can:

- pan;
- rotate;
- zoom;
- select;
- place buildings;
- command;
- inspect.

Close zoom must be sufficient to watch villagers and Primalis behave.

## Third-Person Primalis

Over-shoulder / trailing camera.

It should:

- scale appropriately with growth stage;
- adapt near architecture;
- avoid constant clipping;
- communicate mass;
- use controlled impact shake;
- remain responsive.

## Possession Transition

Switching should feel fast.

Possible transition:

- brief camera move;
- very short slowdown for orientation if needed;
- gameplay resumes immediately.

The simulation does not freeze simply because the player is controlling Primalis.

Returning to RTS view is quick.

---

# 48. CLIMBING IMPLEMENTATION

Do not build universal “climb anything” traversal initially.

Use authored `PrimalisTraversalZone` areas.

A zone may contain:

- allowed entry points;
- anchor data;
- hand/foot targets;
- route branches;
- breakable anchors;
- camera rules;
- event triggers;
- exit points.

When Primalis enters:

1. locomotion state changes;
2. animation/IK controls hand and foot placement;
3. traversal camera activates;
4. authored hazards can occur.

This allows spectacular:

- waterfalls;
- cliffs;
- ice walls;
- fortress walls;
- collapsed dams;
- rescue climbs

without solving arbitrary giant-creature climbing for the entire world.

---

# 49. COMBAT PRINCIPLES

Primalis combat must feel powerful without trivializing settlement defense.

RTS layer remains relevant because:

- Primalis can be injured;
- threats may exist in multiple places;
- civilians need protection;
- structures matter;
- anti-Primalis weapons exist;
- Primalis may disobey;
- the player cannot solve every simultaneous problem by punching it.

Third-person combat focuses on clear powerful verbs:

- swipe;
- shove;
- smash;
- stomp;
- charge;
- grab;
- throw;
- block;
- protect;
- rescue;
- roar.

Do not turn Primalis into a character-action game with a 60-hit combo list.

---

# 50. AUDIO BIBLE — PRIMALIS

Primalis needs a recognizable voice identity.

Minimum conceptual vocal library:

- idle rumble ×4;
- content rumble ×3;
- curious sound ×3;
- food anticipation ×2;
- eating ×4;
- irritation ×3;
- snarl ×4;
- short roar ×3;
- full roar ×3;
- pain light ×4;
- pain heavy ×3;
- fear ×2;
- grief ×2;
- victory ×3;
- exhaustion ×3;
- sleep breathing;
- wake sound.

Approximately 45–50 vocal assets eventually.

Footstep surface families:

- dirt;
- grass;
- stone;
- wood;
- mud;
- snow;
- ice;
- debris.

Adult/Titan movement should layer in deeper impact/body resonance rather than merely increasing volume.

---

# 51. MUSIC

Do not overproduce the soundtrack during prototyping.

Vertical slice needs approximately:

1. Village Calm
2. Village Tension
3. Incoming Attack
4. Combat
5. Primalis Growth
6. Boss / Major Threat
7. Aftermath

The purpose is to establish the musical language.

---

# 52. UI PRINCIPLES

Events must demand attention without forcing the player to live inside spreadsheets.

## Main HUD

Potentially:

- resources;
- population / health / resolve;
- Primalis portrait/status;
- event notifications;
- build controls;
- alert indicators.

## Primalis panel

Primary information:

- Mood;
- Hunger;
- Fatigue;
- Bond;
- Love / Fear;
- skills.

Do not expose every hidden personality variable.

## Villager panel

Show useful human information:

- name;
- age if age remains in scope;
- job;
- home/family where implemented;
- health;
- current thought/action.

Do not show twenty meaningless stats.

---

# 53. REPOSITORY STRUCTURE — CLEAN-SLATE PROJECT

The project begins from:

```text
C:\Primalis
```

Recommended long-term structure:

```text
C:\Primalis
├── project.godot
│
├── docs/
│   ├── PRIMALIS_MASTER.md
│   ├── VERTICAL_SLICE.md
│   ├── ART_BIBLE.md
│   ├── PRIMALIS_BIBLE.md
│   ├── ANIMATION_BIBLE.md
│   ├── ASSET_LEDGER.csv
│   ├── LICENSE_LEDGER.csv
│   ├── REFERENCE_INDEX.md
│   ├── DECISIONS.md
│   └── QA_GATES.md
│
├── references/
│   ├── world/
│   ├── primalis/
│   ├── architecture/
│   ├── villagers/
│   ├── animation/
│   ├── materials/
│   ├── ui/
│   └── setpieces/
│
├── art_source/
│   └── blender/
│       ├── primalis/
│       ├── villagers/
│       ├── buildings/
│       ├── vegetation/
│       ├── environment/
│       └── props/
│
├── assets/
│   ├── models/
│   ├── textures/
│   ├── materials/
│   ├── animations/
│   ├── audio/
│   ├── ui/
│   └── vfx/
│
├── scenes/
├── scripts/
├── data/
├── tools/
└── tests/
```

This is organizational intent, not evidence that these folders already exist.

---

# 54. AI-ASSISTED PRODUCTION STUDIO

The workflow should resemble a small studio, not one giant prompt.

Roles:

| Role | Responsibility |
|---|---|
| Creative Director | final human taste and decisions |
| Design / Production Lead | source of truth, sequencing, task breakdown |
| Godot Gameplay Agent | gameplay systems and code |
| Environment Agent | Blender/environment/world art |
| Character Agent | Primalis and villager character work |
| Animation Agent | rigs, animation, retargeting, motion correction |
| Integration Agent | imports, materials, collision, LOD, scene setup |
| Critic / QA Agent | captures, comparison, scorecards, regression checks |
| Performance / License Auditor | budgets, provenance, legal metadata |

The same AI may occupy several roles, but tasks remain separated.

The environment role does not casually rewrite combat.

The animation role does not redesign the village.

The critic should not be the only judge of its own implementation.

---

# 55. MULTI-AGENT TASK CONTRACT

No agent receives:

> “Make Primalis AAA.”

Every task contains:

- GOAL;
- WHY;
- FILES ALLOWED;
- FILES FORBIDDEN;
- REFERENCE;
- LOCKED ELEMENTS;
- ACCEPTANCE TESTS;
- PERFORMANCE BUDGET;
- EXPECTED CAPTURES;
- EXPECTED REPORT;
- GAUNTLET SCORE THRESHOLD.

One agent task should be small enough that regression is easy to understand.

---

# 56. GIT RULE

Before significant AI work:

1. clean working tree;
2. commit checkpoint;
3. feature branch/worktree where appropriate;
4. one bounded task;
5. run tests;
6. run the game;
7. capture evidence;
8. Gauntlet critique;
9. approve;
10. merge.

Git is not optional safety bureaucracy.

It allows aggressive AI iteration without destroying approved work.

---

# 57. PERFORMANCE TARGETS

Performance must be measured from the beginning.

Initial vertical-slice planning targets:

- 1080p;
- stable 30 FPS minimum on the actual development machine;
- preferably 60 FPS where practical;
- approximately 25–30 villagers in the early slice;
- up to roughly 50 combatants as an initial stress target;
- one active Primalis;
- instanced repeated vegetation;
- LOD where useful;
- no blanket 4K textures;
- controlled realtime lights;
- transparent foliage used carefully;
- expensive volumetrics only after profiling;
- no citywide physics destruction.

These values are provisional and should be refined from actual profiling.

---

# 58. REUSE-FIRST RESOURCE STRATEGY

Before making generic art from scratch, investigate legally appropriate sources such as:

- Poly Haven — natural environment/material needs;
- Quaternius — generic characters/animations/environment kits where style can be integrated;
- Kenney — prototypes, icons, utility content;
- Mixamo — humanoid animation/retargeting where license and fit are appropriate;
- CGTrader — per-item license review;
- Sketchfab — per-item license review.

Primalis remains custom.

Signature architecture remains custom or heavily transformed.

Signature bosses remain custom.

Major set pieces remain deliberately art-directed.

---

# 59. BUILD ORDER

The build order is critical.

## PHASE 0 — FOUNDATION

This is a brand-new project.

Create:

- Godot project;
- Git repository;
- folder structure;
- this master source of truth;
- decision log;
- Gauntlet rules;
- first vertical-slice implementation plan.

No assumption of old code/assets.

## PHASE 1 — UGLY COMPLETE GAME

Everything can be boxes, capsules and simple placeholder meshes.

But the player must be able to:

- move RTS camera;
- build;
- gather;
- assign work;
- feed Primalis;
- observe needs;
- teach/reinforce him;
- receive events;
- prepare defenses;
- survive attacks;
- trigger growth;
- possess Primalis;
- move him;
- fight;
- complete a traversal;
- fight a boss;
- finish the vertical slice.

**This phase proves that PRIMALIS is fun.**

Final art does not block gameplay.

## PHASE 2 — NORTH-STAR VISUAL

Create and approve one beautiful representative RTS image.

Then reproduce its:

- village language;
- palette;
- lighting;
- environment;
- composition;
- Primalis scale.

Do not visually overhaul the entire project until one north-star view proves the style.

## PHASE 3 — PRIMALIS

Highest-priority character-art phase.

- Child;
- Juvenile;
- canonical topology;
- canonical rig;
- hands/feet;
- materials;
- core locomotion;
- emotional idles;
- Godot AnimationTree;
- third-person controller;
- interaction;
- combat;
- growth transition.

Gate:

> **Simply walking Primalis through the village must already feel good.**

## PHASE 4 — VILLAGE ART

- terrain;
- trees;
- rocks;
- roads;
- buildings;
- props;
- villagers;
- clothing;
- lighting;
- weather;
- UI.

Everything uses the same art bible.

## PHASE 5 — COMBAT ART

- militia;
- enemies;
- weapons;
- damage states;
- VFX;
- Primalis combat animation;
- anti-Primalis siege boss;
- battle readability.

## PHASE 6 — CLIMB SET PIECE

- authored environment;
- climbing zones;
- anchors;
- animation;
- IK;
- camera;
- sound;
- water/ice effects;
- narrative crisis.

This should eventually become trailer-quality material.

## PHASE 7 — AUDIO

Priority:

1. Primalis voice;
2. Primalis movement;
3. combat;
4. village ambience;
5. UI;
6. music.

## PHASE 8 — POLISH

- animation contact;
- hand/foot sliding;
- navigation;
- camera collision;
- UI transitions;
- particles;
- sound mix;
- lighting;
- damage decals;
- civilian reactions;
- microbehaviours;
- performance.

## PHASE 9 — EXTERNAL PLAYTEST

A person who did not build the game plays without coaching.

Observe where they:

- stop;
- become confused;
- smile/laugh;
- care;
- get bored;
- fail;
- miss mechanics;
- exploit mechanics;
- misunderstand Primalis.

Then fix or cut.

---

# 60. HARD SCOPE RULES UNTIL THE VERTICAL SLICE IS EXCELLENT

Do not add:

- procedural world;
- second playable god;
- multiplayer;
- vehicles;
- rival civilization simulation;
- huge family-tree simulation;
- massive diplomacy;
- day-one mod support;
- universal climbing;
- fully destructible city;
- 500 individually complex soldiers;
- absurd Godzilla-scale Titan;
- giant production chains;
- crafting system;
- detailed individual villager inventories;
- enormous technology tree;
- random mechanics invented by an AI because they sound cool.

Ideas may be placed in `DEFERRED_IDEAS.md`.

They do not enter production without an explicit scope decision.

---

# 61. PRODUCTION GATES

The project advances only when gates pass.

## Gate 1 — I can play it

The ugly vertical slice can be played from beginning to end.

## Gate 2 — The village feels alive

People visibly live, work and react.

## Gate 3 — I care about Primalis

His needs, behaviour and personality generate emotional reaction.

## Gate 4 — Primalis feels physical

Movement, weight, contact and interaction are believable.

## Gate 5 — This looks like one game

Art direction is coherent.

## Gate 6 — Combat is fun

RTS and Primalis complement each other.

## Gate 7 — Holy shit

Growth / climb / boss / village-defense payoff produces the reaction the game promises.

## Gate 8 — Someone else enjoys it

External playtesting validates the experience.

Only then is the vertical slice successful.

---

# 62. CREATIVE DIRECTOR WORKFLOW

The Creative Director does not need to become an expert Blender modeller, animator, technical artist and systems programmer before being allowed to direct the game.

Useful feedback can remain human:

> “Primalis looks too human when running.”

> “The village doesn't look like it depends on him.”

> “I like the walls. Do not change them.”

> “The snow looks plastic.”

> “I don't care about these villagers.”

> “The attack is too easy.”

> “This building looks generic.”

> “Make this moment terrifying.”

> “He should feel more protective here.”

The production pipeline translates those reactions into bounded tasks and measurable criteria.

Human taste remains the final arbiter.

---

# 63. WHY THE PIPELINE WORKS

The impossible fantasy is:

> Idea → AI button → polished AAA game.

The actual production model is:

> Idea → specification → reference → greybox → implementation → asset search/build → integration → real gameplay capture → criticism → narrow correction → repeat.

The AI does not replace judgment.

It dramatically increases the amount of implementation and iteration that one Creative Director can attempt.

---

# 64. ORIGINALITY BUDGET

Do not spend months uniquely modelling generic objects simply because they exist.

Players will not buy PRIMALIS because its barrel mesh was made from scratch.

Spend originality budget on:

- Primalis;
- his behaviour;
- his growth;
- his movement;
- his relationship with villagers;
- Love/Fear/Bond;
- the city evolving around him;
- signature architecture;
- crises;
- defense;
- third-person transformation of perspective;
- the climbing set piece;
- bosses designed to kill him;
- emotionally meaningful villagers;
- the final transformation from protected child to protector.

Core emotional image:

> **A frightened settlement raises a creature, loves or fears him, builds its entire city around him, and eventually watches him plant himself in front of a collapsing gate while an army comes over the hill.**

That is the game.

---

# 65. SOURCE-OF-TRUTH CHANGE CONTROL

This document should remain stable enough that agents can trust it.

When a major decision changes:

1. Creative Director explicitly changes direction.
2. Record the decision in `DECISIONS.md`.
3. Update the relevant section here.
4. Mark old concept as `DEFERRED` or `REJECTED`.
5. Update downstream bibles/specs.
6. Do not silently retain conflicting rules.

This document describes **what PRIMALIS is**.

More detailed subordinate documents can describe **how individual parts are built**:

- `VERTICAL_SLICE.md`
- `PRIMALIS_BIBLE.md`
- `ANIMATION_BIBLE.md`
- `ART_BIBLE.md`
- `ASSET_LEDGER.csv`
- `LICENSE_LEDGER.csv`
- `QA_GATES.md`

If a subordinate file conflicts with this master, the master wins.

---

# 66. CURRENT PROJECT STATE

As of the creation of this source-of-truth document:

- the project is brand new;
- project root is `C:\Primalis`;
- no prior implementation is assumed;
- no previous prototype is assumed;
- no previous Primalis mesh is assumed;
- no previous animation is assumed;
- no previous settlement scene is assumed;
- no previous asset manifest is assumed to represent built assets;
- all implementation begins from zero.

Previous discussions are valuable only as **design input incorporated into this document**.

They are not implementation history.

---

# 67. IMMEDIATE NEXT OBJECTIVE

Do not begin by making the final Titan model.

Do not begin by downloading hundreds of assets.

Do not begin by building the final ice wall.

Do not begin with a giant skill tree.

The first development objective is:

> **Create a tiny ugly playable loop in which the player can view a small settlement, interact with basic village activity, see a placeholder Child Primalis physically existing in the world, meet one need, issue or influence one behaviour, and feel that both the village and Primalis are part of the same simulation.**

Then run the Gauntlet.

Then expand the loop.

---

# 68. FINAL NORTH STAR

PRIMALIS succeeds when the player can tell a story like this:

> I raised him when he was small enough to walk between the houses. He stole our food. He scared people. He learned who cared for him. We rebuilt streets because he no longer fit. We built walls to protect him. We argued over whether he was a blessing or a monster. Then the armies came. We fought beside him. Eventually the walls were no longer protecting Primalis. Primalis was protecting us.

And the player should know:

> **I did that. I played those moments. I made those decisions. The creature I raised became this.**

That—not any particular polygon count, screenshot, agent count or technology—is the north star.
