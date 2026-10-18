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
-- So ask the game first. svo.rmaff does: it keeps anything GMCP still reports
-- (svo.gmcp_refuse_remove in Setup.lua), so handing it the whole list removes
-- only what the game no longer lists. That one check used to be a second copy
-- here, which read svo.gaffl through svotossa and so missed sleep and
-- seriousconcussion under their other game names, and which went on trusting
-- gaffl after a blackout had left it stale, keeping and re-curing forever an
-- affliction cured during the blackout. rmaff's check does neither: it knows
-- both names, and it stands down until the next List.
--
-- Where GMCP cannot speak, the inference is the only information there is and
-- it stands. That is the four unknowns, which are meant to be resolved exactly
-- this way - working out that an unknown affliction was one of these is the
-- whole point of tracking one - and three real afflictions svof takes no GMCP
-- affliction name for: blindaff and deafaff, because the game sends one
-- blindness (and one deafness) on both feeds at once, as an affliction and as
-- a defence, with nothing to tell an unwanted one from the bayberry defence,
-- so sstosvoa maps both to false and svof reads them from the defence feed;
-- and hoisted, which no sstosvoa entry names. For those three an empty
-- epidermal apply or writhe still decides on its own. earworm used to be
-- outside the gate too, until it was added to sstosvoa.
-- bleeding is not in any list here and must not be: the game
-- reports it through Char.Vitals.charstats as "Bleed: N" rather than as an
-- affliction, and Setup.lua already clears it when that reads 0.
--
-- Blackout stops Char.Afflictions entirely, and the cure lines themselves can
-- go unseen. Presume nothing at all there. The cure messages still arrive as
-- text, which is what the generic and tree triggers are for.
local function presume_cured(which)
  if affs.blackout then
    svo.debugf("empty cure: presuming nothing, blackout has stopped Char.Afflictions")
    return
  end

  svo.rmaff(which)
end
-- expose publicly, so an addon or a user's own empty handler gets the same
-- rule, blackout included, instead of calling svo.rmaff on a list itself
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
-- Ten names were added on 2026-09-23, nine on the repo owner confirming tree
-- cures them and tension on his judgement that an ordinary affliction most
-- likely is tree-curable. Two weaker kinds of evidence were tried first and
-- both turned out to be worthless:
--
--   * The 86-name tree list that used to live in Main trigger functions. It
--     claimed bound, prone, flamefisted, galed, icing, voided and bleeding,
--     none of which tree cures, so it says nothing about the rest.
--   * The existence of a trigger in the Tree cures folder. Every one of those
--     lines has a twin in General cures on the identical pattern - the tree
--     copy is a no-op unless a touchtree action happens to be in flight - so it
--     only proves somebody once wired the line to both paths.
--
-- bleeding is the clearest case: its line, "Your bleeding slows as your blood
-- clots", is the clotting line, and clotting is what cures bleeding. It is not
-- tree-curable and must not go back in. The game does not even model it as an
-- affliction - it arrives in Char.Vitals.charstats as "Bleed: N", which
-- Setup.lua's Vitals handler already acts on - so a sweep here could only ever
-- second-guess a live feed.
--
-- What makes a "most likely" like tension's acceptable at all is presume_cured
-- above. GMCP reports tension, so if tree turns out not to cure it the sweep
-- will not remove it anyway, and the entry costs nothing. Before that gate
-- existed, every name in here was a chance to drop an affliction still held.
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
'laceratedthroat', 'mildconcussion', 'slashedthroat', 'tension'}
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
  -- An unknown's count is reset only when the unknown is actually gone.
  -- Resolving one on an empty cure is the point of tracking it, and GMCP can
  -- never report one, so outside blackout presume_cured always removes them -
  -- but in blackout it removes nothing, and resetting the counts regardless
  -- left unknownany tracked at a count of 0.
  if not affs.unknownmental then svo.dict.unknownmental.count = 0 end
  if not affs.unknownany then svo.dict.unknownany.count = 0 end
end

empty.dragonheal = empty.tree
-- this includes weakness - but if shrugging didn't cure anything, it still means we didn't have weakness as we can't
-- use shrugging with weakness
empty.shrugging  = empty.tree

empty.smoke_elm = function()
  -- earworm was missing. Its entry says smokecure = {'elm', 'cinnabar'}, so elm
  -- curing nothing rules it out the same way it rules out the other three.
  -- tension and unweavingspirit say the same and are still absent, left for
  -- their own check rather than added on the back of this one.
  presume_cured({'deadening', 'madness', 'aeon', 'earworm'})
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
  presume_cured({'anorexia', 'itching', 'stuttering', 'slashedthroat', 'blindaff', 'deafaff'})
  svo.defences.lost('blind')
  svo.defences.lost('deaf')
end

empty.apply_epidermal_body = function ()
  presume_cured({'anorexia', 'itching'})
end

empty.apply_mending_head = function()
  presume_cured({'crushedthroat'})
end

-- The handlers below call svo.rmaff themselves rather than presume_cured,
-- because each pairs its removal with an explicit count reset. rmaff still
-- keeps anything GMCP reports, and when it keeps a counted affliction it puts
-- GMCP's level back at the prompt (svo.gmcp_refuse_remove in Setup.lua), so
-- the reset here cannot leave a kept affliction at a count of 0.
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