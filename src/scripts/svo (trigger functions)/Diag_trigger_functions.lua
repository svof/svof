-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo = svo or {}; svo.loader = svo.loader or {}
svo.loader.diag = function()

function svo.valid.diagnose_start()
  svo.checkaction(svo.dict.diag.physical)
  if svo.actions.diag_physical then
    svo.lifevision.add(svo.actions.diag_physical.p)
  elseif svo.conf.aillusion then
    setTriggerStayOpen("svo diag", 0)
    moveCursor(0, getLineNumber()-1)
    moveCursor(#getCurrentLine(), getLineNumber())
    insertLink(" (i)", '', 'Ignored this diagnose because we aren\'t actually diagnosing right now (if this is godfeelings, don\'t mind me, then)')
    moveCursorEnd()

    -- necessary since the trigger itself lasts on the next line
    svo.prompttrigger("reset diag", function() svo.sk.diag_list = {} end)
   end
end

function svo.valid.empty_diagnose()
  svo.checkaction(svo.dict.diag.physical)
  if svo.actions.diag_physical then
    svo.lifevision.add(svo.actions.diag_physical.p, nil, nil, 1)
    svo.valid.diagnose_end()
  else
    svo.ignore_illusion("Ignoring this illusion because we weren't diagnosing right now.")
  end
end

local whitelist = {}
whitelist.lovers, whitelist.retardation, whitelist.hoisted, whitelist.paradox = true, true, true, true
if svo.haveskillset('metamorphosis') then
  whitelist.cantvitality = true
end
if svo.haveskillset('metamorphosis') or svo.haveskillset('shindo') or svo.haveskillset('kaido') then
  whitelist.cantmorph = true
end

function svo.valid.diagnose_end()
  if svo.sk.diag_list.godfeelings then svo.sk.diag_list = {} setTriggerStayOpen("svo diag", 0) return end

  -- clear ones we don't have
  for affn, _ in pairs(svo.affs) do
    if not svo.sk.diag_list[affn] and not whitelist[affn] then
      svo.debugf("removed %s, don't actually have it.", affn)
      if svo.dict[affn].count then svo.dict[affn].count = 0 end
      svo.rmaff(affn)
    elseif not whitelist[affn] then -- if we do have the aff, remove from diag list, so we don't add it again
      -- but update the current count!
      if type(svo.sk.diag_list[affn]) == 'number' and svo.dict[affn].count then
        svo.dict[affn].count = svo.sk.diag_list[affn]
        svo.updateaffcount(svo.dict[affn])
        svo.debugf("%s count updated to %d", affn, svo.dict[affn].count)
      end

      svo.sk.diag_list[affn] = nil
    end
  end

  -- add left over ones
  for j,k in pairs(svo.sk.diag_list) do
    if not svo.dict[j].aff then svo.debugf("svo: invalid %s in diag end", j) end
    -- skip defs
    if svo.defc[j] == nil then
      svo.checkaction(svo.dict[j].aff, true)
      if type(k) == 'number' and not svo.dict[j].count then
        for _ = 1, k do svo.lifevision.add(svo.actions[j .. '_aff'].p) end
      elseif type(k) == 'number' and svo.dict[j].count then
        svo.lifevision.add(svo.actions[j .. '_aff'].p, nil, k)
      else
        svo.lifevision.add(svo.actions[j .. '_aff'].p)
      end
    end
  end

  svo.affsp = {} -- potential affs
  svo.sk.checkaeony()
  svo.signals.changecuring:emit()
  setTriggerStayOpen("svo diag", 0)
  svo.sk.diag_list = {}
end

-- One handler for every diagnose line, in place of two lists that generated
-- one function per name. The trigger names the affliction, because the trigger
-- is the only thing that knows the game's wording for it - the lists were a
-- second copy of that fact and had drifted both ways: 16 names nothing ever
-- called, and 3 names called that were missing, which made DIAGNOSE clear
-- three afflictions it had just reported.
--
-- The count comes from the trigger's own capture, so the two loops collapse
-- into one branch. 'bleeding' was in both lists and the later one silently
-- won; that is not expressible now.
function svo.valid.diag(name, ...)
  -- select('#', ...) rather than a nil test on the value. A counted trigger
  -- whose capture does not resolve - pressure's lookup table, given a level it
  -- does not know - passed nil, and tonumber(nil) left the key unset so
  -- diagnose_end cleared the affliction. Testing the value instead would set
  -- the key to true and keep it, which is a behaviour change and not this
  -- commit's business.
  local counted, howmuch = select('#', ...) > 0, ...

  -- diagnose_end special-cases godfeelings and returns before its leftover
  -- loop. Every other name reaches svo.dict[name].aff in that loop, so a name
  -- with no entry would nil-index deep inside the reconciliation instead of
  -- being reported here.
  if name ~= 'godfeelings' and not (svo.dict[name] and svo.dict[name].aff) then
    svo.errorf("a diagnose trigger names %q, which svof has no affliction for.", name)
    return
  end

  if counted then
    svo.sk.diag_list[name] = tonumber(howmuch)

    if svo.ignore[name] then
      echo(" (currently ignored)")
    end

    return
  end

  svo.sk.diag_list[name] = true

  if not svo.affs[name] then
    decho(svo.getDefaultColor().."(new)")
  else
    decho(svo.getDefaultColor().." ("..getStopWatchTime(svo.affs[name].sw).."s)")
  end

  if svo.ignore[name] then
    decho(svo.getDefaultColor().." (currently ignored)")
  end
end

end -- end of svo diag loader

if svo.systemloaded then svo.loader.diag() end