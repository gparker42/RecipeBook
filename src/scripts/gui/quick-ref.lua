local event = require("__flib__.event")
local gui = require("__flib__.gui-beta")

local constants = require("constants")
local formatter = require("scripts.formatter")
local util = require("scripts.util")

local function quick_ref_panel(ref, children)
  return {type = "flow", direction = "vertical", children = {
    {type = "label", style = "bold_label", ref = util.append(ref, "label")},
    {type = "frame", style = "rb_slot_table_frame", ref = util.append(ref, "frame"), children = {
      {type = "scroll-pane", style = "rb_slot_table_scroll_pane", ref = util.append(ref, "scroll_pane"), children = {
        {type = "table", style = "slot_table", column_count = 5, ref = util.append(ref, "table"), children = children}
      }}
    }}
  }}
end

local quick_ref_gui = {}

function quick_ref_gui.build(player, player_table, name)
  local recipe_data = global.recipe_book.recipe[name]

  local refs = gui.build(player.gui.screen, {
    {type = "frame", direction = "vertical", ref = {"window"}, children = {
      {type = "flow", ref = {"titlebar_flow"}, children = {
        {type = "label", style = "frame_title", caption = {"rb-gui.recipe"}, ignored_by_interaction = true},
        {type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true},
        {
          type = "sprite-button",
          style = "frame_action_button",
          sprite = "rb_expand_white",
          hovered_sprite = "rb_expand_black",
          clicked_sprite = "rb_expand_black",
          tooltip = {"rb-gui.view-details"},
          mouse_button_filter = {"left"},
          actions = {
            on_click = {gui = "main", action = "open_page", class = "recipe", name = name}
          }
        },
        {
          type = "sprite-button",
          style = "frame_action_button",
          sprite = "utility/close_white",
          hovered_sprite = "utility/close_black",
          clicked_sprite = "utility/close_black",
          mouse_button_filter = {"left"},
          actions = {
            on_click = {gui = "quick_ref", action = "close", name = name}
          }
        }
      }},
      {type = "frame", style = "rb_quick_ref_content_frame", direction = "vertical", children = {
        {type = "frame", style = "subheader_frame", children = {
          {type = "label", style = "rb_toolbar_label", ref = {"toolbar_label"}},
          {type = "empty-widget", style = "flib_horizontal_pusher"}
        }},
        {type = "flow", style = "rb_quick_ref_content_flow", direction = "vertical", children = {
          quick_ref_panel({"ingredients"}, {
            {
              type = "sprite-button",
              style = "flib_slot_button_default",
              tooltip = {"rb-gui.seconds-tooltip"},
              sprite = "quantity-time",
              number = recipe_data.energy,
              enabled = false
            }
          }),
          quick_ref_panel{"products"}
        }}
      }}
    }}
  })
  refs.titlebar_flow.drag_target = refs.window

  -- to pass to the formatter
  local player_data = {
    force_index = player.force.index,
    player_index = player.index,
    settings = player_table.settings,
    translations = player_table.translations
  }

  local _, _, label_caption, label_tooltip = formatter(recipe_data, player_data, nil, true, true)

  -- remove glyph from caption, since it's implied
  if player_data.settings.show_glyphs then
    label_caption = string.gsub(label_caption, "^.-nt%]  ", "")
  end

  refs.toolbar_label.caption = label_caption
  refs.toolbar_label.tooltip = label_tooltip

  -- add contents to tables
  local material_data = global.recipe_book.material
  for _, type in ipairs{"ingredients", "products"} do
    local group = refs[type]
    local i = type == "ingredients" and 1 or 0
    for _, obj in ipairs(recipe_data[type]) do
      local obj_data = material_data[obj.type.."."..obj.name]
      local _, style, _, tooltip = formatter(obj_data, player_data, obj.amount_string, true)
      i = i + 1

      local button_style = string.find(style, "unresearched") and "flib_slot_button_red" or "flib_slot_button_default"
      tooltip = string.gsub(tooltip, "^.-color=.-%]", "%1"..string.gsub(obj.amount_string, "%%", "%%%%").." ")
      local shown_string = (
        obj.avg_amount_string
        and "~"..obj.avg_amount_string
        or string.gsub(obj.amount_string, "^.-(%d+)x$", "%1")
      )

      gui.build(group.table, {
        {
          type = "sprite-button",
          style = button_style,
          sprite = obj.type.."/"..obj.name,
          tooltip = tooltip,
          actions = {
            on_click = {gui = "main", action = "open_page", class = obj.type, name = obj.name}
          },
          children = {
            {
              type = "label",
              style = "rb_slot_label",
              caption = shown_string,
              ignored_by_interaction = true
            },
            {
              type = "label",
              style = "rb_slot_label_top",
              caption = string.find(obj.amount_string, "%%") and "%" or "",
              ignored_by_interaction = true
            }
          }
        }
      })
    end
    group.label.caption = {"rb-gui."..type, i - (type == "ingredients" and 1 or 0)}
  end

  -- save to global
  player_table.gui.quick_ref[name] = refs
end

function quick_ref_gui.destroy(player_table, name)
  local guis = player_table.gui.quick_ref
  local refs = guis[name]
  refs.window.destroy()
  guis[name] = nil
end

function quick_ref_gui.destroy_all(player_table)
  for name in pairs(player_table.gui.quick_ref) do
    quick_ref_gui.destroy(player_table, name)
  end
end

function quick_ref_gui.handle_action(msg, e)
  if msg.action == "close" then
    quick_ref_gui.destroy(global.players[e.player_index], msg.name)
    event.raise(constants.events.update_quick_ref_button, {player_index = e.player_index})
  end
end

return quick_ref_gui
