require "./json_writer"
require "./lib/particles"

out_path = ARGV[0]?
particle_types_path = ARGV[1]?
position_source_types_path = ARGV[2]?

abort "usage: particles.cr <out> <ParticleTypes.java> <PositionSourceType.java>" unless out_path && particle_types_path && position_source_types_path

particles = build_particles(particle_types_path)
position_sources = build_position_sources(position_source_types_path)

File.open(out_path, "w") do |file|
  json_emit(file, {
    "schema"           => 1_i32,
    "particles"        => particles,
    "position_sources" => position_sources,
  } of String => JV, root: true)
  file << '\n'
end
