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
particle_registry = Minecraft::Data::ParticleRegistry.from_json(read_asset_file(root, "particles.json"))

puts "  items: #{data.items.size}, blocks: #{data.blocks.size}, " \
     "materials: #{data.materials.json_unmapped.size}, " \
     "enchantments: #{data.enchantments.size}, entities: #{entities.size}, " \
     "translations: #{translations.size}"

# Cross-file checks Data#initialize doesn't enforce
data.blocks.each do |block|
  data.materials.json_unmapped[block.material]? || raise "block #{block.id_str} uses unknown material '#{block.material}'"
end

raise "particles.json has schema #{particle_registry.schema}" unless particle_registry.schema == 1_u32

def validate_registry_entries(entries, label : String, codecs : Set(String)) : Nil
  ids = Set(UInt32).new
  names = Set(String).new
  entries.each_with_index do |entry, index|
    raise "#{label}: id #{entry.id} is not contiguous at index #{index}" unless entry.id == index
    raise "#{label}: duplicate id #{entry.id}" unless ids.add?(entry.id)
    raise "#{label}: duplicate name #{entry.name}" unless names.add?(entry.name)
    raise "#{label}: unknown codec #{entry.codec}" unless codecs.includes?(entry.codec)
  end
end

validate_registry_entries(
  particle_registry.particles,
  "particles",
  Set{"simple", "block_state", "color", "dust", "dust_color_transition", "sculk_charge", "item_stack", "vibration", "trail", "shriek", "power", "spell", "geyser", "geyser_base"},
)
validate_registry_entries(
  particle_registry.position_sources,
  "position_sources",
  Set{"block_pos", "entity_id_offset"},
)

max_block_state = data.blocks.max_of(&.max_state_id)
data.blocks.each do |block|
  expected = block.max_state_id - block.min_state_id + 1
  actual = (block.min_state_id..block.max_state_id).count { |nr| !data.block_state_names[nr].empty? }
  raise "#{block.id_str}: #{actual} named states != #{expected} state ids" if actual != expected
end

empty = (0..max_block_state).count { |i| data.block_state_names[i].empty? }
puts "  max_block_state=#{max_block_state}, unfilled state-name slots=#{empty}"
puts "  particles=#{particle_registry.particles.size}, position_sources=#{particle_registry.position_sources.size}"

puts "OK: all #{version} assets parsed and derived cleanly"
