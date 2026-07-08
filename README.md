# minecraft-data.cr

Minecraft game data for Crystal: per-version blocks, items, materials, enchantments,
collision shapes, entities and translations — plus the generator that produces new
versions from a Minecraft jar. This shard owns the growing data so consumers
(e.g. [rosegold.cr](https://github.com/RosegoldMC/rosegold.cr)) don't have to.

It replaces a dependency on PrismarineJS's *published*
[minecraft-data](https://github.com/PrismarineJS/minecraft-data) (which has no 26.x)
with a slim, self-generated schema.

## Usage

```yaml
dependencies:
  minecraft-data:
    github: rosegoldmc/minecraft-data.cr
    version: ~> 0.1.0
```

```crystal
require "minecraft-data"

# Embed one version's data at compile time and parse + derive it:
data = Minecraft::Data.load("26.2")
data.blocks                       # Array(Minecraft::Data::Block)
data.block_state_names[8]         # "grass_block[snowy=false]"
data.block_state_collision_shapes # per state: Array of {min_x,min_y,min_z,max_x,max_y,max_z}
data.air_states                   # Set(UInt16)

# Or embed individual files (entities/language aren't part of Data):
Array(Minecraft::Data::EntityMetadata).from_json(Minecraft::Data.read_asset("26.2/entities.json"))
Hash(String, String).from_json(Minecraft::Data.read_asset("26.2/language.json"))
```

Both macros take string literals (or macro-time string expressions), so only the
versions you reference are embedded into your binary. Shipped versions:
`Minecraft::Data::SHIPPED_VERSIONS` = 1.21.8, 1.21.9, 1.21.11, 26.1, 26.2.

## Data schema

One directory per version under `data/<version>/`:

| file | shape | model |
|------|-------|-------|
| `items.json` | `[{id, name, stackSize, maxDurability?, enchantCategories?}]` | `Minecraft::Data::Item` |
| `blocks.json` | `[{name, minStateId, maxStateId, hardness, material, harvestTools?, states:[{name,type,num_values,values?}]}]` | `Minecraft::Data::Block` |
| `blockCollisionShapes.json` | `{blocks:{name->id\|[id...]}, shapes:{id->[[6 floats]...]}}` | `Minecraft::Data::BlockCollisionShapes` |
| `materials.json` | `{material:{item_id: speed_float}}` (keys MUST match `material` names in blocks.json) | `Minecraft::Data::Material` |
| `enchantments.json` | `[{id, name}]` | `Minecraft::Data::Enchantment` |
| `entities.json` | `[{id, name, width, height, type?, category?}]` | `Minecraft::Data::EntityMetadata` |
| `language.json` | `{translation_key: string}` (en_us) | — |

`states[].type` is lowercase `"bool"|"enum"|"int"` (Crystal's enum parse is
case-insensitive). `material` is a PrismarineJS-synthesized field, not a Mojang field —
see "Material synthesis" below.

Data files are stored in `tools/scripts/json_writer.cr`'s canonical
one-record-per-line form: the root container's children each get their own line
(and nested containers with ≥ 16 children expand too), no indentation, raw UTF-8
strings, numbers keeping their source form. Diffs between versions stay one line
per record.

## Generating a new version

From `tools/` (needs `just`, `crystal`, `curl`, `jq`, `unzip`, and Java matching the
MC version — 26.2 needs Java 25):

```
just all 26.2
```

which chains three stages:

1. `just extract 26.2` — `scripts/extract.sh` downloads server+client jars from
   Mojang's piston meta, runs vanilla `--reports`, and pulls block/item tags,
   enchantments, and `en_us.json` into `tools/work/`.
2. `just transform 26.2` — `scripts/transform.cr` turns `--reports` + jar tags into
   the slim schema. `--carry` (auto-resolved: the previous version in `data/`) supplies
   runtime values not present in `--reports`; `tools/deltas/26.2.json` hand-curates
   blocks/entities new in this version. Writes `data/26.2/`.
3. `just validate 26.2` — `scripts/validate.cr` parses the output through this shard's
   actual models and runs `Minecraft::Data`'s derivations. A green run means the data
   is structurally consumable.

### What each input gives

- `--reports` (`java -DbundlerMainClass=net.minecraft.data.Main -jar server.jar --reports`):
  block states + **state IDs**, item/entity registries (authoritative **numeric IDs**),
  and per-item components (`max_stack_size`, `max_damage`=durability, `tool` rules with
  block-tag refs + speeds).
- jar block tags (`data/minecraft/tags/block/*`): membership for material synthesis +
  harvestTools (recursive `#tag` expansion).
- jar enchantments (`data/minecraft/enchantment/*`): enchantment names; numeric ids are
  assigned in **sorted (alphabetical)** registry order, matching vanilla.
- client jar `assets/minecraft/lang/en_us.json`: `language.json`.

### Carry-forward + deltas

**Runtime values not in `--reports`** — `hardness` (`block.defaultDestroyTime`),
collision shapes (`BlockState.getCollisionShape`), and entity `width`/`height`
(`EntityType.sized`) — are carried forward from the previous version by block/entity
**NAME** (state IDs shift between versions, names don't). Blocks/entities **new** in the
version are declared in `tools/deltas/<version>.json`, with values verified against the
decompiled Mojmap source (github.com/extremeheat/extracted_minecraft_data). For 26.2
that delta is exactly the 28 cinnabar/sulfur blocks (all hardness 1.5, shapes = existing
archetypes) + the `sulfur_cube` entity; every other block/entity is identical to 26.1
by name.

`deltas/<version>.json` fields:

- `blocks.<name>.hardness` — from `Blocks.java` `strength(destroy, blast)` (first arg).
- `blocks.<name>.requiresCorrectToolForDrops` — whether `harvestTools` is emitted.
- `collisionArchetype.<name>` — an existing block with identical state structure whose
  collision shape this block reuses (e.g. `cinnabar_slab -> stone_slab`,
  `sulfur_spike -> pointed_dripstone`).
- `entities.<name>` — `{width, height, type, category}` for new entities.

### Fabric route (preferred when upstream mappings exist)

[PrismarineJS/minecraft-data-generator](https://github.com/PrismarineJS/minecraft-data-generator)
(the u9g Unimined/Fabric extractor) runs the real game and dumps collision
shapes/hardness/harvestTools/materials authoritatively, removing the carry-forward +
deltas step entirely. It is **currently blocked for 26.x**: Mojang stopped publishing
Mojmap proguard mappings for the 26.x series and Fabric's `intermediary:26.x` is a
broken `0.0.0` placeholder. If either lands, fork the upstream generator (keep it a
proper GitHub fork, don't vendor it) and add a 26.x module — a copy of `mc/1.21.11`
with: `version "26.x"` + Java 25 in its `build.gradle`, fabric-loader >= 0.19.3 in
`settings.gradle`, `JavaLanguageVersion.of(25)` in the buildSrc conventions, and
Gradle >= 9.1 in the wrapper. The generator's Java sources use stable Mojmap API names
unchanged 1.21.11 -> 26.2, so no source edits are expected. Then
`JAVA_HOME=<java25> ./gradlew :mc:26.x:runServer` and feed the output through
`transform.cr` (or consume the verbose output directly).

### Protocol 773 (MC 1.21.9 / 1.21.10) — fast path

Protocol 773 covers 1.21.9 and 1.21.10; PrismarineJS publishes both under `pc/1.21.9`.
The published verbose files are schema-compatible with this shard's models (extra
fields are ignored by `JSON::Serializable`), so `data/1.21.9/` uses them directly:

```
BASE=https://raw.githubusercontent.com/PrismarineJS/minecraft-data/master/data/pc/1.21.9
for f in items blocks materials enchantments blockCollisionShapes entities language; do
  curl -s "$BASE/$f.json" -o data/1.21.9/$f.json
done
crystal run tools/scripts/validate.cr -- 1.21.9
```

## Material synthesis (load-bearing for break-speed math)

`material` and `materials.json` replicate PrismarineJS's `MaterialsDataGenerator`
exactly, derived from block tags + item `tool` component rules:

- Candidate materials, **first match wins** per block: `vine_or_glow_lichen`
  (VINE/GLOW_LICHEN), `coweb` (COBWEB), `leaves` (tag), `wool` (tag), `gourd`
  (MELON/PUMPKIN/JACK_O_LANTERN), `plant` (tag `sword_efficient`), then one material per
  distinct block-tag referenced by any tool's rules (`mineable/pickaxe`,
  `incorrect_for_wooden_tool`, …), then 5 composite materials (`plant;mineable/axe`,
  `gourd;mineable/axe`, `leaves;mineable/hoe`, `leaves;mineable/axe;mineable/hoe`,
  `vine_or_glow_lichen;plant;mineable/axe`) placed first so the most specific wins.
  Fallback `default`.
- `materials.json` speeds: tool name-prefix table (wooden 2, stone 4, iron 6, diamond 8,
  netherite 9, golden 12; else 1.0) + special shears/sword entries (leaves/coweb→shears
  15, vine_or_glow_lichen→shears 2, wool→shears 5; swords→coweb 15, plant/leaves/gourd
  1.5).
- `harvestTools`: for blocks requiring a correct tool, the items whose tool rules make
  them correct, evaluated like vanilla `Tool.isCorrectForDrops` (first matching rule
  decides, `incorrect_for_*` rules exclude lower tiers).
