-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.


--[[
things to optimize: only do label updates on prompt
handling multiple rooms ideas:
 * draw a far-away label saying "also in area at '%s': blah, blah"
   -> can't work yet, because calculating a possible location would be a pain
 * put names in every room
   -> looks ugly in this combination: http://img7.imagebanana.com/img/oshg8lw5/Selection_037.png
 * label by single letters for groups, with only the rightmost room having the full list of names with letter) prepended
]]

local sys, signals = svo.sys, svo.signals
local conf, sk = svo.conf, svo.sk

-- area = {labels}
local labels = {}

-- default to numerals when we run out
-- while defining this as a function would be nicer, it's easier for most people to mod if it's in this format
local multiplegroups = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'}

conf.peopletracker = type(conf.peopletracker) == 'nil' and true or conf.peopletracker
svo.config.setoption('peopletracker', {
  type = 'boolean',
  onenabled = function ()
    if not deleteMapLabel or not createMapLabel then
      svo.echof("I'm sorry, but your Mudlet is too old and can't make labels on the map yet - update it!")
      conf.peopletracker = false
      raiseEvent("svo config changed", 'peopletracker')
      return
    end

    svo.echof("People tracker <0,250,0>enabled%s.", svo.getDefaultColor())
  end,
  ondisabled = function () sys.clean_old_labels() svo.echof("People tracker <250,0,0>disabled%s.", svo.getDefaultColor()) end,
  installstart = function () conf.peopletracker = true end,
})

conf.clearlabels = type(conf.clearlabels) == 'nil' and true or conf.clearlabels
svo.config.setoption('clearlabels', {
  type = 'boolean',
  onenabled = function () signals.newarea:connect(sys.clear_labels) svo.echof("<0,250,0>Will%s automatically clear map labels that are surrounded by ().", svo.getDefaultColor()) end,
  ondisabled = function ()signals.newarea:disconnect(sys.clear_labels) svo.echof("<250,0,0>Won't%s automatically clear map labels that are surrounded by ().", svo.getDefaultColor()) end,
  installstart = function () conf.clearlabels = true end,
})

conf.labelsfont = type(conf.labelsfont) == 'nil' and 10 or conf.labelsfont
svo.config.setoption('labelsfont', {
  type = 'number',
  onset = function () sys.update_people_labels() svo.echof("Labels set to draw at %dpt.", conf.labelsfont) end,
  installstart = function () conf.labelsfont = 10 end,
})

conf.labelcolor = conf.labelcolor or 'white'
conf.maxdupes = conf.maxdupes or 20
svo.config.setoption('labelcolor', {
  type = 'string',
  vconfig2string = true,
  check = function (what)
    if color_table[what] then return true end
  end,
  onshow = function (defaultcolour)
    fg('gold')
    echoLink("ppl: ", "", "svo People Tracker", true)
    fg(defaultcolour) echo("People tracker ")
    fg('a_cyan') echoLink((conf.peopletracker and 'on' or 'off'), "svo.config.set('peopletracker', "..(conf.peopletracker and 'false' or 'true')..", true)", "Click to "..(conf.peopletracker and 'disable' or 'enable').." people tracking on the map", true)
    fg(defaultcolour) echo("; using")
    fg(conf.labelcolor or 'a_cyan') echoLink(" "..(conf.labelcolor or '?'), "printCmdLine'vconfig labelcolor '", "Click to change the color", true)
    fg(defaultcolour) echo(" map labels (")
    fg('a_cyan') echoLink("view all", "showColors()", "Click to view possible color names that you can use for customizing the label colors", true)
    fg(defaultcolour)
    echo("); font size is ")
    fg('a_cyan') echoLink(tostring(conf.labelsfont), "printCmdLine'vconfig labelsfont '", "Click to set the font size for peopletracker labels", true)
    echo(".\n")
  end,
  onset = function ()
    local r,g,b = unpack(color_table[conf.labelcolor])
    sys.update_people_labels()
    svo.echof("Okay, will color the map labels in <%s,%s,%s>%s%s now.", r,g,b, conf.labelcolor, svo.getDefaultColor())
  end,
  installstart = function ()
    conf.labelcolor = 'blue'
  end
})

-- check for old Mudlet versions
if not deleteMapLabel or not createMapLabel then
  svo.echof("I'm sorry, but your Mudlet is too old and can't make labels on the map yet - update it!")
  return
end

sys.clean_old_labels = function()
  for areanum, arealabels in pairs(labels) do
    for _, label in pairs(arealabels) do
      deleteMapLabel(areanum, label)
    end
  end
  labels = {}
end
signals.sysexitevent:connect(sys.clean_old_labels)

sys.clear_labels = function()
  if not mmp then return end
  local function clearlabels(areaid)
    local t = getMapLabels(areaid)
    if type(t) ~= 'table' then return end

    local starts, ends = string.starts, string.ends
    for labelid, text in pairs(t) do
      if starts(text, '(') and ends(text, ')') then
        deleteMapLabel(areaid, labelid)
      end
    end
  end

  for areaid in pairs(mmp.areatabler or {}) do
    clearlabels(areaid)
  end
end

if conf.clearlabels then
  signals.newarea:connect(sys.clear_labels)
end

sys.update_people_labels = function ()
  -- drawwatch = drawwatch or createStopWatch()
  -- startStopWatch(drawwatch)

  local s,m = pcall(function()
    if not mmp then return end
    -- build a 'location = people' reverse map
    local r = {}
    -- keeps track at which index of multiplegroups are we at
    local multiplescount = 1

    local fr,fg,fb = unpack(color_table[conf.labelcolor or 'white'])
    local br,bg,bb = unpack(color_table.black)

    for k,v in pairs(mmp.pdb) do
      if mmp.pdb_lastupdate[k] then
        r[v] = r[v] or {}; r[v][#r[v]+1] = k
      end
    end

    sys.clean_old_labels()
    if not conf.peopletracker or not mmp.pdb_lastupdate or not mmp.roomexists(mmp.currentroom) then return end

    local getRoomArea, createMapLabel, getRoomCoordinates, concat, sort = getRoomArea, createMapLabel, getRoomCoordinates, table.concat, table.sort

    -- if we have a unique location, draw fancy labels in all rooms on 60% opacity
    for room, persons in pairs(r) do
      sort(persons)
      local ids = mmp.getnums(room, true)

      -- multiples? special case then. Current method implemented is #3
      if ids and #ids >1 and #ids <= conf.maxdupes then
        -- make a table of roomid = {x,y,z}
        -- in a separate variable, track the right-most room ID and x coordinate per-Z level
        local coords, rightmost = {}, {}
        for _, exactroomid in pairs(ids) do
          coords[exactroomid] = {getRoomCoordinates(exactroomid)}
          coords[exactroomid][4] = getRoomArea(exactroomid)

          if not rightmost[coords[exactroomid][3]] or
            coords[exactroomid][1] >= rightmost[coords[exactroomid][3]][1] then -- >= so rightmostroom is set at least once

            rightmost[coords[exactroomid][3]] =
              {coords[exactroomid][1], exactroomid} -- we don't account for the Y coordinate if the X's are the same atm, though
          end
        end

        -- now, draw!
        for roomid, l in pairs(coords) do
          local area = l[4]
          labels[area] = labels[area] or {}

          if rightmost[l[3]] and roomid == rightmost[l[3]][2] then
            -- doesn't account for multiplescount overflowing atm
            labels[area][#labels[area]+1] = createMapLabel(area, '('..multiplegroups[multiplescount].." "..concat(persons, ", ")..')', l[1],l[2],l[3], fr, fg, fb, br, bg, bb, 0,conf.labelsfont)
          else
            labels[area][#labels[area]+1] = createMapLabel(area, '('..multiplegroups[multiplescount]..')', l[1],l[2],l[3], fr, fg, fb, br, bg, bb, 0,conf.labelsfont)
          end
        end
        multiplescount = multiplescount +1

      elseif ids and #ids == 1 then
        local x,y,z = getRoomCoordinates(ids[1])
        local area = getRoomArea(ids[1])

        if area then -- somehow area can still be returned as nil
          labels[area] = labels[area] or {}

          labels[area][#labels[area]+1] = createMapLabel(area, '('..concat(persons, ", ")..')', x,y,z, fr, fg, fb, br, bg, bb, 0,conf.labelsfont)
        end
      end
    end
  end)

  if not s then
    echoLink("(e!)", string.format("echo([=[The problem was: %q]=])", m), 'Oy - there was a problem with the peopletracker. Click on this link and submit a bug report with what it says.')
  end

  -- svo.echof("update took %s", stopStopWatch(drawwatch))
end

signals["mmapper updated pdb"]:connect(function()
  if isPrompt() then
    sys.update_people_labels()
  else
    sk.onprompt_beforeaction_add('update_labels', sys.update_people_labels)
  end
end)

signals.quit:connect(sys.clean_old_labels)
