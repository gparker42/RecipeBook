local player_data = {}

local translation = require("__flib__.control.translation")

function player_data.init(player, index)
  local data = {
    flags = {
      can_open_gui = false,
      translate_on_join = false
    },
    history = {
      session = {position=0},
      overall = {}
    },
    gui = {
      recipe_quick_reference = {}
    }
  }
  global.players[index] = data
  player_data.refresh(player, global.players[index])
end

function player_data.start_translations(player_index)
  for name, data in pairs(global.translation_data) do
    translation.start(player_index, name, data, {include_failed_translations=true, lowercase_sorted_translations=true})
  end
end

function player_data.update_settings(player, player_table)
  local mod_settings = player.mod_settings
  player_table.settings = {
    default_category = mod_settings["rb-default-search-category"].value,
    show_hidden = mod_settings["rb-show-hidden-objects"].value,
    use_fuzzy_search = mod_settings["rb-use-fuzzy-search"].value
  }
end

function player_data.destroy_guis(player, player_table)
  -- local gui_data = player_table.gui
  -- player_table.flags.can_open_gui = false
  -- player.set_shortcut_available("rb-toggle-search", false)
  -- if gui_data.search then
  --   search_gui.close(player, player_table)
  -- end
  -- if gui_data.info then
  --   info_gui.close(player, player_table)
  -- end
  -- recipe_quick_reference_gui.close_all(player, player_table)
end

function player_data.refresh(player, player_table)
  player_data.destroy_guis(player, player_table)
  player_data.update_settings(player, player_table)

  if player.connected then
    player_data.start_translations(player)
  else
    player_table.flags.translate_on_join = true
  end
end

return player_data