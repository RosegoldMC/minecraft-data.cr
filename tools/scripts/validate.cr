# Validate generated data/<version>/ by parsing it through the shard's actual model
# classes and running Minecraft::Data's derivations (block-state-name cartesian product
# vs state-id ranges, per-state collision shape resolution).
# Run: crystal run tools/scripts/validate.cr -- <version>
require "../../src/minecraft-data"

version = ARGV[0]? || Minecraft::Data::SHIPPED_VERSIONS.last
root = "#{__DIR__}/../../data/#{version}"

def read_asset_file(root : String, name : String) : String
  File.read("#{root}/#{name}")
end

puts "Validating data/#{version}/ against Minecraft::Data models"

data = Minecraft::Data.new(
  read_asset_file(root, "items.json"),
  read_asset_file(root, "blocks.json"),
  read_asset_file(root, "materials.json"),
  read_asset_file(root, "enchantments.json"),
  read_asset_file(root, "blockCollisionShapes.json"),
)
entities = Array(Minecraft::Data::EntityMetadata).from_json(read_asset_file(root, "entities.json"))
translations = Hash(String, String).from_json(read_asset_file(root, "language.json"))

puts "  items: #{data.items.size}, blocks: #{data.blocks.size}, " \
     "materials: #{data.materials.json_unmapped.size}, " \
     "enchantments: #{data.enchantments.size}, entities: #{entities.size}, " \
     "translations: #{translations.size}"

# Cross-file checks Data#initialize doesn't enforce
data.blocks.each do |block|
  data.materials.json_unmapped[block.material]? || raise "block #{block.id_str} uses unknown material '#{block.material}'"
end

max_block_state = data.blocks.max_of(&.max_state_id)
data.blocks.each do |block|
  expected = block.max_state_id - block.min_state_id + 1
  actual = (block.min_state_id..block.max_state_id).count { |nr| !data.block_state_names[nr].empty? }
  raise "#{block.id_str}: #{actual} named states != #{expected} state ids" if actual != expected
end

empty = (0..max_block_state).count { |i| data.block_state_names[i].empty? }
puts "  max_block_state=#{max_block_state}, unfilled state-name slots=#{empty}"

puts "OK: all #{version} assets parsed and derived cleanly"
