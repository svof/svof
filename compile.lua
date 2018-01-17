#!/usr/bin/lua

-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local compile = {}

function compile.dowork(addons)
  local f,msg = io.open("bin/svo", "w+")
  if not f then print(msg) return end

  -- load dependencies in
  for _, luamodule in ipairs({
    {"notify.signal", "bin/notify/signal.lua"},
    {"notify.double_queue", "bin/notify/double_queue.lua"},

    {"pl.config", "bin/pl/config.lua"},
    {"pl.dir", "bin/pl/dir.lua"},
    {"pl.pretty", "bin/pl/pretty.lua"},
    {"pl.stringx", "bin/pl/stringx.lua"},
    {"pl.utils", "bin/pl/utils.lua"},
    {"pl.lexer", "bin/pl/lexer.lua"},
    {"pl.path", "bin/pl/path.lua"},
    {"pl.class", "bin/pl/class.lua"},
    {"pl.tablex", "bin/pl/tablex.lua"},
    {"pl.List", "bin/pl/List.lua"},
    {"pl.Map", "bin/pl/Map.lua"},
    {"pl.OrderedMap", "bin/pl/OrderedMap.lua"}
  }) do
  	io.input(luamodule[2])
  	local contents = io.read("*a")
    f:write(([[package.preload['%s'] = (function (...)
      ]]):format(luamodule[1]))
  	f:write(contents)
    f:write([[
     end)]])
  end

  -- load svo files in
  for _, svofile in ipairs({"bin/start.lua", "bin/svo.setup.lua", "bin/svo.misc.lua", "bin/svo.empty.lua", "bin/svo.dict.lua", "bin/svo.skeleton.lua", "bin/svo.controllers.lua", "bin/svo.actionsystem.lua", "bin/svo.pipes.lua", "bin/svo.rift.lua", "bin/svo.valid.diag.lua", "bin/svo.valid.simple.lua", "bin/svo.valid.main.lua", "bin/svo.config.lua", "bin/svo.install.lua", "bin/svo.aliases.lua", "bin/svo.defs.lua", "bin/svo.prio.lua", "bin/svo.sp.lua", "bin/svo.funnies.lua", "bin/svo.dor.lua", "bin/svo.customprompt.lua", "bin/svo.serverside.lua", "bin/svo.runeidentifier.lua", "bin/svo.logger.lua", "bin/svo.peopletracker.lua", "bin/svo.fishdist.lua"}) do
    io.input(svofile)
    local contents = io.read("*a")
    f:write(contents)
  end

  for _,addon in pairs(addons) do
    io.input("bin/svo."..addon..".lua")
    local contents = io.read("*a")
    f:write(contents)
  end

  io.input("bin/end.lua")
  local contents = io.read("*a")
  f:write(contents)

  f:flush()
  f:close()
end

return compile
