# Hatchworks

## First creature

A new game begins on flat, bare soil with one placed Incubator, no egg and zero of every resource. The Incubator unlocks Life immediately. Further Incubators remain available in Build. All structures currently have zero material costs as a temporary balance setting. Invalid sites spend nothing.

Soil and Life are the initial discoveries. A new world contains no buildings and starts with zero materials. Sculpt a pond with Lower to reveal and discover Water. Open Discoveries using the book button. Drag cards onto the board and onto each other, hold LMB to carry a card with the cursor and release it on the board or another card. Discovered concepts are reusable and combining them consumes no resources. Only the first discovery of a result grants its item reward. The Discover tab contains the combination board. The Discoveries tab lists known concepts and combinations. Discovery cards have no tooltips. New concepts have an exclamation mark until a card for that concept is hovered; seen state is shared between the catalog, board and discovery archive.

Discover the Incubator through Soil + Soil Ă˘â€ â€™ Stone, then Stone + Life Ă˘â€ â€™ Incubator. Its first placement is free. The creature starter chain is Soil + Life Ă˘â€ â€™ Seed; Seed + Life Ă˘â€ â€™ Tuftling Egg. Alternative recipes remain: Soil + Water Ă˘â€ â€™ Mud; Mud + Soil Ă˘â€ â€™ Seed; Seed + Water Ă˘â€ â€™ Grass; Grass + Life Ă˘â€ â€™ Tuftling Egg. The egg discovery grants one owned egg. Grass + Grass Ă˘â€ â€™ Plant Fiber; Tuftling + Plant Fiber Ă˘â€ â€™ Feeder; Plant Fiber + Soil Ă˘â€ â€™ Feeder remains an alternative. Discovering the Feeder unlocks it in Build. Each building type has a free first placement after discovery, followed by a paid base price and configured price growth. Building discoveries award no science. Buildings have discovery cards, and later combinations keep their normal science rewards. A Tuftling card is discovered after accepting its hatch. Gathering resources and creature-sown grass feed into the same discovery catalog.

Click a built Incubator with tools turned off. Its selector lists only owned eggs. Starting incubation consumes exactly one egg, takes 30 seconds by default and cannot be started twice. When ready, click Hatch. The egg hatches at the center of the screen. The revealed creature then turns, walks left and faces the player before its information card fades in; Accept spawns one creature of the selected species at a free position beside the Incubator. If all nearby positions are blocked, Return to incubator preserves the ready egg so the player can clear space and try again; its selected sex does not change. Finished eggs never hatch automatically. Each must be collected, selected in an Incubator and incubated separately.

A Tuftling has its own sex and starts with full satiety. Satiety decreases continuously; the default full-to-empty duration is 240 seconds. Below 35%, it seeks a stocked Feeder when one is reachable. At zero, it stops production and may only seek and eat food. It finds reachable water, bathes, walks to free dry soil and shakes to create grassy ground and grass tufts. Gathering mature tufts yields Plant Fiber and preserves the grassy ground. Click a Feeder to transfer available Plant Fiber into its storage. Hungry Tuftlings walk to a reachable feeding spot, eat one meal and restore 60 percentage points of satiety. Fences block these routes. Food is consumed only after eating completes; empty or submerged Feeders cannot feed creatures. A brass SupplyInput marker marks the future transport connection.

World Balance's natural start option is disabled. Optional natural generation creates terrain, plants and deposits once. Sculpting does not spawn flora. Newly sown plants mature and can be harvested; harvested plants do not regrow by themselves. Players can sculpt, gather plants, chop trees and mine rocks. There is no moss, moisture simulation, ground painting or ground harvesting.

The stone incubator has a brass heat inlet on its side. The scene's HeatInput marker gives the future heating pipe connection point and its outward orientation. Its base is a continuous low stone disc with a rounded edge. The three stone supports have rounded caps and smooth shading.

Incubator surfaces use a material atlas developed from the selected stone incubator concept: grey weathered rock with decorative greenery, chestnut wood, aged brass and green bedding. Each mesh component has its own UV mapping; the three standing stones use different texture offsets. UV2 preserves baked contact occlusion and edge data. Rounded brass and foliage parts use smooth normals; the shader keeps subtle edge wear without deriving bump from albedo. Texture prompts and offline UV tools stay in the workbench.

Egg models use an EggShell root with separately shaped rigid shell fragments and a crack overlay. The default egg has 27 curved pieces with shell thickness, inner surfaces and convex collision shapes. Cracks appear before the fragments detach, tumble and land on the presentation floor. The reveal keeps its black backdrop and clears the fragments after acceptance.

## Controls and inspection

- Build opens a shared row for discovered structures and the wooden fence. Undiscovered choices are hidden completely. LMB places a valid structure preview; hold LMB and release to draw a fence. Fences can begin at an existing post. There is no separate Fence mode button or stone fence.
- With tools turned off, a short LMB click on a creature opens its information panel and focuses the camera. Hold LMB for 0.22 seconds or drag to pick it up. Release to drop it without opening the panel.
- Click a built incubator to open its panel. There is no inspection mode, region overlay or flora/deposit information panel.
- RMB closes the camera focus. With no focus, hold MMB or use WASD / arrow keys to pan. Use Q/E or hold Alt + MMB to orbit around the Y axis. RMB closes the active tool, base-button panel or camera focus; over a discovery board card it removes only that card. Scroll zooms, or adjusts brush size in brush modes. While inspecting a focused target, Q/E or Alt + MMB orbit around that object and scroll zooms within a closer 1.6â€“5.0 orthographic size range (starting at 3.2). Panning stays blocked. These three focus zoom settings are exported on Camera3D.
- The bag button toggles Backpack, showing owned eggs, saplings and other items. Resources and science appear only in the top resource bar. Item counts belong to Backpack, while discovery cards represent reusable concepts without quantities. Accepting a hatch discovers the Tuftling concept; it can be combined with Plant Fiber to discover a Feeder.
- The book button toggles Discoveries. Its centered window leaves the base toolbar accessible. Hold LMB to carry cards from the exact grabbed point; release one over another to combine. RMB removes a card from the board without forgetting the discovery or spending an item. The book button pulses for new discoveries received outside the panel, until the panel is opened. There is no tutorial overlay or close button.
- Underlined keywords and habitat/food icons use the shared custom tooltip scenes.

## Hatchworks Database

Open the **Database** tab above the main viewport or **Project > Tools > Hatchworks Database**. The addon is enabled in Project Settings > Plugins. Its interface is authored in scene files below `addons/hatchworks_database/`.

- Catalogs cover discoveries, combination recipes, creatures, creature research, eggs, flora, resources, deposits, fences, buildings, glossary terms and world balance.
- Creature definitions control movement, bathing, shaking, resting, grass output, food, satiety duration, feeding threshold and satiety restored by a meal. Egg definitions control species, breakable shell model and incubation duration. Discovery definitions control one-time item rewards. Recipes reference discovery IDs and work in either ingredient order. Building definitions include unlock discoveries, material costs and feeder storage capacity.
- Glossary terms provide shared keyword and icon descriptions. The Tuftling's habitat is reachable water and free dry soil.
- Search by name or stable ID. Edit cells or detail fields; Ctrl/Shift selects rows for bulk numeric changes. New and Duplicate create independent definitions.
- Save All validates native `.tres` resources. Undo/Redo supports edits, creation and removal. Remove protects referenced definitions. Reload discards unsaved changes. Saving is blocked when a watched file changed outside the panel.
- Start a new game to apply database changes.

The runtime catalog is `resources/database/game_database.tres`. Flora and fence definitions keep their existing locations. New definitions are created below `resources/database/`.

Built-in resource IDs remain stable: 5 Plant Fiber, 6 herbs, 9 wood and 10 stone. IDs 0, 1, 2, 3, 4, 7 and 8 are reserved. Resource quantities are measured in items. Terrain types are separate from inventory resources.

Flora habitat uses slope (rise/run), water depth (positive below water, negative above it) and an optional ground material. Growth rate affects only newly sown plants. Tree and deposit harvesting removes them permanently. Fence estimates assume 32 terrain pixels per meter.

Working files, model builders, backups and verification projects stay outside the game in `../Hatchworks-workbench/`.

UI icons are 64Ä‚â€”64 transparent PNGs with matching line work and padding. Toolbar glyphs fit within 56Ä‚â€”56 Controls. All construction choices use the same scene-authored circular button, spacing and centered icon. Undiscovered buildings and fences have no visible button.

Discovery messages stack at the top left, with at most ten entries and a 16-second visible lifetime. Click a discovery message to open Discoveries, or X to dismiss it. Opening the matching panel removes its messages; unread counters still require hovering or using individual entries. Resource, science and item gains use flying icon/text rewards rather than message cards. Focus and hatch presentation retain the existing message visibility rules; hidden message clocks pause.

In Database Ă˘â€ â€™ Recipes, select a row and choose Ingredient A, Ingredient B and Result from named lists with icons. + New opens a recipe composer; duplicate ingredient pairs are rejected in either order. Save All persists the definitions and Undo/Redo includes recipe edits and creation. In Discoveries, Created by / Used in lists show related recipes; double-click one to edit it, or use + Recipe to prefill that discovery as a result. First-discovery reward items are also selected from a list.

Panel sizing belongs to the Control scenes: PanelContainer, MarginContainer, native scrolling and flow containers fit their contents. Scripts bind data, visibility and events without changing panel geometry. The discovery archive scrolls its entire details column, including the description and both recipe sections, within the available window height. Tooltip scenes have separate button and description layouts; TooltipController positions them above their anchor or beside the cursor without changing their sizes or wrapping settings.

Discovery definitions have editable categories: Nature, Materials, Plants, Concepts, Eggs, Creatures and Buildings. Both discovery tabs offer independent category filters, name searches and sorting by name, category or newest discovery. The Database addon exposes the same Category field.

The Tuftling egg uses a pale green leaf-patterned albedo texture on its outer shell and a separate pale inner-shell color. The existing curved fragments and their physics remain part of the hatching model.

## Science, egg crafting and breeding

Each distinct combination recipe awards science only on its first successful use, including when its result was already known. Reversing ingredient order or repeating a recipe grants no additional science. The resource bar shows science; Backpack contains items only. Science rewards fly to the science counter in the top resource bar.

Creature Research defines one-time rewards keyed by species and action, across all individuals. Tuftling defaults are 2 science for the first accepted hatch, 2 for the first successful grass-sowing cycle and 3 for the first completed breeding. These rewards never regenerate. Ordinary movement and feeding give no science.

Life + Tuftling Egg unlocks the Life Workshop in Build. Its first placement is free after discovery; later copies use its material price and growth settings. The model has separate animated parts for its wheel, screw, press, bowls, rotating rings and book page, with no external connections. Its panel lists discovered egg recipes, costs, progress and collection. There is no Research tab. A Tuftling Egg takes 12 seconds and costs 5 Plant Fiber and 3 science per egg by default. Only one egg can be produced at a time. The egg appears in the central socket only when production finishes, remains there until Collect egg is clicked and then enters Backpack. Creating or collecting an egg never starts incubation.

Click a creature and scroll its information panel to Breeding. The highlighted Start breeding button selects the nearest reachable, ready partner of the same species and opposite sex. Both parents require dry ground, their species habitat in their region and at least 60% satiety. Tuftlings need grassy ground and reachable water; Rootle and Bloomlet need grass without a water requirement, while Pebblit needs rocky ground without a water requirement. Fences block mating through a barrier; an open route around it can still be used. The selected creature remains at the calling site and plays a mate-call animation for at least 3 seconds; one compatible partner of the opposite sex approaches. Both male and female can initiate through the same panel action. Readiness or its blocking reason stays visible, and an active pair can be cancelled from either parent. World saves preserve the caller; older saves retain their original male-led call. Once close, the pair breeds for 6 seconds with floating hearts above both parents. Each spends 20 percentage points of satiety, then waits 120 seconds before breeding again. Picking up or removing a parent, losing the required habitat or becoming too hungry cancels the pair without producing an egg.

Successful breeding lays a matching egg on free dry ground nearby. It stays on the map until clicked, follows sculpted ground and can be collected only once. Clicking it adds it to Backpack and starts an item reward flight to the Backpack icon. It can then be selected in an Incubator. Sex is randomly selected at hatching, including for the first creatures; there is no forced opposite-sex starter pair.

The Database addon exposes per-recipe science rewards, Creature Research entries, egg crafting times and material/science costs, and creature breeding duration, recovery and satiety settings. Science is finite under these rules; start costs and random-sex progression still need gameplay balancing.

## Creature movement, swimming and discovery archive

Creatures use their own collision layer (8) and collide with terrain, fences, structures and other creatures. CreatureNavigation keeps a spatial index for local steering and reserves destinations for bathing, grass sowing, meals and breeding. Reservations are released on interruption, pickup, despawn and navigation rebuild. Hatch spawning and dropping a held creature search for free positions. Static navigation is not rebuilt for ordinary creature movement.

Tuftlings have a dedicated looping skeletal Swim clip in a separate water animation library, including leg paddling, body movement and frond motion. During bathing they choose short routes within sufficiently deep water. They retain the normal bathing timer and then return to dry soil to sow grass. Nearby creatures choose separate bathing and feeding places. Breeding uses a free meeting position beside the partner rather than its occupied center.

Navigation rebuilds publish the path grid, water depths and region IDs together after sculpting settles. An existing published grid remains usable while its replacement is prepared; live obstacle checks still constrain movement. Changes arriving during a rebuild queue a follow-up instead of repeatedly restarting the current build. Completing a rebuild makes each active Tuftling reconsider water, food or sowing ground without pickup. Shore movement uses floor snapping and water-depth hysteresis; an interrupted landing has a finite recovery time, and a stalled route temporarily excludes its failed approach so another route can be tried. Physically unreachable ground remains inaccessible.

The current catalog contains 28 discoverable concepts and 33 combination recipes. Every concept can be reached through combinations from the starting concepts; discovering objects on the map still adds the same reusable concepts. Recipes include Seed + Soil -> Oak, Oak + Soil -> Wood, Soil + Soil -> Stone, Stone + Soil -> Boulder, Boulder + Life -> Pebblit Egg, Grass + Soil -> Shrub, Grass + Water -> Fern, Seed + Mud -> Reeds, Fern + Seed -> Herbs, Stone + Water -> Sand, Wood + Wood -> Wooden fence, Stone + Life -> Incubator and Tuftling Egg + Water -> Tuftling. Discovering the Tuftling concept does not hatch or spawn a creature. The wooden fence unlocks through its discovery concept. Gather plants, Chop trees and Mine rocks are always available; the axe and pickaxe are tools rather than discoveries.

In Discoveries, click an archived concept to see its related recipes and combination count. A single list shows unknown recipes first, followed by known recipes, without repeated status captions or duplicate entries. A recipe is revealed only after that particular pair has been combined. Hidden parts remain ??? even when some of those concepts are already known. Search, categories, sorting and unread markers remain available. The Discover tab keeps its existing drag-and-drop board and a short combining hint.

The first discovery of each flora species grants one matching sapling item. Repeating a discovery grants no additional item. Open Backpack, scroll to the sapling and click Plant. The map shows a placement preview; LMB plants at a valid position, consumes one sapling and exits planting when the stack is empty. Esc cancels without spending an item. The preview checks growth conditions, water depth, spacing, buildings, rocks, fences and creature space. Trees and shrubs reserve their obstacle footprint from planting onward. Saplings grow using the species growth rate; there is no automatic regrowth after harvesting. Reeds require a suitable shore location.

Flora definitions expose their icon and sapling item ID in Hatchworks Database, and first-discovery rewards can select these items. Fence definitions expose their required discovery.

The Discoveries and Backpack windows share the same scene-authored outer dimensions and screen margins. Their scrollable content fills the available interior. Construction prices show available/required amounts for each material, individually white when sufficient and red when missing; free structures show Free.

## Leisure and creature wellbeing

Satiety and Contentment appear below the creature's name and sex in the inspection panel, with short custom tooltips. Low satiety lowers contentment. Hungry creatures prioritize a reachable feeder that has their food, including at zero satiety. When food, a free feeding spot or a route is unavailable, they continue their normal behaviour and retry feeding periodically. Empty or removed feeders release the creature back to its ordinary activities. Zero satiety does not disable work, leisure, swimming or Pebblit aggression. Creatures begin at 75 contentment. Energy is no longer a creature statistic, work cost or breeding requirement.

Tuftlings take 8Ă˘â‚¬â€ś16 seconds of leisure after 1Ă˘â‚¬â€ś2 successful grass-sowing cycles. They rest on dry ground with a breathing, closed-eye animation. The other species use their own configured leisure intervals and durations. Breaks depend on completed work cycles rather than an energy meter. A swimmer leaves the water before resting. Hunger can interrupt rest, and navigation changes preserve a rest already in progress.

Contentment follows a target gradually, with a default 30-second response setting. The baseline combines satiety (45%), the dry-space allowance (35%) and nearby company of the same species (20%), then applies species sensitivities to crowding, noise and other species as described below. The preferred area is 12 square meters per creature, shared among creatures in the same fence-defined region and excluding water. A companion counts within 6 meters in that region. Held creatures do not count as occupants. Space, preferred area and company counts are shown in the panel. Contentment changes bathing and shaking speed from 70% to 110%; its initial 75% corresponds to the original work pace.

Local movement uses shared position and movement snapshots, gentle separation and courtesy steering. Idle or resting creatures step out of an approaching creature's way. Head-on traffic chooses a consistent passing side; a lower-priority creature can back out of a narrow passage. Physics collisions and static obstacle sweeps remain active. No creature is teleported through another creature, fence or building.

Females use the same rig with a broader leaf rosette and cream flowers attached to the central frond, plus an amber coat and fronds distinct from the fresh green male. The palette material preserves the original albedo detail, normals and roughness while keeping brown feet, eyes and cream flowers unchanged. This appearance is applied both in the world and during the hatch reveal. The separate behaviour library supplies looping Rest and Call skeletal animations. Male calling selects exactly one female; breeding remains an explicit panel action.

The Database addon exposes leisure intervals and durations, preferred area, companion radius, contentment response and breeding call/cooldown/satiety settings. These defaults are an initial gameplay balance.

Building discoveries unlock construction without granting inventory items. Each type has one free first placement by default, then paid copies. BuildingController.placement_costs uses the recorded total number placed to calculate the next price; every placement checks and spends that same price. Eggs and saplings retain their one-time discovery rewards.


## Rootle, Pebblit and Bloomlet

The three additional species have animated skeletal models, separate male/female silhouettes and colors, matching 27-piece breakable eggs, discovery icons and complete incubation, inspection, feeding, leisure and breeding support. The models include idle, movement, eating, work, pickup, fall, landing, swim, rest and mating-call animations. Pebblit additionally curls into a ball, rolls to a work site and uncurls before stomping. Bloomlet hovers and releases pollen while sowing.

First eggs are discovered through Oak + Life -> Rootle Egg, Boulder + Life -> Pebblit Egg and Herbs + Life -> Bloomlet Egg. Each first discovery grants one egg to Backpack. The Life Workshop can craft more discovered eggs for 5 Plant Fiber and 3 science, taking 15 seconds by default. Crafting does not hatch the egg. Each egg can also combine with Soil to discover its creature concept; accepting an actual hatch discovers the same concept. Breeding produces a collectible egg on the map.

Rootle plants oak and shrubs on free grassy ground. Bloomlet sows ferns that can be gathered for Herbs. They approach planting sites, complete a work animation and leave growing specimens; trees yield Wood through chopping. All species eat Plant Fiber through the existing Feeder. Local output caps stop production when the surroundings are full, and harvesting frees room for more. Existing hunger, leisure, contentment, navigation reservations and creature separation apply to these species.

Male Pebblits work on dry soil, grass or rock. Their timed landing gently ripples terrain heights, converts ground to rock and can create a mineable stone deposit. Sand is preserved throughout the impact footprint. Female Pebblits curl up and roll while grinding soil, grass or rock into small sandy clearings. They create no deposits and preserve terrain heights. Sand production pauses once nearby dry-ground coverage reaches the configured limit (30% by default), and both site selection and the effect recheck this cap. Existing deposits are retained. Both sexes keep their hunger, leisure, rocky breeding habitat and aggression rules. At low contentment or insufficient shared space, either sex automatically interrupts ordinary work, travel or leisure to charge a reachable wooden fence or building. Each completed charge is followed by a mandatory rest animation for the configured aggression_cooldown (12 seconds by default), exposed as Rest after each charge (s) in both database editors. If it is still upset after resting, it can charge again. Walls still block routes and attacks. Hunger affects contentment without disabling aggression. Reachable food is checked before choosing a new charge; a completed charge still requires its configured rest. Breeding and being carried keep their existing priority. Remaining recovery is persisted in world saves.


Buildings and built fence elements have durability. Clicking one shows condition and a Repair button in its information panel. Repair currently costs zero. An element at zero durability is removed; any incubating egg, workshop job or stored food is lost without a refund. Destroying an incubator during its hatch presentation closes that presentation and does not spawn a creature. Fence destruction updates the navigation opening.

First accepted hatches, first successful species work and first completed breeding award science once per species and action across all individuals. Rootle's work action is planting, Pebblit's observations are creating a stone deposit and making a sandy clearing, and Bloomlet's is growing herbs. Repeated work does not award more science. The Database addon exposes each species' habitat, water requirement, production timings, output radius/cap, impact settings and aggression settings, along with building maximum health and the new egg and discovery definitions.


## Pause menu, persistent worlds and languages

Escape opens a scene-authored Control pause menu. Resume or Escape returns to the previous panel or presentation. Escape first dismisses a reset/quit confirmation. The menu offers Save game, Reset game, English/Polski, music volume and Quit game. Reset requires confirmation, removes both world save copies and reloads the bare starting map; language and music settings remain. Closing the application window uses the same save / quit without saving / cancel choices as the menu. Simulation and world input pause while the menu is open. Active discovery dragging is cancelled without combining, and the hatch reveal's otherwise-always-running model animation is also suspended. UI layout and sizes remain entirely in Control/Container scenes.

GameManager coordinates the menu and startup. SaveGame is a native Godot autoload backed by SaveGameService.gd. The startup scene is scenes/ui/main_menu.tscn, with Continue (enabled when a save exists), New game, Options and Quit. New game asks for confirmation before removing an existing save. Options share persisted language, music and effects settings with the pause menu. There is one save slot at user://saves/world.save, loaded when Continue starts gameplay. Every confirmed exit from gameplay saves first, including closing the window; a failed save keeps the game open and shows its error. The confirmation says that the game will be saved, with Quit and Cancel actions. Exiting from the startup menu does not write a world. user://saves/world.backup preserves the previous valid save. Settings live separately in user://settings.cfg.

The versioned binary format stores native non-object variants, a magic header, SHA256 and a length limit. A temporary file is verified before replacing the main save; an invalid latest file can recover from the previous backup, with an explicit menu message. IDs, types, finite values, dimensions and references are validated before replacing the world. Saves require the same map_size and pixels_per_unit as the current configured map. An incompatible layout or format version is rejected rather than silently resetting the world.

Saved state includes terrain heights and ground masks, water, environment seed, flora/growth and partially harvested trees, deposits and mining progress, fence topology and durability, buildings/health/stocks/jobs, inventory, discoveries/known recipes/unread state, science and one-time research, all creature species/sex/stats/cooldowns, active breeding, committed work effects, loose eggs, the discovery board and normal camera view. Navigation and transient movement routes are rebuilt. A save during hatch presentation returns that egg to Ready with its already-selected sex; it does not duplicate or automatically accept the creature. Open panels, notifications and pointer gestures are transient UI state.

Localization uses Godot TranslationServer and the CSV importer. localization/game.csv provides English source IDs and Polish/English translations, with native game.en.translation and game.pl.translation resources configured in project.godot. The current catalog contains 418 messages. Switching language updates existing panels, notifications, discovery cards, labels, tooltips, inventory and creature information without restarting. Species proper names and stable database IDs are unchanged. Database names and descriptions translate at runtime; the database editor and source resources remain English. Polish keyword inflections retain their custom tooltip links. Localization stores the chosen language and music volume with ConfigFile.

## Updated controls, scale and background music

The short new-world camera tutorial shows PNG keycaps for movement followed by rotation; the permanent input panel has been removed. WASD/arrow movement is blocked while typing, inspecting a focused target or using a modal panel. Q/E rotation remains available during focus, rotating around the inspected object; typing and modal panels block it. MMB pans; Alt must be held when starting MMB rotation. Scroll still zooms or changes brush size in brush tools. Selecting an existing building closes the current base-button mode and opens its information panel. The gathering button now has a crossed axe/pickaxe PNG rather than a basket.

Discovery combination uses the actual overlap of card rectangles on LMB release, rather than requiring the cursor itself to be over the target. If several cards overlap, the largest intersection wins. Dragged cards retain the point where they were grabbed. RMB over a board card removes it; RMB elsewhere closes the discovery panel. The former bottom result/hint message is removed.

All four world creature scenes use 65% of their previous model size with matching sphere collision radii (Tuftling .325 m, Rootle .390 m, Pebblit .455 m and Bloomlet .2925 m). CharacterBody3D roots remain unscaled. Models, offsets and effects are adjusted in the scenes, and camera focus moves closer. Visible creature heights are approximately .79Ă˘â‚¬â€ś.94 m, while mature oak variants are 2.93Ă˘â‚¬â€ś3.38 m. Existing navigation, swimming, shore exit, work, spawning, dropping and breeding remain functional. A physically occupied actor may reserve its current position within 3 cm without a spare buffer blocking close pairs; other occupied destinations stay blocked.

First Sprouts is an original 32-bar ambient composition at 82 BPM, approximately 93.66 seconds, combining harp-like plucks, airy flute, soft keys, bells and warm pads. Its loop is a native compressed AudioStreamOggVorbis resource. A single AudioStreamPlayer autoload keeps music continuous across world resets and while the menu pauses simulation. The menu volume slider affects music only, reaches true silence at zero and persists independently of the world save. Offline composition, the WAV/OGG masters, builders and all verification files remain in Hatchworks-workbench.


## Backpack, reward presentation and unread content

Buildings no longer have floating Label3D names or status/timer messages. Incubator countdowns, feeder stock and workshop progress remain in their inspection panels; glow, food fill, work animations and ready eggs still provide world feedback. Loose egg names and harvesting feedback are separate and remain.

The player-facing item mode is now Backpack (MODE.BACKPACK retains numeric value 8). Backpack lists only owned items, including eggs and saplings, with an empty-state message when appropriate. Materials and science remain in the top resource bar. Stable IDs and internal scene paths remain compatible with existing saves.

RewardFlightController under CanvasLayer/Rewards consumes separate gained signals while preserving the existing authoritative added/changed APIs. ResourceInventory, ItemInventory and ScienceController accept optional reward origins: Vector3 for world acquisition, Vector2 for a UI source. Harvesting, loose eggs, discovered rewards, workshop collection, hatch/science actions and breeding pass the actual source. Flying icon/+quantity Controls follow curved screen-space paths to the relevant resource icon or Backpack icon, update moving destinations and ignore mouse input. Off-screen sources are projected/clamped safely. Bursts can merge at the same source, and at most eight flights run at once.

Authoritative quantities change immediately. Resource/science counters subtract pending gains, show spending immediately and reveal each gain only when its flight arrives. Item stacks are immediately owned; the new-type badge on Backpack waits for that type's first arrival. Pausing freezes flights; hatch presentation holds them until the world is visible again. Reset/load cancels the presentation queue and synchronizes the bar to saved quantities without replaying gains. The quantity presentation is transient and is not saved.

NewContentTracker stores seen keys for item types, construction choices, fences and tools, and uses DiscoveryController's existing unread state for discovery concepts. All five base buttons have native numeric badge scenes. New types/options are counted once, independent of stack quantities. Initial sculpt and gathering tools are unread too. Opening a panel does not mark its contents seen. Hovering or using an individual entry clears its marker; using either ingredient in a discovery combination also marks it seen, even when its card was reached by overlap rather than cursor hover. Item consumption and real tool use update seen state. SaveGame stores this metadata as an optional field, preserving compatibility with earlier version-1 saves.

A scene-authored CameraTutorial replaces the permanent input panel. A new world first asks the player to move the camera with WASD, arrows or MMB, then rotate it with Q/E or Alt+MMB. Only actual manual camera movement advances the steps; focus motion, blocked input and zoom do not. The small top-center prompt clears the resource bar and base buttons and hides while camera focus or modal UI blocks navigation. Tutorial progress is saved with the world. Reset starts it again; pre-tutorial saves treat it as complete. All static layout stays in Control/Container scenes; reward motion is the deliberate dynamic positioning exception.

Ask the user whenever the intended meaning or behavior is not completely clear. This collaboration rule is recorded in AGENTS.md.

## Discovery graph and concise interface

Open Project > Tools > Discovery Graph, or use Discovery Graph in the Database main-screen toolbar. The graph contains only discovery cards. Select a discovery and choose one of its related recipes to see the two ingredients and the result; Show all displays the overview. Edit recipes in the side panel with A + B -> Result and a science reward. Graph positions are stored as editor metadata. The addon remains English.

The Database main screen uses Creatures / Discoveries / Database / Design Doc tabs, a catalog list on the left, a large asset preview or discovery graph in the middle, and grouped searchable parameters on the right. Database retains the category selector for all twelve catalogs. All twelve catalogs use this layout. Save All validates native resources, recipe references and duplicate unordered ingredient pairs. Deletions require confirmation and preserve resources still referenced by other entries. The UI is built from native Control/Container scenes. Only graph-card placement is dynamic.

Saved changes from the HTML Studio or another resource editor reload automatically when the native addon has no pending edits. Unsaved field values and incomplete text remain in the native editor when an external change arrives. A conflict blocks saving until the saved version is reloaded and the draft reconciled.

Runtime tooltips and database descriptions use short in-world PL/EN copy. The Life Workshop retains egg selection, crafting duration, real material/science costs, working progress and collection, while omitting incubation time, sex explanation, repeated cost headings and idle explanatory paragraphs. Creature Energy and its database fields are removed; the version-1 save reader discards legacy energy/recovery fields and restores a former energy-recovery activity as ordinary leisure.

## Creature sensitivities, compact inspection and local studio

Sensitivities belong to CreatureSpecies, not individual randomized creatures. noise_sensitivity and crowding_sensitivity range from 0 to 1. species_aversions is a directed Dictionary[StringName,float] of other species IDs and strengths from 0 to 1. Aversion applies whenever a disliked species shares the region, regardless of proximity; reverse relations are independent. Several present aversions add up and clamp to 1. Undiscovered species remain anonymous in the game panel.

The contentment target is clamp(satiety * 0.45 + 35 + company * 20 - crowding_stress * 35 - noise_stress * 25 - species_stress * 25, 0, 100). Crowding is the missing fraction of preferred dry space times crowding sensitivity, replacing the previous space term rather than adding a second penalty. Noise stress is the sampled local noise level times noise sensitivity. Contentment still approaches the target at the configured response rate. Preferred space and companion range remain editable. A shared regional snapshot refreshes once per second and is invalidated when regions change or a world loads.

Initial values (noise / crowding / aversion) are Tuftling 0.75 / 0.65 / Pebblit 0.65; Rootle 0.40 / 0.85 / Pebblit 0.35; Pebblit 0.10 / 1.00 / Bloomlet 0.30; Bloomlet 1.00 / 0.50 / Pebblit 0.85. These are starting balance values, editable in the native database and local studio.

NoiseController belongs to the map. Working incubators and workshops are continuous sources; chopping, mining and Pebblit impacts create transient pulses. Distance attenuates noise across fences and regions. An idle feeder is quiet. A creature ignores its own pulses. Noise fades with simulation time and pauses with the world; load clears transient sources and rebuilds machine sources from active states. Derived stress values are recomputed rather than added to the strict creature save record, retaining existing save compatibility.

The creature inspection panel uses PNG icons, satiety/contentment bars, a short activity state, dry-space/company numbers, sensitivity levels and current-stress bars. Food, habitat, sex, breeding requirements and aversions use shared custom tooltip scenes. A compact CreatureCard instance is used only in inspection; the hatch card retains its description. All layout remains native Control/Container scenes.

SoundEffects is a spatial-audio autoload with an Effects bus and a separately persisted volume slider in the pause menu. Fifteen original baked mono WAV effects cover four creature voices, grass/plant/herb work, water, chopping, mining, Pebblit impacts, machine start/ready and the two working-machine loops. Female and male voices use mild pitch variation; ambient voices are spaced apart and playback is bounded. Machine loops stop when work ends, and deleting their source stops its audio. Sound volume does not change simulated noise or creature stress. Offline synthesis sources and audio previews remain outside the game.

The HTML Database Studio lives in ../Hatchworks-workbench/creature-editor. Open Open Creature Editor.cmd for local access at http://127.0.0.1:8769/. Creatures provides animated 3D previews and grouped balance controls. Discoveries provides the simplified discovery graph and recipe forms. Database exposes all twelve native catalogs, including asset and reference fields. All three pages edit the same Godot resource database as the addon, without a second JSON balance store.

Open Open WiFi Editor.cmd for password-protected access from the same private network. Choose a temporary password locally at launch, then open one of the printed LAN URLs, normally on port 8768. The password is not stored in source files or passed on the command line. See the Studio README for launching, authentication, backups and conflict handling. No firewall rules or router forwarding are added automatically.

Clean pages automatically refresh saved external changes; unsaved drafts remain in place and stale writes are rejected. Saves validate candidates through Godot and back up replaced files outside the game. Restart gameplay to apply changed balance to an active game session. New names and descriptions are English source text; translation CSV editing remains separate.

Model previews, browser modules, native bridge scripts, caches, server files, launchers and test artifacts stay outside the game. The game project retains only its runtime resources, native editor addon and project documentation. Render hosting and bidirectional Git publishing are future setup work; the local Studio does not publish commits or expose a public service.

Pebblit sex-specific production is configured in CreatureSpecies using the shared/male production and female override fields. A Shared female override keeps the same behaviour for both sexes; Tuftling, Rootle and Bloomlet currently use it. Both the native database addon and HTML Studio expose the override and nearby sand coverage limit. Sand creation discovers the existing Sand idea and awards 3 science once for its first observed occurrence. Active sand work and its applied-effect marker persist in world saves. Pending female quarry work in older saves resumes as sand work.


## Building prices and discovery-first start

A new world begins with Soil and Life, zero materials and no Incubator. Soil + Soil -> Stone and Stone + Life -> Incubator unlock the first building; its first placement is free. Boulder + Life -> Pebblit Egg provides the requested egg recipe. Stable discovery and recipe IDs are retained for saves.

The first Incubator, Feeder and Life Workshop are independently free after discovering each building. The second copy uses the base price:

| Building | Wood | Stone | Plant Fiber |
| --- | ---: | ---: | ---: |
| Incubator | 5 | 10 | 5 |
| Feeder | 5 | 0 | 2 |
| Life Workshop | 15 | 20 | 10 |

Buildings expose First placement is free, Price growth type (Linear / Multiplicative) and Price increase per copy (%) in the native addon and the HTML Database catalog, under Price progression. Default growth is linear at 50% of the base price per additional paid copy: free, 100%, 150%, 200%, etc. Multiplicative growth at 50% uses free, 100%, 150%, 225%, etc. Resource quantities round up. Zero growth keeps paid copies at the base price. Changing these settings affects future placement prices.

Price history is tracked separately by building type and counts successful placements, including buildings later destroyed. Failed or cancelled placement spends nothing and changes no count. The history is saved with the world and restored independently of current building count. Older saves without history infer it from standing buildings; already destroyed buildings from before this update cannot be reconstructed. Existing saved worlds retain their structures. Reset/new game uses the empty start.

Building-recipe rewards are zero in the data and enforced by ScienceController, including alternate or edited recipes. Discoveries still unlock the building, but they grant no construction kits, materials or science. Ordinary recipes, first creature actions and breeding keep their established science rules. Wooden fences retain their existing per-meter and per-post material costs.

The full-screen hatch presentation is ordered above toolbar badges, notifications and reward flights, with the pause menu and custom tooltips above it. Entering the presentation dismisses any previous tooltip. Static layout and breeding button styles remain in their Control scenes.

## Native World Studio and shared Design Doc

The Database main screen now matches the web Studio's three-column layout and dark
forest palette. Creature previews show the actual male/female appearances and their
animation clips, with play/pause, drag orbit, reset view and wheel zoom. Preview models
do not run gameplay AI or edit their source scene. All panel dimensions and layouts are
authored in Control/Container scenes; only 3D camera orbit and graph cards are dynamic.

**Open Web Studio**, also available under **Project / Tools**, opens the corresponding
page for this project. It reuses a matching localhost service or starts the existing
PowerShell launcher. Right-click the button to configure this project's port or launcher
path. Defaults are **8769** and the sibling workbench creature-editor launcher.

**Design Doc** in Godot and **design.html** in the web Studio edit the same
**docs/DESIGN.md**. The document describes current game rules, detailed creature AI and
separately marked future ideas. Changing its text does not change database parameters.
Godot has Write/Read views and the browser has an outline, reading preview and Markdown
editor. Both provide explicit Save and Reload saved actions. Clean views pick up external
saves; drafts remain intact on conflict and stale saves are blocked. Saves use a shared
lock, revision checks, atomic replacement and backups outside the game under the
project parent's **Hatchworks-workbench/design-doc-data/<project-key>** folder.

## Focus, happiness and editable creature AI

Esc dismisses the current panel, tool mode or inspected creature/building before opening the pause menu. It also returns an unfinished hatch presentation to its incubator without losing the egg. A subsequent Esc opens the pause menu. While inspecting an actor, its inspection-bounds center stays in the camera center, including during movement and orbiting. Leaving focus preserves the current camera position and rotation and smoothly increases orthographic size by 20%. The factor is exported as `focus_release_zoom_factor`; saved camera views preserve this resulting location and zoom.

The happiness meter has face icons and boundaries at 40% and 70%: Unhappy below 40%, Neutral below 70%, Happy from 70%. Its custom cursor tooltip displays current happiness, the level and actual contributions from base comfort, satiety, company, crowding, noise and unwanted neighbours. These contributions come from the same calculation used by the creature, and happiness still approaches its target gradually.

**Database / Creature AI** and **Web Studio / Creature AI** (`ai.html`) edit the same `CreatureSpecies.ai_graph` data. Each species has a graph of its existing Eat, Attack, Rest and Work behaviours, plus an Any state source for global checks. Drag nodes, connect states, select a transition and edit numeric/boolean conditions, AND/OR matching and priority. Higher priorities are tried first; an unavailable action falls through to the next matching action. The graph can inspect hunger, happiness, work cycles, sex, company, stress, carried water, swimming, dry ground and navigation readiness. Attack remains a Pebblit capability. The Hungry and Unhappy-or-cramped predicates use the existing species thresholds; explicit numeric conditions can replace those activation thresholds.

An empty graph uses the existing default behaviour ordering. An explicitly authored graph with no matching enabled action waits. Movement, swimming, safe landings, breeding, ongoing work completion and mandatory attack cooldowns retain their existing controllers. Native edits support Undo/Redo and Save All; the web editor saves one species with revision checks. Both validate the shared graph schema before writing. Restart gameplay to apply saved rules.
