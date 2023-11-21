local constants = require("constants")

local util = require("scripts.util")

local beacon = require("scripts.database.beacon")
local burning = require("scripts.database.burning")
local crafter = require("scripts.database.crafter")
local entity = require("scripts.database.entity")
local entity_state = require("scripts.database.entity-state")
local entity_type = require("scripts.database.entity-type")
local equipment_category = require("scripts.database.equipment-category")
local equipment = require("scripts.database.equipment")
local fluid = require("scripts.database.fluid")
local fuel_category = require("scripts.database.fuel-category")
local generator = require("scripts.database.generator")
local group = require("scripts.database.group")
local item = require("scripts.database.item")
local item_type = require("scripts.database.item-type")
local lab = require("scripts.database.lab")
local mining_drill = require("scripts.database.mining-drill")
local offshore_pump = require("scripts.database.offshore-pump")
local recipe_category = require("scripts.database.recipe-category")
local recipe = require("scripts.database.recipe")
local resource_category = require("scripts.database.resource-category")
local resource = require("scripts.database.resource")
local science_pack = require("scripts.database.science-pack")
local technology = require("scripts.database.technology")

local database = {}

function database.build()
  -- Create class tables
  for _, class in pairs(constants.classes) do
    database[class] = {}
  end

  -- Create dictionaries
  for _, class in pairs(constants.classes) do
    util.new_dictionary(class)
    util.new_dictionary(class .. "_description")
  end
  util.new_dictionary("gui", constants.gui_strings)

  -- Data that is needed for generation but will not be saved
  local metadata = {}

  entity_type(database)
  equipment_category(database)
  fuel_category(database)
  group(database)
  item_type(database)
  recipe_category(database)
  resource_category(database)
  science_pack(database)

  equipment(database)

  beacon(database, metadata)
  crafter(database, metadata)
  generator(database)
  entity(database, metadata)
  mining_drill(database)

  fluid(database, metadata)

  lab(database)
  offshore_pump(database)     -- requires fluids

  item(database, metadata)    -- requires all entities

  recipe(database, metadata)
  resource(database)
  technology(database, metadata)

  offshore_pump.check_enabled_at_start(database)
  fluid.process_temperatures(database, metadata)
  mining_drill.add_resources(database)
  fuel_category.check_fake_category(database)
  lab.process_researched_in(database)

  burning(database)
  entity_state(database)

  database.generated = true
end

local function update_launch_products(launch_products, force_index, to_value)
  for _, launch_product in ipairs(launch_products) do
    local product_data = database.item[launch_product.name]
    if product_data.researched_forces then
      product_data.researched_forces[force_index] = to_value
    end
    update_launch_products(product_data.rocket_launch_products, force_index, to_value)
  end
end

function database.update_research_ingredients_missing(obj_ident, obj_data, force_index)
  obj_data.research_ingredients_missing = obj_data.research_ingredients_missing or {}

  if obj_data.enabled_at_start or (obj_data.researched_forces and obj_data.researched_forces[force_index]) then
    -- no research required, or research completed
    obj_data.research_ingredients_missing[force_index] = 0
    return
  end

  -- Find the fewest un-researched research ingredients
  -- among all techs that unlock this object
  -- (if this object is a tech, look at its own research ingredients)
  local smallest_ingredients_missing = 9999
  for _, technology_ident in pairs(obj_ident.class == "technology" and { obj_ident } or obj_data.unlocked_by) do
    local ingredients_missing = 0
    local technology_data = database.technology[technology_ident.name]
    local technology_prototype = global.prototypes.technology[technology_ident.name]
    for _, ingredient in pairs(technology_prototype.research_unit_ingredients) do
      ingredient_data = database[ingredient.type][ingredient.name]
      if ingredient_data.enabled_at_start then
        -- enabled at start, not missing
      elseif ingredient_data.researched_forces and ingredient_data.researched_forces[force_index] then
        -- researched, not missing
      else
        ingredients_missing = ingredients_missing + 1
      end
    end

    if ingredients_missing < smallest_ingredients_missing then
      smallest_ingredients_missing = ingredients_missing
      if smallest_ingredients_missing == 0 then
        -- can't do better than this, stop looking
        break
      end
    end
  end

  obj_data.research_ingredients_missing[force_index] = smallest_ingredients_missing
end

function database.handle_research_updated(technology, to_value, skip_research_ingredients_missing)
  local force_index = technology.force.index
  -- Technology
  local technology_data = database.technology[technology.name]
  -- Other mods can update technologies during on_configuration_changed before RB gets a chance to config change
  if not technology_data then
    return
  end
  technology_data.researched_forces[force_index] = to_value

  -- Unlock objects
  for _, objects in pairs({
    technology_data.unlocks_equipment,
    technology_data.unlocks_fluids,
    technology_data.unlocks_items,
    technology_data.unlocks_entities,
    technology_data.unlocks_recipes,
  }) do
    for _, obj_ident in ipairs(objects) do
      local class = obj_ident.class
      local obj_data = database[class][obj_ident.name]

      -- Unlock this object
      if obj_data.researched_forces then
        obj_data.researched_forces[force_index] = to_value
      end

      if class == "fluid" and obj_data.temperature_ident then
        -- Unlock base fluid
        local base_fluid_data = database.fluid[obj_data.prototype_name]
        if base_fluid_data.researched_forces then
          base_fluid_data.researched_forces[force_index] = to_value
        end
      elseif class == "item" then
        -- Unlock rocket launch products
        update_launch_products(obj_data.rocket_launch_products, force_index, to_value)
      elseif class == "offshore_pump" then
        -- Unlock pumped fluid
        local fluid = obj_data.fluid
        local fluid_data = database.fluid[fluid.name]
        if fluid_data.researched_forces then
          fluid_data.researched_forces[force_index] = to_value
        end
      end
    end
  end

  if not skip_research_ingredients_missing then
    -- If this tech contributes research ingredients to any other techs,
    -- update research_ingredients_missing for those other techs and their unlocks.
    for _, other_tech_ident in pairs(technology_data.contributes_research_ingredients_to) do
      local other_tech_data = database.technology[other_tech_ident.name]
      for _, objects in pairs({
        { other_tech_ident },
        other_tech_data.unlocks_equipment,
        other_tech_data.unlocks_fluids,
        other_tech_data.unlocks_items,
        other_tech_data.unlocks_entities,
        other_tech_data.unlocks_recipes,
      }) do
        for _, obj_ident in ipairs(objects) do
          local obj_data = database[obj_ident.class][obj_ident.name]
          database.update_research_ingredients_missing(obj_ident, obj_data, force_index)
        end
      end
    end
  end
end

function get_science_sorting_number(obj_data)
  return (obj_data.science_packs and #obj_data.science_packs or 9999)
end

function science_comparator(lhs_ident, rhs_ident)
  local lhs_data = database[lhs_ident.class][lhs_ident.name]
  local rhs_data = database[rhs_ident.class][rhs_ident.name]

  -- sort by science packs
  local lhs_sci = get_science_sorting_number(lhs_data)
  local rhs_sci = get_science_sorting_number(rhs_data)
  if lhs_sci ~= rhs_sci then
    return lhs_sci < rhs_sci
  end

  -- same science packs, sort by name
  return lhs_ident.name < rhs_ident.name
end

function database.check_force(force)
  if not force.valid then
    return
  end

  for _, technology in pairs(force.technologies) do
    if technology.enabled and technology.researched then
      database.handle_research_updated(technology, true, true)
    end
  end

  -- Initialize research_ingredients_missing for all technologies
  -- and all objects that can be unlocked by technologies.
  -- Do this after updating research to improve performance.
  for _, class in ipairs({ "technology", "entity", "equipment", "fluid", "item", "recipe" }) do
    for name, obj_data in pairs(database[class]) do
      database.update_research_ingredients_missing({ class = class, name = name }, obj_data, force.index)
    end
  end

  -- Sort ingredient_in and product_of lists
  -- Simpler tech comes first.
  for _, class in ipairs({ "item", "fluid" }) do
    for name, obj_data in pairs(database[class]) do
      for _, field in ipairs({ "ingredient_in", "product_of" }) do
        if obj_data[field] then
          table.sort(obj_data[field], science_comparator)
        end
      end
    end
  end
end

function database.check_forces()
  for _, force in pairs(global.forces) do
    database.check_force(force)
  end
end

return database
