def strip_ns(name : String) : String
  i = name.index(':')
  i ? name[(i + 1)..] : name
end

def load_json(path : String) : JSON::Any
  JSON.parse(File.read(path))
end

def id_map(registries : JSON::Any, registry : String) : Hash(String, Int32)
  map = {} of String => Int32
  registries[registry]["entries"].as_h.each do |k, v|
    map[strip_ns(k)] = v["protocol_id"].as_i
  end
  map
end
