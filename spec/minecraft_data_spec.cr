require "spec"
require "../src/minecraft-data"

LATEST = Minecraft::Data.load("26.2")

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
end
