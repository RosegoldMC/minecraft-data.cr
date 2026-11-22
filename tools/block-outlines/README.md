# Block outline data

Use Python 3.10+, JDK 25+, Crystal, and curl. From `tools/`:

```sh
just outlines /path/to/scratch
just check-outlines /path/to/scratch
```

Both commands take optional versions after the scratch path. Without `just`, run
`python3 -I tools/block-outlines/generate.py --work-dir /path/to/scratch` from the
repository root. Add `--check` to regenerate and compare without changing `data/`.

The generator caches Mojang's server bundles and, for the older releases, official
server mappings in the scratch directory. It checks the pinned Mojang SHA-1 hashes
and the SHA-256 hashes in each bundle before running Java in a fresh scratch
subdirectory. The same formatter used in CI formats the generated JSON before
writing or comparing `data/<version>/blockOutlines.json`.

These assets come from vanilla `getShape`, keyed by the vanilla registry and state
IDs. Generation checks every ID and block name against the shard's `blocks.json`
and checks held-item names against `items.json`. The box lists preserve holes and
other non-cube shapes. Each asset also records the positional offsets actually
applied to outlines and the alternate shapes for light and scaffolding when held
in the main hand.

The generator uses an empty world, so shulker boxes have their closed outline.
It reports blocks with a separate `getInteractionShape`; those shapes override
the hit face in vanilla and aren't exported here.
