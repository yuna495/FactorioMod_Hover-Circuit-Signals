local GUI_NAME = "hover_circuit_signals_window"

local SETTING_ENABLED = "hover-circuit-signals-enabled"
local SETTING_OFFSET_X = "hover-circuit-signals-offset-x"
local SETTING_OFFSET_Y = "hover-circuit-signals-offset-y"
local SETTING_COLUMNS = "hover-circuit-signals-columns"
local SETTING_MAX_SIGNALS = "hover-circuit-signals-max-signals"
local SETTING_UPDATE_INTERVAL = "hover-circuit-signals-update-interval"
local SETTING_SHOW_NETWORK_ID = "hover-circuit-signals-show-network-id"
local SETTING_COMPACT_NUMBERS = "hover-circuit-signals-compact-numbers"
local SETTING_SEPARATE_IO = "hover-circuit-signals-separate-io"
local SETTING_SEPARATE_WIRE_COLOR = "hover-circuit-signals-separate-wire-color"
local SETTING_SORT_ORDER = "hover-circuit-signals-sort-order"

local HOVER_STABLE_TICKS = 12

local function get_storage()
  storage.players = storage.players or {}
  return storage.players
end

local function valid(obj)
  return obj and obj.valid
end

local function get_entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then
    return entity.unit_number
  end
  return entity.name .. "_" .. tostring(entity.position.x) .. "_" .. tostring(entity.position.y) .. "_" .. tostring(entity.surface.index)
end

local function safe_destroy(element)
  if valid(element) then
    element.destroy()
  end
end

local function get_player_data(player_index)
  local players_data = get_storage()
  if not players_data[player_index] then
    players_data[player_index] = {
      toggled_off = false,
      selected_unit_number = nil,
      pending_unit_number = nil,
      pending_since = 0,
      last_gui_signature = nil,
      window = nil
    }
  end
  return players_data[player_index]
end

local function get_player_settings(player)
  local s = settings.get_player_settings(player)
  return {
    enabled = s[SETTING_ENABLED] and s[SETTING_ENABLED].value,
    offset_x = s[SETTING_OFFSET_X] and s[SETTING_OFFSET_X].value or 280,
    offset_y = s[SETTING_OFFSET_Y] and s[SETTING_OFFSET_Y].value or 220,
    columns = s[SETTING_COLUMNS] and s[SETTING_COLUMNS].value or 5,
    max_signals = s[SETTING_MAX_SIGNALS] and s[SETTING_MAX_SIGNALS].value or 25,
    update_interval = s[SETTING_UPDATE_INTERVAL] and s[SETTING_UPDATE_INTERVAL].value or 10,
    show_network_id = s[SETTING_SHOW_NETWORK_ID] and s[SETTING_SHOW_NETWORK_ID].value,
    compact_numbers = s[SETTING_COMPACT_NUMBERS] and s[SETTING_COMPACT_NUMBERS].value,
    separate_io = s[SETTING_SEPARATE_IO] and s[SETTING_SEPARATE_IO].value,
    separate_wire_color = s[SETTING_SEPARATE_WIRE_COLOR] and s[SETTING_SEPARATE_WIRE_COLOR].value,
    sort_order = s[SETTING_SORT_ORDER] and s[SETTING_SORT_ORDER].value or "prototype"
  }
end

-- 数値のフォーマット
local function format_count_full(count)
  local formatted = tostring(math.abs(count))
  local k
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  if count < 0 then
    formatted = "-" .. formatted
  end
  return formatted
end

local function format_count_compact(count)
  local abs_count = math.abs(count)
  local sign = count < 0 and "-" or ""
  if abs_count < 1000 then
    return tostring(count)
  elseif abs_count < 1000000 then
    local v = string.format("%.1fk", abs_count / 1000)
    v = string.gsub(v, "%.0k$", "k")
    return sign .. v
  elseif abs_count < 1000000000 then
    local v = string.format("%.1fM", abs_count / 1000000)
    v = string.gsub(v, "%.0M$", "M")
    return sign .. v
  else
    local v = string.format("%.1fG", abs_count / 1000000000)
    v = string.gsub(v, "%.0G$", "G")
    return sign .. v
  end
end

-- ワイヤーコネクタのメタ情報定義
local function get_connector_meta(connector_id, connectors)
  local ids = defines.wire_connector_id
  if not ids then
    return { io_type = "output", color = connector_id % 2 == 1 and "red" or "green" }
  end

  local has_separate_io =
    (ids.combinator_output_red and connectors[ids.combinator_output_red]) or
    (ids.combinator_output_green and connectors[ids.combinator_output_green])

  if has_separate_io then
    if connector_id == ids.combinator_input_red then return { io_type = "input", color = "red" } end
    if connector_id == ids.combinator_input_green then return { io_type = "input", color = "green" } end
    if connector_id == ids.combinator_output_red then return { io_type = "output", color = "red" } end
    if connector_id == ids.combinator_output_green then return { io_type = "output", color = "green" } end
  else
    if connector_id == ids.circuit_red then return { io_type = "output", color = "red" } end
    if connector_id == ids.circuit_green then return { io_type = "output", color = "green" } end
  end

  return { io_type = "output", color = connector_id % 2 == 1 and "red" or "green" }
end

-- 回路データ収集 (Factorio 2.0 API)
local function collect_circuit_data(entity, p_settings)
  if not valid(entity) then return nil end

  local ok, connectors = pcall(function()
    return entity.get_wire_connectors(false)
  end)

  if not ok or not connectors then return nil end

  local sections = {}
  local seen_keys = {}

  for connector_id, connector in pairs(connectors) do
    if connector and connector.connection_count > 0 then
      local network = nil
      local ok_network, found_network = pcall(function()
        return entity.get_circuit_network(connector_id)
      end)
      if ok_network then
        network = found_network
      end

      local meta = get_connector_meta(connector_id, connectors)
      local io_type = meta.io_type
      local color = meta.color

      local net_id = network and network.network_id or nil

      local sig_ok, raw_signals = pcall(function()
        return network and network.signals or entity.get_signals(connector_id)
      end)

      local signal_list = {}
      if sig_ok and raw_signals then
        for _, s in pairs(raw_signals) do
          if s.signal and s.count and s.count ~= 0 then
            table.insert(signal_list, {
              signal = {
                type = s.signal.type or "item",
                name = s.signal.name,
                quality = s.signal.quality or "normal"
              },
              count = s.count
            })
          end
        end
      end

      local io_group = p_settings.separate_io and io_type or "all"
      local color_group = p_settings.separate_wire_color and color or "all"
      local net_str = net_id and tostring(net_id) or "0"
      local key = io_group .. "_" .. color_group .. "_" .. net_str

      if #signal_list > 0 and not seen_keys[key] then
        seen_keys[key] = true

        table.insert(sections, {
          io_type = io_type,
          color = color,
          net_id = net_id or 0,
          signals = signal_list
        })
      end
    end
  end

  if #sections == 0 then
    return nil
  end

  return sections
end

-- 信号ソート
local function sort_signals(signals, sort_order)
  table.sort(signals, function(a, b)
    if sort_order == "count-desc" then
      local abs_a = math.abs(a.count)
      local abs_b = math.abs(b.count)
      if abs_a ~= abs_b then
        return abs_a > abs_b
      end
    elseif sort_order == "name" then
      local name_a = a.signal.name or ""
      local name_b = b.signal.name or ""
      if name_a ~= name_b then
        return name_a < name_b
      end
    end

    local type_a = a.signal.type or "item"
    local type_b = b.signal.type or "item"
    if type_a ~= type_b then
      return type_a < type_b
    end

    local name_a = a.signal.name or ""
    local name_b = b.signal.name or ""
    if name_a ~= name_b then
      return name_a < name_b
    end

    local qual_a = a.signal.quality or "normal"
    local qual_b = b.signal.quality or "normal"
    return qual_a < qual_b
  end)
end

-- 位置計算 (Clamp付き)
local function build_gui_signature(sections_data, p_settings, total_signals)
  local parts = {
    tostring(p_settings.columns),
    tostring(p_settings.max_signals),
    tostring(p_settings.show_network_id),
    tostring(p_settings.compact_numbers),
    tostring(p_settings.separate_io),
    tostring(p_settings.separate_wire_color),
    tostring(p_settings.sort_order),
    tostring(total_signals)
  }

  for _, sec in ipairs(sections_data) do
    table.insert(parts, sec.io_type or "")
    table.insert(parts, sec.color or "")
    table.insert(parts, tostring(sec.net_id or 0))

    for _, entry in ipairs(sec.signals) do
      table.insert(parts, entry.signal.type or "")
      table.insert(parts, entry.signal.name or "")
      table.insert(parts, entry.signal.quality or "")
      table.insert(parts, tostring(entry.count or 0))
    end
  end

  return table.concat(parts, "\31")
end

local function estimate_window_size(sections_data, p_settings, total_signals)
  local columns = math.max(1, p_settings.columns or 5)
  local max_signals = math.max(1, p_settings.max_signals or 25)
  local visible_slots = math.min(total_signals, max_signals)
  local width = (columns * 40) + 28
  local height = 20

  for _, sec in ipairs(sections_data) do
    local has_header = p_settings.separate_io or p_settings.separate_wire_color or
      (p_settings.show_network_id and sec.net_id and sec.net_id > 0)
    if has_header then
      height = height + 22
    end

    local section_slots = #sec.signals
    if section_slots == 0 then
      height = height + 30
    elseif visible_slots > 0 then
      local rows = math.ceil(math.min(section_slots, visible_slots) / columns)
      height = height + (rows * 40) + 10
      visible_slots = math.max(0, visible_slots - section_slots)
    else
      height = height + 10
    end
  end

  return width, height
end

local function update_window_position(player, window, p_settings, sections_data, total_signals)
  if not valid(window) then return end

  local resolution = player.display_resolution or { width = 1920, height = 1080 }
  local scale = player.display_scale or 1
  if scale <= 0 then scale = 1 end

  local gui_width = resolution.width / scale
  local gui_height = resolution.height / scale

  local win_w, win_h = estimate_window_size(sections_data, p_settings, total_signals)

  local target_x = gui_width - p_settings.offset_x - win_w
  local target_y = gui_height - p_settings.offset_y - win_h

  local clamped_x = math.max(0, math.min(target_x, gui_width - win_w))
  local clamped_y = math.max(0, math.min(target_y, gui_height - win_h))

  window.location = { x = math.floor(clamped_x), y = math.floor(clamped_y) }
end

-- ウィンドウ削除
local function close_window(p_data)
  safe_destroy(p_data.window)
  p_data.window = nil
  p_data.last_gui_signature = nil
end

local function reset_hover_state(p_data)
  close_window(p_data)
  p_data.selected_unit_number = nil
  p_data.pending_unit_number = nil
  p_data.pending_since = 0
end

local function schedule_hover(p_data, unit_num, tick)
  if p_data.pending_unit_number == unit_num then
    return
  end

  p_data.pending_unit_number = unit_num
  p_data.pending_since = tick or game.tick

  if p_data.selected_unit_number ~= unit_num then
    p_data.selected_unit_number = nil
    close_window(p_data)
  end
end

-- ツールチップ構築
local function build_signal_tooltip(entry, section, p_settings)
  local full_val = format_count_full(entry.count)
  local tooltip = { "" }

  table.insert(tooltip, { "hover-circuit-signals.tooltip-signal-val", full_val })

  if p_settings.show_network_id then
    local color_loc = { "hover-circuit-signals." .. section.color }
    table.insert(tooltip, "\n")
    table.insert(tooltip, { "hover-circuit-signals.tooltip-net-id", color_loc, tostring(section.net_id) })
  end

  if p_settings.separate_io then
    local io_loc = { "hover-circuit-signals." .. section.io_type }
    table.insert(tooltip, "\n")
    table.insert(tooltip, { "hover-circuit-signals.tooltip-terminal", io_loc })
  end

  return tooltip
end

-- GUI生成 / 更新
local function refresh_gui(player, p_data, entity, p_settings)
  local sections_data = collect_circuit_data(entity, p_settings)

  if not sections_data then
    close_window(p_data)
    return
  end

  local display_sections = {}
  local total_signals = 0
  for _, sec in ipairs(sections_data) do
    sort_signals(sec.signals, p_settings.sort_order)
    table.insert(display_sections, sec)
    total_signals = total_signals + #sec.signals
  end

  if #display_sections == 0 then
    close_window(p_data)
    return
  end

  sections_data = display_sections
  local gui_signature = build_gui_signature(sections_data, p_settings, total_signals)

  if valid(p_data.window) and p_data.last_gui_signature == gui_signature then
    update_window_position(player, p_data.window, p_settings, sections_data, total_signals)
    return
  end

  if not valid(p_data.window) then
    local screen = player.gui.screen
    local window = screen.add({
      type = "frame",
      name = GUI_NAME,
      direction = "vertical",
      style = "frame"
    })
    window.style.padding = 6
    p_data.window = window
  end

  local window = p_data.window
  p_data.last_gui_signature = gui_signature
  window.clear()

  local displayed_count = 0
  local overflow_count = 0
  local overflow_parent_table = nil

  for sec_idx, sec in ipairs(sections_data) do
    local header_text = { "" }
    if p_settings.separate_io then
      table.insert(header_text, { "hover-circuit-signals." .. sec.io_type })
      table.insert(header_text, " ")
    end

    if p_settings.separate_wire_color then
      table.insert(header_text, "● ")
      table.insert(header_text, { "hover-circuit-signals." .. sec.color })
    end

    if p_settings.show_network_id and sec.net_id and sec.net_id > 0 then
      table.insert(header_text, " #" .. tostring(sec.net_id))
    end

    if #header_text > 1 then
      local label = window.add({
        type = "label",
        caption = header_text,
        style = "bold_label"
      })
      label.style.bottom_margin = 2
      if sec_idx > 1 then
        label.style.top_margin = 4
      end
    end

    local inner_frame = window.add({
      type = "frame",
      direction = "vertical",
      style = "inside_shallow_frame"
    })
    inner_frame.style.padding = 4

    local table_element = inner_frame.add({
      type = "table",
      column_count = p_settings.columns
    })
    table_element.style.cell_padding = 1

    for _, entry in ipairs(sec.signals) do
      local remaining_in_total = total_signals - displayed_count

      if displayed_count < p_settings.max_signals - 1 or (displayed_count == p_settings.max_signals - 1 and remaining_in_total == 1) then
        displayed_count = displayed_count + 1

        local display_text = p_settings.compact_numbers and format_count_compact(entry.count) or format_count_full(entry.count)
        local tooltip = build_signal_tooltip(entry, sec, p_settings)

        local btn = table_element.add({
          type = "choose-elem-button",
          elem_type = "signal",
          style = "slot_button",
          tooltip = tooltip
        })
        btn.elem_value = entry.signal
        btn.locked = true
        btn.style.size = 38

        btn.add({
          type = "label",
          style = "count_label",
          caption = display_text,
          ignored_by_interaction = true,
          tooltip = tooltip
        })
      else
        overflow_count = overflow_count + 1
        overflow_parent_table = table_element
      end
    end
  end

  -- 残件数タイルの追加
  if overflow_count > 0 and overflow_parent_table then
    local overflow_text = "+" .. tostring(overflow_count)
    local tooltip = { "hover-circuit-signals.tooltip-more-signals", tostring(overflow_count) }

    local btn = overflow_parent_table.add({
      type = "button",
      caption = overflow_text,
      style = "slot_button",
      tooltip = tooltip
    })
    btn.style.size = 38
    btn.style.font = "default-bold"
  end

  update_window_position(player, window, p_settings, sections_data, total_signals)
end

-- イベントハンドラ
local function on_tick(event)
  for _, player in ipairs(game.connected_players) do
    local p_data = get_player_data(player.index)
    local p_settings = get_player_settings(player)

    if not p_settings.enabled or p_data.toggled_off then
      reset_hover_state(p_data)
    else
      local selected = player.selected
      if valid(selected) then
        local unit_num = get_entity_key(selected)

        schedule_hover(p_data, unit_num, event.tick)

        if event.tick - (p_data.pending_since or event.tick) >= HOVER_STABLE_TICKS and
          (p_data.selected_unit_number ~= unit_num or (event.tick % p_settings.update_interval == player.index % p_settings.update_interval)) then
          p_data.selected_unit_number = unit_num
          refresh_gui(player, p_data, selected, p_settings)
        end
      else
        reset_hover_state(p_data)
      end
    end
  end
end

local function on_selected_entity_changed(event)
  local player = game.get_player(event.player_index)
  if not valid(player) then return end

  local p_data = get_player_data(player.index)
  local p_settings = get_player_settings(player)

  if not p_settings.enabled or p_data.toggled_off then
    reset_hover_state(p_data)
    return
  end

  local selected = player.selected
  if valid(selected) then
    schedule_hover(p_data, get_entity_key(selected), event.tick)
  else
    reset_hover_state(p_data)
  end
end

local function on_toggle_hotkey(event)
  local player = game.get_player(event.player_index)
  if not valid(player) then return end

  local p_data = get_player_data(player.index)
  p_data.toggled_off = not p_data.toggled_off

  if p_data.toggled_off then
    reset_hover_state(p_data)
    player.create_local_flying_text({
      text = { "hover-circuit-signals.msg-disabled" },
      create_at = { player.position.x, player.position.y - 1 }
    })
  else
    player.create_local_flying_text({
      text = { "hover-circuit-signals.msg-enabled" },
      create_at = { player.position.x, player.position.y - 1 }
    })

    local selected = player.selected
    if valid(selected) then
      local p_settings = get_player_settings(player)
      local unit_num = get_entity_key(selected)
      p_data.pending_unit_number = unit_num
      p_data.pending_since = event.tick - HOVER_STABLE_TICKS
      p_data.selected_unit_number = unit_num
      refresh_gui(player, p_data, selected, p_settings)
    end
  end
end

local function on_player_left(event)
  local players_data = get_storage()
  if players_data[event.player_index] then
    close_window(players_data[event.player_index])
    players_data[event.player_index] = nil
  end
end

local function on_runtime_mod_setting_changed(event)
  local prefix = "hover-circuit-signals"
  if event.setting ~= nil and string.sub(event.setting, 1, string.len(prefix)) ~= prefix then
    return
  end

  local player = game.get_player(event.player_index)
  if not valid(player) then return end

  local p_data = get_player_data(player.index)
  local p_settings = get_player_settings(player)

  if not p_settings.enabled or p_data.toggled_off then
    reset_hover_state(p_data)
    return
  end

  local selected = player.selected
  if valid(selected) then
    local unit_num = get_entity_key(selected)
    p_data.pending_unit_number = unit_num
    p_data.pending_since = event.tick - HOVER_STABLE_TICKS
    p_data.selected_unit_number = unit_num
    refresh_gui(player, p_data, selected, p_settings)
  else
    reset_hover_state(p_data)
  end
end

script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)
script.on_event("hover-circuit-signals-toggle", on_toggle_hotkey)
script.on_event(defines.events.on_player_left_game, on_player_left)
script.on_event(defines.events.on_player_removed, on_player_left)

script.on_init(function()
  get_storage()
end)

script.on_configuration_changed(function()
  get_storage()
end)
