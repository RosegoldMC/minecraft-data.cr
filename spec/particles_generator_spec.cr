require "spec"
require "../tools/scripts/json_writer"
require "../tools/scripts/lib/particles"

describe "particle asset generator" do
  it "rejects an unrecognized registration" do
    path = ""
    path = File.tempname("particles")
    File.write(path, "public static final ParticleType<UnknownParticleOptions> UNKNOWN = register(\"unknown\", false);\n")

    expect_raises(Exception, /Unknown particle option/) { build_particles(path) }
  ensure
    File.delete(path) if path && File.exists?(path)
  end

  it "rejects a registration whose declaration format changes" do
    path = ""
    path = File.tempname("particles")
    File.write(path, "public static final WeirdParticleType UNKNOWN = register(\"unknown\", false);\n")

    expect_raises(Exception, /Unrecognized particle registration/) { build_particles(path) }
  ensure
    File.delete(path) if path && File.exists?(path)
  end
end
