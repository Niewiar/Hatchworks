# Hatchworks Forge

Enable Hatchworks Forge in Project Settings > Plugins. Open its independent, nonmodal window through Project > Tools > Hatchworks Forge. Closing the window preserves an edited draft and keeps the session available for reopening.

The first Forge section is Discoveries. It contains Connections, Tile Usage and Conflicts views. Native Control/Container scenes define the interface. GraphEdit owns graph navigation and zoom.

Select a discovery to see its incoming recipes and ingredient partners. Click a recipe to edit A + B → result and its science reward. Discovery chips can be dragged onto ingredient/result fields. Names, categories, icons and descriptions are editable; existing discovery and recipe IDs remain stable because saved games reference them.

Edits remain in a separate document with Undo/Redo. Save Draft preserves incomplete or conflicting work without changing game data. Restore Draft checks that its source revision is still current. Save Data validates the full catalog and writes only changed resources.

A + B and B + A are the same input pair. All recipes sharing a pair form a conflict group, including identical results. A + A, cycles and different pairs producing the same result are valid. The Conflicts view lists every affected recipe and links back to its editor.

Usage counts each recipe once. Ingredient and result roles are separate. A + A occupies two ingredient slots but is one recipe. Category totals cover the entire catalog.

Drafts, transaction journals and backups are kept outside the game under ../Hatchworks-workbench/forge/<project-identity>/. Save operations check disk hashes and pending native Inspector edits, stage new content, preserve existing UIDs and keep recovery copies. An interrupted save is recovered before the next load; recovery stops if doing so would overwrite an external edit.

Ctrl+S saves data; Ctrl+Shift+S saves a draft. Ctrl+Z and Ctrl+Y/Ctrl+Shift+Z control the document when a text field is not consuming those shortcuts.

The Forge window hosts independent tool sections. Discoveries is composed of a document, an index, a store, the shared runtime catalog validator and separate scene views. Further Forge tools can be added as new sections without expanding the discovery controller.

## Creatures

The native Creatures section contains a searchable portrait list, one Model and Parameters workspace, and a separate History view. Male/female switches affect the model preview; the parameter form explicitly names shared settings and female overrides. Real Godot materials, camera presets/orbit/pan/zoom, grid/bones, animation playback/seeking/frame steps/speed/loop and links to related eggs/research remain available.

Parameters are organized into Identity, Happiness, Feeding, Landscape, Work, Rest, Breeding, Movement, Aggression, Handling and Advanced categories as appropriate for the creature. Each category has an explanation; editable rows have clear names, units and relevant help. The form omits IDs, file references, structural controller roles, unsupported diets and parameters unused by the chosen creature. Ordinary gait remains bound to the current model's calibrated limit; Pebblit's configurable base charge speed is labeled as such.

Terrain targets and species aversions use native percentage controls rather than JSON. Terrain values are stored from 0 to 100; aversions convert displayed percentages to stored fractions. Empty female profiles inherit the base profile, and explicit zero overrides remain intact. Additional legacy map entries can be removed without discarding valid edits. The AI graph remains an advanced JSON setting.

Category changes, model variants, history and save commit pending numeric input. Draft changes from every category are retained and validated, including hidden or unfinished entries. Save shows a change summary, checks the full game database, disk fingerprints and pending native Inspector edits, then uses the shared UID-preserving file transaction. Failed restores preserve the original draft; new work archives protected drafts before replacing the active draft. State lives outside the game under the Forge workbench directory.

The model preview instantiates appearance scenes only, strips gameplay/audio callbacks and duplicates animation libraries before applying playback rules. Camera and playback controls do not modify game models or animations. Layout is defined entirely by Control/Container scenes. The independent Forge window defaults to 1440 × 900 with a 1280 × 760 minimum and native scrolling.

The HTML editor and its server have already been removed from the active project. Archived source and backups remain outside the game.


## Animation Viewer and review notes

Project > Tools > Hatchworks Animation Viewer opens a separate native window. Choose any creature from the game catalog and either sex, then select an animation in the shared 3D preview. Drag with the left or middle mouse button to orbit, right mouse button to pan, and use the wheel to zoom. Front, side and three-quarter presets and grid/bone overlays remain available.

The frame field seeks an exact zero-based frame at the selected FPS (1–120, default 30). Previous/next step to adjacent whole frames, including after pausing between frames. Playback supports pause, speed changes and looping. Preview animation libraries are duplicated and gameplay/audio callbacks are removed; playback never edits the original game animation resources.

Write notes for the selected whole animation. Frame numbers can be included manually in the text. Add Note saves a new entry; selecting an entry restores its creature, sex, animation and reference FPS for editing. New Note starts a separate entry, and Delete removes the selected entry. Added or updated notes are saved to `user://hatchworks_forge/animation_review.json`. A damaged draft is preserved and can be bypassed by exporting new in-memory notes.

Export to Desktop opens a native Save dialog with `Hatchworks-animation-review.md` on the operating system's Desktop selected by default. The UTF-8 Markdown report groups notes by creature, sex and original clip name and includes model references, reference FPS and duration. It contains written comments; it does not attach a particular frame or create screenshots automatically.


Paired animation previews display both creatures. Tuftling Play is paired with another Play; Call shows both Tuftlings hopping, with a short delay for the partner. Other species retain a listening Idle partner. GreetLeft/GreetRight have been removed; existing review notes for retired clips remain editable and exportable. Choose the partner's sex independently. The selected creature remains the primary subject of exact frame controls and original clip duration. Notes and exported reports retain the partner's sex and clip. The regular Forge parameter preview retains its solo mode.


The Animation Viewer includes the associated creature VFX and sound events, with local VFX/SFX toggles and preview volume. It uses copies of the existing particle scenes and the game's sound profiles. Particle simulation follows the selected animation time, including pausing, rewinding and looping; scrubbing does not fire audio events. Playback triggers sounds at their associated markers, and pause or closing the viewer stops them. Tool controls do not change the game's audio settings.

Sleep shows Tuftling Z signs. Tuftling Work emits water droplets throughout the clip and plays wet-leaf rustling; Swim has no assigned sound. Call shows hearts and gentle chirps from both Tuftlings. A listening Idle partner of another species does not call back. Paused sound is resumed at the selected animation position when playback continues. Headbutt and Attack use their existing impact sounds. Random ambient vocalizations are independent of animation markers. Notes retain the selected VFX/SFX switches and volume so the exported feedback can be interpreted in context.
