-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local sk = svo.sk

function svo.ph_diag(aff)
  if not sk.healingmap[aff] then
    echo(" (your Healing skills don't know how to cure "..aff..")")
    return
  end

  if not sk.healingmap[aff]() then
    echo(" (you lack the open channels to cure "..aff..")")
    return
  end

  svo.currently_diagnosing.affs[aff] = true
end

-- called on the prompt to determine, and heal, the most important affliction
-- as determined by sync prio
function svo.healothersaff()
  local syncprios = svo.make_sync_prio_table("%s")

  -- syncprios is now a sparse table with priorities - afflictions
  -- trasverse the table to find the highest priotized affliction
  -- that healing can heal

  local highestcount, highestaff = 0
  for prio, aff in pairs(syncprios) do
    -- print(string.format("aff: %s, prio: %s, highestcount: %s, currently_diagnosing: %s, sk.healingmap: %s", aff, prio, highestcount, tostring(svo.currently_diagnosing.affs[aff]), tostring(sk.healingmap[aff])))
    if svo.currently_diagnosing.affs[aff] and sk.healingmap[aff] and prio > highestcount and sk.healingmap[aff]() then
      highestcount, highestaff = prio, aff
    end
  end

  local cant_heal_these = {'unknowncrippledlimb', 'blackout'}

  if not highestaff or table.contains(cant_heal_these, highestaff) then echo(string.format("%s hasn't got any afflictions we can cure\n", (svo.currently_diagnosing.name or '?'))) return end

  local aff = highestaff

  local svonames = {
    blind = 'blindness',
    deaf = 'deafness',
    blindaff = 'blindness',
    deafaff = 'deafness',
    illness = 'vomiting',
    weakness = 'weariness',
    crippledleftarm = 'arms',
    crippledrightarm = 'arms',
    crippledleftleg = 'legs',
    crippledrightleg = 'legs',
    unknowncrippledleg = 'legs',
    unknowncrippledarm = 'arms',
    ablaze = 'burning',
  }

  send("heal "..svo.currently_diagnosing.name .." "..(svonames[aff] or aff), false)
  echo(" (healing "..(svonames[aff] or aff)..")")
end

svo.echof("Loaded svo Priest Healer.")
