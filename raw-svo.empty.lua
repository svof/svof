-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local empty = {}

$(
local paths = {}
paths.oldpath = package.path
package.path = package.path..";./?.lua;./bin/?.lua;"
pretty = require "pl.pretty"
package.path = paths.oldpath

function _comp(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) == 'table' then
    for k, v in pairs(a) do
      if not b[k] then return false end
      if not _comp(v, b[k]) then return false end
    end
  else
    if a ~= b then return false end
  end
  return true
end
function n_complement(set1, set2)
  if not set1 and set2 then return false end

  local complement = {}

  for _, val1 in pairs(set1) do
    local insert = true
    for _, val2 in pairs(set2) do
      if _comp(val1, val2) then
        insert = false
      end
    end
    if insert then table.insert(complement, val1) end
  end

  return complement
end

)

#madness_affs = {"addiction", "confusion", "dementia", "hallucinations", "hypersomnia", "illness", "impatience", "lethargy", "loneliness", "madness", "masochism", "paranoia", "recklessness", "stupidity", "vertigo"}

#for herbname, herb in pairs({
#goldenseal = {"dissonance", "impatience", "stupidity", "dizziness", "epilepsy", "shyness"},
#kelp = {"asthma", "hypochondria", "healthleech", "sensitivity", "clumsiness", "weakness"},
#lobelia = {"claustrophobia", "recklessness", "agoraphobia", "loneliness", "masochism", "vertigo", "spiritdisrupt", "airdisrupt", "waterdisrupt", "earthdisrupt", "firedisrupt"},
#ginseng = {"haemophilia", "darkshade", "relapsing", "addiction", "illness", "lethargy"},
#ash = {"hallucinations", "hypersomnia", "confusion", "paranoia", "dementia"},
#bellwort = {"generosity", "pacifism", "justice", "inlove", "peace"},
#}) do
empty.eat_$(herbname) = function()
  lostbal_herb()

  if not affs.madness then
# _put("    removeaff(".. pretty.write(herb, "")..")\n")
  else
# _put("    removeaff(".. pretty.write(n_complement(herb, madness_affs), "")..")\n")
  end

end
#end

-- handle affs with madness separately

empty.eat_bloodroot = function()
  lostbal_herb()
  removeaff("paralysis")

  if not affs.stain then removeaff("slickness") end
end

empty.focuscurables = {"claustrophobia", "masochism", "dizziness", "confusion", "stupidity", "generosity", "loneliness", "agoraphobia", "recklessness", "epilepsy", "pacifism", "anorexia", "shyness", "vertigo", "unknownmental", "airdisrupt", "earthdisrupt", "waterdisrupt", "firedisrupt", "paranoia", "hallucinations", "dementia"}

-- expose publicly
focuscurables = empty.focuscurables
empty.focus = function()
  if affs.madness then return end

  removeaff(empty.focuscurables)
end

-- you /can/ cure hamstring, dissonance with tree
empty.treecurables = {"ablaze", "addiction", "aeon", "agoraphobia", "anorexia", "asthma", "blackout", "claustrophobia", "clumsiness", "confusion", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "darkshade", "deadening", "dementia", "disloyalty", "disrupt", "dissonance", "dizziness", "epilepsy", "fear", "generosity", "haemophilia", "hallucinations", "healthleech",  "hellsight", "hypersomnia", "hypochondria", "illness", "impatience", "inlove", "itching", "justice", "lethargy", "loneliness", "madness", "masochism","pacifism", "paralysis", "paranoia", "peace", "recklessness", "relapsing", "selarnia", "sensitivity", "shyness", "slickness", "stupidity", "stuttering", "unknownany", "unknowncrippledarm", "unknowncrippledleg", "unknownmental", "vertigo", "voyria", "weakness", "hamstring", "shivering", "frozen", "skullfractures", "crackedribs", "wristfractures", "torntendons", "depression", "parasite"}
empty.treecurableswithmadness = {"ablaze", "aeon", "agoraphobia", "anorexia", "asthma", "blackout", "claustrophobia", "clumsiness", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "darkshade", "deadening", "disloyalty", "disrupt", "dissonance", "dizziness", "epilepsy", "fear", "generosity", "haemophilia", "healthleech",  "hellsight", "hypochondria", "inlove", "itching", "justice", "pacifism", "paralysis", "peace", "relapsing", "selarnia", "sensitivity", "shyness", "slickness", "stuttering", "unknownany", "unknowncrippledarm", "unknowncrippledleg", "unknownmental", "vertigo", "voyria", "weakness", "hamstring", "shivering", "frozen", "depression", "parasite"}

-- expose publicly
treecurables = empty.treecurables
empty.tree = function ()
  if affs.madness then
    removeaff(empty.treecurableswithmadness)
  else
    removeaff(empty.treecurables)
  end
end

empty.dragonheal = empty.tree
-- this includes weakness - but if shrugging didn't cure anything, it still means we didn't have weakness as we can't use shrugging with weakness
empty.shrugging  = empty.tree

empty.smoke_elm = function()
  removeaff({"deadening", "madness", "aeon"})
end

empty.smoke_valerian = function()
  removeaff({"disloyalty", "manaleech", "slickness", "hellsight"})
end


empty.writhe = function()
  removeaff({"impale", "bound", "webbed", "roped", "transfixed", "hoisted"})
end

empty.apply_epidermal_head = function ()
  removeaff({"anorexia", "itching", "stuttering", "slashedthroat", "blindaff", "deafaff", "scalded"})
  defences.lost("blind")
  defences.lost("deaf")
end

empty.apply_epidermal_body = function ()
  removeaff({"anorexia", "itching"})
end

empty.apply_mending = function()
  dict.unknowncrippledlimb.count = 0
  dict.unknowncrippledarm.count = 0
  dict.unknowncrippledleg.count = 0
  removeaff({"selarnia", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "ablaze", "severeburn", "extremeburn", "charredburn", "meltingburn", "unknowncrippledarm", "unknowncrippledleg", "unknowncrippledlimb"})
end

empty.noeffect_mending_arms = function()
  removeaff({"crippledrightarm", "crippledleftarm", "unknowncrippledarm"})
  dict.unknowncrippledarm.count = 0
end

empty.noeffect_mending_legs = function()
  removeaff({"crippledrightleg", "crippledleftleg", "unknowncrippledleg"})
  dict.unknowncrippledleg.count = 0
end

empty.apply_health_head = function()
  removeaff({"skullfractures"})
  dict.skullfractures.count = 0
end

empty.apply_health_torso = function()
  removeaff({"crackedribs"})
  dict.crackedribs.count = 0
end

empty.apply_health_arms = function()
  removeaff({"wristfractures"})
  dict.wristfractures.count = 0
end

empty.apply_health_legs = function()
  removeaff({"torntendons"})
  dict.torntendons.count = 0
end

empty.sip_immunity = function ()
  removeaff("voyria")
end

empty.eat_ginger = function ()
  removeaff({"cholerichumour", "melancholichumour", "phlegmatichumour", "sanguinehumour"})
  dict.cholerichumour.count = 0
  dict.melancholichumour.count = 0
  dict.phlegmatichumour.count = 0
  dict.sanguinehumour.count = 0
end
