local math = require("__flib__.math")
local table = require("__flib__.table")

local constants = require("constants")

local util = require("scripts.util")

local function insert_science_packs(database, obj_data, science_packs)
  if #science_packs == 0 then
    return
  end

  local existing = obj_data.science_packs
  local existing_len = #existing

  -- If there are no existing science packs
  if #obj_data.science_packs == 0 then
    obj_data.science_packs = science_packs
    return
  end

  local existing_highest_ident = existing[existing_len]
  local existing_highest_data = database.science_pack[existing_highest_ident.name]

  local new_highest_ident = science_packs[#science_packs]
  local new_highest_data = database.science_pack[new_highest_ident.name]

  -- The object should show when the fewest possible science packs are enabled
  if existing_highest_data.order > new_highest_data.order then
    obj_data.science_packs = science_packs
  end
end

return function(database, metadata)
  for name, prototype in pairs(storage.prototypes.technology) do
    local unlocks_equipment = util.unique_obj_array()
    local unlocks_fluids = util.unique_obj_array()
    local unlocks_items = util.unique_obj_array()
    local unlocks_entities = util.unique_obj_array()
    local unlocks_recipes = util.unique_obj_array()
    local research_ingredients_per_unit = {}

    -- Research units and ingredients per unit
    for _, ingredient in ipairs(prototype.research_unit_ingredients) do
      research_ingredients_per_unit[#research_ingredients_per_unit + 1] = {
        class = "item",  -- GrP 1.x allowed fluids, 2.x no longer does?
        name = ingredient.name,
        amount_ident = util.build_amount_ident({ amount = ingredient.amount }),
      }
    end

    local research_unit_count
    local formula = prototype.research_unit_count_formula
    if not formula then
      research_unit_count = prototype.research_unit_count
    end

    -- Collect the list of science packs required by this technology's research.
    local science_packs = table.map(prototype.research_unit_ingredients, function(pack)
      return { class = "science_pack", name = pack.name }
    end)

    -- Collect the list of science packs required by this technology
    -- and its prerequisite technologies.
    -- We use whatever precursor tech


    -- This technology unlocks recipes, materials, entities.
    -- Set their respective science pack requirements.
    --
    -- GrP fixme need to include prerequisite technology costs to solve
    --   ## the "uranium problem" ##
    --   Vanilla U-235 is unlocked by Uranium Processing. Uranium Processing
    --   unlocks after mining some ore, which counts as 1 research ingredient.
    --   Thus it appears to be available soon based on a simple count of
    --   unresearched research ingredients. In reality Uranium Processing also
    --   requires Uranium Mining, and that requires three more science packs.
    --   Including prerequisite costs means that U-235 does not appear
    --   to be available soon at the start of the game.
    for _, modifier in ipairs(prototype.effects) do
      if modifier.type == "unlock-recipe" then
        local recipe_data = database.recipe[modifier.recipe]

        -- Check if the category should be ignored for recipe availability
        local disabled = constants.disabled_categories.recipe_category[recipe_data.recipe_category.name]
        if not disabled or disabled ~= 0 then
          -- Recipe
          insert_science_packs(database, recipe_data, science_packs)
          recipe_data.unlocked_by[#recipe_data.unlocked_by + 1] = { class = "technology", name = name }
          recipe_data.researched_forces = {}
          unlocks_recipes[#unlocks_recipes + 1] = { class = "recipe", name = modifier.recipe }
          for _, product in pairs(recipe_data.products) do
            local product_name = product.name
            local product_data = database[product.class][product_name]
            local product_ident = { class = product_data.class, name = product_data.prototype_name }

            -- For "empty X barrel" recipes, do not unlock the fluid with the barreling recipe
            -- This is to avoid fluids getting "unlocked" when they are in reality still 100 hours away
            -- GrP fixme does this also include other barrel-like items like canisters?
            local is_empty_barrel_recipe = string.find(modifier.recipe, "^empty%-.+%-barrel$")
            if product_data.class ~= "fluid" or not is_empty_barrel_recipe then
              product_data.researched_forces = {}
              insert_science_packs(database, product_data, science_packs)
              product_data.unlocked_by[#product_data.unlocked_by + 1] = { class = "technology", name = name }
            end

            -- Materials (products of the unlocked recipe)
            if product_data.class == "item" then
              unlocks_items[#unlocks_items + 1] = product_ident
            elseif product_data.class == "fluid" and not is_empty_barrel_recipe then
              unlocks_fluids[#unlocks_fluids + 1] = product_ident
            end

            -- Entities (products of the unlocked recipe that can be placed)
            local place_result = metadata.place_results[product_name]
            if place_result then
              local entity_data = database.entity[place_result.name]
              if entity_data then
                entity_data.researched_forces = {}
                insert_science_packs(database, entity_data, science_packs)
                entity_data.unlocked_by[#entity_data.unlocked_by + 1] = { class = "technology", name = name }
                unlocks_entities[#unlocks_entities + 1] = place_result
              end
            end

            -- Equipment (products of the unlocked recipe that can be equipped)
            local place_as_equipment_result = metadata.place_as_equipment_results[product_name]
            if place_as_equipment_result then
              local equipment_data = database.equipment[place_as_equipment_result.name]
              if equipment_data then
                equipment_data.researched_forces = {}
                insert_science_packs(database, equipment_data, science_packs)
                equipment_data.unlocked_by[#equipment_data.unlocked_by + 1] = { class = "technology", name = name }
                unlocks_equipment[#unlocks_equipment + 1] = place_as_equipment_result
              end
            end
          end
        end
      end
    end

    local level = prototype.level
    local max_level = prototype.max_level

    database.technology[name] = {
      class = "technology",
      contributes_research_ingredients_to = util.unique_obj_array(),
      hidden = prototype.hidden,
      max_level = max_level,
      min_level = level,
      prerequisite_of = {},
      prerequisites = {},
      prototype_name = name,
      researched_forces = {},
      research_ingredients_per_unit = research_ingredients_per_unit,
      research_unit_count_formula = formula,
      research_unit_count = research_unit_count,
      research_unit_energy = prototype.research_unit_energy / 60,
      science_packs = science_packs,
      unlocks_entities = unlocks_entities,
      unlocks_equipment = unlocks_equipment,
      unlocks_fluids = unlocks_fluids,
      unlocks_items = unlocks_items,
      unlocks_recipes = unlocks_recipes,
      upgrade = prototype.upgrade,
    }

    -- Assemble name
    local localised_name
    if level ~= max_level then
      localised_name = {
        "",
        prototype.localised_name,
        " (" .. level .. "-" .. (max_level == math.max_uint and "∞" or max_level) .. ")",
      }
    else
      localised_name = prototype.localised_name
    end

    util.add_to_dictionary("technology", prototype.name, localised_name)
    util.add_to_dictionary("technology_description", name, prototype.localised_description)
  end

  -- Generate prerequisites and prerequisite_of and contributes_research_ingredients_to
  for name, technology in pairs(database.technology) do
    local prototype = storage.prototypes.technology[name]

    if prototype.prerequisites then
      for prerequisite_name in pairs(prototype.prerequisites) do
        technology.prerequisites[#technology.prerequisites + 1] = { class = "technology", name = prerequisite_name }
        local prerequisite_data = database.technology[prerequisite_name]
        prerequisite_data.prerequisite_of[#prerequisite_data.prerequisite_of + 1] = {
          class = "technology",
          name = name,
        }
      end
    end

    -- other_tech in tech.contributes_research_ingredients_to[]
    -- means one of tech's unlocks is a research ingredient of other_tech
    for _, ingredient in ipairs(prototype.research_unit_ingredients) do
      local ingredient_data = database.item[ingredient.name]
      for _, contributor_ident in pairs(ingredient_data.unlocked_by) do
        local contributor_data = database.technology[contributor_ident.name]
        contributor_data.contributes_research_ingredients_to[#contributor_data.contributes_research_ingredients_to + 1] = { class = "technology", name = name }
      end
    end
  end
end
