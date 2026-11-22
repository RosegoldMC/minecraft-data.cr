require "spec"
require "../src/minecraft-data"

describe Minecraft::Data::BlockOutlines do
  {% for version in Minecraft::Data::SHIPPED_VERSIONS %}
    it "ships outlines for every block state in #{{{version}}}" do
      data = Minecraft::Data.load({{version}})
      outlines = Minecraft::Data::BlockOutlines.from_json(Minecraft::Data.read_asset({{version + "/blockOutlines.json"}}))

      outlines.blocks.size.should eq(data.blocks.size)
      data.blocks.each_with_index do |block, id|
        row = outlines.blocks[id]
        state_count = block.max_state_id.to_i - block.min_state_id.to_i + 1
        [1, state_count].should contain(row.size)
        row.each { |shape_id| (0...outlines.shapes.size).should contain(shape_id) }
      end
      outlines.shapes.each do |shape|
        shape.each do |box|
          box.size.should eq(6)
          (0...3).each { |axis| box[axis].should be < box[axis + 3] }
        end
      end

      states = 0...data.block_state_names.size
      outlines.offsets.should_not be_empty
      outlines.offsets.each do |state, xz, y|
        states.should contain(state)
        xz.should be >= 0
        y.should be >= 0
      end
      item_names = data.items.map(&.name).to_set
      outlines.held.each do |state, item, shape_id|
        states.should contain(state)
        item_names.should contain(item)
        (0...outlines.shapes.size).should contain(shape_id)
      end

      coral_id = data.blocks.index(&.id_str.==("tube_coral_fan")).not_nil!
      outlines.shapes[outlines.blocks[coral_id].first].should eq([[0.125, 0.0, 0.125, 0.875, 0.25, 0.875]])
      light_id = data.blocks.index(&.id_str.==("light")).not_nil!
      outlines.shapes[outlines.blocks[light_id].first].should be_empty
      light_state = data.blocks[light_id].min_state_id
      held_light = outlines.held.find { |state, item, _| state == light_state && item == "light" }.not_nil!
      outlines.shapes[held_light[2]].should eq([[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]])
    end
  {% end %}
end
