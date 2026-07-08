# Numeric ids assigned in sorted (alphabetical) registry order.
def build_enchantments(ench_dir : String) : Array(JV)
  names = Dir.glob("#{ench_dir}/*.json").map { |path| File.basename(path, ".json") }.sort!
  out = [] of JV
  names.each_with_index do |enchant_name, idx|
    entry = {} of String => JV
    entry["id"] = idx
    entry["name"] = enchant_name
    out << entry
  end
  out
end
