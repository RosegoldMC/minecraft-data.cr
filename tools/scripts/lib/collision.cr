# Shapes carried by NAME from the previous version; new blocks reuse an archetype's.
def build_collision_shapes(blocks : Array(Hash(String, JV)), carry_shapes : JSON::Any,
                           deltas : JSON::Any) : Hash(String, JV)
  carry_block_map = carry_shapes["blocks"].as_h
  carry_shape_def = carry_shapes["shapes"].as_h
  archetypes = deltas["collisionArchetype"]?.try(&.as_h) || {} of String => JSON::Any

  out_blocks = {} of String => JV
  blocks.each do |block|
    name = block["name"].as(String)
    if carry_block_map.has_key?(name)
      out_blocks[name] = carry_block_map[name]
    elsif archetypes.has_key?(name)
      src = archetypes[name].as_s
      raise "archetype source '#{src}' for '#{name}' not found in carry shapes" unless carry_block_map.has_key?(src)
      out_blocks[name] = carry_block_map[src]
    else
      raise "no collision shape for new block '#{name}': add to deltas.collisionArchetype"
    end
  end

  out_shapes = {} of String => JV
  carry_shape_def.each { |k, v| out_shapes[k] = v }

  result = {} of String => JV
  result["blocks"] = out_blocks
  result["shapes"] = out_shapes
  result
end
