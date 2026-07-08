# Block/item tags with recursive #tag expansion.
class Tags
  getter dir : String

  def initialize(@dir : String)
    @cache = {} of String => Set(String)
  end

  def members(tag_path : String) : Set(String)
    if cached = @cache[tag_path]?
      return cached
    end
    @cache[tag_path] = Set(String).new # cycle guard
    result = Set(String).new
    f = "#{@dir}/#{tag_path}.json"
    if File.exists?(f)
      data = load_json(f)
      values = data.as_h? ? data["values"].as_a : data.as_a
      values.each do |v|
        entry = v.as_h? ? v["id"].as_s : v.as_s
        if entry.starts_with?('#')
          result.concat(members(strip_ns(entry[1..])))
        else
          result << strip_ns(entry)
        end
      end
    end
    @cache[tag_path] = result
    result
  end

  def has?(tag_path : String, name : String) : Bool
    members(tag_path).includes?(name)
  end
end
