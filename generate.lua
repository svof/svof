#!/usr/bin/lua

-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local preprocess = require "luapp" . preprocess
require "luarocks.loader"
local lapp    = require 'pl.lapp'
local lfs     = require 'lfs'
local seq     = require 'pl.seq'
local pretty  = require 'pl.pretty'
local stringx = require 'pl.stringx'
local tablex  = require 'pl.tablex'
local file    = require 'file'
local compile = require 'compile'

local cwd = lfs.currentdir()

local args = lapp [[
-d,--debug  Build with debugging information enabled
-r,--release (default false)  Build all systems
-o,--own  Build a Svof for yourself
-n,--newlines  Remove excess newlines on Windows systems
 <name...> (default none )  Class to build a system for
]]

--[[
  Building new updates is done by creating a new release on GitHub. The rest is done by travis.
]]

local builder         = "lua" -- or "luajit"
local doall           = args.release ~= "false" -- make doall a bool
local name            = args.name
local release         = not args.debug
local own             = args.own
local version         = args.release
local defaultaddons   = {
  "dragonlimbcounter", "elistsorter", "enchanter", "fishdist", "inker", "logger", "offering", "peopletracker", "reboundingsileristracker", "refiller", "runeidentifier", "namedb",
  priest = {"priestreport", "priesthealing", "priestlimbcounter"},
  magi = {"burncounter", "magilimbcounter", "stormhammertarget"},
  monk = {"mindnet", "monklimbcounter"}, blademaster = "mindnet",
  infernal = {"knightlimbcounter"},
  runewarden = {"knightlimbcounter"},
  paladin = {"knightlimbcounter"},
  sentinel = {"metalimbcounter"},
  sylvan = {"metalimbcounter"},
  druid = {"metalimbcounter"},
}


if doall then
  print("Releasing? I hope you updated the version number!")
end

io.input(cwd.."/classlist.lua")
local s = io.read("*all")

-- load file into our sandbox; credit to http://lua-users.org/wiki/SandBoxes
local i = {}
-- run code under environment
local function run(untrusted_code)
  local untrusted_function, message = loadstring(untrusted_code)
  if not untrusted_function then return nil, message end
  setfenv(untrusted_function, i)
  return pcall(untrusted_function)
end

assert(run (s))

local function oneconcat(tbl)
  assert(type(tbl) == "table", "oneconcat wants a table as an argument.")
  local result = {}
  for i,_ in pairs(tbl) do
    result[#result+1] = i
  end

  return table.concat(result, ", ")
end
function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '') --trim left spaces
  s = string.gsub(s, '%s+$', '') --trim right spaces
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

local missing_data = {}
local function dowork(systemfor, release, own)
  systemfor = stringx.title(systemfor)

  local tbl = {}
  tbl.version = version
  tbl.ipairs = ipairs
  tbl.string = string
  tbl.pairs = pairs
  tbl.table = table
  tbl.type = type
  tbl.tostring = tostring
  tbl.require = require
  tbl.package = package
  tbl.print = print
  tbl.pcall = pcall
  tbl.skills = {}
  tbl.class = systemfor
  tbl.io = io

  if not tbl.class then
    missing_data[#missing_data+1] = tbl.name.. " is missing a class!"
    print(tbl.name.. " is missing a class!")
    tbl.class = "noclass"
  end

  if type(tbl.class) == "string" then
    tbl.class = tbl.class:lower()
  else
    for _, class in pairs(tbl.class) do
      tbl.class[class] = class:lower()
    end
  end

  tbl.sys = "svo"
  tbl.url = {}
  tbl.addons = {}

  -- add default addons
  for k, addon in pairs(defaultaddons) do
    if type(k) == 'number' or k == tbl.class then
      if type(addon) == "string" and not tablex.find(tbl.addons, addon) then
      tbl.addons[#tbl.addons+1] = addon
      elseif type(addon) == "table" then
        for _, addn in pairs(addon) do
          if not tablex.find(tbl.addons, addn) then
            tbl.addons[#tbl.addons+1] = addn
          end
        end
      end
    end
  end

  -- setup tbl.skills of the person as key-true table
  if type(tbl.class) == "string" then
    for _, skillset in ipairs(i.skills[tbl.class:lower()]) do
      tbl.skills[skillset] = true
    end
  else
    for _, class in ipairs(tbl.class) do
      for _, skillset in ipairs(i.skills[class:lower()]) do
        tbl.skills[skillset] = true
      end
    end
  end

  print(string.format("Doing system for %s, skills are: %s", systemfor, oneconcat(tbl.skills)))

  if not release then
    tbl.DEBUG_actions = true
    tbl.DEBUG_lifevision = true
    tbl.DEBUG = true
    tbl.DEBUG_diag = true
    tbl.DEBUG_prio = true
    print"Building debug..."
  else
    tbl.DEBUG_actions = false
    tbl.DEBUG_lifevision = false
    tbl.DEBUG = false
    tbl.DEBUG_diag = false
    tbl.DEBUG_prio = false
  end

  local files = {
    "svo.setup", "svo.misc", "svo.empty", "svo.dict", "svo.skeleton", "svo.controllers", "svo.actionsystem", "svo.pipes", "svo.rift", "svo.valid.diag", "svo.valid.simple", "svo.valid.main", "svo.config", "svo.install", "svo.aliases", "svo.defs", "svo.prio", "svo.sp", "svo.funnies", "svo.dor", "svo.customprompt", "svo.serverside"
  }

  if next(tbl.addons) then
    for _, addon in pairs(tbl.addons) do
      if type(addon) == "string" and not tablex.find(files, "svo."..addon) then
        files[#files+1] = "svo."..addon
      end
    end
    print(string.format("Added %s addon%s to the system...", table.concat(tbl.addons, ", "), #tbl.addons ~= 1 and "s" or ""))
  end

  -- does the preprocessing stages and outputs into the bin/ folder
  for _,j in ipairs(files) do
    local result, message = preprocess({input = {"raw-".. j ..".lua"}, output = {"bin/".. j ..".lua"}, lookup = tbl})
    if not result then print("Failed on "..j.."; "..message) os.exit(1) end
  end

  tbl.files = files

  result, message = preprocess({input = {"raw-end.lua"}, output = {"bin/end.lua"}, lookup = tbl})
  if not result then print(message) end
  -- end of the preprocessing stages

  -- clean old
  os.remove(cwd.."/bin/svo.lua")
  os.remove(cwd.."/bin/svo")

  -- compile new svo
  compile.dowork(tbl.addons)
  ret, message = loadfile(cwd.."/bin/svo") -- do a compile of the concatinated
                                           -- svo to check the syntax
  if not ret then
    print(message)
    os.exit(1)
  end
  
  if args.newlines then
    print("Removing excess newlines.")
    local f = io.open(cwd.."/bin/svo", "r+")
    local s = f:read("*all")
    f:close()
    f = io.open(cwd.."/bin/svo", "w+")
    local i
    s, i = string.gsub(s, "\r\n", "\n")
    print(i.." newlines replaced.")
    f:write(s)
    f:close()
  end
  
  -- clear existing addons
  local svo_template = cwd.."/svo template"
  for item in lfs.dir(svo_template) do
    local xmlname = item:match(".+%.xml$")
    if xmlname and xmlname ~= "svo (install the zip, not me).xml" then os.remove(svo_template.."/"..item) end
  end

  -- copy the new svo over to the template folder
  file.copy(cwd.."/bin/svo", cwd.."/svo template/svo")

  -- if building for yourself, also move it to the own svo folder, so it can be used
  if own then
    file.copy(cwd.."/bin/svo", cwd.."/own svo/svo")
  end

  -- update config.lua
  local f = io.open(cwd.."/svo template/config.lua", "w+")
  f:write(string.format([[mpackage = "%s svo"]], systemfor))
  f:flush()
  f:close()

  -- copy new addons xml files in
  for creator, addon in pairs(tbl.addons) do
    file.copy(cwd.."/svo ("..addon..").xml", cwd.."/svo template/svo ("..addon..").xml")
  end

  -- copy main system in
  file.copy(cwd.."/svo (install the zip, not me).xml", cwd.."/svo template/svo (install the zip, not me).xml")

  print("Making a package...")
  local cmd = [[7z a -tzip "]]..systemfor..[[ svo" "]]..cwd..[[/svo template/*" > NUL:]]
  os.execute(cmd)

  -- send away to output folder
  file.move(cwd.."/"..systemfor.." svo.zip",  cwd.."/output/"..systemfor..".Svof.v"..version..".zip")
  print("All done! How good is that!")
end


if doall then
  for class, _ in pairs(i.skills) do
    local s,m = pcall(dowork, class, release, own)
    if not s then print(m) return end
  end
  print("Hey, don't forget to upload docs! Post on website, forums, and in-game news section as well!")
else
  for name in seq.map(stringx.title, name) do
    local s,m = pcall(dowork, name, release, own)
    if not s then print(m) end
  end
end

if #missing_data > 0 then
  print(pretty.write(missing_data))
end
