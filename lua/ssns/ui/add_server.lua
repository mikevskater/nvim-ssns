---@class AddServerUI
---Floating UI for adding and managing server connections
local AddServerUI = {}

local UiFloat = require('ssns.ui.float')
local Connections = require('ssns.connections')
local Cache = require('ssns.cache')
local KeymapManager = require('ssns.keymap_manager')

-- Current state
local current_float = nil
local current_screen = "list"  -- "list" or "new"
local selected_index = 1
local connections_list = {}

-- Highlight namespace
local ns_id = vim.api.nvim_create_namespace("ssns_add_server")

-- Database type options
local DB_TYPES = {
  { id = "sqlserver", label = "SQL Server", icon = "" },
  { id = "mysql", label = "MySQL", icon = "" },
  { id = "postgres", label = "PostgreSQL", icon = "" },
  { id = "sqlite", label = "SQLite", icon = "" },
}

-- Placeholder hints for server path by type
local PATH_HINTS = {
  sqlserver = ".\\SQLEXPRESS  or  localhost\\INSTANCE  or  192.168.1.100",
  mysql = "localhost:3306  or  user:pass@host:3306",
  postgres = "localhost:5432  or  user:pass@host:5432",
  sqlite = "C:\\path\\to\\database.db  or  /path/to/database.db",
}

---Build a full connection string from type and server path
---@param db_type string Database type (sqlserver, mysql, postgres, sqlite)
---@param server_path string The server path entered by user
---@return string connection_string Full connection string with scheme
local function build_connection_string(db_type, server_path)
  if not server_path or server_path == "" then
    return ""
  end

  -- If it already has a scheme, return as-is
  if server_path:match("^%w+://") then
    return server_path
  end

  local scheme = db_type
  if db_type == "postgres" then
    scheme = "postgresql"
  end

  -- For sqlite, handle paths
  if db_type == "sqlite" then
    -- Windows absolute path (C:\...)
    if server_path:match("^%a:\\") then
      return scheme .. ":///" .. server_path
    end
    -- Unix absolute path (/...)
    if server_path:match("^/") then
      return scheme .. "://" .. server_path
    end
    -- Relative path
    return scheme .. ":///" .. server_path
  end

  return scheme .. "://" .. server_path
end

---Extract server path from a full connection string
---@param connection_string string Full connection string
---@return string server_path Just the path portion
local function extract_server_path(connection_string)
  if not connection_string or connection_string == "" then
    return ""
  end

  -- Remove scheme prefix (sqlserver://, mysql://, etc.)
  local path = connection_string:gsub("^%w+://", "")

  -- For sqlite with triple slash, remove extra slash
  path = path:gsub("^/(%a:\\)", "%1")  -- Windows: sqlite:///C:\ -> C:\

  return path
end

---Get type label and icon for a db_type
---@param db_type string
---@return string label, string icon
local function get_type_info(db_type)
  for _, t in ipairs(DB_TYPES) do
    if t.id == db_type then
      return t.label, t.icon
    end
  end
  return "Unknown", ""
end

---Apply highlights to a buffer
---@param bufnr number Buffer number
---@param highlights table[] Array of {line, col_start, col_end, hl_group}
local function apply_highlights(bufnr, highlights)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl[4], hl[1], hl[2], hl[3])
  end
end

---Close the current floating window
function AddServerUI.close()
  if current_float then
    pcall(function() current_float:close() end)
  end
  current_float = nil
  current_screen = "list"
  selected_index = 1
end

---Open the Add Server UI
function AddServerUI.open()
  AddServerUI.close()

  connections_list = Connections.load()

  if #connections_list == 0 then
    AddServerUI.show_new_connection_form()
  else
    AddServerUI.show_connection_list()
  end
end

---Check if a connection is already in the tree
---@param name string Connection name
---@return boolean
local function is_in_tree(name)
  return Cache.server_exists(name)
end

---Show the list of saved connections
function AddServerUI.show_connection_list()
  -- Close any existing float first to prevent window stacking
  if current_float then
    pcall(function() current_float:close() end)
    current_float = nil
  end

  current_screen = "list"
  connections_list = Connections.load()

  -- Build display lines
  local lines = {}
  local highlights = {}

  if #connections_list == 0 then
    table.insert(lines, "")
    table.insert(lines, "  No saved connections")
    table.insert(lines, "")
    table.insert(lines, "  Press n to create a new connection")
    table.insert(lines, "")

    -- Highlights
    table.insert(highlights, {1, 0, -1, "Comment"})
    table.insert(highlights, {3, 8, 9, "Special"})  -- 'n' key
  else
    table.insert(lines, "")

    for i, conn in ipairs(connections_list) do
      local in_tree = is_in_tree(conn.name)
      local _, icon = get_type_info(conn.type or "sqlserver")

      -- Selection indicator
      local prefix = i == selected_index and "  " or "   "

      -- Build status indicators
      local indicators = ""
      if conn.favorite or conn.auto_connect then
        indicators = indicators .. " ★"
      end
      if conn.auto_connect then
        indicators = indicators .. "⚡"
      end
      if in_tree then
        indicators = indicators .. " [active]"
      end

      local line = string.format("%s%s %s%s", prefix, icon, conn.name, indicators)
      table.insert(lines, line)

      local line_idx = #lines - 1
      if i == selected_index then
        table.insert(highlights, {line_idx, 0, -1, "CursorLine"})
        table.insert(highlights, {line_idx, 2, 5, "Function"})  -- Icon
      else
        table.insert(highlights, {line_idx, 3, 6, "Comment"})  -- Icon dimmed
      end

      -- Highlight indicators
      if conn.favorite or conn.auto_connect then
        local star_pos = line:find("★")
        if star_pos then
          table.insert(highlights, {line_idx, star_pos - 1, star_pos + 2, "WarningMsg"})
        end
      end
      if in_tree then
        local active_pos = line:find("%[active%]")
        if active_pos then
          table.insert(highlights, {line_idx, active_pos - 1, -1, "DiagnosticOk"})
        end
      end
    end

    table.insert(lines, "")
  end

  -- Help section
  table.insert(lines, "  ───────────────────────────────────────────")
  local sep_line = #lines - 1
  table.insert(highlights, {sep_line, 0, -1, "Comment"})

  table.insert(lines, "")
  table.insert(lines, "  a Enter   Add to tree       n   New")
  table.insert(lines, "  e         Edit              d   Delete")
  table.insert(lines, "  f *       Toggle favorite   q   Close")
  table.insert(lines, "  j k       Navigate")
  table.insert(lines, "")

  -- Highlight keybinds
  for i = sep_line + 2, #lines - 2 do
    -- Highlight key letters (first column of keys)
    table.insert(highlights, {i, 2, 10, "Special"})
    table.insert(highlights, {i, 24, 32, "Special"})
  end

  -- Get keymaps from config
  local km = KeymapManager.get_group("add_server")
  local common = KeymapManager.get_group("common")

  -- Build keymaps table dynamically
  local keymaps = {}
  keymaps[common.close or "q"] = function() AddServerUI.close() end
  keymaps[common.cancel or "<Esc>"] = function() AddServerUI.close() end
  keymaps[common.nav_down or "j"] = function() AddServerUI.navigate(1) end
  keymaps[common.nav_up or "k"] = function() AddServerUI.navigate(-1) end
  keymaps[common.nav_down_alt or "<Down>"] = function() AddServerUI.navigate(1) end
  keymaps[common.nav_up_alt or "<Up>"] = function() AddServerUI.navigate(-1) end
  keymaps[km.add or "a"] = function() AddServerUI.add_selected_to_tree() end
  keymaps[common.confirm or "<CR>"] = function() AddServerUI.add_selected_to_tree() end
  keymaps[km.new or "n"] = function() AddServerUI.show_new_connection_form() end
  keymaps[km.delete or "d"] = function() AddServerUI.delete_selected() end
  keymaps[km.edit_connection or "e"] = function() AddServerUI.edit_selected() end
  keymaps[km.toggle_favorite or "f"] = function() AddServerUI.toggle_favorite_selected() end
  keymaps[km.toggle_favorite_alt or "*"] = function() AddServerUI.toggle_favorite_selected() end

  -- Create floating window
  current_float = UiFloat.create(lines, {
    title = " Server Connections ",
    title_pos = "center",
    footer = " ★ favorite  ⚡ auto-connect ",
    footer_pos = "center",
    border = "rounded",
    min_width = 48,
    min_height = 10,
    centered = true,
    default_keymaps = false,
    keymaps = keymaps,
  })

  -- Apply highlights after window creation
  if current_float and current_float:is_valid() then
    apply_highlights(current_float.bufnr, highlights)

    -- Position cursor on selected item
    if #connections_list > 0 then
      current_float:set_cursor(1 + selected_index, 0)
    end
  end
end

---Navigate the connection list
---@param direction number 1 for down, -1 for up
function AddServerUI.navigate(direction)
  if #connections_list == 0 then
    return
  end

  selected_index = selected_index + direction

  -- Wrap around
  if selected_index < 1 then
    selected_index = #connections_list
  elseif selected_index > #connections_list then
    selected_index = 1
  end

  -- Refresh the list display
  AddServerUI.show_connection_list()

  -- Position cursor on selected item
  if current_float and current_float:is_valid() then
    current_float:set_cursor(1 + selected_index, 0)
  end
end

---Add the selected connection to the tree
function AddServerUI.add_selected_to_tree()
  if #connections_list == 0 then
    vim.notify("No connections to add", vim.log.levels.WARN)
    return
  end

  local conn = connections_list[selected_index]
  if not conn then
    return
  end

  -- Check if already in tree
  if is_in_tree(conn.name) then
    vim.notify(string.format("'%s' is already in tree", conn.name), vim.log.levels.INFO)
    return
  end

  -- Add server to cache
  local server, err = Cache.add_server_from_connection(conn)

  if server then
    vim.notify(string.format("Added '%s' to tree", conn.name), vim.log.levels.INFO)

    -- Close the UI
    AddServerUI.close()

    -- Refresh tree
    local UiTree = require('ssns.ui.tree')
    UiTree.render()
  else
    vim.notify(string.format("Failed to add '%s': %s", conn.name, err or "Unknown error"), vim.log.levels.ERROR)
  end
end

---Delete the selected connection
function AddServerUI.delete_selected()
  if #connections_list == 0 then
    return
  end

  local conn = connections_list[selected_index]
  if not conn then
    return
  end

  -- Confirm deletion
  local confirm = vim.fn.confirm(
    string.format("Delete connection '%s'?", conn.name),
    "&Yes\n&No",
    2
  )

  if confirm ~= 1 then
    return
  end

  -- Remove from file
  if Connections.remove(conn.name) then
    vim.notify(string.format("Deleted '%s'", conn.name), vim.log.levels.INFO)

    -- Adjust selected index if needed
    if selected_index > #connections_list - 1 then
      selected_index = math.max(1, #connections_list - 1)
    end

    -- Refresh list
    AddServerUI.show_connection_list()
  end
end

---Edit the selected connection
function AddServerUI.edit_selected()
  if #connections_list == 0 then
    return
  end

  local conn = connections_list[selected_index]
  if not conn then
    return
  end

  AddServerUI.show_new_connection_form(conn)
end

---Toggle favorite status for the selected connection
function AddServerUI.toggle_favorite_selected()
  if #connections_list == 0 then
    return
  end

  local conn = connections_list[selected_index]
  if not conn then
    return
  end

  local success, new_state = Connections.toggle_favorite(conn.name)

  if success then
    local status = new_state and "added to" or "removed from"
    vim.notify(string.format("'%s' %s favorites", conn.name, status), vim.log.levels.INFO)

    -- Refresh list
    AddServerUI.show_connection_list()

    -- Restore cursor position
    if current_float and current_float:is_valid() then
      current_float:set_cursor(1 + selected_index, 0)
    end
  end
end

---Show the new connection form
---@param edit_connection table? Existing connection to edit
function AddServerUI.show_new_connection_form(edit_connection)
  -- Close any existing float first to prevent window stacking
  if current_float then
    pcall(function() current_float:close() end)
    current_float = nil
  end

  current_screen = "new"
  local is_edit = edit_connection ~= nil

  -- Form state - extract server_path from connection_string for editing
  local server_path = ""
  if edit_connection and edit_connection.connection_string then
    server_path = extract_server_path(edit_connection.connection_string)
  end

  local form_state = {
    name = edit_connection and edit_connection.name or "",
    server_path = server_path,
    db_type = edit_connection and edit_connection.type or "sqlserver",
    favorite = edit_connection and edit_connection.favorite or false,
    auto_connect = edit_connection and edit_connection.auto_connect or false,
  }

  AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
end

---Show form with current state (refreshes content while keeping keymaps functional)
---@param form_state table Current form values
---@param edit_connection table? Original connection being edited
function AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
  -- Close existing float and recreate to ensure keymaps are fresh
  if current_float then
    pcall(function() current_float:close() end)
    current_float = nil
  end

  current_screen = "new"
  local is_edit = edit_connection ~= nil

  -- Get type info
  local type_label, type_icon = get_type_info(form_state.db_type)
  local path_hint = PATH_HINTS[form_state.db_type] or ""

  -- Build form lines
  local lines = {}
  local highlights = {}

  -- Server Type section
  table.insert(lines, "")
  table.insert(lines, "  SERVER TYPE")
  table.insert(highlights, {1, 2, -1, "Title"})

  table.insert(lines, string.format("  %s %s", type_icon, type_label))
  table.insert(highlights, {2, 2, 5, "Function"})
  table.insert(highlights, {2, 5, -1, "String"})

  table.insert(lines, "  Press t to change")
  table.insert(highlights, {3, 8, 9, "Special"})
  table.insert(highlights, {3, 0, -1, "Comment"})

  table.insert(lines, "")

  -- Connection Name section
  table.insert(lines, "  CONNECTION NAME")
  table.insert(highlights, {5, 2, -1, "Title"})

  local name_display = form_state.name ~= "" and form_state.name or "(not set)"
  table.insert(lines, "  " .. name_display)
  if form_state.name ~= "" then
    table.insert(highlights, {6, 2, -1, "String"})
  else
    table.insert(highlights, {6, 2, -1, "Comment"})
  end

  table.insert(lines, "  Press n to set")
  table.insert(highlights, {7, 8, 9, "Special"})
  table.insert(highlights, {7, 0, -1, "Comment"})

  table.insert(lines, "")

  -- Server Path section
  table.insert(lines, "  SERVER PATH")
  table.insert(highlights, {9, 2, -1, "Title"})

  local path_display = form_state.server_path ~= "" and form_state.server_path or "(not set)"
  table.insert(lines, "  " .. path_display)
  if form_state.server_path ~= "" then
    table.insert(highlights, {10, 2, -1, "String"})
  else
    table.insert(highlights, {10, 2, -1, "Comment"})
  end

  table.insert(lines, "  Press p to set")
  table.insert(highlights, {11, 8, 9, "Special"})
  table.insert(highlights, {11, 0, -1, "Comment"})

  table.insert(lines, "  " .. path_hint)
  table.insert(highlights, {12, 0, -1, "DiagnosticHint"})

  table.insert(lines, "")

  -- Options section
  table.insert(lines, "  OPTIONS")
  table.insert(highlights, {14, 2, -1, "Title"})

  local fav_checkbox = form_state.favorite and "[x]" or "[ ]"
  local auto_checkbox = form_state.auto_connect and "[x]" or "[ ]"

  table.insert(lines, string.format("  %s ★ Favorite          Show in tree on startup", fav_checkbox))
  table.insert(highlights, {15, 2, 5, form_state.favorite and "DiagnosticOk" or "Comment"})
  table.insert(highlights, {15, 6, 7, "WarningMsg"})
  table.insert(highlights, {15, 26, -1, "Comment"})

  table.insert(lines, string.format("  %s ⚡ Auto-connect      Connect automatically", auto_checkbox))
  table.insert(highlights, {16, 2, 5, form_state.auto_connect and "DiagnosticOk" or "Comment"})
  table.insert(highlights, {16, 6, 8, "DiagnosticWarn"})
  table.insert(highlights, {16, 26, -1, "Comment"})

  table.insert(lines, "  Press f or a to toggle")
  table.insert(highlights, {17, 8, 9, "Special"})
  table.insert(highlights, {17, 13, 14, "Special"})
  table.insert(highlights, {17, 0, -1, "Comment"})

  table.insert(lines, "")

  -- Actions section
  table.insert(lines, "  ───────────────────────────────────────────")
  table.insert(highlights, {19, 0, -1, "Comment"})

  table.insert(lines, "")
  table.insert(lines, "  s   Save connection       T   Test connection")
  table.insert(lines, "  b   Back to list          q   Close")
  table.insert(lines, "")

  -- Highlight action keys
  table.insert(highlights, {21, 2, 3, "Special"})
  table.insert(highlights, {21, 28, 29, "Special"})
  table.insert(highlights, {22, 2, 3, "Special"})
  table.insert(highlights, {22, 28, 29, "Special"})

  local title = is_edit and " Edit Connection " or " New Connection "

  -- Get keymaps from config
  local km = KeymapManager.get_group("add_server")
  local common = KeymapManager.get_group("common")

  -- Build keymaps table dynamically
  local keymaps = {}
  keymaps[common.close or "q"] = function() AddServerUI.close() end
  keymaps[common.cancel or "<Esc>"] = function()
    if #connections_list > 0 then
      AddServerUI.show_connection_list()
    else
      AddServerUI.close()
    end
  end
  keymaps[km.back or "b"] = function()
    if #connections_list > 0 then
      AddServerUI.show_connection_list()
    else
      AddServerUI.close()
    end
  end
  keymaps[km.db_type or "t"] = function()
    AddServerUI.prompt_db_type(form_state, edit_connection)
  end
  keymaps[km.set_name or "n"] = function()
    AddServerUI.prompt_name(form_state, edit_connection)
  end
  keymaps[km.set_path or "p"] = function()
    AddServerUI.prompt_server_path(form_state, edit_connection)
  end
  keymaps[km.toggle_favorite or "f"] = function()
    form_state.favorite = not form_state.favorite
    AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
  end
  keymaps[km.toggle_auto_connect or "a"] = function()
    form_state.auto_connect = not form_state.auto_connect
    -- Auto-connect implies favorite
    if form_state.auto_connect then
      form_state.favorite = true
    end
    AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
  end
  keymaps[km.save or "s"] = function()
    AddServerUI.save_connection(form_state, edit_connection)
  end
  keymaps[km.test or "T"] = function()
    AddServerUI.test_connection(form_state)
  end

  -- Create fresh float with keymaps
  current_float = UiFloat.create(lines, {
    title = title,
    title_pos = "center",
    border = "rounded",
    min_width = 52,
    min_height = 20,
    centered = true,
    default_keymaps = false,
    keymaps = keymaps,
  })

  -- Apply highlights after window creation
  if current_float and current_float:is_valid() then
    apply_highlights(current_float.bufnr, highlights)
  end
end

---Prompt for database type selection
---@param form_state table Current form values
---@param edit_connection table? Original connection being edited
function AddServerUI.prompt_db_type(form_state, edit_connection)
  -- Build selection items
  local items = {}
  for _, t in ipairs(DB_TYPES) do
    table.insert(items, string.format("%s %s", t.icon, t.label))
  end

  vim.ui.select(items, {
    prompt = "Select Database Type:",
  }, function(choice, idx)
    if choice and idx then
      form_state.db_type = DB_TYPES[idx].id
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Prompt for connection name
---@param form_state table Current form values
---@param edit_connection table? Original connection being edited
function AddServerUI.prompt_name(form_state, edit_connection)
  vim.ui.input({
    prompt = "Connection Name: ",
    default = form_state.name,
  }, function(input)
    if input and input ~= "" then
      form_state.name = input
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Prompt for server path
---@param form_state table Current form values
---@param edit_connection table? Original connection being edited
function AddServerUI.prompt_server_path(form_state, edit_connection)
  local hint = PATH_HINTS[form_state.db_type] or ""
  local prompt = "Server Path"
  if hint ~= "" then
    prompt = prompt .. " (e.g. " .. hint:match("^([^%s]+)") .. ")"
  end
  prompt = prompt .. ": "

  vim.ui.input({
    prompt = prompt,
    default = form_state.server_path,
  }, function(input)
    if input then
      form_state.server_path = input
      AddServerUI.show_new_connection_form_with_state(form_state, edit_connection)
    end
  end)
end

---Save the connection
---@param form_state table Current form values
---@param edit_connection table? Original connection being edited
function AddServerUI.save_connection(form_state, edit_connection)
  -- Validate
  if form_state.name == "" then
    vim.notify("Connection name is required", vim.log.levels.ERROR)
    return
  end

  if form_state.server_path == "" then
    vim.notify("Server path is required", vim.log.levels.ERROR)
    return
  end

  -- Build full connection string from type + path
  local connection_string = build_connection_string(form_state.db_type, form_state.server_path)

  local connection = {
    name = form_state.name,
    type = form_state.db_type,
    connection_string = connection_string,
    favorite = form_state.favorite,
    auto_connect = form_state.auto_connect,
  }

  local success
  if edit_connection then
    -- Update existing
    success = Connections.update(edit_connection.name, connection)
    if success then
      vim.notify(string.format("Updated '%s'", connection.name), vim.log.levels.INFO)
    end
  else
    -- Add new
    success = Connections.add(connection)
    if success then
      vim.notify(string.format("Saved '%s'", connection.name), vim.log.levels.INFO)
    end
  end

  if success then
    -- If favorite is set, automatically add to tree (if not already there)
    if connection.favorite or connection.auto_connect then
      if not Cache.server_exists(connection.name) then
        local server, err = Cache.add_server_from_connection(connection)
        if server then
          -- If auto_connect, also connect the server
          if connection.auto_connect then
            server:connect()
          end
          -- Refresh tree to show the new server
          local UiTree = require('ssns.ui.tree')
          UiTree.render()
        end
      end
    end

    -- Reload list and show it
    connections_list = Connections.load()
    AddServerUI.show_connection_list()
  end
end

---Test the connection
---@param form_state table Current form values
function AddServerUI.test_connection(form_state)
  if form_state.server_path == "" then
    vim.notify("Server path is required", vim.log.levels.ERROR)
    return
  end

  vim.notify("Testing connection...", vim.log.levels.INFO)

  -- Build full connection string
  local connection_string = build_connection_string(form_state.db_type, form_state.server_path)

  -- Create a temporary server to test the connection
  local Factory = require('ssns.factory')
  local test_name = "_test_" .. os.time()

  local server, err = Factory.create_server(test_name, connection_string)

  if not server then
    vim.notify(string.format("Connection failed: %s", err or "Unknown error"), vim.log.levels.ERROR)
    return
  end

  -- Try to connect
  local connect_ok, connect_err = pcall(function()
    return server:connect()
  end)

  if connect_ok and server:is_connected() then
    vim.notify("Connection successful!", vim.log.levels.INFO)
    -- Disconnect the test server
    pcall(function() server:disconnect() end)
  else
    vim.notify(string.format("Connection failed: %s", connect_err or "Could not connect"), vim.log.levels.ERROR)
  end
end

return AddServerUI
