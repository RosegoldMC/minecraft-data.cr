# Material synthesis and tool speeds replicate PrismarineJS's minecraft-data-generator
# (MaterialsDataGenerator); see README for algorithm + provenance.
TOOL_SPEED_PREFIX = [
  {"wooden", 2.0}, {"stone", 4.0}, {"iron", 6.0},
  {"diamond", 8.0}, {"netherite", 9.0}, {"golden", 12.0},
]

COMPOSITES = [
  ["plant", "mineable/axe"],
  ["gourd", "mineable/axe"],
  ["leaves", "mineable/hoe"],
  ["leaves", "mineable/axe", "mineable/hoe"],
  ["vine_or_glow_lichen", "plant", "mineable/axe"],
]

SPECIAL_VINE  = Set{"vine", "glow_lichen"}
SPECIAL_COWEB = Set{"cobweb"}
SPECIAL_GOURD = Set{"melon", "pumpkin", "jack_o_lantern"}

def tool_speed_for_item(item_name : String) : Float64
  TOOL_SPEED_PREFIX.each do |(prefix, speed)|
    return speed if item_name.starts_with?(prefix)
  end
  1.0
end

record ToolData,
  tag_to_items : Hash(String, Hash(String, Float64)),
  tool_tag_order : Array(String),
  sword_items : Array(String),
  tool_rules : Hash(String, Array(Tuple(String, Bool)))

# Every TOOL item, every rule (regardless of correct_for_drops), contributes
# {item: name-prefix-speed} to a material named after the rule's block-tag path.
def collect_tool_materials(components_dir : String, item_ids : Hash(String, Int32)) : ToolData
  tag_to_items = {} of String => Hash(String, Float64)
  tool_tag_order = [] of String
  sword_items = [] of String
  tool_rules = {} of String => Array(Tuple(String, Bool))

  item_ids.to_a.sort_by { |(_, id)| id }.each do |(name, _id)|
    comp_path = "#{components_dir}/#{name}.json"
    next unless File.exists?(comp_path)
    comps = load_json(comp_path)["components"]?.try(&.as_h) || {} of String => JSON::Any
    sword_items << name if name.includes?("sword")
    tool = comps["minecraft:tool"]?
    next unless tool
    rules = tool["rules"]?.try(&.as_a) || [] of JSON::Any
    rules.each do |rule|
      blocks = rule["blocks"]?
      next unless blocks && blocks.as_s? # array-of-blocks form not used by vanilla tools
      bs = blocks.as_s
      ok = rule["correct_for_drops"]?.try(&.as_bool?) || false
      if bs.starts_with?('#')
        mat = strip_ns(bs[1..])
        (tool_rules[name] ||= [] of Tuple(String, Bool)) << {"#" + mat, ok}
        unless tag_to_items.has_key?(mat)
          tag_to_items[mat] = {} of String => Float64
          tool_tag_order << mat
        end
        tag_to_items[mat][name] = tool_speed_for_item(name)
      else
        (tool_rules[name] ||= [] of Tuple(String, Bool)) << {strip_ns(bs), ok}
      end
    end
  end
  ToolData.new(tag_to_items, tool_tag_order, sword_items, tool_rules)
end

# Vanilla Tool.isCorrectForDrops: FIRST matching rule decides; correct iff that rule's
# correct_for_drops is true. Returns {item_id => true} sorted by numeric id.
def compute_harvest_tools(block_name : String, tags : Tags,
                          tool_rules : Hash(String, Array(Tuple(String, Bool))),
                          item_ids : Hash(String, Int32)) : Hash(String, Bool)
  result = {} of String => Bool
  tool_rules.each do |item_name, rules|
    correct = false
    rules.each do |(ref, ok)|
      matches = ref.starts_with?('#') ? tags.has?(ref[1..], block_name) : ref == block_name
      if matches
        correct = ok
        break
      end
    end
    result[item_ids[item_name].to_s] = true if correct
  end
  sorted = {} of String => Bool
  result.to_a.sort_by { |(k, _)| k.to_i }.each { |(k, v)| sorted[k] = v }
  sorted
end

# Ordered (material, members) list, first match wins. Composites placed FIRST
# (prismarine addFirst; reversed so the most-specific last-inserted wins).
def build_material_predicates(tags : Tags, tool_tag_order : Array(String)) : Array(Tuple(String, Set(String)))
  base = [] of Tuple(String, Set(String))
  base << {"vine_or_glow_lichen", SPECIAL_VINE}
  base << {"coweb", SPECIAL_COWEB}
  base << {"leaves", tags.members("leaves")}
  base << {"wool", tags.members("wool")}
  base << {"gourd", SPECIAL_GOURD}
  base << {"plant", tags.members("sword_efficient")}
  tool_tag_order.each { |mat| base << {mat, tags.members(mat)} }

  by_name = {} of String => Set(String)
  base.each { |(n, m)| by_name[n] = m }

  composites = [] of Tuple(String, Set(String))
  COMPOSITES.each do |parts|
    members = if parts.all? { |part| by_name.has_key?(part) }
                parts.map { |part| by_name[part] }.reduce { |acc, set| acc & set }
              else
                Set(String).new
              end
    composites << {parts.join(";"), members}
  end
  composites.reverse + base
end

def material_for_block(block_name : String, ordered : Array(Tuple(String, Set(String)))) : String
  ordered.each do |(mat, members)|
    return mat if members.includes?(block_name)
  end
  "default"
end

def build_materials(tool : ToolData, item_ids : Hash(String, Int32)) : Hash(String, JV)
  speeds = {} of String => Hash(String, Float64)
  speeds["default"] = {} of String => Float64
  add = ->(mat : String, item_name : String, speed : Float64) {
    (speeds[mat] ||= {} of String => Float64)[item_ids[item_name].to_s] = speed
  }

  tool.tag_to_items.each do |mat, items|
    items.each { |item_name, speed| add.call(mat, item_name, speed) }
  end

  if item_ids.has_key?("shears")
    [{"leaves", 15.0}, {"coweb", 15.0}, {"vine_or_glow_lichen", 2.0}, {"wool", 5.0}].each do |(mat, sp)|
      add.call(mat, "shears", sp)
    end
  end
  tool.sword_items.each do |sword|
    add.call("coweb", sword, 15.0)
    ["plant", "leaves", "gourd"].each { |mat| add.call(mat, sword, 1.5) }
  end

  COMPOSITES.each do |parts|
    merged = {} of String => Float64
    parts.each { |part| speeds[part]?.try { |hash| merged.merge!(hash) } }
    speeds[parts.join(";")] = merged
  end

  out = {} of String => JV
  speeds.each do |mat, items|
    inner = {} of String => JV
    items.each { |k, v| inner[k] = v }
    out[mat] = inner
  end
  out
end
