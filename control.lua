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
local KEY_SEPARATOR = "\31"

local IO_ORDER = {
  input = 1,
  output = 2,
  circuit = 3,
  all = 4
}

local COLOR_ORDER = {
  red = 1,
  green = 2,
  all = 3
}

local function valid(obj)
  return obj and obj.valid
end

local function get_storage()
  storage.players = storage.players or {}
  storage.active_players = storage.active_players or {}
  return storage
end

local function get_players_storage()
  return get_storage().players
end

local function get_active_players_storage()
  return get_storage().active_players
end

local function mark_player_active(player_index)
  get_active_players_storage()[player_index] = true
end

local function clear_player_active(player_index)
  get_active_players_storage()[player_index] = nil
end

local function setting_value(settings_table, setting_name, default_value)
  local setting = settings_table[setting_name]
  if setting and setting.value ~= nil then
    return setting.value
  end
  return default_value
end

local function clamp(value, min_value, max_value)
  value = tonumber(value) or min_value
  return math.max(min_value, math.min(value, max_value))
end

local function get_player_settings(player)
  local s = settings.get_player_settings(player)
  return {
    enabled = setting_value(s, SETTING_ENABLED, true),
    offset_x = clamp(setting_value(s, SETTING_OFFSET_X, 280), 0, 4096),
    offset_y = clamp(setting_value(s, SETTING_OFFSET_Y, 220), 0, 4096),
    columns = clamp(setting_value(s, SETTING_COLUMNS, 5), 1, 10),
    max_signals = clamp(setting_value(s, SETTING_MAX_SIGNALS, 25), 1, 100),
    update_interval = clamp(setting_value(s, SETTING_UPDATE_INTERVAL, 12), 1, 120),
    show_network_id = setting_value(s, SETTING_SHOW_NETWORK_ID, true),
    compact_numbers = setting_value(s, SETTING_COMPACT_NUMBERS, true),
    separate_io = setting_value(s, SETTING_SEPARATE_IO, true),
    separate_wire_color = setting_value(s, SETTING_SEPARATE_WIRE_COLOR, true),
    sort_order = setting_value(s, SETTING_SORT_ORDER, "prototype")
  }
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

local function clear_gui_refs(p_data)
  p_data.window = nil
  p_data.gui_refs = nil
  p_data.last_gui_signature = nil
end

local function close_window(p_data, player)
  safe_destroy(p_data.window)

  if valid(player) and valid(player.gui.screen[GUI_NAME]) then
    safe_destroy(player.gui.screen[GUI_NAME])
  end

  clear_gui_refs(p_data)
end

local function reset_hover_state(p_data, player)
  close_window(p_data, player)
  p_data.selected_unit_number = nil
  p_data.pending_unit_number = nil
  p_data.pending_since = 0
  p_data.next_refresh_tick = nil
end

local function get_player_data(player_index)
  local players_data = get_players_storage()
  local p_data = players_data[player_index]

  if not p_data then
    p_data = {}
    players_data[player_index] = p_data
  end

  if p_data.toggled_off == nil then
    p_data.toggled_off = false
  end

  p_data.selected_unit_number = p_data.selected_unit_number
  p_data.pending_unit_number = p_data.pending_unit_number
  p_data.pending_since = p_data.pending_since or 0
  p_data.next_refresh_tick = p_data.next_refresh_tick
  p_data.last_gui_signature = p_data.last_gui_signature
  p_data.window = p_data.window
  p_data.gui_refs = p_data.gui_refs

  return p_data
end

local function format_count_full(count)
  local formatted = tostring(math.abs(count))
  local k
  while true do
    formatted, k = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
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

local function signal_key(signal)
  return table.concat({
    signal.type or "item",
    signal.name or "",
    signal.quality or "normal"
  }, KEY_SEPARATOR)
end

local function source_key(source)
  return table.concat({
    tostring(source.net_id or 0),
    source.color or "",
    source.io_type or ""
  }, KEY_SEPARATOR)
end

local function section_key_for_source(source, p_settings)
  local io_group = p_settings.separate_io and source.io_type or "all"
  local color_group = p_settings.separate_wire_color and source.color or "all"
  return io_group .. KEY_SEPARATOR .. color_group
end

local function normalize_signal_id(signal)
  if not signal or not signal.name then return nil end
  return {
    type = signal.type or "item",
    name = signal.name,
    quality = signal.quality or "normal"
  }
end

local function signal_elem_tooltip(signal)
  return {
    type = "signal",
    signal_type = signal.type or "item",
    name = signal.name,
    quality = signal.quality or "normal"
  }
end

local function terminal_loc(io_type)
  if io_type == "input" then
    return { "hover-circuit-signals.input" }
  elseif io_type == "output" then
    return { "hover-circuit-signals.output" }
  elseif io_type == "all" then
    return { "hover-circuit-signals.terminal-all" }
  end
  return { "hover-circuit-signals.terminal-circuit" }
end

local function color_loc(color)
  if color == "red" then
    return { "hover-circuit-signals.red" }
  elseif color == "green" then
    return { "hover-circuit-signals.green" }
  end
  return { "hover-circuit-signals.wire-all" }
end

local function get_connector_meta(connector_id)
  local ids = defines.wire_connector_id

  if connector_id == ids.circuit_red then
    return { io_type = "circuit", color = "red" }
  elseif connector_id == ids.circuit_green then
    return { io_type = "circuit", color = "green" }
  elseif connector_id == ids.combinator_input_red then
    return { io_type = "input", color = "red" }
  elseif connector_id == ids.combinator_input_green then
    return { io_type = "input", color = "green" }
  elseif connector_id == ids.combinator_output_red then
    return { io_type = "output", color = "red" }
  elseif connector_id == ids.combinator_output_green then
    return { io_type = "output", color = "green" }
  end

  return nil
end

local function get_real_connection_count(connector)
  if not valid(connector) then return 0 end

  local ok_real, real_count = pcall(function()
    return connector.real_connection_count
  end)
  if ok_real and real_count then
    return real_count
  end

  local ok_count, connection_count = pcall(function()
    return connector.connection_count
  end)
  if ok_count and connection_count then
    return connection_count
  end

  return 0
end

local function get_network(entity, connector_id)
  local ok_network, network = pcall(function()
    return entity.get_circuit_network(connector_id)
  end)
  if ok_network and valid(network) then
    return network
  end
  return nil
end

local function get_network_id(network, connector)
  if valid(network) then
    local ok_id, net_id = pcall(function()
      return network.network_id
    end)
    if ok_id and net_id then
      return net_id
    end
  end

  if valid(connector) then
    local ok_id, net_id = pcall(function()
      return connector.network_id
    end)
    if ok_id and net_id then
      return net_id
    end
  end

  return 0
end

local function read_signals(entity, connector_id, network)
  local ok_signals, raw_signals = pcall(function()
    if valid(network) then
      return network.signals
    end
    return entity.get_signals(connector_id)
  end)

  if ok_signals then
    return raw_signals
  end

  return nil
end

local function add_source(target, source)
  target.source_map = target.source_map or {}
  target.sources = target.sources or {}

  if not target.source_map[source.key] then
    target.source_map[source.key] = true
    table.insert(target.sources, source)
  end
end

local function sort_sources(sources)
  table.sort(sources, function(a, b)
    local io_a = IO_ORDER[a.io_type] or 99
    local io_b = IO_ORDER[b.io_type] or 99
    if io_a ~= io_b then return io_a < io_b end

    local color_a = COLOR_ORDER[a.color] or 99
    local color_b = COLOR_ORDER[b.color] or 99
    if color_a ~= color_b then return color_a < color_b end

    return (a.net_id or 0) < (b.net_id or 0)
  end)
end

local function collect_circuit_data(entity, p_settings)
  if not valid(entity) then return nil, false end

  local ok_connectors, connectors = pcall(function()
    return entity.get_wire_connectors(false)
  end)

  if not ok_connectors or not connectors then
    return nil, false
  end

  local sections = {}
  local sections_by_key = {}
  local seen_sources = {}
  local has_connected_circuit = false

  for connector_id, connector in pairs(connectors) do
    local meta = get_connector_meta(connector_id)

    if meta and valid(connector) and get_real_connection_count(connector) > 0 then
      has_connected_circuit = true

      local network = get_network(entity, connector_id)
      local net_id = get_network_id(network, connector)
      local source = {
        io_type = meta.io_type,
        color = meta.color,
        net_id = net_id
      }
      source.key = source_key(source)

      if not seen_sources[source.key] then
        seen_sources[source.key] = true

        local raw_signals = read_signals(entity, connector_id, network)
        if raw_signals then
          local section_key = section_key_for_source(source, p_settings)
          local section = sections_by_key[section_key]

          if not section then
            section = {
              key = section_key,
              io_type = p_settings.separate_io and source.io_type or "all",
              color = p_settings.separate_wire_color and source.color or "all",
              signals = {},
              signals_by_key = {},
              sources = {},
              source_map = {}
            }
            sections_by_key[section_key] = section
            table.insert(sections, section)
          end

          local source_added_to_section = false

          for _, raw_signal in pairs(raw_signals) do
            local signal = normalize_signal_id(raw_signal.signal)
            local count = raw_signal.count or 0

            if signal and count ~= 0 then
              local key = signal_key(signal)
              local entry = section.signals_by_key[key]

              if not entry then
                entry = {
                  key = key,
                  signal = signal,
                  count = 0,
                  sources = {},
                  source_map = {}
                }
                section.signals_by_key[key] = entry
                table.insert(section.signals, entry)
              end

              entry.count = entry.count + count
              add_source(entry, source)

              if not source_added_to_section then
                add_source(section, source)
                source_added_to_section = true
              end
            end
          end
        end
      end
    end
  end

  local display_sections = {}
  for _, section in ipairs(sections) do
    local non_zero_signals = {}
    local section_sources = {}
    local section_source_map = {}

    for _, entry in ipairs(section.signals) do
      if entry.count ~= 0 then
        sort_sources(entry.sources)

        for _, source in ipairs(entry.sources) do
          if not section_source_map[source.key] then
            section_source_map[source.key] = true
            table.insert(section_sources, source)
          end
        end

        table.insert(non_zero_signals, entry)
      end
    end

    if #non_zero_signals > 0 then
      section.signals = non_zero_signals
      section.signals_by_key = nil
      section.source_map = nil
      section.sources = section_sources
      sort_sources(section.sources)
      table.insert(display_sections, section)
    end
  end

  if #display_sections == 0 then
    return nil, has_connected_circuit
  end

  table.sort(display_sections, function(a, b)
    local io_a = IO_ORDER[a.io_type] or 99
    local io_b = IO_ORDER[b.io_type] or 99
    if io_a ~= io_b then return io_a < io_b end

    local color_a = COLOR_ORDER[a.color] or 99
    local color_b = COLOR_ORDER[b.color] or 99
    if color_a ~= color_b then return color_a < color_b end

    local net_a = a.sources[1] and a.sources[1].net_id or 0
    local net_b = b.sources[1] and b.sources[1].net_id or 0
    return net_a < net_b
  end)

  return display_sections, has_connected_circuit
end

local function compare_signal_identity(a, b)
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
end

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

    return compare_signal_identity(a, b)
  end)
end

local function build_gui_signature(all_sections, p_settings)
  local parts = {
    tostring(p_settings.columns),
    tostring(p_settings.max_signals),
    tostring(p_settings.show_network_id),
    tostring(p_settings.separate_io),
    tostring(p_settings.separate_wire_color),
    tostring(p_settings.sort_order)
  }

  for _, section in ipairs(all_sections) do
    table.insert(parts, section.io_type or "")
    table.insert(parts, section.color or "")

    local source_keys = {}
    for _, source in ipairs(section.sources or {}) do
      table.insert(source_keys, source.key)
    end
    table.sort(source_keys)
    for _, key in ipairs(source_keys) do
      table.insert(parts, key)
    end

    local signal_keys = {}
    for _, entry in ipairs(section.signals or {}) do
      table.insert(signal_keys, entry.key)
    end
    table.sort(signal_keys)
    for _, key in ipairs(signal_keys) do
      table.insert(parts, key)
    end
  end

  return table.concat(parts, KEY_SEPARATOR)
end

local function prepare_display_plan(sections_data, p_settings)
  local total_signals = 0
  for _, section in ipairs(sections_data) do
    sort_signals(section.signals, p_settings.sort_order)
    total_signals = total_signals + #section.signals
  end

  local max_signals = math.max(1, p_settings.max_signals or 25)
  local slots_for_signals = max_signals
  if total_signals > max_signals then
    slots_for_signals = max_signals - 1
  end

  local visible_entries = {}
  local visible_sections = {}
  local overflow_count = 0

  for _, section in ipairs(sections_data) do
    local visible_signals = {}

    for _, entry in ipairs(section.signals) do
      if #visible_entries < slots_for_signals then
        table.insert(visible_entries, {
          section = section,
          entry = entry
        })
        table.insert(visible_signals, entry)
      else
        overflow_count = overflow_count + 1
      end
    end

    if #visible_signals > 0 then
      table.insert(visible_sections, {
        key = section.key,
        io_type = section.io_type,
        color = section.color,
        sources = section.sources,
        signals = visible_signals
      })
    end
  end

  return {
    all_sections = sections_data,
    sections = visible_sections,
    visible_entries = visible_entries,
    overflow_count = overflow_count,
    total_signals = total_signals
  }
end

local function section_has_header(section, p_settings)
  if p_settings.separate_io and section.io_type ~= "all" and section.io_type ~= "circuit" then
    return true
  end

  if p_settings.separate_wire_color and section.color ~= "all" then
    return true
  end

  return p_settings.show_network_id and #section.sources == 1 and (section.sources[1].net_id or 0) > 0
end

local function build_section_header(section, p_settings)
  if not section_has_header(section, p_settings) then
    return nil
  end

  local header = { "" }

  if p_settings.separate_io and section.io_type ~= "all" and section.io_type ~= "circuit" then
    table.insert(header, terminal_loc(section.io_type))
    table.insert(header, " ")
  end

  if p_settings.separate_wire_color and section.color ~= "all" then
    table.insert(header, color_loc(section.color))
    table.insert(header, " ")
  end

  if p_settings.show_network_id and #section.sources == 1 and (section.sources[1].net_id or 0) > 0 then
    table.insert(header, "#" .. tostring(section.sources[1].net_id))
  end

  return header
end

local function estimate_window_size(display_plan, p_settings)
  local columns = math.max(1, p_settings.columns or 5)
  local width = (columns * 40) + 28
  local height = 20

  for _, section in ipairs(display_plan.sections) do
    if section_has_header(section, p_settings) then
      height = height + 22
    end

    local rows = math.ceil(#section.signals / columns)
    height = height + (rows * 40) + 10
  end

  if display_plan.overflow_count > 0 then
    height = height + 50
  end

  return width, height
end

local function update_window_position(player, window, p_settings, display_plan)
  if not valid(window) then return end

  local resolution = player.display_resolution or { width = 1920, height = 1080 }
  local scale = player.display_scale or 1
  if scale <= 0 then scale = 1 end

  local gui_width = resolution.width / scale
  local gui_height = resolution.height / scale
  local win_w, win_h = estimate_window_size(display_plan, p_settings)

  local target_x = gui_width - p_settings.offset_x - win_w
  local target_y = gui_height - p_settings.offset_y - win_h
  local clamped_x = math.max(0, math.min(target_x, gui_width - win_w))
  local clamped_y = math.max(0, math.min(target_y, gui_height - win_h))

  window.location = { x = math.floor(clamped_x), y = math.floor(clamped_y) }
end

local function build_signal_tooltip(entry)
  local tooltip = { "" }
  table.insert(tooltip, { "hover-circuit-signals.tooltip-signal-val", format_count_full(entry.count) })

  local quality = entry.signal.quality or "normal"
  if quality ~= "normal" then
    table.insert(tooltip, "\n")
    table.insert(tooltip, { "hover-circuit-signals.tooltip-quality", quality })
  end

  if #entry.sources == 1 then
    local source = entry.sources[1]
    table.insert(tooltip, "\n")
    table.insert(tooltip, { "hover-circuit-signals.tooltip-wire", color_loc(source.color) })
    table.insert(tooltip, "\n")
    table.insert(tooltip, { "hover-circuit-signals.tooltip-network-id", tostring(source.net_id or 0) })
    table.insert(tooltip, "\n")
    table.insert(tooltip, { "hover-circuit-signals.tooltip-terminal", terminal_loc(source.io_type) })
  else
    table.insert(tooltip, "\n")
    table.insert(tooltip, { "hover-circuit-signals.tooltip-sources-header" })

    for _, source in ipairs(entry.sources) do
      table.insert(tooltip, "\n")
      table.insert(tooltip, "  ")
      table.insert(tooltip, {
        "hover-circuit-signals.tooltip-source",
        color_loc(source.color),
        tostring(source.net_id or 0),
        terminal_loc(source.io_type)
      })
    end
  end

  return tooltip
end

local function display_count(entry, p_settings)
  if p_settings.compact_numbers then
    return format_count_compact(entry.count)
  end
  return format_count_full(entry.count)
end

local function ensure_window(player, p_data)
  if valid(p_data.window) then
    return p_data.window
  end

  local screen = player.gui.screen
  if valid(screen[GUI_NAME]) then
    p_data.window = screen[GUI_NAME]
    return p_data.window
  end

  local window = screen.add({
    type = "frame",
    name = GUI_NAME,
    direction = "vertical",
    style = "frame"
  })
  window.style.padding = 6
  p_data.window = window
  return window
end

local function create_signal_tile(parent, entry, p_settings)
  local tooltip = build_signal_tooltip(entry)

  local button = parent.add({
    type = "choose-elem-button",
    elem_type = "signal",
    style = "slot_button",
    tooltip = tooltip,
    elem_tooltip = signal_elem_tooltip(entry.signal),
    locked = true
  })
  button.elem_value = entry.signal
  button.locked = true
  button.style.size = 38

  local label = button.add({
    type = "label",
    style = "count_label",
    caption = display_count(entry, p_settings),
    ignored_by_interaction = true,
    tooltip = tooltip
  })

  return {
    button = button,
    label = label
  }
end

local function add_signal_section(window, section, p_settings, refs, section_index)
  local header = build_section_header(section, p_settings)
  if header then
    local label = window.add({
      type = "label",
      caption = header,
      style = "bold_label"
    })
    label.style.bottom_margin = 2
    if section_index > 1 then
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

  for _, entry in ipairs(section.signals) do
    table.insert(refs.signal_slots, create_signal_tile(table_element, entry, p_settings))
  end
end

local function add_overflow_section(window, p_settings, refs, overflow_count)
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

  local tooltip = { "hover-circuit-signals.tooltip-more-signals", tostring(overflow_count) }
  local button = table_element.add({
    type = "button",
    caption = { "hover-circuit-signals.more-signals", tostring(overflow_count) },
    style = "slot_button",
    tooltip = tooltip
  })
  button.style.size = 38
  button.style.font = "default-bold"
  refs.overflow_button = button
end

local function update_existing_gui(player, p_data, p_settings, display_plan)
  local refs = p_data.gui_refs
  if not refs or not valid(p_data.window) then
    return false
  end

  if #(refs.signal_slots or {}) ~= #display_plan.visible_entries then
    return false
  end

  for index, visible_entry in ipairs(display_plan.visible_entries) do
    local slot = refs.signal_slots[index]
    local entry = visible_entry.entry

    if not slot or not valid(slot.button) or not valid(slot.label) then
      return false
    end

    local tooltip = build_signal_tooltip(entry)
    slot.button.elem_value = entry.signal
    slot.button.elem_tooltip = signal_elem_tooltip(entry.signal)
    slot.button.tooltip = tooltip
    slot.label.caption = display_count(entry, p_settings)
    slot.label.tooltip = tooltip
  end

  if display_plan.overflow_count > 0 then
    if not valid(refs.overflow_button) then
      return false
    end

    refs.overflow_button.caption = { "hover-circuit-signals.more-signals", tostring(display_plan.overflow_count) }
    refs.overflow_button.tooltip = { "hover-circuit-signals.tooltip-more-signals", tostring(display_plan.overflow_count) }
  elseif refs.overflow_button then
    return false
  end

  update_window_position(player, p_data.window, p_settings, display_plan)
  return true
end

local function rebuild_gui(player, p_data, p_settings, display_plan, gui_signature)
  local window = ensure_window(player, p_data)
  if not valid(window) then return end

  window.clear()

  local refs = {
    signal_slots = {},
    overflow_button = nil
  }

  for section_index, section in ipairs(display_plan.sections) do
    add_signal_section(window, section, p_settings, refs, section_index)
  end

  if display_plan.overflow_count > 0 then
    add_overflow_section(window, p_settings, refs, display_plan.overflow_count)
  end

  p_data.gui_refs = refs
  p_data.last_gui_signature = gui_signature
  update_window_position(player, window, p_settings, display_plan)
end

local function refresh_gui(player, p_data, entity, p_settings)
  local sections_data, has_connected_circuit = collect_circuit_data(entity, p_settings)

  if not sections_data then
    close_window(p_data, player)
    return false, has_connected_circuit
  end

  local display_plan = prepare_display_plan(sections_data, p_settings)
  local gui_signature = build_gui_signature(display_plan.all_sections, p_settings)

  if valid(p_data.window) and p_data.last_gui_signature == gui_signature then
    if update_existing_gui(player, p_data, p_settings, display_plan) then
      return true, has_connected_circuit
    end
  end

  rebuild_gui(player, p_data, p_settings, display_plan, gui_signature)
  return true, has_connected_circuit
end

local function schedule_hover(p_data, unit_num, tick)
  if p_data.pending_unit_number == unit_num then
    return
  end

  p_data.pending_unit_number = unit_num
  p_data.pending_since = tick or game.tick
  p_data.next_refresh_tick = nil

  if p_data.selected_unit_number ~= unit_num then
    p_data.selected_unit_number = nil
    close_window(p_data)
  end
end

local function schedule_next_refresh(p_data, tick, player_index, interval)
  if interval <= 1 then
    p_data.next_refresh_tick = tick + 1
    return
  end

  local phase = player_index % interval
  local earliest_tick = tick + interval
  local offset = (phase - (earliest_tick % interval)) % interval

  p_data.next_refresh_tick = earliest_tick + offset
end

local function refresh_player_activity(player, tick)
  local p_data = get_player_data(player.index)
  local p_settings = get_player_settings(player)

  if not p_settings.enabled or p_data.toggled_off then
    reset_hover_state(p_data, player)
    clear_player_active(player.index)
    return
  end

  local selected = player.selected
  if valid(selected) then
    schedule_hover(p_data, get_entity_key(selected), tick)
    mark_player_active(player.index)
  else
    reset_hover_state(p_data, player)
    clear_player_active(player.index)
  end
end

local function refresh_player_after_setting_changed(player, tick)
  local event_tick = tick or game.tick
  local p_data = get_player_data(player.index)
  local p_settings = get_player_settings(player)

  if not p_settings.enabled or p_data.toggled_off then
    reset_hover_state(p_data, player)
    clear_player_active(player.index)
    return
  end

  local selected = player.selected
  if not valid(selected) then
    reset_hover_state(p_data, player)
    clear_player_active(player.index)
    return
  end

  local unit_num = get_entity_key(selected)
  p_data.pending_unit_number = unit_num
  p_data.pending_since = event_tick - HOVER_STABLE_TICKS
  p_data.selected_unit_number = unit_num

  local _, has_connected_circuit = refresh_gui(player, p_data, selected, p_settings)
  schedule_next_refresh(p_data, event_tick, player.index, p_settings.update_interval)

  if has_connected_circuit then
    mark_player_active(player.index)
  else
    clear_player_active(player.index)
  end
end

local function on_tick(event)
  for player_index in pairs(get_active_players_storage()) do
    local player = game.get_player(player_index)

    if not valid(player) or not player.connected then
      clear_player_active(player_index)
    else
      local p_data = get_player_data(player.index)
      local p_settings = get_player_settings(player)

      if not p_settings.enabled or p_data.toggled_off then
        reset_hover_state(p_data, player)
        clear_player_active(player.index)
      else
        local selected = player.selected

        if not valid(selected) then
          reset_hover_state(p_data, player)
          clear_player_active(player.index)
        else
          local unit_num = get_entity_key(selected)
          schedule_hover(p_data, unit_num, event.tick)

          local stable = event.tick - (p_data.pending_since or event.tick) >= HOVER_STABLE_TICKS
          if stable then
            local selected_changed = p_data.selected_unit_number ~= unit_num
            local due = event.tick >= (p_data.next_refresh_tick or 0)

            if selected_changed or due then
              p_data.selected_unit_number = unit_num
              local _, has_connected_circuit = refresh_gui(player, p_data, selected, p_settings)
              schedule_next_refresh(p_data, event.tick, player.index, p_settings.update_interval)

              if not has_connected_circuit then
                clear_player_active(player.index)
              end
            end
          end
        end
      end
    end
  end
end

local function on_selected_entity_changed(event)
  local player = game.get_player(event.player_index)
  if not valid(player) then return end

  refresh_player_activity(player, event.tick)
end

local function on_toggle_hotkey(event)
  local player = game.get_player(event.player_index)
  if not valid(player) then return end

  local p_data = get_player_data(player.index)
  p_data.toggled_off = not p_data.toggled_off

  if p_data.toggled_off then
    reset_hover_state(p_data, player)
    clear_player_active(player.index)
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
      p_data.next_refresh_tick = nil

      if p_settings.enabled then
        refresh_gui(player, p_data, selected, p_settings)
        schedule_next_refresh(p_data, event.tick, player.index, p_settings.update_interval)
        mark_player_active(player.index)
      end
    end
  end
end

local function on_player_left(event)
  local p_data = get_players_storage()[event.player_index]
  if p_data then
    local player = game.get_player(event.player_index)
    reset_hover_state(p_data, player)
  end
  clear_player_active(event.player_index)
end

local function on_player_removed(event)
  local players_data = get_players_storage()
  local p_data = players_data[event.player_index]
  if p_data then
    close_window(p_data)
    players_data[event.player_index] = nil
  end
  clear_player_active(event.player_index)
end

local function on_player_joined(event)
  local player = game.get_player(event.player_index)
  if not valid(player) then return end

  local p_data = get_player_data(player.index)
  reset_hover_state(p_data, player)
  refresh_player_activity(player, event.tick)
end

local function setting_belongs_to_mod(setting_name)
  if setting_name == nil then return true end
  local prefix = "hover-circuit-signals"
  return string.sub(setting_name, 1, string.len(prefix)) == prefix
end

local function on_runtime_mod_setting_changed(event)
  if not setting_belongs_to_mod(event.setting) then
    return
  end

  if event.player_index then
    local player = game.get_player(event.player_index)
    if valid(player) then
      refresh_player_after_setting_changed(player, event.tick)
    end
  end
end

local function rebuild_connected_player_activity(tick)
  local active_players = get_active_players_storage()
  for player_index in pairs(active_players) do
    active_players[player_index] = nil
  end

  for _, player in ipairs(game.connected_players) do
    local p_data = get_player_data(player.index)
    reset_hover_state(p_data, player)
    refresh_player_activity(player, tick or game.tick)
  end
end

script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)
script.on_event(defines.events.on_player_joined_game, on_player_joined)
script.on_event(defines.events.on_player_left_game, on_player_left)
script.on_event(defines.events.on_player_removed, on_player_removed)
script.on_event("hover-circuit-signals-toggle", on_toggle_hotkey)

script.on_init(function()
  get_storage()
  rebuild_connected_player_activity(game.tick)
end)

script.on_configuration_changed(function()
  get_storage()
  rebuild_connected_player_activity(game.tick)
end)
