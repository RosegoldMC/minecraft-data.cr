def proptype(values : Array(String)) : Tuple(String, Int32)
  if values == ["true", "false"]
    {"bool", 2}
  elsif values.all? { |v| !v.empty? && v.each_char.all?(&.ascii_number?) }
    {"int", values.size}
  else
    {"enum", values.size}
  end
end

def build_blocks(blocks_report : JSON::Any, tags : Tags, ordered : Array(Tuple(String, Set(String))),
                 carry_by_name : Hash(String, JSON::Any), deltas : JSON::Any,
                 tool_rules : Hash(String, Array(Tuple(String, Bool))),
                 item_ids : Hash(String, Int32)) : Array(Hash(String, JV))
  delta_blocks = deltas["blocks"]?
  out = [] of Hash(String, JV)
  blocks_report.as_h.each do |full_name, bdef|
    name = strip_ns(full_name)
    state_ids = bdef["states"].as_a.map(&.["id"].as_i)

    states = [] of JV
    if props = bdef["properties"]?.try(&.as_h)
      props.each do |pname, pvals_any|
        pvals = pvals_any.as_a.map(&.as_s)
        t, nv = proptype(pvals)
        st = {} of String => JV
        st["name"] = pname
        st["type"] = t
        st["num_values"] = nv
        vals = [] of JV
        pvals.each { |x| vals << x }
        st["values"] = vals
        states << st
      end
    end

    carried = carry_by_name[name]?
    delta = delta_blocks.try(&.[name]?)
    hardness : JV = if carried
      carried["hardness"]? || -1.0
    elsif delta
      delta["hardness"]? || -1.0
    else
      -1.0
    end

    requires_tool = (carried && carried["harvestTools"]?) ||
                    (delta && (delta["requiresCorrectToolForDrops"]?.try(&.as_bool?) || false))
    harvest = requires_tool ? compute_harvest_tools(name, tags, tool_rules, item_ids) : nil

    entry = {} of String => JV
    entry["name"] = name
    entry["hardness"] = hardness
    entry["material"] = material_for_block(name, ordered)
    entry["minStateId"] = state_ids.min
    entry["maxStateId"] = state_ids.max
    entry["states"] = states
    if harvest && !harvest.empty?
      hh = {} of String => JV
      harvest.each { |k, v| hh[k] = v }
      entry["harvestTools"] = hh
    end
    out << entry
  end
  out.sort_by! { |entry| entry["minStateId"].as(Int32) }
  out
end
