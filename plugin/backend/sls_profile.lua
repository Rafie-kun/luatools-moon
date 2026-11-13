-- sls_profile: find the SLSsteam profile the RUNNING Steam client uses.
--
-- LuaTools/Lumen runs in its own process (a systemd/user service or a manually
-- started binary), so it does NOT inherit the environment Steam was launched
-- with. A 64-bit launcher such as SLSsteam-Careca-x64 starts Steam with
-- XDG_CONFIG_HOME pointing at a private profile
-- (e.g. ~/.config/SLSsteam-careca-x64), because its library reads
-- $XDG_CONFIG_HOME/SLSsteam. Writing settings, appinfo and manifests to the
-- default ~/.config/SLSsteam then leaves every change invisible to the injected
-- client: toggles appear to work but never apply, and provisioned appinfo for a
-- newly added game is never found.
--
-- Resolution order:
--   1. SLSSTEAM_CONFIG_HOME (explicit override, same layout as XDG_CONFIG_HOME)
--   2. XDG_CONFIG_HOME of the running `steam` process (same HOME only)
--   3. XDG_CONFIG_HOME of another same-HOME process (launcher wrappers)
--   4. our own XDG_CONFIG_HOME
--   5. $HOME/.config
--
-- Returns the directory that CONTAINS the `SLSsteam` directory, matching
-- XDG_CONFIG_HOME semantics. A Steam process of another user is ignored.

local M = {}

-- Main client process names. The 64-bit runtime starts the client as
-- `steamrt64/steam` but keeps comm `steam`; helpers are `steamwebhelper`.
local STEAM_COMMS = { steam = true, steamwebhelper = true }

local function default_read(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local data = file:read("*a")
  file:close()
  return data
end

local function default_comm(pid)
  local file = io.open("/proc/" .. tostring(pid) .. "/comm", "rb")
  if not file then return nil end
  local name = file:read("*l")
  file:close()
  return name
end

local function default_pids()
  local pids = {}
  local pipe = io.popen("ls -1 /proc 2>/dev/null")
  if not pipe then return pids end
  for entry in pipe:lines() do
    if entry:match("^%d+$") then pids[#pids + 1] = entry end
  end
  pipe:close()
  return pids
end

-- Parse a NUL-separated environ blob. `string.gsub("%z", "\n")` keeps the
-- pattern engine away from embedded NULs (which older LuaJIT builds treat as
-- the end of the subject).
local function environ_value(blob, key)
  if type(blob) ~= "string" then return nil end
  local text = blob:gsub("%z", "\n")
  for item in text:gmatch("[^\n]+") do
    if item:sub(1, #key + 1) == key .. "=" then
      return item:sub(#key + 2)
    end
  end
  return nil
end

-- config_home(opts) -> string|nil
-- opts (all optional, for tests): pids(), read(path), comm(pid), env(name), home
function M.config_home(opts)
  opts = opts or {}
  local env = opts.env or os.getenv
  local read = opts.read or default_read
  local comm = opts.comm or default_comm
  local pids = opts.pids or default_pids
  local home = opts.home or env("HOME") or ""

  local explicit = env("SLSSTEAM_CONFIG_HOME")
  if explicit and explicit ~= "" then return explicit end

  if home ~= "" then
    local fallback
    local ok, list = pcall(pids)
    if ok and type(list) == "table" then
      for _, pid in ipairs(list) do
        local blob = read("/proc/" .. tostring(pid) .. "/environ")
        if blob then
          local proc_home = environ_value(blob, "HOME")
          if proc_home == home then
            local xdg = environ_value(blob, "XDG_CONFIG_HOME")
            local okc, name = pcall(comm, pid)
            if not okc then name = nil end
            local is_steam = name ~= nil and STEAM_COMMS[name] == true
            if is_steam then
              if xdg and xdg ~= "" then return xdg end
              -- The running client has no private profile: this is the default
              -- ~/.config layout, so stop here rather than guessing again.
              return home .. "/.config"
            end
            if fallback == nil and xdg and xdg ~= "" then fallback = xdg end
          end
        end
      end
    end
    if fallback then return fallback end
  end

  local own = env("XDG_CONFIG_HOME")
  if own and own ~= "" then return own end
  if home == "" then return nil end
  return home .. "/.config"
end

-- root(opts) -> "<config home>/SLSsteam" | nil
function M.root(opts)
  local base = M.config_home(opts)
  if not base then return nil end
  return base .. "/SLSsteam"
end

return M
