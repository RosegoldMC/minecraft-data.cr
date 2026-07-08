require "json"

# Canonical JSON emitter for the generator's output.
#
# Style: "one record per line". The root container's direct children each go on their own
# line; any nested container with >= JSON_EXPAND_MIN children is also expanded (so the
# blockCollisionShapes blocks/shapes maps stay readable), while smaller ones stay compact.
# No indentation — git diffs become one line per record with only newlines added, so the
# embedded assets barely grow. Numbers keep their source form (2.0 stays 2.0); strings are
# emitted as raw UTF-8.
#
# Accepts both parsed `JSON::Any` trees (format.cr reformatting files in place) and the
# `JV` values transform.cr builds, so generation writes canonical output in one pass.

JSON_EXPAND_MIN = 16

# Recursive value type the emitter accepts. Carried/delta numbers are spliced as JSON::Any
# so they keep their source int-vs-float form; computed numbers use native Int32/Float64.
alias JV = Nil | Bool | Int32 | Int64 | Float64 | String | JSON::Any | Array(JV) | Hash(String, JV)

def json_emit_string(io : IO, str : String) : Nil
  io << '"'
  str.each_char do |chr|
    case chr
    when '"'  then io << "\\\""
    when '\\' then io << "\\\\"
    when '\b' then io << "\\b"
    when '\t' then io << "\\t"
    when '\n' then io << "\\n"
    when '\f' then io << "\\f"
    when '\r' then io << "\\r"
    else
      if chr.ord < 0x20
        io << "\\u" << chr.ord.to_s(16).rjust(4, '0')
      else
        io << chr
      end
    end
  end
  io << '"'
end

def json_emit_scalar(io : IO, raw) : Nil
  case raw
  when Nil    then io << "null"
  when Bool   then io << (raw ? "true" : "false")
  when String then json_emit_string(io, raw)
  else             io << raw.to_s # Int32 / Int64 / Float64
  end
end

def json_emit_compact(io : IO, node : JV | JSON::Any::Type) : Nil
  node = node.raw if node.is_a?(JSON::Any)
  case node
  when Hash
    io << '{'
    first = true
    node.each do |key, value|
      io << ',' unless first
      first = false
      json_emit_string(io, key)
      io << ':'
      json_emit_compact(io, value)
    end
    io << '}'
  when Array
    io << '['
    node.each_with_index do |value, idx|
      io << ',' if idx > 0
      json_emit_compact(io, value)
    end
    io << ']'
  else
    json_emit_scalar(io, node)
  end
end

def json_emit(io : IO, node : JV | JSON::Any::Type, root : Bool = false) : Nil
  node = node.raw if node.is_a?(JSON::Any)
  case node
  when Hash
    if !node.empty? && (root || node.size >= JSON_EXPAND_MIN)
      io << "{\n"
      first = true
      node.each do |key, value|
        io << ",\n" unless first
        first = false
        json_emit_string(io, key)
        io << ':'
        json_emit(io, value)
      end
      io << "\n}"
    else
      json_emit_compact(io, node)
    end
  when Array
    if !node.empty? && (root || node.size >= JSON_EXPAND_MIN)
      io << "[\n"
      node.each_with_index do |value, idx|
        io << ",\n" if idx > 0
        json_emit(io, value)
      end
      io << "\n]"
    else
      json_emit_compact(io, node)
    end
  else
    json_emit_scalar(io, node)
  end
end

def pretty_format_file(path : String) : Nil
  doc = JSON.parse(File.read(path))
  File.open(path, "w") do |file|
    json_emit(file, doc, root: true)
    file << '\n'
  end
end
