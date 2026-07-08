# Transform Minecraft jar data into the slim per-version data/<version>/ schema.
#
# Run via the justfile (`just transform 26.2`) or directly:
#   crystal run tools/scripts/transform.cr -- \
#     --work tools/work/ --carry data/26.1 --deltas tools/deltas/26.2.json \
#     --entity-classify <verbose entities.json> --out data/26.2
#
# Inputs (under --work): reports/ (vanilla --reports), jar-data/tags/{block,item}/,
# jar-data/enchantment/, lang/en_us.json. --carry is the previous version's slim assets
# (runtime values carried forward by NAME); --deltas hand-curates blocks/entities new in
# this version. Output is written in json_writer.cr's canonical one-record-per-line form.
# The material synthesis and tool-speed logic replicate PrismarineJS's
# minecraft-data-generator (see README for algorithm + provenance).
require "json"
require "./json_writer"
require "./lib/json_source"
require "./lib/tags"
require "./lib/items"
require "./lib/materials"
require "./lib/blocks"
require "./lib/collision"
require "./lib/enchantments"
require "./lib/entities"

def write_file(out_dir : String, name : String, value : JV)
  path = "#{out_dir}/#{name}"
  File.open(path, "w") do |file|
    json_emit(file, value, root: true)
    file << '\n'
  end
  puts "  #{name}: #{File.size(path)} bytes"
end

work = carry = deltas_path = out_dir = classify_path = nil
i = 0
while i < ARGV.size
  case ARGV[i]
  when "--work"            then work = ARGV[i + 1]; i += 2
  when "--carry"           then carry = ARGV[i + 1]; i += 2
  when "--deltas"          then deltas_path = ARGV[i + 1]; i += 2
  when "--entity-classify" then classify_path = ARGV[i + 1]; i += 2
  when "--out"             then out_dir = ARGV[i + 1]; i += 2
  else
    STDERR.puts "unknown argument: #{ARGV[i]}"
    exit 1
  end
end

abort "missing --work" unless work
abort "missing --carry" unless carry
abort "missing --deltas" unless deltas_path
abort "missing --out" unless out_dir

reports = "#{work}/reports"
registries = load_json("#{reports}/registries.json")
blocks_report = load_json("#{reports}/blocks.json")
components_dir = "#{reports}/minecraft/components/item"
block_tags = Tags.new("#{work}/jar-data/tags/block")
item_tags = Tags.new("#{work}/jar-data/tags/item")
ench_dir = "#{work}/jar-data/enchantment"
deltas = (deltas_path && File.exists?(deltas_path)) ? load_json(deltas_path) : JSON.parse("{}")

item_ids = id_map(registries, "minecraft:item")

carry_block_by_name = {} of String => JSON::Any
load_json("#{carry}/blocks.json").as_a.each { |blk| carry_block_by_name[blk["name"].as_s] = blk }
carry_shapes = load_json("#{carry}/blockCollisionShapes.json")
carry_entity_by_name = {} of String => JSON::Any
load_json("#{carry}/entities.json").as_a.each { |e| carry_entity_by_name[e["name"].as_s] = e }

tool = collect_tool_materials(components_dir, item_ids)
ordered = build_material_predicates(block_tags, tool.tool_tag_order)

classify = {} of String => JSON::Any
if classify_path && File.exists?(classify_path)
  load_json(classify_path).as_a.each { |e| classify[e["name"].as_s] = e }
end

Dir.mkdir_p(out_dir)
puts "Writing slim data files to #{out_dir}"

blocks = build_blocks(blocks_report, block_tags, ordered, carry_block_by_name, deltas, tool.tool_rules, item_ids)
blocks_jv = [] of JV
blocks.each { |blk| blocks_jv << blk }

write_file(out_dir, "items.json", build_items(registries, components_dir, item_tags))
write_file(out_dir, "blocks.json", blocks_jv)
write_file(out_dir, "materials.json", build_materials(tool, item_ids))
write_file(out_dir, "enchantments.json", build_enchantments(ench_dir))
write_file(out_dir, "blockCollisionShapes.json", build_collision_shapes(blocks, carry_shapes, deltas))
write_file(out_dir, "entities.json", build_entities(registries, carry_entity_by_name, deltas, classify))
write_file(out_dir, "language.json", load_json("#{work}/lang/en_us.json"))
puts "done"
