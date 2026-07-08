require "json"
require "./models"

# Parsed Minecraft game data for one game version: the raw registries plus
# the derivations consumers need (block state names, air states, per-state
# collision shapes).
#
# The constructor is pure — it takes the five JSON documents as strings.
# Use the `Minecraft::Data.load("26.2")` macro to build one with the shipped
# data embedded at compile time.
class Minecraft::Data
  getter items : Array(Item)

  getter blocks : Array(Block)

  getter materials : Material

  getter enchantments : Array(Enchantment)

  # block state nr -> "oak_slab[type=top, waterlogged=true]"
  getter block_state_names : Array(String)

  # Set of block state IDs that are air (air, cave_air, void_air)
  getter air_states : Set(UInt16)

  # block state nr -> boxes that combine to make up that block state's collision shape
  getter block_state_collision_shapes : Array(Shape)

  def initialize(items_json : String, blocks_json : String, materials_json : String,
                 enchantments_json : String, collision_shapes_json : String)
    @items = Array(Item).from_json(items_json)
    @blocks = Array(Block).from_json(blocks_json)
    @materials = Material.from_json(materials_json)
    @enchantments = Array(Enchantment).from_json(enchantments_json)
    collision_shapes = BlockCollisionShapes.from_json(collision_shapes_json)

    max_block_state = blocks.flat_map(&.max_state_id).max

    @air_states = Set(UInt16).new
    blocks.each do |block|
      if block.id_str.in?("air", "cave_air", "void_air")
        (block.min_state_id..block.max_state_id).each { |state| @air_states << state }
      end
    end

    @block_state_names = Array(String).new(max_block_state + 1, "")
    blocks.each do |block|
      if block.states.empty?
        block_state_names[block.min_state_id] = block.id_str
      else
        # example (slab): [["type=top", "waterlogged=true"], ["type=top", "waterlogged=false"], ["type=bottom", "waterlogged=true"], ["type=bottom", "waterlogged=false"], ["type=double", "waterlogged=true"], ["type=double", "waterlogged=false"]]
        prop_combos = Indexable.cartesian_product block.states.map { |prop|
          case prop.type
          when BlockPropertyType::ENUM; prop.values.not_nil! # ameba:disable Lint/NotNil
          when BlockPropertyType::INT ; (0...prop.num_values)
          when BlockPropertyType::BOOL; ["true", "false"] # weird order but that's how it is
          else
            raise "Invalid block property type #{prop.type} in #{block.id_str}.#{prop.name}"
          end.map { |value| "#{prop.name}=#{value}" }
        }
        prop_combos.each_with_index do |props, i|
          state_nr = block.min_state_id + i
          block_state_names[state_nr] = block.id_str + "[#{props.join ", "}]"
        end
      end
    end

    @block_state_collision_shapes = Array(Shape).new(max_block_state + 1, [] of Box)
    blocks.each do |block|
      block_shape_nrs = collision_shapes.blocks[block.id_str].try do |j|
        j.is_a?(Array) ? j : [j]
      end
      (block.min_state_id..block.max_state_id).each do |state_nr|
        state_nr_in_block = (state_nr - block.min_state_id) % block_shape_nrs.size
        shape_nr = block_shape_nrs[state_nr_in_block]
        block_state_collision_shapes[state_nr] = collision_shapes.shapes[shape_nr.to_s]
      end
    end
  end
end
