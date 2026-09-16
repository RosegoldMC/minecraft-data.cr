# Shapes carried by NAME from the previous version; new blocks reuse an archetype's.
def build_collision_shapes(blocks : Array(Hash(String, JV)), carry_shapes : JSON::Any,
                           deltas : JSON::Any) : Hash(String, JV)
  carry_block_map = carry_shapes["blocks"].as_h
  carry_shape_def = carry_shapes["shapes"].as_h
  archetypes = deltas["collisionArchetype"]?.try(&.as_h) || {} of String => JSON::Any
  custom_shapes = deltas["collisionShapes"]?.try(&.as_h) || {} of String => JSON::Any

  out_blocks = {} of String => JV
  out_shapes = {} of String => JV
  carry_shape_def.each { |k, v| out_shapes[k] = v }
  next_shape_id = out_shapes.keys.max_of(&.to_i) + 1

  blocks.each do |block|
    name = block["name"].as(String)
    if carry_block_map.has_key?(name)
      out_blocks[name] = carry_block_map[name]
    elsif shapes = custom_shapes[name]?
      state_shapes = shapes.as_a
      state_count = block["maxStateId"].as(Int32) - block["minStateId"].as(Int32) + 1
      raise "#{name}: #{state_shapes.size} custom collision shapes != #{state_count} states" if state_shapes.size != state_count

      ids = [] of JV
      state_shapes.each do |shape|
        key = shape.to_json
        existing = out_shapes.find { |_, candidate| candidate.to_json == key }
        if existing
          ids << existing[0].to_i
        else
          out_shapes[next_shape_id.to_s] = shape
          ids << next_shape_id
          next_shape_id += 1
        end
      end
      out_blocks[name] = ids
    elsif archetypes.has_key?(name)
      src = archetypes[name].as_s
      raise "archetype source '#{src}' for '#{name}' not found in carry shapes" unless carry_block_map.has_key?(src)
      out_blocks[name] = carry_block_map[src]
    else
      raise "no collision shape for new block '#{name}': add to deltas.collisionArchetype"
    end
  end

  result = {} of String => JV
  result["blocks"] = out_blocks
  result["shapes"] = out_shapes
  result
end
