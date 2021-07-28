local gui = require("__flib__.gui-beta")

local shared = require("scripts.shared")
local util = require("scripts.util")

local settings_gui = {}

function settings_gui.build(player, player_table)
  local refs = gui.build(player.gui.screen, {
    {
      type = "frame",
      direction = "vertical",
      caption = {"gui.rb-settings"},
      ref = {"window"},
      actions = {
        on_closed = {gui = "settings", action = "close"},
      },
      {type = "frame", style = "inside_deep_frame_for_tabs",
        {type = "tabbed-pane", style = "tabbed_pane_with_no_side_padding",
          {tab = {type = "tab", caption = {"gui.rb-general"}}, content = {type = "scroll-pane", style = "flib_naked_scroll_pane_under_tabs", style_mods = {width = 500, height = 500}}},
          {tab = {type = "tab", caption = {"gui.rb-categories"}}, content = {type = "scroll-pane", style = "flib_naked_scroll_pane_under_tabs", style_mods = {width = 500, height = 500}}},
          {tab = {type = "tab", caption = {"gui.rb-pages"}}, content = {type = "scroll-pane", style = "flib_naked_scroll_pane_under_tabs", style_mods = {width = 500, height = 500}}},
        }
      },
      {type = "flow", style = "dialog_buttons_horizontal_flow",
        {type = "button", style = "back_button", caption = {"gui.cancel"}},
        {type = "empty-widget", style = "flib_dialog_footer_drag_handle", ref = {"footer_drag_handle"}},
        {
          type = "button",
          style = "confirm_button",
          caption = {"gui.confirm"},
          actions = {
            on_click = {gui = "settings", action = "confirm"},
          },
        },
      }
    }
  })

  refs.window.force_auto_center()
  player.opened = refs.window

  player_table.guis.settings = {
    refs = refs,
    state = {
    },
  }
end

function settings_gui.destroy(player_table)
  player_table.guis.settings.refs.window.destroy()
  player_table.guis.settings = nil
end

function settings_gui.toggle(player, player_table)
  if player_table.guis.settings then
    settings_gui.destroy(player_table)
  else
    settings_gui.build(player, player_table)
  end
end

function settings_gui.handle_action(msg, e)
  local player = game.get_player(e.player_index)
  local player_table = global.players[e.player_index]

  local gui_data = player_table.guis.settings
  local state = gui_data.state
  local refs = gui_data.refs

  local action = msg.action

  if action == "close" then
    settings_gui.destroy(player_table)
    shared.deselect_settings_button(player, player_table)
  elseif action == "confirm" then
    if e.name == defines.events.on_gui_click then
      settings_gui.destroy(player_table)
      shared.deselect_settings_button(player, player_table)
    else
      player.play_sound{path = "utility/confirm"}
    end
  end
end

return settings_gui
