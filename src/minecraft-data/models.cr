require "json"

# Macro-free schema models for the per-version data files. No runtime or
# compile-time-embedding dependencies — safe to require from generator scripts.
class Minecraft::Data
  # entries of items.json
  class Item
    include JSON::Serializable

    def initialize(@id : UInt32, @name : String, @stack_size : UInt8, @max_durability : UInt16? = nil, @enchant_categories : Array(String)? = nil)
    end

    getter id : UInt32
    @[JSON::Field(key: "name")]
    getter name : String
    @[JSON::Field(key: "stackSize")]
    getter stack_size : UInt8
    @[JSON::Field(key: "maxDurability")]
    getter max_durability : UInt16?
    @[JSON::Field(key: "enchantCategories")]
    getter enchant_categories : Array(String)?
  end

  # entries of enchantments.json
  class Enchantment
    include JSON::Serializable

    def initialize(@id : UInt32, @name : String)
    end

    getter id : UInt32
    getter name : String
  end

  # root of materials.json: material name -> {item id -> speed multiplier}
  class Material
    include JSON::Serializable
    include JSON::Serializable::Unmapped
  end

  # entries of blocks.json
  class Block
    include JSON::Serializable

    @[JSON::Field(key: "name")]
    getter id_str : String
    @[JSON::Field(key: "minStateId")]
    getter min_state_id : UInt16
    @[JSON::Field(key: "maxStateId")]
    getter max_state_id : UInt16
    getter hardness : Float32 = -1.0
    @[JSON::Field(key: "harvestTools")]
    getter harvest_tools : Hash(String, Bool)?
    getter material : String

    # Not individual block states, but the properties that, in combination, make up each block state.
    # Empty array if block has only one state.
    getter states : Array(BlockProperty)
  end

  # entries of `states` field in blocks.json
  class BlockProperty
    include JSON::Serializable

    getter name : String
    getter type : BlockPropertyType
    getter num_values : UInt16
    getter values : Array(String)?
  end

  enum BlockPropertyType
    BOOL
    ENUM
    INT
  end

  # root of blockCollisionShapes.json
  class BlockCollisionShapes
    include JSON::Serializable

    # block id string -> block's shape nr (if same for all states) | each block state's shape nr
    getter blocks : Hash(String, UInt16 | Array(UInt16))
    # shape nr -> array of boxes that combine to make up that block state shape
    getter shapes : Hash(String, Shape)
  end

  # one box: {min_x, min_y, min_z, max_x, max_y, max_z}
  alias Box = {Float32, Float32, Float32, Float32, Float32, Float32}
  alias Shape = Array(Box)

  # entries of entities.json
  class EntityMetadata
    include JSON::Serializable

    property id : Int32
    property name : String
    property width : Float64
    property height : Float64
    @[JSON::Field(key: "type")]
    property entity_type : String = ""
    property category : String = ""
  end
end
