# Dims from carry/delta; type/category from classify source or delta.
def build_entities(registries : JSON::Any, carry_by_name : Hash(String, JSON::Any),
                   deltas : JSON::Any, classify : Hash(String, JSON::Any)) : Array(JV)
  ids = id_map(registries, "minecraft:entity_type")
  delta_entities = deltas["entities"]?
  out = [] of JV
  ids.to_a.sort_by { |(_, eid)| eid }.each do |(name, eid)|
    carried = carry_by_name[name]?
    delta = delta_entities.try(&.[name]?)
    dims = delta || carried
    cls = (delta && delta["type"]?) ? delta : classify[name]?

    entry = {} of String => JV
    entry["id"] = eid
    entry["name"] = name
    entry["width"] = dims.try(&.["width"]?) || 0.0
    entry["height"] = dims.try(&.["height"]?) || 0.0
    if cls && (t = cls["type"]?)
      entry["type"] = t
    end
    if cls && (cat = cls["category"]?)
      entry["category"] = cat
    end
    out << entry
  end
  out
end
