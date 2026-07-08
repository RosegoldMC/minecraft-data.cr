def enchant_categories_for(item_name : String, item_tags : Tags, category_tags : Array(String)) : Array(String)
  category_tags.select { |cat| item_tags.has?("enchantable/#{cat}", item_name) }.sort!
end

def build_items(registries : JSON::Any, components_dir : String, item_tags : Tags) : Array(JV)
  ids = id_map(registries, "minecraft:item")
  category_tags = [] of String
  ench_dir = "#{item_tags.dir}/enchantable"
  if Dir.exists?(ench_dir)
    category_tags = Dir.glob("#{ench_dir}/*.json").map { |path| File.basename(path, ".json") }
  end

  items = [] of JV
  ids.to_a.sort_by { |(_, iid)| iid }.each do |(name, iid)|
    comp_path = "#{components_dir}/#{name}.json"
    stack_size = 64
    max_durability = nil.as(Int32?)
    if File.exists?(comp_path)
      comps = load_json(comp_path)["components"]?.try(&.as_h) || {} of String => JSON::Any
      stack_size = comps["minecraft:max_stack_size"]?.try(&.as_i) || 64
      max_durability = comps["minecraft:max_damage"]?.try(&.as_i)
    end
    entry = {} of String => JV
    entry["id"] = iid
    entry["name"] = name
    entry["stackSize"] = stack_size
    entry["maxDurability"] = max_durability if max_durability
    unless category_tags.empty?
      cats = enchant_categories_for(name, item_tags, category_tags)
      unless cats.empty?
        arr = [] of JV
        cats.each { |cat| arr << cat }
        entry["enchantCategories"] = arr
      end
    end
    items << entry
  end
  items
end
