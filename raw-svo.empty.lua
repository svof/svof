-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local empty = svo.empty

local affs = svo.affs

local madness_affs = {'addiction', 'confusion', 'dementia', 'hallucinations', 'hypersomnia', 'illness', 'impatience',
'lethargy', 'loneliness', 'madness', 'masochism', 'paranoia', 'recklessness', 'stupidity', 'vertigo'}

for herbname, herbaffs in pairs({
  goldenseal = {'dissonance', 'impatience', 'stupidity', 'dizziness', 'epilepsy', 'shyness', 'depression',
   'shadowmadness'},
  kelp = {'asthma', 'hypochondria', 'healthleech', 'sensitivity', 'clumsiness', 'weakness'},
  lobelia = {'claustrophobia', 'recklessness', 'agoraphobia', 'loneliness', 'masochism', 'vertigo', 'spiritdisrupt',
  'airdisrupt', 'waterdisrupt', 'earthdisrupt', 'firedisrupt'},
  ginseng = {'haemophilia', 'darkshade', 'relapsing', 'addiction', 'illness', 'lethargy'},
  ash = {'hallucinations', 'hypersomnia', 'confusion', 'paranoia', 'dementia'},
  bellwort = {'generosity', 'pacifism', 'justice', 'inlove', 'peace', 'retribution', 'timeloop'}
}) do
  empty['eat_'..herbname] = function()
    svo.lostbal_herb()

    if not affs.madness then
      svo.rmaff(herbaffs)
    else
      svo.rmaff(table.n_complement(herbaffs, madness_affs))
    end

  end
end

-- handle affs with madness separately

empty.eat_bloodroot = function()
  svo.lostbal_herb()
  svo.rmaff('paralysis')

  if not affs.stain then svo.rmaff('slickness') end
end

empty.degenerateaffs = {'weakness', 'clumsiness', 'lethargy', 'illness', 'asthma', 'paralysis'}
-- expose publicly
svo.degenerateaffs = empty.degenerateaffs

empty.deteriorateaffs = {'stupidity', 'confusion', 'hallucinations', 'depression', 'shadowmadness', 'vertigo',
'masochism', 'agoraphobia', 'claustrophobia'}
-- expose publicly
svo.deteriorateaffs = empty.deteriorateaffs

empty.focuscurables = {'claustrophobia', 'masochism', 'dizziness', 'confusion', 'stupidity', 'generosity',
'loneliness', 'agoraphobia', 'recklessness', 'epilepsy', 'pacifism', 'anorexia', 'shyness', 'vertigo', 'unknownmental',
'airdisrupt', 'earthdisrupt', 'waterdisrupt', 'firedisrupt', 'paranoia', 'hallucinations', 'dementia'}

-- expose publicly
svo.focuscurables = empty.focuscurables
empty.focus = function()
  if affs.madness then return end

  svo.rmaff(empty.focuscurables)
end

-- you /can/ cure hamstring, dissonance with tree
empty.treecurables = {'ablaze', 'addiction', 'aeon', 'agoraphobia', 'anorexia', 'asthma', 'blackout', 'claustrophobia',
'clumsiness', 'confusion', 'crippledleftarm', 'crippledleftleg', 'crippledrightarm', 'crippledrightleg', 'darkshade',
'deadening', 'dementia', 'disloyalty', 'disrupt', 'dissonance', 'dizziness', 'epilepsy', 'fear', 'generosity',
'haemophilia', 'hallucinations', 'healthleech',  'hellsight', 'hypersomnia', 'hypochondria', 'illness', 'impatience',
'inlove', 'itching', 'justice', 'lethargy', 'loneliness', 'madness', 'masochism', 'pacifism', 'paralysis', 'paranoia',
'peace', 'recklessness', 'relapsing', 'selarnia', 'sensitivity', 'shyness', 'slickness', 'stupidity', 'stuttering',
'unknownany', 'unknowncrippledarm', 'unknowncrippledleg', 'unknownmental', 'vertigo', 'voyria', 'weakness', 'hamstring',
'shivering', 'frozen', 'skullfractures', 'crackedribs', 'wristfractures', 'torntendons', 'depression', 'parasite',
'retribution', 'shadowmadness', 'timeloop', 'degenerate', 'deteriorate'}
empty.treeblocks = {
  madness = {'madness', 'dementia', 'stupidity', 'confusion', 'hypersomnia', 'paranoia', 'hallucinations', 'impatience',
  'addiction', 'agoraphobia', 'inlove', 'loneliness', 'recklessness', 'masochism'},
  hypothermia = {'frozen', 'shivering'},
}
-- expose publicly
svo.treecurables = empty.treecurables

svo.gettreeableaffs = function(getall)
  local a = svo.deepcopy(empty.treecurables)
  for blockaff, blocked in pairs(empty.treeblocks) do
    if affs[blockaff] then
      for _, remaff in ipairs(blocked) do
        table.remove(a, table.index_of(a, remaff))
      end
    end
  end
  if not getall then
    local i = 1
    while #a >= i do
      if not affs[a[i]] then
        table.remove(a, i)
      else
        i = i + 1
      end
    end
  end
  return a
end

empty.tree = function ()
  local a = svo.gettreeableaffs()
  svo.debugf("Tree cured nothing, removing: "..table.concat(a, ", "))
  svo.rmaff(a)
  svo.dict.unknownmental.count = 0
  svo.dict.unknownany.count = 0
end

empty.dragonheal = empty.tree
-- this includes weakness - but if shrugging didn't cure anything, it still means we didn't have weakness as we can't
-- use shrugging with weakness
empty.shrugging  = empty.tree

empty.smoke_elm = function()
  svo.rmaff({'deadening', 'madness', 'aeon'})
end

empty.smoke_valerian = function()
  svo.rmaff({'disloyalty', 'manaleech', 'slickness', 'hellsight'})
end


empty.writhe = function()
  svo.rmaff({'impale', 'bound', 'webbed', 'roped', 'transfixed', 'hoisted'})
end

empty.apply_epidermal_head = function ()
  svo.rmaff({'anorexia', 'itching', 'stuttering', 'slashedthroat', 'blindaff', 'deafaff', 'scalded'})
  svo.defences.lost('blind')
  svo.defences.lost('deaf')
end

empty.apply_epidermal_body = function ()
  svo.rmaff({'anorexia', 'itching'})
end

empty.apply_mending = function()
  svo.dict.unknowncrippledlimb.count = 0
  svo.dict.unknowncrippledarm.count = 0
  svo.dict.unknowncrippledleg.count = 0
  svo.rmaff({'selarnia', 'crippledleftarm', 'crippledleftleg', 'crippledrightarm', 'crippledrightleg', 'ablaze',
    'severeburn', 'extremeburn', 'charredburn', 'meltingburn', 'unknowncrippledarm', 'unknowncrippledleg',
    'unknowncrippledlimb'})
end

empty.noeffect_mending_arms = function()
  svo.rmaff({'crippledrightarm', 'crippledleftarm', 'unknowncrippledarm'})
  svo.dict.unknowncrippledarm.count = 0
end

empty.noeffect_mending_legs = function()
  svo.rmaff({'crippledrightleg', 'crippledleftleg', 'unknowncrippledleg'})
  svo.dict.unknowncrippledleg.count = 0
end

empty.apply_health_head = function()
  svo.rmaff({'skullfractures'})
  svo.dict.skullfractures.count = 0
end

empty.apply_health_torso = function()
  svo.rmaff({'crackedribs'})
  svo.dict.crackedribs.count = 0
end

empty.apply_health_arms = function()
  svo.rmaff({'wristfractures'})
  svo.dict.wristfractures.count = 0
end

empty.apply_health_legs = function()
  svo.rmaff({'torntendons'})
  svo.dict.torntendons.count = 0
end

empty.sip_immunity = function ()
  svo.rmaff('voyria')
end

empty.eat_ginger = function ()
  svo.rmaff({'cholerichumour', 'melancholichumour', 'phlegmatichumour', 'sanguinehumour'})
  svo.dict.cholerichumour.count = 0
  svo.dict.melancholichumour.count = 0
  svo.dict.phlegmatichumour.count = 0
  svo.dict.sanguinehumour.count = 0
end
