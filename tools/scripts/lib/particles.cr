PARTICLE_CODECS = {
  "BlockParticleOption"        => "block_state",
  "ColorParticleOption"        => "color",
  "DustParticleOptions"        => "dust",
  "DustColorTransitionOptions" => "dust_color_transition",
  "SculkChargeParticleOptions" => "sculk_charge",
  "ItemParticleOption"         => "item_stack",
  "VibrationParticleOption"    => "vibration",
  "TrailParticleOption"        => "trail",
  "ShriekParticleOption"       => "shriek",
  "PowerParticleOption"        => "power",
  "SpellParticleOption"        => "spell",
  "GeyserParticleOptions"      => "geyser",
  "GeyserBaseParticleOptions"  => "geyser_base",
}

POSITION_SOURCE_CODECS = {
  "BlockPositionSource"  => "block_pos",
  "EntityPositionSource" => "entity_id_offset",
}

def build_particles(path : String) : Array(JV)
  particles = [] of JV
  File.each_line(path) do |line|
    next unless line.includes?("= register(")

    if match = /SimpleParticleType\s+\w+\s*=\s*register\("([^"]+)"/.match(line)
      particles << particle_metadata(particles.size, match[1], "simple")
    elsif match = /ParticleType<(\w+)>\s+\w+\s*=\s*register\("([^"]+)"/.match(line)
      option_type, name = match[1], match[2]
      codec = PARTICLE_CODECS[option_type]? || raise "Unknown particle option #{option_type} in #{path}"
      particles << particle_metadata(particles.size, name, codec)
    else
      raise "Unrecognized particle registration in #{path}: #{line.strip}"
    end
  end
  raise "No particle registrations found in #{path}" if particles.empty?
  particles
end

private def particle_metadata(id : Int32, name : String, codec : String) : JV
  {"id" => id, "name" => "minecraft:#{name}", "codec" => codec} of String => JV
end

def build_position_sources(path : String) : Array(JV)
  position_sources = [] of JV
  File.each_line(path) do |line|
    next unless line.includes?("= register(")

    if match = /PositionSourceType<(\w+)>\s+\w+\s*=\s*register\("([^"]+)"/.match(line)
      source_type, name = match[1], match[2]
      codec = POSITION_SOURCE_CODECS[source_type]? || raise "Unknown position source #{source_type} in #{path}"
      position_sources << particle_metadata(position_sources.size, name, codec)
    else
      raise "Unrecognized position-source registration in #{path}: #{line.strip}"
    end
  end
  raise "No position source registrations found in #{path}" if position_sources.empty?
  position_sources
end
