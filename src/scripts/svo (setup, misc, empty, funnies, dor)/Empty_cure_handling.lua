-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

-- functions for resetting the right afflilictions when a cure cured nothing

svo = svo or {}; svo.loader = svo.loader or {}
svo.loader.empty = function()

local empty = svo.empty

local affs = svo.affs

-- Every handler in this file acts on the same inference: a cure that cured
-- nothing is evidence we did not have the afflictions it would have cured. That
-- is usually right and occasionally very wrong, and when it is wrong svof
-- forgets an affliction you still have and stops curing it.
--
-- So ask the game first. svo.gaffl mirrors Char.Afflictions, and
-- svo.dict.svotossa says whether GMCP can speak to a given svof name at all -
-- the same gate the Char.Afflictions.List reconciler uses in Setup.lua before
-- it will drop anything. Where GMCP can speak and still reports the affliction,
-- the inference is simply wrong, so the affliction stays.
--
-- Where GMCP cannot speak, the inference is the only information there is and
-- it stands. That is the four unknowns, which are meant to be resolved exactly
-- this way - working out that an unknown affliction was one of these is the
-- whole point of tracking one - and earworm, which is the only real affliction
-- in that position. bleeding is not in any list here and must not be: the game
-- reports it through Char.Vitals.charstats as "Bleed: N" rather than as an
-- affliction, and Setup.lua already clears it when that reads 0.
--
-- Blackout stops Char.Afflictions entirely, so svo.gaffl goes stale rather than
-- empty and every name would read as still held. Presume nothing at all there.
-- The cure messages still arrive as text, which is what the generic and tree
-- triggers are for.
local function presume_cured(which)
  if type(which) == 'string' then which = {which} end

  if affs.blackout then
    svo.debugf("empty cure: presuming nothing, blackout has stopped Char.Afflictions")
    return
  end

  -- GMCP keys a levelled affliction "name (2)" and up, bare at level 1, so
  -- compare on the bare name the way Setup.lua's parseaffname does.
  local reported = {}
  for key in pairs(svo.gaffl) do
    reported[key:match("^(.-) %(%d+%)$") or key] = true
  end

  local gone, kept = {}, nil
  for _, aff in ipairs(which) do
    local gmcpname = svo.dict.svotossa[aff]
    if gmcpname and reported[gmcpname] then
      kept = (kept and kept .. ", " or "") .. aff
    else
      gone[#gone+1] = aff
    end
  end

  if kept then
    svo.debugf("empty cure: keeping %s, the game still reports it", kept)
  end

  svo.rmaff(gone)
end
-- expose publicly, so an addon or a user's own empty handler can use the same
-- rule instead of calling svo.rmaff on a list and hoping
empty.presume_cured = presume_cured
svo.presume_cured = presume_cured

local madness_affs = {'addiction', 'confusion', 'dementia', 'hallucinations', 'hypersomnia', 'illness', 'impatience',
'lethargy', 'loneliness', 'madness', 'masochism', 'paranoia', 'recklessness', 'stupidity', 'vertigo'}

for herbname, herbaffs in pairs({
  goldenseal = {'dissonance', 'impatience', 'stupidity', 'dizziness', 'epilepsy', 'shyness', 'depression',
   'shadowmadness', 'mycalium', 'sandfever', 'horror', 'fulminated'},
  kelp = {'asthma', 'hypochondria', 'healthleech', 'sensitivity', 'clumsiness', 'weakness', 'rebbies'},
  lobelia = {'claustrophobia', 'recklessness', 'agoraphobia', 'loneliness', 'masochism', 'vertigo', 'guilt', 'spiritburn', 'tenderskin'},
  ginseng = {'haemophilia', 'darkshade', 'relapsing', 'addiction', 'illness', 'lethargy', 'flushings'},
  ash = {'hallucinations', 'hypersomnia', 'confusion', 'paranoia', 'dementia', 'crescendo'},
	pear = {'pressure'},
  bellwort = {'generosity', 'pacifism', 'justice', 'inlove', 'peace', 'pyre', 'retribution', 'timeloop', 'indifference'},
  bloodroot = {'paralysis', 'pyramides'}
  
}) do
  empty['eat_'..herbname] = function()
    svo.lostbal_herb()

    if not affs.madness then
      presume_cured(herbaffs)
    else
      presume_cured(table.n_complement(herbaffs, madness_affs))
    end

  end
end

-- handle affs with madness separately

empty.eat_bloodroot = function()
  svo.lostbal_herb()
  presume_cured({'paralysis', 'slickness'})
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
'paranoia', 'hallucinations', 'dementia'}

-- expose publicly
svo.focuscurables = empty.focuscurables
empty.focus = function()
  if affs.madness then return end

  presume_cured(empty.focuscurables)
end


-- Everything a tree touch could have cured. When one cures nothing, empty.tree()
-- removes every name here that we currently have, so a name that does not belong
-- makes svof drop an affliction you still have. empty.dragonheal and
-- empty.shrugging are the same function, so this list speaks for all three.
--
-- Nine names were added on 2026-09-23, on the repo owner confirming tree cures
-- them. Only owner or in-game confirmation gets a name in here. Two weaker kinds
-- of evidence were tried first and both turned out to be worthless:
--
--   * The 86-name tree list that used to live in Main trigger functions. It
--     claimed bound, prone, flamefisted, galed, icing, voided, bleeding and
--     tension, none of which tree cures, so it says nothing about the rest.
--   * The existence of a trigger in the Tree cures folder. Every one of those
--     lines has a twin in General cures on the identical pattern - the tree
--     copy is a no-op unless a touchtree action happens to be in flight - so it
--     only proves somebody once wired the line to both paths.
--
-- bleeding is the clearest case: its line, "Your bleeding slows as your blood
-- clots", is the clotting line, and clotting is what cures bleeding. It is not
-- tree-curable and must not go back in.
--
-- UNCONFIRMED, kept rather than removed on suspicion, pending the owner
-- checking in game: paralysis, skullfractures, crackedribs, wristfractures and
-- torntendons, all of which have been here since 2018 and rest on nothing
-- better than the trigger pairing above; and latched, added 2026-09-23, whose
-- only tree evidence is a Tree cures trigger and whose confirmed cure is
-- SIP HEALTH. If tree does not cure latched, an empty tree makes svof forget a
-- latch still held and the next health sip heals instead of clearing it.
empty.treecurables = {'ablaze', 'addiction', 'aeon', 'agoraphobia', 'anorexia', 'asthma', 'blackout', 'claustrophobia',
'clumsiness', 'confusion', 'crippledleftarm', 'crippledleftleg', 'crippledrightarm', 'crippledrightleg', 'darkshade',
'deadening', 'dementia', 'disloyalty', 'disrupt', 'dissonance', 'dizziness', 'epilepsy', 'fear', 'generosity',
'haemophilia', 'hallucinations', 'healthleech',  'hellsight', 'hypersomnia', 'hypochondria', 'illness', 'impatience',
'inlove', 'itching', 'justice', 'lethargy', 'loneliness', 'madness', 'masochism', 'pacifism', 'paralysis', 'paranoia',
'peace', 'pyre', 'recklessness', 'relapsing', 'selarnia', 'sensitivity', 'shyness', 'slickness', 'stupidity', 'stuttering',
'unknownany', 'unknowncrippledarm', 'unknowncrippledleg', 'unknownmental', 'vertigo', 'voyria', 'weakness',
'shivering', 'frozen', 'skullfractures', 'crackedribs', 'wristfractures', 'torntendons', 'depression', 'parasite',
'retribution', 'shadowmadness', 'timeloop', 'degenerate', 'deteriorate', 'guilt', 'spiritburn', 'tenderskin', 'crushedthroat',
'horror', 'earworm', 'crescendo', 'fulminated',
'latched', 'flushings', 'mycalium', 'pyramides', 'rebbies', 'sandfever',
'laceratedthroat', 'mildconcussion', 'slashedthroat'}
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
  svo.debugf("Tree cured nothing, considering: "..table.concat(a, ", "))
  presume_cured(a)
  -- Left unconditional. Neither unknown is in svotossa, so GMCP can never
  -- report one and presume_cured always removes them - resolving an unknown on
  -- an empty cure is the whole reason for tracking one - which keeps these two
  -- lines consistent with what was actually removed.
  svo.dict.unknownmental.count = 0
  svo.dict.unknownany.count = 0
end

empty.dragonheal = empty.tree
-- this includes weakness - but if shrugging didn't cure anything, it still means we didn't have weakness as we can't
-- use shrugging with weakness
empty.shrugging  = empty.tree

empty.smoke_elm = function()
  presume_cured({'deadening', 'madness', 'aeon'})
end

empty.smoke_valerian = function()
  presume_cured({'disloyalty', 'manaleech', 'slickness', 'hellsight'})
end

empty.smoke_pear = function()
	presume_cured('pressure')
end

empty.writhe = function()
  presume_cured({'impale', 'bound', 'webbed', 'roped', 'transfixed', 'hoisted'})
end

empty.apply_epidermal_head = function ()
  presume_cured({'anorexia', 'itching', 'stuttering', 'slashedthroat', 'blindaff', 'deafaff', 'scalded'})
  svo.defences.lost('blind')
  svo.defences.lost('deaf')
end

empty.apply_epidermal_body = function ()
  presume_cured({'anorexia', 'itching'})
end

empty.apply_mending_head = function()
  presume_cured({'crushedthroat'})
end

-- The handlers below are NOT gated, deliberately. Each pairs its removal with
-- an explicit count reset, and keeping an affliction while zeroing its count
-- would leave svof in a state neither half agrees with. Deciding what the count
-- should do when GMCP overrules the removal is its own question, so these keep
-- today's behaviour until it is answered.
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
  presume_cured('voyria')
end

empty.eat_ginger = function ()
  svo.rmaff({'cholerichumour', 'melancholichumour', 'phlegmatichumour', 'sanguinehumour'})
  svo.dict.cholerichumour.count = 0
  svo.dict.melancholichumour.count = 0
  svo.dict.phlegmatichumour.count = 0
  svo.dict.sanguinehumour.count = 0
end

end -- end of svo empty loader

if svo.systemloaded then svo.loader.empty() end