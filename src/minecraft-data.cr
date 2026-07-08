require "json"
require "./minecraft-data/models"
require "./minecraft-data/data"

class Minecraft::Data
  VERSION = "0.1.0"

  DATA_ROOT = "#{__DIR__}/../data/"

  # Game versions shipped in data/, in release order.
  SHIPPED_VERSIONS = ["1.21.8", "1.21.9", "1.21.11", "26.1", "26.2"]

  # Compile-time embed of one data file. `path` must be a string literal
  # (or a macro-time string expression), e.g.
  #
  #     Minecraft::Data.read_asset("26.2/entities.json")
  #
  # Only the files actually referenced get embedded into the binary, so
  # consumers control which versions they ship.
  macro read_asset(path)
    {{read_file Minecraft::Data::DATA_ROOT + path}}
  end

  # Build a `Minecraft::Data` for one game version, embedding only that
  # version's files. `version` must be a string literal (or macro-time
  # string expression), e.g. `Minecraft::Data.load("26.2")`.
  macro load(version)
    Minecraft::Data.new(
      Minecraft::Data.read_asset({{version + "/items.json"}}),
      Minecraft::Data.read_asset({{version + "/blocks.json"}}),
      Minecraft::Data.read_asset({{version + "/materials.json"}}),
      Minecraft::Data.read_asset({{version + "/enchantments.json"}}),
      Minecraft::Data.read_asset({{version + "/blockCollisionShapes.json"}}),
    )
  end
end
