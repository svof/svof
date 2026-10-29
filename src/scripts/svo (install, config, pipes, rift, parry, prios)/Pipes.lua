-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo = svo or {}; svo.loader = svo.loader or {}
svo.loader.pipes = function()

svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/pipes")

svo.me.pipes = svo.me.pipes or {}

local pipes, me = svo.pipes, svo.me

pipes.valerian = pipes.valerian or
  {lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = 'valerian', filledwith2 = 'valerian', maxpuffs = 10, maxpuffs2 = 10}
me.pipes.valerian = pipes.valerian

pipes.elm = pipes.elm or
{lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = 'elm', filledwith2 = 'elm', maxpuffs = 10, maxpuffs2 = 10}
me.pipes.elm = pipes.elm

pipes.skullcap = pipes.skullcap or
{lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = 'skullcap', filledwith2 = 'skullcap', maxpuffs = 10, maxpuffs2 = 10}
me.pipes.skullcap = pipes.skullcap

pipes.pnames = {'valerian','elm','skullcap'}

pipes.empties = {}

-- which of svof's pipes holds contents, as the game names them: the herb,
-- or the mineral that cures the same, or nil
local function pipe_holding(contents)
  contents = contents:lower()
  if contents:find("skullcap", 1, true) or contents:find("malachite", 1, true) then return 'skullcap' end
  if contents:find("valerian", 1, true) or contents:find("realgar", 1, true) then return 'valerian' end
  if contents:find("elm", 1, true) or contents:find("cinnabar", 1, true) then return 'elm' end
end

-- A pipe went out. The game says what it holds:
--   Your pipe, containing a skullcap flower, has gone cold and dark.
-- so that herb's pipes are marked out, both when there are two, as the line
-- doesn't say which. svof used to guess the pipe from the order it last lit
-- them in, and marked the wrong one out. LIGHT PIPES relights it, and the
-- game's answer marks every pipe lit (svo.valid.litallpipes).
function svo.pipeout()
  local contents = type(line) == 'string' and line:match("containing (.-), has gone cold and dark")
  local herb = contents and pipe_holding(contents)
  for _, name in ipairs(pipes.pnames) do
    -- a line svof can't read could be any of them
    if not herb or name == herb then
      local pipe = pipes[name]
      if not pipe.arty then pipe.lit = false end
      if not pipe.arty2 then pipe.lit2 = false end
    end
  end
end

-- the game lit every pipe that needed it, or said none did
function svo.allpipeslit()
  for _, name in ipairs(pipes.pnames) do
    pipes[name].lit, pipes[name].lit2 = true, true
  end
  svo.sk.forcelight_valerian, svo.sk.forcelight_elm, svo.sk.forcelight_skullcap = false, false, false
end

function svo.pipestart()
  local oldvalerianmaxpuffs, oldelmmaxpuffs, oldskullcapmaxpuffs = pipes.valerian.maxpuffs, pipes.elm.maxpuffs, pipes.skullcap.maxpuffs
  local oldvalerianmaxpuffs2, oldelmmaxpuffs2, oldskullcapmaxpuffs2 = pipes.valerian.maxpuffs2, pipes.elm.maxpuffs2, pipes.skullcap.maxpuffs2

  pipes.valerian = {lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = 'valerian', filledwith2 = 'valerian', maxpuffs = oldvalerianmaxpuffs, maxpuffs2 = oldvalerianmaxpuffs2}
  me.pipes.valerian = pipes.valerian

  pipes.elm = {lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = 'elm', filledwith2 = 'elm', maxpuffs = oldelmmaxpuffs, maxpuffs2 = oldelmmaxpuffs2}
  me.pipes.elm = pipes.elm

  pipes.skullcap = {lit = false, lit2 = false, id = 0, id2 = 0, arty = false, arty2 = false, puffs = 0, puffs2 = 0, filledwith = 'skullcap', filledwith2 = 'skullcap', maxpuffs = oldskullcapmaxpuffs, maxpuffs2 = oldskullcapmaxpuffs2}
  me.pipes.skullcap = pipes.skullcap
end

function svo.parseplist()
  local pipenames = {
    ["slippery elm"]                = 'elm',
    ["a valerian leaf"]             = 'valerian',
    ["a skullcap flower"]           = 'skullcap',
    ["a pinch of ground cinnabar"]  = 'elm',
    ["a pinch of realgar crystals"] = 'valerian',
    ["a pinch of ground malachite"] = 'skullcap'
  }

  local short_names = {
    ["slippery elm"]                = 'elm',
    ["a valerian leaf"]             = 'valerian',
    ["a skullcap flower"]           = 'skullcap',
    ["a pinch of ground cinnabar"]  = 'cinnabar',
    ["a pinch of realgar crystals"] = 'realgar',
    ["a pinch of ground malachite"] = 'malachite'
  }

  local id     = tonumber(matches[3])
  local herb   = pipenames[matches[4]]
  local puffs  = tonumber(matches[5])
  local status = matches[2]

  if not (id and herb and puffs and status) then return end

  local filled,lit,arty,puffskey, maxpuffs
  if pipes[herb].id == 0 then
    pipes[herb].id = id
    svo.firstpipe = true
    filled = 'filledwith'
    lit = 'lit'
    arty = 'arty'
    puffskey = 'puffs'
    maxpuffs = 'maxpuffs'
  else
    pipes[herb].id2 = id
    svo.firstpipe = false
    filled = 'filledwith2'
    lit = 'lit2'
    arty = 'arty2'
    puffskey = 'puffs2'
    maxpuffs = 'maxpuffs2'
  end

  pipes[herb][arty] = false

  pipes[herb][filled] = short_names[matches[4]]

  if status == 'out' then
    pipes[herb][lit] = false
  elseif status == 'lit' then
    pipes[herb][lit] = true
   elseif status == 'artf' then
    pipes[herb][arty] = true
  end

  pipes[herb][puffskey] = puffs

  -- assume it's a 20 puff pipe if the puffs we have atm is over 10 (bigger than normal)
  if puffs > 10 then
    pipes[herb][maxpuffs] = 20
    echo(" ")
    setFgColor(unpack(svo.getDefaultColorNums))
    echo("(a 20-puff pipe)")
  end

  -- warn if relighting pipes is on ignore, to make it more obvious - people tended to miss the original line
  if svo.ignore.lightpipes and status ~= 'artf' then
    local because = type(svo.ignore.lightpipes) == 'table' and svo.ignore.lightpipes.because or "you asked"
    decho(" "..svo.getDefaultColor().."(")
    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true)
    echoLink("re-enable lighting", 'svo.unsetignore("lightpipes"); svo.echof("Re-enabled lighting of pipes."); if not svo.conf.relight then svo.config.set([[relight]], [[on]], true) end', 'Re-lighting pipes was put on ignore because '..because..' - click the link to re-enable it', true)
    setUnderline(false)
    decho(svo.getDefaultColor()..")")
  end
end

function svo.parseplistempty()
  local id = tonumber(matches[3])
  local status = matches[2]
  if not (id and status) then return end

  -- save the data, to later assign the pipes to herbs
  pipes.empties[#pipes.empties+1] = {id = id, arty = (status == 'artf' and true or false), status = status}
end

function svo.parseplistend()
  -- fill up at least one of each first
  for id = 1, #pipes.pnames do
    local i = pipes.pnames[id]
    if pipes[i] and pipes[i].id == 0 and next(pipes.empties) then
      pipes[i].id = pipes.empties[#pipes.empties].id
      if pipes.empties[#pipes.empties].status == 'Lit' then
        pipes[i].lit = true
      else
        pipes[i].lit = false
      end

      if pipes.empties[#pipes.empties].arty then
        pipes[i].arty = true
      end

      pipes.empties[#pipes.empties] = nil
    end
  end

  -- fill up secondary ones
  for id = 1, #pipes.pnames do
    local i = pipes.pnames[id]
    if pipes[i] and pipes[i].id2 == 0 and next(pipes.empties) then
      pipes[i].id2 = pipes.empties[#pipes.empties].id
      if pipes.empties[#pipes.empties].status2 == 'Lit' then
        pipes[i].lit2 = true
      else
        pipes[i].lit2 = false
      end

      if pipes.empties[#pipes.empties].arty then
        pipes[i].arty2 = true
      end

      pipes.empties[#pipes.empties] = nil
    end
  end

  pipes.empties = {}
  svo.signals.after_lifevision_processing:unblock(svo.cnrl.checkwarning) -- check for stain lock
  svo.make_gnomes_work()
end

-- assumes that we set some pipe to 0 already. This is used during install only
function svo.pipe_assignid(newid)
  newid = tonumber(newid)
  for id = 1, #pipes.pnames do
    local i = pipes.pnames[id]
    if pipes[i].id == 0 then
      pipes[i].id = newid
      svo.conf[i..'id'] = newid
      pipes[i].lit = false
      send("empty "..newid, false)
      raiseEvent("svo config changed", i..'id')
      return i
    elseif pipes[i].id2 == 0 and pipes[pipes.pnames[#pipes.pnames]].id ~= 0 then
      pipes[i].id2 = newid
      svo.conf[i..'id2'] = newid
      pipes[i].lit2 = false
      send("empty "..newid, false)
      raiseEvent("svo config changed", i..'id2')
      return i
    end
  end
end

if lfs.attributes(getMudletHomeDir() .. "/svo/pipes/conf") then
  local ok = pcall(table.load, getMudletHomeDir() .. "/svo/pipes/conf", pipes)
  if ok then
    -- maxpuffs were added later on in the game, so make sure this field exists for upgrading systems
    pipes.elm.maxpuffs         = pipes.elm.maxpuffs or 10
    pipes.skullcap.maxpuffs    = pipes.skullcap.maxpuffs or 10
    pipes.valerian.maxpuffs    = pipes.valerian.maxpuffs or 10

    -- secondary pipes were added later on, so drop it in
    pipes.elm.maxpuffs2        = pipes.elm.maxpuffs2 or 10
    pipes.skullcap.maxpuffs2   = pipes.skullcap.maxpuffs2 or 10
    pipes.valerian.maxpuffs2   = pipes.valerian.maxpuffs2 or 10

    pipes.elm.lit2             = pipes.elm.lit2 or false
    pipes.skullcap.lit2        = pipes.skullcap.lit2 or false
    pipes.valerian.lit2        = pipes.valerian.lit2 or false

    pipes.elm.id2              = pipes.elm.id2 or 0
    pipes.skullcap.id2         = pipes.skullcap.id2 or 0
    pipes.valerian.id2         = pipes.valerian.id2 or 0

    pipes.elm.arty2            = pipes.elm.arty2 or false
    pipes.skullcap.arty2       = pipes.skullcap.arty2 or false
    pipes.valerian.arty2       = pipes.valerian.arty2 or false

    pipes.elm.puffs2           = pipes.elm.puffs2 or 0
    pipes.skullcap.puffs2      = pipes.skullcap.puffs2 or 0
    pipes.valerian.puffs2      = pipes.valerian.puffs2 or 0

    pipes.elm.filledwith2      = pipes.elm.filledwith2 or 'elm'
    pipes.skullcap.filledwith2 = pipes.skullcap.filledwith2 or 'skullcap'
    pipes.valerian.filledwith2 = pipes.valerian.filledwith2 or 'valerian'

    me.pipes.elm               = pipes.elm
    me.pipes.skullcap          = pipes.skullcap
    me.pipes.valerian          = pipes.valerian
  end
end

svo.signals.connected:connect(function ()
  if not pipes.valerian.arty then pipes.valerian.lit   = false end
  if not pipes.elm.arty then pipes.elm.lit             = false end
  if not pipes.skullcap.arty then pipes.skullcap.lit   = false end

  if not pipes.valerian.arty2 then pipes.valerian.lit2 = false end
  if not pipes.elm.arty2 then pipes.elm.lit2           = false end
  if not pipes.skullcap.arty2 then pipes.skullcap.lit2 = false end

  if not pipes.valerian.filledwith then pipes.valerian.filledwith   = 'valerian' end
  if not pipes.elm.filledwith then pipes.elm.filledwith             = 'elm' end
  if not pipes.skullcap.filledwith then pipes.skullcap.filledwith   = 'skullcap' end

  if not pipes.valerian.filledwith2 then pipes.valerian.filledwith2 = 'valerian' end
  if not pipes.elm.filledwith2 then pipes.elm.filledwith2           = 'elm' end
  if not pipes.skullcap.filledwith2 then pipes.skullcap.filledwith2 = 'skullcap' end
end, 'setup pipes on login')

svo.signals.saveconfig:connect(function ()
  local s,m = svo.tablesave(getMudletHomeDir() .. "/svo/pipes/conf", pipes)
  if not s then
    svo.echof("Couldn't save settings; %s", m)
  end
end, 'save pipes config')

end -- end of svo pipes loader

if svo.systemloaded then svo.loader.pipes() end