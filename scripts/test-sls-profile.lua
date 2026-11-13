#!/usr/bin/env luajit
-- Unit tests for plugin/backend/sls_profile.lua: it must resolve the SLSsteam
-- profile of the RUNNING Steam client, not LuaTools' own environment.
-- Run from the repo root:  luajit scripts/test-sls-profile.lua
package.path = "plugin/backend/?.lua;" .. package.path

local pass, fail = 0, 0
local function check(name, cond)
  if cond then
    pass = pass + 1
  else
    fail = fail + 1
    io.write("FAIL " .. name .. "\n")
  end
end

local profile = dofile("plugin/backend/sls_profile.lua")

local function envof(values)
  return function(key) return values[key] end
end

-- /proc/<pid>/environ fixture: NUL-separated KEY=VALUE entries.
local function blob(values)
  local parts = {}
  for key, value in pairs(values) do parts[#parts + 1] = key .. "=" .. value end
  return table.concat(parts, "\0") .. "\0"
end

-- ── explicit override ────────────────────────────────────────────────────────
do
  local scanned = false
  local got = profile.config_home({
    env = envof({ HOME = "/home/u", SLSSTEAM_CONFIG_HOME = "/opt/sls-profile" }),
    pids = function() scanned = true; return {} end,
  })
  check("explicit SLSSTEAM_CONFIG_HOME wins", got == "/opt/sls-profile")
  check("explicit override skips /proc", scanned == false)
end

-- ── the steam client's XDG_CONFIG_HOME outranks wrapper processes ────────────
do
  local environ = {
    ["/proc/10/environ"] = blob({ HOME = "/home/u", XDG_CONFIG_HOME = "/home/u/.config" }),
    ["/proc/11/environ"] = blob({
      HOME = "/home/u",
      XDG_CONFIG_HOME = "/home/u/.config/SLSsteam-careca-x64",
    }),
  }
  local comms = { ["10"] = "bash", ["11"] = "steam" }
  local got = profile.config_home({
    env = envof({ HOME = "/home/u" }),
    pids = function() return { "10", "11" } end,
    read = function(path) return environ[path] end,
    comm = function(pid) return comms[pid] end,
  })
  check("steam profile wins over a wrapper process",
    got == "/home/u/.config/SLSsteam-careca-x64")
end

-- ── steamwebhelper shares the client environment ─────────────────────────────
do
  local got = profile.config_home({
    env = envof({ HOME = "/home/u" }),
    pids = function() return { "20" } end,
    read = function()
      return blob({ HOME = "/home/u", XDG_CONFIG_HOME = "/home/u/.config/deck-sls" })
    end,
    comm = function() return "steamwebhelper" end,
  })
  check("steamwebhelper counts as the client", got == "/home/u/.config/deck-sls")
end

-- ── a default-layout client must not fall through to a stale wrapper ─────────
do
  local environ = {
    ["/proc/30/environ"] = blob({
      HOME = "/home/u",
      XDG_CONFIG_HOME = "/home/u/.config/old-experiment",
    }),
    ["/proc/31/environ"] = blob({ HOME = "/home/u" }),
  }
  local comms = { ["30"] = "bash", ["31"] = "steam" }
  local got = profile.config_home({
    env = envof({ HOME = "/home/u" }),
    pids = function() return { "30", "31" } end,
    read = function(path) return environ[path] end,
    comm = function(pid) return comms[pid] end,
  })
  check("steam without XDG_CONFIG_HOME means ~/.config", got == "/home/u/.config")
end

-- ── another user's injected Steam session is ignored ─────────────────────────
do
  local got = profile.config_home({
    env = envof({ HOME = "/home/u" }),
    pids = function() return { "40" } end,
    read = function()
      return blob({ HOME = "/home/other", XDG_CONFIG_HOME = "/home/other/.config" })
    end,
    comm = function() return "steam" end,
  })
  check("other user's steam is ignored", got == "/home/u/.config")
end

-- ── same-HOME launcher without a steam comm is still honoured ────────────────
do
  local got = profile.config_home({
    env = envof({ HOME = "/home/u" }),
    pids = function() return { "50" } end,
    read = function()
      return blob({ HOME = "/home/u", XDG_CONFIG_HOME = "/home/u/.config/launcher" })
    end,
    comm = function() return "python3" end,
  })
  check("same-HOME launcher env is a fallback", got == "/home/u/.config/launcher")

  local got2 = profile.config_home({
    env = envof({ HOME = "/home/u", XDG_CONFIG_HOME = "/home/u/own-xdg" }),
    pids = function() return { "51" } end,
    read = function()
      return blob({ HOME = "/home/other", XDG_CONFIG_HOME = "/home/other/.config" })
    end,
    comm = function() return "steam" end,
  })
  check("own XDG_CONFIG_HOME is the last resort", got2 == "/home/u/own-xdg")
end

-- ── HOME fallback and missing HOME ──────────────────────────────────────────
do
  local got = profile.config_home({
    env = envof({ HOME = "/home/u" }),
    pids = function() return {} end,
  })
  check("no process -> $HOME/.config", got == "/home/u/.config")

  local none = profile.config_home({
    env = envof({}),
    pids = function() return {} end,
  })
  check("no HOME -> nil", none == nil)
end

-- ── environ parsing edge cases ──────────────────────────────────────────────
do
  local got = profile.config_home({
    env = envof({ HOME = "/home/u" }),
    pids = function() return { "60", "61" } end,
    read = function(path)
      if path == "/proc/60/environ" then
        -- missing HOME must not match an empty HOME
        return blob({ XDG_CONFIG_HOME = "/nope" })
      end
      return blob({ HOME = "/home/u", XDG_CONFIG_HOME = "/home/u/.config/right" })
    end,
    comm = function() return "steam" end,
  })
  check("entries without HOME are skipped", got == "/home/u/.config/right")

  local with_junk = profile.config_home({
    env = envof({ HOME = "/home/u" }),
    pids = function() return { "62" } end,
    read = function()
      return "LANG=C\0HOME=/home/u\0XDG_CONFIG_HOME=/home/u/.config/x\0"
    end,
    comm = function() return "steam" end,
  })
  check("NUL-separated environ is parsed", with_junk == "/home/u/.config/x")
end

-- ── root() composes the SLSsteam directory ──────────────────────────────────
do
  check("root appends SLSsteam",
    profile.root({ env = envof({ HOME = "/home/u" }), pids = function() return {} end })
      == "/home/u/.config/SLSsteam")
  check("root nil without HOME",
    profile.root({ env = envof({}), pids = function() return {} end }) == nil)
end

io.write(string.format("sls_profile: %d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
