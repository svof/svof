-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local sk = svo.sk

local hittable

svo.bl_list = {}
svo.burn_levels = {
  'ablaze',
  'severe',
  'extreme',
  'charred',
  'melting'
}

local bl_list, burn_levels = svo.bl_list, svo.burn_levels

function sk.bl_checkburncounter()
  -- make the announces work with a singleprompt
  local echof = svo.itf
  moveCursor(0, getLineNumber())

  -- we'll only ever have one name here so far. Actually add up the hits here and store them
  local who, action = next(hittable)
  action = action or ""

  if not who then
    echof("Failed to connect.\n")
  end

  -- can only add levels if someone is dehydrated
  if action == "add level" and (bl_list[who].dehydrate ~= 0 or bl_list[who].level == 0) then
    bl_list[who].level = bl_list[who].level + 1
    if bl_list[who].level > #burn_levels then bl_list[who].level = #burn_levels end

  elseif action == "only ablaze" and bl_list[who].level == 0 then
    bl_list[who].level = 1
  elseif action == "add to all" then
    for _, data in pairs(bl_list) do
      if data.dehydrate ~= 0 or data.level == 0 then
        data.level = data.level + 1
        if data.level > #burn_levels then data.level = #burn_levels end
      end
    end

    -- wipe the 'all' person, as that is not a real person
    bl_list.all = nil
  elseif action == "remove level" then
    bl_list[who].level = bl_list[who].level - 1
    if bl_list[who].level < 0 then bl_list[who].level = 0 end
  elseif action == 'dehydrate' then
    if bl_list[who].dehydrate ~= 0 then
      killTimer(bl_list[who].dehydrate)
    end

    bl_list[who].dehydrate = tempTimer(45+svo.getping(), function()
      bl_list[who].dehydrate = 0
      echof("\n%s's dehydrate wore off.\n", who)
      svo.showprompt()
    end)
  elseif action == "lost dehydrate" then
    if bl_list[who].dehydrate ~= 0 then
      killTimer(bl_list[who].dehydrate)
      bl_list[who].dehydrate = 0
    end

  elseif action == "remove ablaze only" then
    if bl_list[who].level == 1 then
      bl_list[who].level = 0
    end
  else
    svo.debugf("bl_checkburncounter: unknown action '%s'", action)
  end

  raiseEvent("svo burncounter hit", who)

  -- if a specific person and they are ablaze
  if who ~= 'all' and bl_list[who].level > 0 then
    echof("%ss burn is %s (%s).%s\n", who, burn_levels[bl_list[who].level], bl_list[who].level, (bl_list[who].dehydrate == 0 and '' or ' They are also dehydrated.'))
  -- if a specific person and their ablaze was cured
  elseif who ~= 'all' and bl_list[who].level == 0 then
    echof("%s isn't on fire%s.\n", who, (bl_list[who].dehydrate == 0 and '' or ' (but they are dehydrated)'))
  else
    local function getburnlevels()
      local t = {}
      for person, data in pairs(bl_list) do
        if data.dehydrate ~= 0 then
          t[#t+1] = string.format("%s's burn is %s (%s)%s", person, burn_levels[data.level], data.level, (data.dehydrate == 0 and '' or ' and dehydrated'))
        end
      end

      return svo.concatand(t)
    end

    local burnsstring = getburnlevels()
    if burnsstring ~= "" then
      echof("%s.\n", burnsstring)
    end
  end

  -- turn things off
  hittable = {}
  disableTrigger("svobl Don't register")
  svo.signals.after_prompt_processing:block(sk.bl_checkburncounter)
end

function svo.bl_count(who, what)
  bl_list[who] = bl_list[who] or {level = 0, dehydrate = 0}
  svo.lasthit = who

  hittable[who] = what
  svo.signals.after_prompt_processing:unblock(sk.bl_checkburncounter)
  enableTrigger("svokl Don't register")
end

svo.signals.after_prompt_processing:connect(sk.bl_checkburncounter)
svo.signals.after_prompt_processing:block(sk.bl_checkburncounter)

function svo.bl_ignore()
  if not next(hittable) then return end
  table.remove(select(2, next(hittable)))
end

function svo.bl_reset(whom, quiet)
  if svo.defc.dragonform then return end

  if whom then whom = string.title(whom) end
  local echof = svo.echof
  if quiet then echof = function() end end


  if whom == 'All' then
    bl_list = {}
    echof("Reset everyone's burn status.")
  elseif not whom and svo.lasthit then
    bl_list[svo.lasthit] = {level = 0, dehydrate = 0}
    echof("Reset %s's burn status.", svo.lasthit)
  elseif bl_list[whom:lower()] then
    if not svo.lasthit or not bl_list[svo.lasthit] then
      echof("Not keeping track of anyone yet to reset their burn.")
    end
  elseif whom then
    if bl_list[whom] then
      bl_list[whom] = nil
      echof("Reset %s's burn status.", whom)
    else
      echof("Weren't keeping track of %s anyway.", whom)
    end
  else
    echof("Not keeping track of anyone to reset them anyway.")
  end
  raiseEvent("svo burncounter reset")
end

function svo.bl_show()
  if not next(bl_list) then svo.echof("burncounter: Not keeping track of anyone yet."); return end

  setFgColor(unpack(svo.getDefaultColorNums))
  for person, burnt in pairs(bl_list) do
    echo("---"..person.." ") fg('a_darkgrey')
    echoLink("(reset)", 'svo.bl_reset"'..person..'"', "Reset burn status for "..person, true)
    setFgColor(unpack(svo.getDefaultColorNums))
    echo(string.rep("-", (92-#person-12))) -- 12 for the 'reset' link
    echo"\n"
    echo(string.format(" burn level: %s (%s), dehydrated: %s", burn_levels[burnt.level] or 'none', burnt.level, (burnt.dehydrate == 0 and 'no' or 'yes')))
    echo"\n"
  end
  echo(string.rep("-", 91))
end

svo.echof("Loaded svo Knight burncounter.")
