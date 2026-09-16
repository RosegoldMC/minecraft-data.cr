require "spec"
require "../src/minecraft-data"

LATEST              = Minecraft::Data.load("26.3")
PARTICLE_REGISTRIES = {
  "1.21.8"  => Minecraft::Data::ParticleRegistry.from_json(Minecraft::Data.read_asset("1.21.8/particles.json")),
  "1.21.9"  => Minecraft::Data::ParticleRegistry.from_json(Minecraft::Data.read_asset("1.21.9/particles.json")),
  "1.21.11" => Minecraft::Data::ParticleRegistry.from_json(Minecraft::Data.read_asset("1.21.11/particles.json")),
  "26.1"    => Minecraft::Data::ParticleRegistry.from_json(Minecraft::Data.read_asset("26.1/particles.json")),
  "26.2"    => Minecraft::Data::ParticleRegistry.from_json(Minecraft::Data.read_asset("26.2/particles.json")),
  "26.3"    => Minecraft::Data::ParticleRegistry.from_json(Minecraft::Data.read_asset("26.3/particles.json")),
}

describe Minecraft::Data do
  it "parses all registries of the latest shipped version" do
    LATEST.items.size.should be > 0
    LATEST.blocks.size.should be > 0
    LATEST.enchantments.size.should be > 0
    LATEST.materials.json_unmapped.size.should be > 0
  end

  it "derives a name for every block state" do
    max_state = LATEST.blocks.max_of(&.max_state_id)
    LATEST.block_state_names.size.should eq(max_state + 1)
    LATEST.block_state_names.count(&.empty?).should eq(0)
  end

  it "derives a collision shape slot for every block state" do
    max_state = LATEST.blocks.max_of(&.max_state_id)
    LATEST.block_state_collision_shapes.size.should eq(max_state + 1)
  end

  it "treats air as an air state with no collision boxes" do
    air = LATEST.blocks.find { |b| b.id_str == "air" }.not_nil!
    LATEST.air_states.should contain(air.min_state_id)
    LATEST.block_state_collision_shapes[air.min_state_id].should be_empty
  end

  it "gives stone a full-cube collision shape" do
    stone = LATEST.blocks.find { |b| b.id_str == "stone" }.not_nil!
    shapes = LATEST.block_state_collision_shapes[stone.min_state_id]
    shapes.size.should eq(1)
    shapes[0].should eq({0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32, 1.0_f32, 1.0_f32})
  end

  it "references only materials that exist" do
    LATEST.blocks.each do |block|
      LATEST.materials.json_unmapped.has_key?(block.material).should be_true
    end
  end

  it "names multi-property states with property=value pairs" do
    slab = LATEST.blocks.find { |b| b.id_str == "oak_slab" }.not_nil!
    LATEST.block_state_names[slab.min_state_id].should eq("oak_slab[type=top, waterlogged=true]")
  end

  it "ships the shelf mushroom's age and facing collision shapes" do
    mushroom = LATEST.blocks.find { |b| b.id_str == "shelf_mushroom" }.not_nil!
    mushroom.min_state_id.should eq(11227_u16)
    mushroom.max_state_id.should eq(11234_u16)
    LATEST.block_state_collision_shapes[mushroom.min_state_id].should eq([
      {0.1875_f32, 0.5625_f32, 0.5625_f32, 0.8125_f32, 0.6875_f32, 1.0_f32},
      {0.3125_f32, 0.5_f32, 0.75_f32, 0.6875_f32, 0.5625_f32, 1.0_f32},
    ])
    LATEST.block_state_collision_shapes[mushroom.max_state_id].should eq([
      {0.0_f32, 0.5_f32, 0.0625_f32, 0.625_f32, 0.6875_f32, 0.9375_f32},
      {0.0_f32, 0.375_f32, 0.25_f32, 0.375_f32, 0.5_f32, 0.75_f32},
    ])
  end

  it "ships contiguous particle and position-source registries for every version" do
    PARTICLE_REGISTRIES.each_value do |registry|
      registry.schema.should eq(1_u32)
      registry.particles.map(&.id).should eq((0...registry.particles.size).map(&.to_u32).to_a)
      registry.particles.find(&.name.==("minecraft:item")).not_nil!.codec.should eq("item_stack")
      registry.position_sources.map(&.codec).should eq(["block_pos", "entity_id_offset"])
    end

    PARTICLE_REGISTRIES["26.2"].particles.find(&.name.==("minecraft:geyser_base")).not_nil!.codec.should eq("geyser_base")
  end
end
