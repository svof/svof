-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

-- everything to do about Svof's defences - database, tracking, switching, etc.

svo = svo or {}; svo.loader = svo.loader or {}
svo.loader.defences = function()

local sys, affs, defdefup, defkeepup, signals = svo.sys, svo.affs, svo.defdefup, svo.defkeepup, svo.signals
local conf, sk, me, defs, defc = svo.conf, svo.sk, svo.me, svo.defs, svo.defc
local defences, rift = svo.defences, svo.rift
local actions, lifevision = svo.actions, svo.lifevision

svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/defup+keepup")

--[[ a small dictionary to know which defences belong to which skillset ]]
defences.def_types = defences.def_types or {}

-- the list from 'def'
defences.def_def_list = defences.def_def_list or {}
defences.defup_timer = defences.defup_timer or createStopWatch()

function defences.gettime(defence, max)
  if not defc[defence] then return "" end

  local time = max-math.ceil(getStopWatchTime(svo.dict[defence].stopwatch)/max)
  if time < 0 then return "" else
    return time..'m'
  end
end

-- runs f, and reports an error from it the way a failed action does,
-- without stopping whatever called it
local function run_reporting(what, f, ...)
  local ok, err = pcall(f, ...)
  if not ok then
    svo.debugf("%s failed: %s", what, tostring(err))
    echoLink("(e!)", [[svo.echof([=[The problem was: ]]..what..[[ failed: ]]..tostring(err)..[[]=])]],
      'Oy - there was a problem. Click on this link and submit a bug report with what it says along with a '..
        'copy/paste of what you saw.')
  end
end

-- A defence's ongot and onlost, on its record, are consequences of having
-- it or losing it, as opposed to the bookkeeping of svof's own command for
-- it: they run whenever the defence comes or goes, by any path - svof's
-- command, a line, GMCP or DEF. They run last, so a broken one cannot leave
-- the defence half set.
local function consequence(def, hook)
  local rec = svo.defs_data and svo.defs_data[def]
  if rec and rec[hook] then run_reporting(def .. "'s " .. hook, rec[hook]) end
end

-- functions to handle the defc table events updates
function defences.got(def)
  if not defc[def] then defc[def] = true; raiseEvent("svo got def", def); consequence(def, 'ongot') end
end

function defences.lost(def)
  if defc[def] then defc[def] = false; raiseEvent("svo lost def", def); consequence(def, 'onlost') end
end

-- The defences svof raises with a command that finishes before the defence
-- arrives: the command starts a wait, and the wait's completion sets the
-- defence. Keyed by defence, the wait's dictionary entry.
defences.waits = {
  blind = 'waitingonblind',
  deaf = 'waitingondeaf',
  dragonbreath = 'waitingfordragonbreath',
  dragonform = 'waitingfordragonform',
  mace = 'waitingformace',
  rebounding = 'waitingonrebounding',
  sileris = 'waitingforsileris',
  speed = 'curingspeed',
  viridian = 'waitingforviridian',
}

-- Blindness and deafness are a defence when you want them up and an
-- affliction when you do not, and the prompt flags decide which on every
-- prompt (check_promptflags). The game reports them the same way either
-- way, so on its word alone the decision stays with the next prompt.
defences.prompt_decides = { blind = true, deaf = true }

-- The game says you have def: GMCP gained it, or DEF listed it. That is not
-- svof's own command finishing, and must not be booked as one. If svof's
-- command for it is in flight, that command went through: it finishes now,
-- its bookkeeping (a balance, a pipe puff) is recorded once, and a wait it
-- starts finishes with it. If nothing is in flight, svof did nothing, so
-- the defence is simply set. None of it goes through lifevision, since the
-- game's own word is not a line an illusion can fake.
function defences.confirm(def)
  local function finish(act, ...)
    -- a claim a line already filed for it has nothing left to finish
    if lifevision.l[act.name] then lifevision.l:set(act.name, nil) end
    svo.actionfinished(act, nil, ...)
  end

  local entry = svo.dict[def]
  if type(entry) == 'table' then
    for _, act in pairs(entry) do
      -- (true): the defence is already up, for the oncompleteds that would
      -- otherwise start a wait for it
      if type(act) == 'table' and act.def and actions[act.name] then finish(act, true) end
    end
  end

  local wait = defences.waits[def] and svo.dict[defences.waits[def]]
  wait = wait and wait.waitingfor
  if wait and actions[wait.name] then finish(wait) end

  if not defences.prompt_decides[def] then defences.got(def) end
end

-- The game says you do not have def: GMCP lost it. The defence's gone runs
-- now, outside lifevision, so an illusion on the paragraph cannot discard
-- what the game said.
function defences.unconfirm(def)
  local entry = svo.dict[def]
  if type(entry) == 'table' and entry.gone then
    run_reporting(def .. "'s gone", entry.gone.oncompleted)
  else
    defences.lost(def)
  end
end

-- custom def types like channels
defences.custom_types = {}

defences.nodef_list = svo.phpTable()

-- set an initial mode to something, as it always needs to be a valid mode
svo.defs.mode = 'basic'

-- defc = current defs

-- specialskip: if this function returns true, that defence will be ignored for defup
svo.defs_data = svo.pl.OrderedMap {}
local defs_data = svo.defs_data
  defs_data:set('softfocus', { type = 'general',
    mana = 'lots',
    def = "You have softened the focus of your eyes.",
    on = {"You let your eyes go out of focus, causing you to miss some details.", "Your eyes are already out of focus."},
    off = {"You bring your eyes back into focus.", "Your eyes are already in focus."}})
  defs_data:set('metawake', { type = 'general',
    def = "You are concentrating on maintaining distance from the dreamworld.",
    mana = 'lots',
    on = {"You order your mind to ensure you will not journey far into the dreamworld.", "You already have metawake turned on."},
    off = {"You cease concentrating on maintaining distance from the dreamworld.", "You already have metawake turned off."}})
  defs_data:set('mass', { type = 'general',
    def = "You are extremely heavy and difficult to move.",
    offr = {[[^You are pulled out of the room by \w+ and \w+ whip\!$]],
            [[^A large handaxe comes flying into the room, arcs toward you, and carries you away with it to \w+!$]]},
    off = {"You feel your density return to normal.", "The savage winds pick you up and toss you through the air."}})
  defs_data:set('magicresist', { type = 'general',
    on_only = "That resistance already suffuses your form.",
    def = "You are enchanted against magic damage."})
  defs_data:set('fireresist', { type = 'general',
    on_only = "That resistance already suffuses your form.",
    def = "You are enchanted against fire damage."})
  defs_data:set('electricresist', { type = 'general',
    on_only = "That resistance already suffuses your form.",
    def = "You are enchanted against electric damage."})
  defs_data:set('coldresist', { type = 'general',
    on_only = "That resistance already suffuses your form.",
    def = "You are enchanted against cold damage."})
  defs_data:set('skywatch', { type = 'general',
    mana = 'little',
    def = "You are aware of movement in the skies.",
    on = {"You are now watching the skies.", "You are already watching the skies."},
    off = "You are no longer watching the skies."})
  defs_data:set('toughness', { nodef = true,
    def = "Your skin is toughened." })
  defs_data:set("defended", { nodef = true,
    def = "You are being defended by a stalwart ally." })
  defs_data:set('waterbubble', { type = 'general',
    def = "You are surrounded by a pocket of air."})
  defs_data:set('resistance', { nodef = true,
    def = "You are resisting magical damage."})
if not svo.haveskillset('alchemy') then
  defs_data:set('empower', { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    on = "You are already empowered by astronomical energies.",
    defr = [[^You are resonating with (?:the )?(?:Nebula )?(\w+)'s energy\.$]]})
end
if not svo.haveskillset('elementalism') or not svo.haveskillset('aeonics') or not svo.haveskillset('weatherweaving') then
  defs_data:set('reflection', { nodef = true,
    def = "You are surrounded by one reflection of yourself.",
    defr = [[^You are surrounded by \d+ reflections? of yourself\.$]]})
end
  defs_data:set('shipwarning', { nodef = true,
    def = "You are aware of all nearby ship movements."})
  defs_data:set('constitution', { nodef = true,
    def = "You are using your superior constitution to prevent nausea." })
  defs_data:set('preaching', { nodef = true,
    def = "You have accepted a blessing for aid in times of need." })
  defs_data:set('frostblessing', { nodef = true,
    def = "You are protected by the power of a Frost Spiritshield."})
  defs_data:set('willpowerblessing', { nodef = true,
    def = "You are regenerating willpower at an increased rate."})
  defs_data:set('thermalblessing', { nodef = true,
    def = "You are protected by the power of a Thermal Spiritshield."})
  defs_data:set('earthblessing', { nodef = true,
    def = "You are protected by the power of an Earth Spiritshield."})
if not svo.haveskillset('groves') then
  defs_data:set('harmony', { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are under the blessing of the (\w+) environment\.$]]})
end
  defs_data:set('enduranceblessing', { nodef = true,
    def = "You are regenerating endurance at an increased rate.",})
  defs_data:set('thirdeye', { type = 'general', def = "You possess the sight of the third eye.",
    on = {"You now possess the gift of the third eye.", "You already possess the thirdeye.", "You already possess the gift of the third eye."}})
  defs_data:set('treewatch', { type = 'general',
    mana = 'little',
    def = "You are watching the trees or rigging above for signs of movement.",
    on = {"You begin to keep a watchful eye on the treeline.", "You begin to keep a watchful eye on the rigging."},
    off = "You cease to watch the treeline."})
  defs_data:set('groundwatch', { type = 'general',
    mana = 'little',
    def = "You are aware of movement on the ground.",
    on = {"You begin to keep a watchful eye on the ground below.", "You are already keeping a watchful eye on the ground."},
    off = "You cease keeping a watchful eye on the ground below."})
  defs_data:set('alertness', { type = 'general',
    mana = 'little',
    def = "Your senses are attuned to nearby movement.",
    on = {"You prick up your ears.", "Alertness is already on!", "Your sense of hearing is already heightened."},
    off = {"You cease your watchful alertness.", "Alertness is already off!"}})
  defs_data:set('curseward', { type = 'general',
    def = "A curseward has been established about your person.",
    off = "Your curseward has been breached!",
    on = {"You bring a curseward into being to protect you from harm.", "You already have curseward up."}})
  defs_data:set('bell', { type = 'general',
    on = {"You will now attempt to detect attempts to spy on your person.", "You touch the bell tattoo.", "You already have the bell tattoo defence."},
    def = "You are protected by the bell tattoo."})
  defs_data:set('cloak', { type = 'general',
    on = {"You caress the tattoo and immediately you feel a cloak of protection surround you.", "You are already protected by the cloak tattoo."},
    def = "You are surrounded by a cloak of protection."})
  defs_data:set('favour', { nodef = true,
    ondef = function () return string.format("(%s by %s, %sh)",matches[2],matches[3], matches[4]) end,
    defr = [[^You are (\w+)favoured by (\w+) for over \d+ Achaean month \(which is about (\d+) hours?\)$]] })
  defs_data:set('telesense', { type = 'general',
    mana = 'little',
    def = "You are attuned to local telepathic interference.",
    on = {"You attune your mind to local telepathic interference.", "Your mind is already attuned to local telepathic interference."},
    off = {"Your mind is no longer concentrating on telepathic interference.", "Your mind is already not attuned to local telepathic interference."}})
  defs_data:set('hypersight', { type = 'general',
    mana = 'little',
    def = "You are utilising hypersight.",
    on = {"You concentrate your mind and engage your ability of hypersight.", "You are already concentrating on hypersight."},
    off = {"You cease to concentrate on hypersight.", "You are already not concentrating on hypersight."}})
  defs_data:set('parry', { nodef = true,
    ondef = function ()
      local t = svo.sps.parry_currently
      for limb, _ in pairs(t) do t[limb] = false end
      t[matches[2]] = true
      svo.check_sp_satisfied()

      return "("..matches[2]..")"
    end,
    tooltip = "Completely blocks health and wound damage on a limb if you aren't hindered.",
    defr = [[^You will attempt to parry attacks to your (.+)\.$]]
  })

  defs_data:set('nightsight', { type = 'general',
    def = "Your vision is heightened to see in the dark.",
    on = {"Your vision sharpens with light as you gain night sight.", "Your eyes already have the benefit of night sight."},
    off = {"Your eyes lose the benefit of night sight.", "Your eyes cannot lose the benefit of night sight, since they do not already have it!"}})
  defs_data:set('block', { type = 'general',
    specialskip = function ()
      return (not sys.enabledgmcp) or not (gmcp.Room and gmcp.Room.Info.exits[conf.blockingdir])
    end,
    ondef = function ()
      svo.dict.block.physical.blockingdir = sk.anytoshort(matches[2])
      return "("..svo.dict.block.physical.blockingdir..")"
    end,
    -- the game's word on blocking does not say which way: assume the way
    -- svof blocks, as block's oncompleted does without a direction, so
    -- keepup does not block again to put it right
    ongot = function ()
      local physical = svo.dict.block.physical
      if not physical.blockingdir or physical.blockingdir == "" then physical.blockingdir = conf.blockingdir end
    end,
    defr = [[^You are blocking the exit (.+)\.$]],
    off = {"You stop blocking.", "You were not blocking.", "You cease blocking the exit.", "You begin to flap your wings powerfully, and rise quickly up into the firmament."},
    })
  defs_data:set('targetting', { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    tooltip = "Focuses hits on the targetted limb.",
    defr = [[^You are aiming your attacks to the (.+)\.$]]
  })
  defs_data:set('breath', { type = 'general',
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].meditate then
        svo['def'..whereto][mode].meditate = false
        if echoback then svo.echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].dilation then
        svo['def'..whereto][mode].dilation = false
        if echoback then svo.echof("Removed dilation from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].flame then
        svo['def'..whereto][mode].flame = false
        if echoback then svo.echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].lyre then
        svo['def'..whereto][mode].lyre = false
        if echoback then svo.echof("Removed lyre from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end}) -- added in xml w/ conf.gagbreath
  defs_data:set('vigilance', { type = 'general',
    on = {"You squint your eyes, more alert to potential danger.", "You are already vigilant."},
    mana = 'little',
    def = "You are vigilantly watching for potential danger.",
    off = {"You relax your vigilance.", "You are not maintaining vigilance."}})
  defs_data:set('satiation', { type = 'general',
    invisibledef = true,
    on = {"You begin concentrating on efficient digestion.", "You are already concentrating on efficient digestion."},
    off = "Your digestive efficiency returns to normal."})
  defs_data:set('clinging', { type = 'general',
    on = {"You begin to use your entire body to cleverly cling to the branches of the tree while still maintaining a great deal of freedom of action.","You are already clinging to the trees.", "You must be in the trees to cling to branches, or in the rigging of a ship to cling to the ropes."},
    off = "You cease your clinging behaviour and release the tree.",
    def = {"You are clinging tightly to the trees.", "You are clinging tightly to a ship's rigging."}})
  defs_data:set('selfishness', { type = 'general', def = "You are feeling quite selfish.",
    onenable = function ()
      if conf.serverside and svo.serverignore.selfishness then
        svo.serverignore.selfishness = nil
        svo.echof("Setting Selfishness to be handled by Svof - serverside can't auto-generosity.")
      end

      return true
    end,
    on = {"You rub your hands together greedily.", "You already are a selfish bastard."},
    off = {"A feeling of generosity spreads throughout you.", "No worries. You're not a selfish bastard as is."}})
  defs_data:set('flying', { nodef = true,
    def = "You are soaring high above the ground." })
  defs_data:set('starburst', { nodef = true,
    def = "You are walking with the grace of the stars." })
  defs_data:set('chameleon', { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are assuming the identity of (\w+)\.$]]})
  defs_data:set('insomnia', { type = 'general',
    def = "You have insomnia, and cannot easily go to sleep.",
    -- insomnia curing it is done in trigs as well
    -- "Your insomnia has cleared up.": done in triggers for loki
  })
  defs_data:set('kola', { type = 'general',
    def = "You are feeling extremely energetic." })
  defs_data:set("extra crits", { nodef = true,
    def = "You are surrounded by a lucky green aura."})
  defs_data:set('rebounding', { type = 'general',
    def = "You are protected from hand-held weapons with an aura of rebounding.",
    off = {"Your defensive barriers disappear.", "Your aura of weapons rebounding disappears.", "A small brown lemming rips apart your aura of rebounding defence with its claws.", "The vines rip apart the aura of rebounding surrounding you."},
    offr = {[[^\w+'s cantata shatters the defences surrounding you\.$]], [[^\w+ delivers a single, powerful blow to the aura of rebounding surrounding you, shattering it\.$]], [[^\w+ brings .+? down in a single diagonal stroke, carving cleanly through your aura of rebounding\.$]], [[^\w+ whirls .+? over \w+ head, before bringing it down upon your aura of rebounding, shattering it instantly\.$]], [[^The point of .+? strikes your aura of rebounding, and rapid cracks begin to spread outward from the point of impact\. Moments later, the protection shatters\.$]]}})
  defs_data:set('blind', { type = 'general',
    def = "You are blind." })
  defs_data:set('boar tattoo', { nodef = true,
    def = "The vitality of the boar is energising you."})
  defs_data:set('moss tattoo', { nodef = true,
    def = "Your wounds are being staunched by the moss tattoo."})
  defs_data:set('moon tattoo', { nodef = true,
    def = "Illuminated by the light of the moon."})
  defs_data:set('megalith tattoo', { nodef = true,
    def = "Mentally bolstered by the power of the megalith."})
  defs_data:set('ox tattoo', { nodef = true,
    def = "The endurance of the great ox flows through you."})
  defs_data:set('xp boost', { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are experiencing a (\d+) percent experience boost\.$]] })
  defs_data:set('xp bonus', { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = {[[^You are benefitt?ing from a (\d+)% experience bonus\.$]], [[^You are benefitting from a (\d+)% bonus to experience gain\.$]] }})
  defs_data:set('crit bonus', { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = {[[^You are benefitt?ing from a (\d+)% bonus to critical hits\.$]], [[^You are benefitting from a (\d+)% bonus to critical hits\.$]] }})
  defs_data:set('deaf', { type = 'general',
    def = "You are deaf.",
    off = "The unnatural sound rips through your defences against auditory attacks." })
  defs_data:set("xp gain", { nodef = true,
    def = "You are surrounded by a vibrant white aura." })
  defs_data:set('myrrh', { type = 'general',
    def = "Your mind is racing with enhanced speed." })
  defs_data:set('deathsight', { type = 'general',
    def = "Your mind has been attuned to the realm of Death.",
    on = {"Your mind is already attuned to the realm of Death.", "You shut your eyes and concentrate on the Soulrealms. A moment later, you feel inextricably linked with the realm of Death."},
    onr = "^A miasma of darkness passes over your eyes and you feel a link to the realm of Death,? form in your mind\\.$",
    off = {"You relax your link with the realm of Death.", "You are not linked with the realm of Death."}})
  defs_data:set('mindseye', { type = 'general',
    -- with mindseye up, the blindness and deafness you already have may be
    -- defences rather than afflictions, or the other way round
    ongot = function ()
      if (defc.deaf or affs.deafaff) and ((defdefup[defs.mode].deaf) or (conf.keepup and defkeepup[defs.mode].deaf) or defc.mindseye) then
        defences.got('deaf')
        svo.rmaff('deafaff')
      elseif (defc.deaf or affs.deafaff) then
        defences.lost('deaf')
        svo.addaffdict(svo.dict.deafaff)
      end

      if (defc.blind or affs.blindaff) and ((defdefup[defs.mode].blind) or (conf.keepup and defkeepup[defs.mode].blind)) and (svo.me.class == 'Apostate' or defc.mindseye) then
        defences.got('blind')
        svo.rmaff('blindaff')
      elseif (defc.blind or affs.blindaff) then
        defences.lost('blind')
        svo.addaffdict(svo.dict.blindaff)
      end
    end,
    on = {"Touching the mindseye tattoo, your senses are suddenly heightened.", "You already possess the mindseye defence."},
    def = "Your senses are magically heightened."})
  defs_data:set('lyre', { type = 'general',
    specialskip = function() return not conf.lyre end,
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].meditate then
        svo['def'..whereto][mode].meditate = false
        if echoback then svo.echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].breath then
        svo['def'..whereto][mode].breath = false
        if echoback then svo.echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].dilation then
        svo['def'..whereto][mode].dilation = false
        if echoback then svo.echof("Removed dilation from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = "You deftly shape the wall of light into a barrier surrounding yourself.",
    onr = [[^You strum .+, and a prismatic barrier forms around you\.$]],
    def = "You are standing within a prismatic barrier.",
    off = {"Your prismatic barrier dissolves into nothing.", "The stream hits your prismatic barrier, shattering it.", "The breath weapon rips apart your prismatic barrier.", "The breath weapon rips through both your shield and prismatic barrier.", "The spear shatters your prismatic barrier."}})
  defs_data:set('speed', { type = 'general',
    def = "Your sense of time is heightened, and your reactions are speeded."})
  defs_data:set('frost', { type = 'general', def = "You are tempered against fire damage.",
    -- to a Metamorph, frost is their temperance as well: each comes and goes with the other
    ongot = function () if svo.haveskillset('metamorphosis') then defences.got('temperance') end end,
    onlost = function () if svo.haveskillset('metamorphosis') then defences.lost('temperance') end end,
    on = "A chill runs over your icy skin.",
    off = "Forks of flame lick against your skin, melting away your protection against fire."})
  defs_data:set('venom', { type = 'general', def = "Your resistance to damage by poison has been increased.",
    on = "You feel a momentary dizziness as your resistance to damage by poison increases."})
  defs_data:set('levitation', { type = 'general', def = "You are walking on a small cushion of air.",
    on = {"Your body begins to feel lighter and you feel that you are floating slightly.", "Your body grows light and buoyant as you touch the feather tattoo, and you begin hovering above the ground."}})
  defs_data:set('caloric', { type = 'general',
    def = "You are coated in an insulating unguent."})
  defs_data:set('sileris', { type = 'general',
    def = "You are protected from the fangs of serpents."})
  defs_data:set('chargeshield', { nodef = true,
    def = "You are surrounded by a non-conducting chargeshield."})
  defs_data:set('meditate', { type = 'general',
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].breath then
        svo['def'..whereto][mode].breath = false
        if echoback then svo.echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].dilation then
        svo['def'..whereto][mode].dilation = false
        if echoback then svo.echof("Removed dilation from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].flame then
        svo['def'..whereto][mode].flame = false
        if echoback then svo.echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].lyre then
        svo['def'..whereto][mode].lyre = false
        if echoback then svo.echof("Removed lyre from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = "You close your eyes, bow your head, and empty your mind of all thought.",
    off = {"You snap your head up as you break your meditation.", "You cease your meditation having achieved full will and mana."}})
  defs_data:set('shield', { type = 'general',
    on = {"You touch the tattoo and a nearly invisible magical shield forms around you.", "You bid your guardian angel to raise an aura to shield you."},
    onr = [[^(\w+)'s angel surrounds you with a protective shield\.$]],
    off = {"Your movement causes your magical shield to dissipate.", "The breath weapon rips through your shield.", "The point of the weapon comes to a sudden stop as its tip impacts your magical shield. Originating at the point of impact, fractures spread across the barrier before it shatters.", "Your action causes the nearly invisible magical shield around you to fade away.", "The stream hits your magical shield, shattering it.", "The spout of molten lava surges against your shield, which shatters under the intense force and heat.", "Your defensive barriers disappear.", "A glowing spear comes flying in towards you. The spear shatters your shield.", "The breath weapon rips through both your shield and prismatic barrier.", "With a mad cackle, a gremlin leaps at you and batters your shield with a flurry of blows, fracturing it in moments.", "A dissonant tone shatters the magical shield surrounding you."},
    offr = {[[^\w+ razes your magical shield with ]],
        [[^A massive, translucent hammer rises out of .+'s tattoo and smashes your magical shield\.]],
        [[^\w+'s cantata shatters your magical shield\.$]],
        [[^The meteor, shot by \w+, slams into your shield, shattering it\.$]],
        [[^\w+ flays away your shield defence\.$]],
        [[^\w+ sends myriad russet streams towards you, shattering your shield\.$]],
        [[^\w+'s cantata shatters the defences surrounding you\.$]],
        [[^\w+'s many heads lash out around you, shattering your protective shield\.$]],
        [[^\w+ delivers a single, powerful blow to the magical shield surrounding you, shattering it\.$]],
        [[^\w+ continues \w+ assault, coming around for a second blow that scythes straight through your magical shield\.$]],
        [[^\w+ brings .+? down in a single diagonal stroke, carving cleanly through your magical shield\.$]],
        [[^\w+ continues \w+ attack, coming back around with a bone rattling blow with .+? that causes your magical shield to explode in a shower of twinkling shards\.$]],
        [[^\w+ whirls .+ over \w+ head, before bringing it down upon your magical shield, shattering it instantly\.$]],
        [[^\w+ summons a blade of condensed air and shears cleanly through the magical shield surrounding you\.$]],
        [[^The shadow of \w+ suddenly comes alive, leaping forward to hammer at your shield in a silent frenzy of blows\. Your protection lasts mere moments before exploding in a shower of prismatic shards\.$]],
    },
    def = "You are surrounded by a nearly invisible magical shield."})
  defs_data:set('riding', { type = 'general',
    specialskip = function() return defc.dragonform or string.find(svo.me.class, "Elemental") end,
    ondef = function ()
      if tostring(conf.ridingsteed) and tostring(conf.ridingsteed):match("([A-Za-z]+)") and string.find(matches[2], tostring(conf.ridingsteed):match("([A-Za-z]+)"), nil, true) then
        return "("..tostring(conf.ridingsteed):match("([A-Za-z]+)")..")"
      else
        return "("..matches[2]..")"
      end
    end,
    defr = [[^You are riding (.+)\.$]],
    onr = {[[^You climb up on .+\.$]], [[^You easily vault onto the back of .+\.$]]},
    on = {"You step aboard the chariot and firmly grasp the reins."},
    offr = {[[^You step down off of .+\.$]], [[^You lose purchase on .+\.$]], [[^\w+ waves \w+ palm in your direction, and you can only watch as your surroundings dissolve and fade from existence\.$]], [[^You feel your blessed soul drawn toward \w+ as you are delivered out of harm's way\.$]], [[^\w+ steps into the attack, grabs your arm, and throws you violently to the ground\.$]], [[^You feel a strong tug in the pit of your stomach\. Your surroundings dissolve into the featureless swirl of the ether, resolving once more into a recognisable landscape as you land before \w+\.$]]},
    off = {"You are not currently riding anything.", "You are not currently riding that.", "You must be mounted to trample.", "You are thrown from the room by the sheer force of the fiery blast.", "You're drawn screaming into its hellish maw.", "The ring of shining metal carries you up into the skies.", "You clamber off of your mount.","You need to be riding a proper mount to gallop.", "You call upon your dark power, and instantly a black wind descends upon you. In seconds your body begins to dissipate, and you are one with the odious vapour.", "You vaguely make out a large, square doorway of light and you step through it."}})

if not svo.haveskillset('groves') then
  defs_data:set("grove vigour", { nodef = true,
    def = "You are bathed in an aura of radiant sunlight."})
end

-- Dragoncraft: everyone gets it
  defs_data:set('dragonform', { type = 'dragoncraft',
    offline_defence = true,
    invisibledef = true,
    stays_on_death = true,
    on = "You already maintain the form of the Dragon.",
    off = "Your draconic form melts away, leaving you suddenly weaker and more vulnerable." })
  defs_data:set('dragonarmour', { type = 'dragoncraft',
    specialskip = function() return not defc.dragonform end,
    def = "You are surrounded by draconic armour.",
    off = "You relax your draconic armour.",
    on = {"With a low rumbling from deep within your belly, you beseech Ashaxei for protection. Your skin ripples as a web of crackling magical energy dances like fire across its surface, settling to solidify into a flexible, translucent shell.", "You are already surrounded by draconic armour, Wyrm."}})
  defs_data:set('dragonbreath', { type = 'dragoncraft',
    specialskip = function() return not defc.dragonform end,
    def = "You have summoned your draconic breath weapon.",
    off = {"You have not summoned your breath weapon.", "As the strain on your inflated lungs reaches extremity, you open your glistening, tooth-lined maw wide and rain a great tempest of venom down upon the ground below."},
    offr = {[[^As the strain on your inflated lungs reaches extremity, you open your glistening, tooth-lined maw wide and rain .+]], [[^Focusing your breath into a concentrated stream, you direct a blast of]], [[^Opening your great maw, you unleash an overpowering blast of flesh-searing lightning at .+, whose body goes rigid as \w+ screams in agony\.$]], [[^Opening your dragon's mouth to its fullest, you blast .+ with your toxic wrath, damaging \w+ very essence\.$]], [[^Opening your massive maw, you throw your head forward and blast wave after wave of deadly, all-consuming cold at .+\.$]], [[^Opening your maw, you force out a tremendous stream of acid, blasting the flesh from the very bones of .+\.$]], [[^Drawing a mighty breath to fill your lungs, you crane your neck backwards and send a screaming volley of \w+-infused vapour into the air\.$]], [[^You rear back your head, and with a keening roar unleash incandescent hell upon]], [[^With a roar of triumph, you unleash a cataclysm of crushing psi energy, laying waste to .+'s mind\.]], [[^Summoning a torpid cloud of \w+ deep within your belly, you expel your breath toward]] }})

if svo.haveskillset('necromancy') then
  defs_data:set('deathsight', { type = 'necromancy',
    staysindragon = true,
    availableindragon = true,
    def = "Your mind has been attuned to the realm of Death.",
    on = {"Your mind is already attuned to the realm of Death.", "You shut your eyes and concentrate on the Soulrealms. A moment later, you feel inextricably linked with realm of Death."},
    onr = "^A miasma of darkness passes over your eyes and you feel a link to the realm of Death,? form in your mind\\.$",
    off = {"You relax your link with the realm of Death.", "You are not linked with the realm of Death."}})
  defs_data:set('soulcage', { type = 'necromancy',
    staysindragon = true,
    offline_defence = true,
    on = {"Your soul is already protected by the soulcage.", "You lower the barrier between your spirit and the soulcage.", "You begin to spin a web of necromantic power about your soul, drawing on your vast reserves of life essence. Moment by moment the bonds grow stronger, until your labours are complete. Your soul is entirely safe from harm, fortified in a cage of immortal power."},
    off = {"You have not caged your soul in life essence.", "You carefully raise a barrier between your spirit and the soulcage.", "As you feel the last remnants of strength ebb from your tormented body, you close your eyes and let darkness embrace you. Suddenly, you feel your consciousness wrenched from its pitiful mortal frame and your soul is free. You feel your form shifting, warping and changing as you whirl and spiral outward, ever outward. A jolt of sensation awakens you, and you open your eyes tentatively to find yourself trapped within a physical body once more."},
    onr = [[^You may not use soulcage for another \d+ Achaean day\(s\)\.$]],
    def = "Your being is protected by the soulcage."})
  defs_data:set('deathaura', { type = 'necromancy',
    on = {"You let the blackness of your soul pour forth.", "You already possess an aura of death."},
    def = "You are emanating an aura of death.",
    off = "Your aura of death has worn off."})
  defs_data:set('shroud', { type = 'necromancy',
    on = {"Calling on your dark power, you draw a thick shroud of concealment about yourself to cover your every action.", "You draw a Shadowcloak about you and blend into your surroundings.", "You draw a cloak of the Blood Maiden about you and blend into your surroundings."},
    def = "Your actions are cloaked in secrecy.",
    off = {"Your shroud dissipates and you return to the realm of perception.", "The flash of light illuminates you - you have been discovered!"}})
  defs_data:set('lifevision', { type = 'necromancy',
    on = {"You narrow your eyes and blink rapidly, enhancing your vision to seek out sources of lifeforce in others.", "You already possess enhanced vision."},
    def = "You have enhanced your vision to be able to see traces of lifeforce."})
  defs_data:set('putrefaction', { type = 'necromancy',
    on = {"You concentrate for a moment and your flesh begins to dissolve away, becoming slimy and wet.", "You have already melted your flesh. Why do it again?"},
    def = "You are bathed in the glorious protection of decaying flesh.",
    off = "You concentrate briefly and your flesh is once again solid."})
  defs_data:set('vengeance', { type = 'necromancy',
    staysindragon = true,
    offline_defence = true,
    on = {"You swear to yourself that you will wreak vengeance on your slayer.", "Vengeance already burns within your heart, Necromancer."},
    def = "You have sworn vengeance upon those who would slay you.",
    off = {"You forswear your previous oath for vengeance, sudden forgiveness entering your heart.", "You have sworn vengeance against none, Necromancer."}})
end
if svo.haveskillset('oppression') then
  defs_data:set('deathaura', { type = 'oppression',
    on = {"You let the blackness of your soul pour forth.", "You already possess an aura of death."},
    def = "You are emanating an aura of death.",
    off = "Your aura of death has worn off."})
end
if svo.haveskillset('discipline') then
  defs_data:set('weathering', { type = 'discipline',
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set('fury', { type = 'discipline',
    on = {"Your eyes rage with fury.", "You're already raged with fury!", "Too much fury in a day is unhealthy!"},
    off = {"You suddenly lose the fury in your eyes.", "You are already calm and not feeling any fury."},
    def = "Fury rages in your eyes."})
  defs_data:set('sturdiness', { type = 'discipline',
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you."})
  defs_data:set('grip', { type = 'discipline',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set('resistance', { type = 'discipline',
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
end
if svo.haveskillset('malignity') then
  defs_data:set('weathering', { type = 'malignity',
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set('fury', { type = 'malignity',
    on = {"Your eyes rage with fury.", "You're already raged with fury!", "Too much fury in a day is unhealthy!"},
    off = {"You suddenly lose the fury in your eyes.", "You are already calm and not feeling any fury."},
    def = "Fury rages in your eyes."})
  defs_data:set('sturdiness', { type = 'malignity',
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you."})
  defs_data:set('grip', { type = 'malignity',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set('resistance', { type = 'malignity',
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
end
if svo.haveskillset('valour') then
  defs_data:set('weathering', { type = 'valour',
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set('fury', { type = 'valour',
    on = {"Your eyes rage with fury.", "You're already raged with fury!", "Too much fury in a day is unhealthy!"},
    off = {"You suddenly lose the fury in your eyes.", "You are already calm and not feeling any fury."},
    def = "Fury rages in your eyes."})
  defs_data:set('sturdiness', { type = 'valour',
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you."})
  defs_data:set('grip', { type = 'valour',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set('resistance', { type = 'valour',
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
end
if svo.haveskillset('dominion') then
  defs_data:set('weathering', { type = 'dominion',
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set('fury', { type = 'dominion',
    on = {"Your eyes rage with fury.", "You're already raged with fury!", "Too much fury in a day is unhealthy!"},
    off = {"You suddenly lose the fury in your eyes.", "You are already calm and not feeling any fury."},
    def = "Fury rages in your eyes."})
  defs_data:set('sturdiness', { type = 'dominion',
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you."})
  defs_data:set('grip', { type = 'dominion',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set('resistance', { type = 'dominion',
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
end

if svo.haveskillset('evileye') then
  defs_data:set('truestare', { type = 'evileye',
    on = {"A sharp pain spikes through your skull, before settling into a dull throbbing just behind your eyes.", "You are already enhancing your ocular prowess. Lost: Your truestare defence erodes away."},
    def = "You are enhancing your ocular prowess."})
end

if svo.haveskillset('weaponmastery') then
  defs_data:set('deflect', { type = 'weaponmastery',
    on = "You will now attempt to deflect arrows toward less vital areas.",
    def = "You are attempting to deflect arrows toward less vital areas."})
  defs_data:set('mastery', { type = 'weaponmastery',
    on = {"You have begun exercising true mastery of the blades through superior concentration.", "You already have mastery on."},
    def = "You are concentrating on mastery of bladecraft.",
    off = "You relax your mastery of the blades a bit, finding it too taxing to maintain."})
end

if svo.haveskillset('shindo') then
  defs_data:set('weathering', { type = 'shindo',
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set('sturdiness', { type = 'shindo',
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you." })
  defs_data:set('toughness', { type = 'shindo',
    def = "Your skin is toughened.",
    on = "Flexing your muscles, you concentrate on forcing unnatural toughness over the surface of your skin."})
  defs_data:set('clarity', { type = 'shindo',
    on = {"You are already concentrating on a clearer awareness of your environs.", "As you focus upon your visual field, the shadows grow faint, details become pronounced, and the world seems somehow more real."},
    def = "You are seeing the world around you with greater clarity of vision." })
  defs_data:set('mindnet', { type = 'shindo',
    on = {"You cast an invisible mind net out into the distance, allowing it to settle about the surrounding land.", "Extending your well-trained senses, you focus upon the movements of others nearby.", "You already have mindnet active."},
    def = "You have cast a mindnet over the local area.",
    off = "You cease concentration and your mind net vanishes."})
  defs_data:set('constitution', { type = 'shindo',
    def = "You are using your superior constitution to prevent nausea.",
    on = {"You clench the muscles in your stomach, determined to svo.assert your superior constitution.", "You are using your superior constitution to prevent nausea."}})
  defs_data:set('waterwalk', { type = 'shindo',
    def = "You are poised to glide across the surface of water.",
    on = {"You are already poised to glide across the surface of water.", "Dancing lightly on your feet, you prepare to run across the surface of water."}})
  defs_data:set('shintrance', { type = 'shindo',
    on = {"You are already focused upon gaining shindo energy.", "You centre your focus inwards, slowly opening yourself up to the energy of Shindo."},
    off = "You break out of the Shin Trance, sighing as you feel your accumulated Shin energy vanish.",
    def = "You are deep within the Shin trance."})
  defs_data:set('consciousness', { type = 'shindo',
    def = "You are maintaining consciousness at all times.",
    off = {"You are not maintaining consciousness.", "You will no longer concentrate on retaining full consciousness."},
    on = {"You are already maintaining consciousness.", "You will remain conscious at all times."}})
  defs_data:set('bind', { type = 'shindo',
    on = {"You bind Shin energy to your form, willing your body to accept its restorative power.", "You are already binding Shin energy."},
    def = "You are diverting excess Shin energy into regeneration.",
    off = "You cease binding excess Shin energy towards regeneration."})
  defs_data:set('projectiles', { type = 'shindo',
    def = "You are alert to incoming projectiles.",
    off = {"You cease your watch for projectiles.", "You are not watching for projectiles."},
    on = "You look about sharply, poised to avoid all incoming projectiles."})
  defs_data:set('dodging', { type = 'shindo',
    on = "You resolve to keep an eye on the skies for danger.",
    def = "You are watching the skies for danger.",
    off = {"You are not using Shindo Dodging.", "You cease watching the skies."}})
  defs_data:set('grip', { type = 'shindo',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set('immunity', { type = 'shindo',
    on = "You close your eyes and grit your teeth, feeling the heat of the blood pumping through your veins.",
    off = "You cease concentrating on immunity."})
end

if svo.haveskillset('twoarts') then
  defs_data:set('retaliationstrike', { type = 'twoarts',
    def = "You are performing retaliatory strikes against your attackers.",
    off = "You will no longer strike in retaliation.",
    onr = [[Grasping the hilt of \w+ \w+, you prepare to counterattack when the opportunity arises\.$]]})
  defs_data:set('doya', { type = 'twoarts',
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Lowering your centre of gravity, you drop into the Doya stance.",
    def = "You are in the Doya stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{'thyr', 'mir', 'arash', 'sanya', 'doya'} do
        if stance ~= newdef and svo['def'..whereto][mode][stance] then
          svo['def'..whereto][mode][stance] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.thyr or defc.mir or defc.arash or defc.sanya)
    end })
  defs_data:set('thyr', { type = 'twoarts',
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Readying yourself with a flourish, you flow into the Thyr stance.",
    def = "You are in the Thyr stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{'thyr', 'mir', 'arash', 'sanya', 'doya'} do
        if stance ~= newdef and svo['def'..whereto][mode][stance] then
          svo['def'..whereto][mode][stance] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.doya or defc.mir or defc.arash or defc.sanya)
    end })
  defs_data:set('mir', { type = 'twoarts',
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Resolving to move as water, you enter the Mir stance.",
    def = "You are in the Mir stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{'thyr', 'mir', 'arash', 'sanya', 'doya'} do
        if stance ~= newdef and svo['def'..whereto][mode][stance] then
          svo['def'..whereto][mode][stance] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.thyr or defc.doya or defc.arash or defc.sanya)
    end })
  defs_data:set('arash', { type = 'twoarts',
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Mind set on the dancing flame, you take up the Arash stance.",
    def = "You are in the Arash stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{'thyr', 'mir', 'arash', 'sanya', 'doya'} do
        if stance ~= newdef and svo['def'..whereto][mode][stance] then
          svo['def'..whereto][mode][stance] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.thyr or defc.mir or defc.doya or defc.sanya)
    end })
  defs_data:set('sanya', { type = 'twoarts',
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Clearing your mind, you sink into the Sanya stance.",
    def = "You are in the Sanya stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{'thyr', 'mir', 'arash', 'sanya', 'doya'} do
        if stance ~= newdef and svo['def'..whereto][mode][stance] then
          svo['def'..whereto][mode][stance] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.thyr or defc.mir or defc.arash or defc.doya)
    end })
end

if svo.haveskillset('subterfuge') then
  defs_data:set('phase', { type = 'subterfuge',
    on = {"A short burst of azure light fills your vision and when it is gone, you find yourself phased out of sync with the rest of reality." , "You are already phased!"},
    def = "Phased slightly out of reality, you are effectively untouchable.",
    off = {"There's a flash of light and you're pulled back into phase with reality." , "Your surroundings shatter into a cloud of glowing stars which dissipate to leave you back where you began." , "You are suddenly and unexpectedly pulled back into phase with reality."}})
  defs_data:set('hiding', { type = 'subterfuge',
    on = {"You conceal yourself using all the guile you possess.", "You are already hidden.", "Too many prying eyes prevent you from finding a suitable hiding place."},
    def = "You have used great guile to conceal yourself.",
    off = {"You emerge from your hiding place.","You are discovered!","The flash of light illuminates you - you have been discovered!", "From what do you wish to emerge?"}})
  defs_data:set('scales', { type = 'subterfuge',
    on = {"You concentrate and slowly your body is covered by protective, serpentine scales.","You are already covered in protective, serpentine scales."},
    def = "Serpentine scales protect your body.",
    off = "You ripple your muscles and as you watch, your skin turns white and peels off, taking your protective scaling with it."})
  defs_data:set('pacing', { type = 'subterfuge',
    on = {"You begin to pace yourself and prepare for sudden bursts of exertion.","You are already pacing."},
    def = "You are paced for bursts of exertion.",
    off = "You are no longer pacing yourself."})
  defs_data:set('bask', { type = 'subterfuge',
    on = {"You lie down and stretch yourself out, ready to bask beneath the blazing sun.", "The stresses and strains of existence gradually fall from you.", "The rays of sunlight spread a healing warmth through your body."},
    def = "Your blood is being heated by the sun.",
    off = "You rise to your feet."})
  defs_data:set('listen', { type = 'subterfuge',
    onr = [[^You listen intently to the (.+)\.$]],
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].eavesdrop then
        svo['def'..whereto][mode].eavesdrop = false
        if echoback then svo.echof("Removed eavesdrop from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    def = "You are listening in on another conversation.",
    specialskip = function ()
      return (defc.eavesdrop)
    end
    })
  defs_data:set('eavesdrop', { type = 'subterfuge',
    onr = [[^You listen intently to the (.+)\.$]],
    def = "You are listening in on another conversation."}) --this ability completely replaces listen
  defs_data:set('lipread', { type = 'subterfuge',
    on = {"You will now lip read to overcome the effects of deafness.", "You are already lipreading."},
    def = "You are lipreading to overcome deafness.",
    specialskip = function()
      return (not mindseye or (defc.blind or affs.blindaff))
    end })
  defs_data:set('weaving', { type = 'subterfuge',
    mana = 'lots',
    on = {"You picture a cobra in your mind, and slowly begin to weave back and forth agilely.", "You are already imitating the cobra."},
    def = "Cobra-like, you are weaving back and forth to dodge blows.",
    off = "You cease your cobra-like weaving.",  --this vanishes when mana is 0 without a message, just like alertness
    })
  defs_data:set('cloaking', { type = 'subterfuge',
    on = "You toss a sparkling cloud of dust over yourself and as it settles you shimmer into invisibility.",
    def = "Your actions are cloaked in secrecy.",
    off = {"You dispel all illusion magics that were woven about yourself.","Your shroud dissipates and you return to the realm of perception."},
    -- not compatible with ghost per Alyssea
    offr = [[^\w+ points a finger at you and you feel anti-magic sweep over you\.$]] })
  defs_data:set('ghost', { type = 'subterfuge',
    on = "You project a net of light about yourself until your image becomes faded and ghostly.",
    def = "You are shimmering with a ghostly light.",
    off = {"You dispel all illusion magics that were woven about yourself.", "Your ghostly image slowly intensifies until you appear flesh and blood again."},
    offr = [[^\w+ points a finger at you and you feel anti-magic sweep over you\.$]], })
  defs_data:set('secondsight', { type = 'subterfuge',
    on = {"You narrow your eyes, allowing your vision to extend beyond the normal spectrum.", "You already possess the second sight."},
    def = "You are able to detect wormholes due to possessing the second sight.",})
end

if svo.haveskillset('swashbuckling') then
  defs_data:set('drunkensailor', { type = 'swashbuckling',
    on = {"You start swaying to and fro seemingly unpredictably as you enter the stance of the Drunken Sailor.", "You are already in the stance of the Drunken Sailor."},
    def = "The Drunken Sailor stance protects you.",
    off = "You relax into your normal fighting stance.",
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].heartsfury then
        svo['def'..whereto][mode].heartsfury = false
        if echoback then svo.echof("Removed heartsfury from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    specialskip = function ()
      return (defc.heartsfury)
    end})
  defs_data:set('arrowcatch', { type = 'swashbuckling',
    mana = 'lots',
    on = {"You have begun to look for arrows to pluck from the air.", "You already have arrowcatching on."},
    def = "You are attempting to pluck arrows from the air.",
    off = "You've turned off arrowcatching."})
  defs_data:set('balancing', { type = 'swashbuckling',
    mana = 'lots',
    on = {"You move onto the balls of your feet and begin to concentrate on balance.", "You're already balancing."},
    def = "You are balancing on the balls of your feet.",
    off = "You cease to balance on the balls of your feet."})
  defs_data:set('acrobatics', { type = 'swashbuckling',
    on = {"You begin leaping and bouncing about, making it more difficult to hit you.", "You are already bouncing around acrobatically."},
    def = "You are bouncing around acrobatically.",
    off = "You cease your acrobatic leaping and bouncing."})
  defs_data:set('dodging', { type = 'swashbuckling',
    on = {"You resolve to keep an eye on the skies for danger.", "You are already watching the skies."},
    def = "You are watching the skies for danger.",
    off = "You cease watching the skies."})
  defs_data:set('grip', { type = 'swashbuckling',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set('heartsfury', { type = 'swashbuckling',
    on = {"Taut with rage, you enter the Heart's Fury stance.", "You are already in the Heart's Fury stance."},
    def = "The Heart's Fury stance protects you.",
    off = "You relax into your normal fighting stance.",
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].drunkensailor then
        svo['def'..whereto][mode].drunkensailor = false
        if echoback then svo.echof("Removed drunkensailor from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    specialskip = function ()
      return (defc.drunkensailor)
    end})

  --[[trueparry = { type = 'swashbuckling',
    on = "You will now attempt to parry attacks on your arms", --arms replaceable with legs/centre/right/left
    def = {"You will attempt to parry attacks to your left arm.", "You will attempt to parry attacks to your right arm."} --DEF shows both limbs being parried when trueparrying
    off = "You cease your attempts at parrying."]]
end

if svo.haveskillset('voicecraft') then
  defs_data:set('lay', { type = 'voicecraft',
    on = {"You sing a powerful Lay of distortion, protecting against the creation of physical images of yourself.", "You sing a powerful Lay of distortion."},
    def = "You are protected from the creation of physical images of yourself.",
    offr = [[^Your Lay of distortion is destroyed by \w+'s attempted fashion\.$]]})
  defs_data:set('tune', { type = 'voicecraft',
    on = "Singing a powerful tune of safety and protection, you weave musical defences around yourself.",
    def = "You are protected from damage by a tune of safety."})
  defs_data:set('songbird', { type = 'voicecraft',
    on = {"Lifting your head, you whistle an intricate, lilting tune. You are soon answered by a blue-feathered songbird that wings swiftly in and perches upon your shoulder.", "Your songbird twitters upon your shoulder, reminding you of its presence."},
    def = "A songbird is perched upon your shoulder.",
    off = "With a final chirp, the songbird upon your shoulder takes flight and wings swiftly away."})
  defs_data:set('aria', { type = 'voicecraft',
    on = {"Your voice rises to the heavens with your instrument as you sing an Aria of healing to yourself.", "Your voice rises to the heavens with your instrument, but without your audience, as you sing an Aria of healing to yourself."},
    def = "Your health is enhanced by the beauties of an Aria.",
    off = "The heavenly strains of the Aria slowly fall silent."})
end

if svo.haveskillset('harmonics') then
  defs_data:set('lament', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "Slowly you take up the dark and sombre tones of a Lament.",
    off = "A burdensome sense of oppression lifts as the Lament arrives at its mournful conclusion."})
  defs_data:set('anthem', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "An Anthem fills the air with its mighty fortress of protective influences as you take up its stately music.",
    off = "The structure of protection afforded by the Anthem decays with the final notes of the composition."})
  defs_data:set('harmonius', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "Blending several seemingly distinct musical ideas into one majestic whole, you begin the Harmonius.",
    off = "The individual strands blended by the Harmonius slowly disintegrate into cacophony as the song ends."})
  defs_data:set('contradanse', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "An elaborate Contradanse melody begins to pervade the room.",
    off = "Melody slows, simplifies, and comes to an end, terminating the elaborate Contradanse."})
  defs_data:set('paxmusicalis', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "You experience true rest and relief as you gently enter into the first soothing passage of the Pax Musicalis.",
    off = "The peaceful strains of the Paxmusicalis slowly fade to silence."})
  defs_data:set('gigue', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "You dash off a few bars, launching into the detailed patterns of a Gigue.",
    off = "Your thoughts return to their normal order as the Gigue's airs fade from the room."})
  defs_data:set('bagatelle', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "Through a series of musical twists and turns you begin the Bagatelle.",
    off = "Twisting and turning no more, the Bagatelle ends suddenly."})
  defs_data:set('partita', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "Delicate and precise, you take up a Partita.",
    off = "The Partita ends without fanfare, precisely as it began."})
  defs_data:set('berceuse', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "You begin a delicate Berceuse, playing with great tenderness.",
    off = "The Berceuse drifts faintly away as its final notes float softly through the area."})
  defs_data:set('continuo', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "Your feelings rise with a Continuo's opening movement.",
    off = "The Continuo falters and dies and, along with it, the thrilling feeling it had brought."})
  defs_data:set('wassail', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "The Wassail's first notes stir and strengthen you.",
    off = "The Wassail trails slowly off, coming to a melancholy conclusion."})
  defs_data:set('canticle', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "You enter into the realms of the divine as you play the opening strains of a sacred Canticle.",
    off = "The instabilities of the world again impinge upon you as the Canticle draws to a close."})
  defs_data:set('reel', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "With a hop you enter into the complex, up-tempo dance melody of a Reel.",
    off = "The Reel comes around again, sounding as though ready to begin another step, and suddenly stops."})
  defs_data:set('hallelujah', {type = 'harmonics', custom_def_type = 'harmonic',
    on = "With a powerful fanfare, you begin a resounding Hallelujah.",
    off = "The Hallelujah's final amen fills you with awe at its power, and sorrow for the ending of this uplifting piece."})
end

if svo.haveskillset('devotion') then
  defs_data:set('inspiration', { type = 'devotion',
    on = {"You bow your head and, praying to the gods for inspiration, you are soon rewarded as your body is suffused with strength."},
    def = "Your limbs are suffused with divinely-inspired strength.",
    off = "You slump slightly as the divinely-inspired strength leaves your body." })
  defs_data:set('bliss', { type = 'devotion',
    staysindragon = true,
    on = {"You pour blessings of bliss over yourself, granting visions of the majesty of the divine.", "The divine choir lingers on in your mind, and your spirit soars.", "That person is already experiencing bliss."},
    onr = [[^(\w+) pours blessings over you, and divine choirs begin to sing joyously at the edge of your hearing\.]],
    invisibledef = true })
  defs_data:set('bloodsworn', { type = 'devotion',
    onr = [[^You are bloodsworn to \w+\.$]],
    on = "The true power of the bloodsworn begins to rage in your veins.",
    invisibledef = true,
    off = "The power of the bloodsworn leaves you." })
end

if svo.haveskillset('spirituality') then
  defs_data:set('mace', { type = 'spirituality',
    invisibledef = true})
  defs_data:set('heresy', { type = 'spirituality',
    def = "You are hunting heretics.",
    off = "Your rage to destroy heretics subsides.",
    on = {"Rage fills you as the thought of heresy inspires you to greater efforts.", "You are already hunting the heretics."}})
  defs_data:set('summon', { type = 'spirituality',
    def = "You are regenerating endurance at an increased rate.",
    custom_def_type = 'angel',
    off = {"The light of the guardian angel dims quietly out of existence.", "Your guardian angel must be visible before you can communicate with her.", "Your guardian angel shimmers silently away."},
    on = {"A flower of white light blooms in the air beside you, and your guardian is by your side.", "You feel confusion radiate from your guardian, who hovers already at your side."}})
  defs_data:set('empathy', { type = 'spirituality',
    specialskip = function() return not defc.summon end,
    off = {"You stop using your guardian angel's empathic link.", "You're not using your guardian angel's empathic link.", "Your empathic link with your angel is severed."},
    custom_def_type = 'angel',
    on = {"A feeling of deep peace fills you as your fate is bound with that of your guardian angel.", "Your guardian informs you sadly that she lacks the power to obey your command."}})
  defs_data:set('care', { type = 'spirituality',
    specialskip = function() return not defc.summon end,
    off = {"Your guardian angel ceases healing your afflictions.", "Your guardian angel is not currently healing your afflictions.", "Your guardian ceases to pass on her care."},
    custom_def_type = 'angel',
    on = {"Your guardian angel begins to shimmer with a soft red light.", "Your guardian informs you sadly that she lacks the power to obey your command."}})
  defs_data:set('watch', { type = 'spirituality',
    on = "You bid your angel to watch over you.",
    off = {"You order your angel to cease tracking the movements of your enemies.", "Your guardian angel is not currently watching your enemies.", "Your guardian ceases to watch."},
    custom_def_type = 'angel',
    })
end

if svo.haveskillset('metamorphosis') then
  defs_data:set('affinity', { type = 'metamorphosis',
    on = {"You are already embracing the spirit that dwells within you.", "You embrace the spirit that dwells within you and are overcome with the joy of true unity."},
    def = "You have a great affinity with your spirit form." })
    --general meta ability,

  defs_data:set('bonding', { type = 'metamorphosis',
    on = {"You are already bonding with the spirits, Metamorph.", "Your soul draws inexorably closer to its spirit host as the spiritual bonding magic works about you."},
    def = "You are bonded to your spirit totem.",
    off = {"Your soul is not under the influence of a spiritual bond to its spirit host", "You shiver briefly as the spiritual bonding of your soul to its spirit host ends."}})
    --general meta ability

  defs_data:set('elusiveness', { type = 'metamorphosis',
    specialskip = function() return not sk.morphsforskill.elusiveness end,
    on = {"You are already watching for pursuit.", "Your eyes flicker this way and that as you watch for pursuers."},
    def = "You are alert to those who would pursue you.",
    off = {"You are not watching for pursuers, Metamorph.", "You cease watching for pursuit."},
    })
    --Basilisk, Hyena, Wolverine, Jaguar

  defs_data:set('flame', { type = 'metamorphosis',
    specialskip = function() return not sk.morphsforskill.flame end,
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'hydra'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end
      return true
    end,
    invisibledef = true,
    on = {"You take a deep breath and realise your error - you sputter and engulf yourself in fire!", "You take a deep breath and feel the heat begin to build within you.", "You may now breathe yellow fire.", "You may now breathe blue fire.","You may now breathe white fire.", "With a roar you channel your reserves into your inner flame, instantly summoning forth a raging inferno.","You are already summoning your flame.",},
    offr = [[^You inhale deeply, allowing the raging flames to build up inside you. With an earth-shaking roar, you release a white-hot jet of fire directly at \w+\.$]],
    off = {"You can not relax a flame that you have not yet summoned.","A small gout of fire erupts harmlessly from your mouth.", "You take a deep breath and realise your error - you sputter and engulf yourself in fire!", "Unleashing white-hot flames in a reckless burst of fire, you create a roaring inferno about your person.", "Your inner fire does not burn with sufficient intensity, Metamorph.", "You take a deep breath and realise your error - you splutter and engulf yourself in fire!"},
    })
    --Wyvern, Basilisk

  defs_data:set('lyre', { type = 'metamorphosis',
    specialskip = function() return not conf.lyre or not sk.morphsforskill.lyre end,
    availableindragon = true,
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].meditate then
        svo['def'..whereto][mode].meditate = false
        if echoback then svo.echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].breath then
        svo['def'..whereto][mode].breath = false
        if echoback then svo.echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].flame then
        svo['def'..whereto][mode].flame = false
        if echoback then svo.echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = {"You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.", "You strum a Lasallian lyre, and a prismatic barrier forms around you.", "You deftly shape the wall of light into a barrier surrounding yourself.", "You strum a darkly glowing mandolin, and a prismatic barrier forms around you."},
    def = "You are standing within a prismatic barrier.",
    off = {"Your prismatic barrier dissolves into nothing.", "The stream hits your prismatic barrier, shattering it.", "The breath weapon rips apart your prismatic barrier.", "The breath weapon rips through both your shield and prismatic barrier.", "The spear shatters your prismatic barrier."}})
    --Nightingale Only

  -- defs_data:set('nightsight', { type = 'metamorphosis',
  --   specialskip = function() return not sk.morphsforskill.nightsight end,
  --   on = "Your vision sharpens with light as you gain night sight.",
  --   def = "Your vision is heightened to see in the dark.",
  --   off = "Your eyes lose the benefit of night sight.",
  --   })
    --Wildcat, Wolf, Cheetah, Owl, Hyena, Condor, Wolverine, Jaguar, Eagle, Icewyrm, Wyvern, Hydra

  defs_data:set('rest', { type = 'metamorphosis',
    specialskip = function() return not sk.morphsforskill.rest end,
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].flame then
        svo['def'..whereto][mode].flame = false
        if echoback then svo.echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = {"You find a quiet corner, curl up and settle down to rest.","You feel the strains of the world falling away from your weary limbs.", "But you're already resting, O sloth!"},
    invisibledef = true,
    off = {"Your rest is interrupted.", "You rise from your rest, refreshed and full of energy."}})
    --Sloth only

  defs_data:set('resistance', { type = 'metamorphosis',
    specialskip = function() return not sk.morphsforskill.resistance end,
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
    --Basilisk, Jaguar, Hydra

  defs_data:set('stealth', { type = 'metamorphosis',
    specialskip = function() return not sk.morphsforskill.stealth end,
    on = {"You are already moving in total silence.", "You will now move in total silence."},
    def = "Your movements are incredibly stealthy.",
    off = {"You are not currently moving silently, Metamorph.", "You cease concentrating on stealth."},
    })
    --Basilisk, Hyena, Jaguar

  defs_data:set('temperance', { type = 'metamorphosis',
    specialskip = function() return not sk.morphsforskill.temperance end,
    -- temperance is frost as well: each comes and goes with the other
    ongot = function () defences.got('frost') end,
    onlost = function () defences.lost('frost') end,
    on = {"Your skin is already chilled, Metamorph.", "A chill runs over your icy skin."},
    def = "You are tempered against fire damage.",
    })
    --Icewyrm, Wyvern, Hydra

  defs_data:set('vitality', { type = 'metamorphosis',
    specialskip = function() return not sk.morphsforskill.vitality end,
    on = {"Your body is already aglow with vitality.", "Your body positively glows with health and vitality."},
    def = "You will call upon your fortitude in need.",
    off = {"You cannot call upon your vitality again so soon.", "A surge of rejuvenating energy floods your system, healing your wounds."}})
    --Bear, Elephant, Jaguar, Icewyrm, Wyvern, Hydra

  defs_data:set('squirrel', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A squirrel spirit co-habits your body." })
  defs_data:set('wildcat', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A wildcat spirit co-habits your body." })
  defs_data:set('wolf', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A wolf spirit co-habits your body." })
  defs_data:set('turtle', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A turtle spirit co-habits your body." })
  defs_data:set('jackdaw', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A jackdaw spirit co-habits your body." })
  defs_data:set('cheetah', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A cheetah spirit co-habits your body." })
  defs_data:set('owl', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "An owl spirit co-habits your body." })
  defs_data:set('hyena', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A hyena spirit co-habits your body." })
  defs_data:set('condor', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A condor spirit co-habits your body." })
  defs_data:set('gopher', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A gopher spirit co-habits your body." })
  defs_data:set('sloth', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A sloth spirit co-habits your body." })
if svo.me.class == 'Sentinel' then
  defs_data:set('basilisk', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A basilisk spirit co-habits your body." })
end
  defs_data:set('bear', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A bear spirit co-habits your body." })
  defs_data:set('nightingale', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A nightingale spirit co-habits your body." })
  defs_data:set('elephant', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "An elephant spirit co-habits your body." })
  defs_data:set('wolverine', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A wolverine spirit co-habits your body." })
if svo.me.class == 'Sentinel' then
  defs_data:set('jaguar', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A jaguar spirit co-habits your body." })
end
  defs_data:set('eagle', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "An eagle spirit co-habits your body." })
  defs_data:set('gorilla', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A gorilla spirit co-habits your body." })
  defs_data:set('icewyrm', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "An icewyrm spirit co-habits your body." })
if svo.me.class == 'Druid' then
  defs_data:set('wyvern', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A wyvern spirit co-habits your body." })

  defs_data:set('hydra', { type = 'metamorphosis',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'squirrel', 'wildcat', 'wolf', 'turtle', 'jackdaw', 'cheetah', 'owl', 'hyena', 'condor', 'gopher', 'sloth', 'basilisk', 'bear', 'nightingale', 'elephant', 'wolverine', 'jaguar', 'eagle', 'gorilla', 'icewyrm', 'wyvern', 'hydra', 'flame'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A hydra spirit co-habits your body."})
end
end

if svo.haveskillset('occultism') then
  defs_data:set('shroud', { type = 'occultism',
    on = "Calling on your dark power, you draw a thick shroud of concealment about yourself to cover your every action.",
    off = {"Your shroud dissipates and you return to the realm of perception.", "The flash of light illuminates you - you have been discovered!"},
    offr = [[^\w+ points a finger at you and you feel anti-magic sweep over you\.$]],
    def = "Your actions are cloaked in secrecy." })
  defs_data:set('astralvision', { type = 'occultism',
    on = {"Gritting your teeth, you focus your will and expand your aura throughout the surroundings about you, seeking out the aura of others.", "You already possess enhanced vision."},
    --astralvision gives both deathsight and lifevision at the same time, there is no way to manually lower lifevision
    def = "You have enhanced your vision to be able to see traces of lifeforce." })
  defs_data:set('distortedaura', { type = 'occultism',
    on = {"Clenching your fists, you focus your will on distorting your own aura. Your mind reels as your aura twists the very air around you.", "Your aura is already distorted, Occultist."},
    off = {"You concentrate on calming your distorted aura, breathing a sigh of relief as it subsides to its normal state.","Your aura is not distorted, Occultist."},
    def = "You have distorted your own aura." })
  defs_data:set('tentacles', { type = 'occultism',
    on = {"You raise your hands above your head, focusing your will to warp your own body. Ignoring the excruciating pain, tentacles spring out from the sides of your body and flail about of their own accord.","Tentacles are already flailing from your body."},
    off = "You breathe a sigh of comfort as the flailing tentacles recede back into your body.",
    def = "You have tentacles flailing from your body." })
  defs_data:set('devilmark', { type = 'occultism',
    on = {"You lick your finger and then bend your will to the task of tracing the mark of the devil over your heart. There is a slight burning and a black mark forms where you've traced.","You already have the mark of the devil upon your heart.", [[The Devil in your service says, "Your will demands I serve you again, and so it shall be."]]},
    off = {"You do not bear the mark of the devil.", "You draw your hand across your heart, releasing any devils in your service and erasing their mark from your skin.", "You feel the devilmark fade from your heart.", "You bend your will to the task of tracing the mark of the devil over your heart, but the presence of a devil waiting in service nullifies its effect."},
    specialskip = function() return defc.devil end,
    def = "The devilmark is upon your breast." })
  defs_data:set('astralform', { type = 'occultism',
    -- a disembodied presence rides nothing
    ongot = function () defences.lost('riding') end,
    on ={"You summon all your will to focus your aura. In a flash of blazing light, your aura consumes your body and nothing is left except your disembodied presence.","You have taken the astralform and can not do that."},
    offr = {[[^You concentrate and are once again \w+\.$]],[[You are already in \w+ form\.$]]},
    def = "As an insubstantial astral light, you are immune from many attacks." })
  defs_data:set('heartstone', { type = 'occultism',
    on = "Cupping your hands before you, you tap into your stores of karma. Focusing your will on the image of your own heart, an unearthly crimson glow fills your cupped hands and solidifies into a heart-shaped ruby.",
    off = "A heartstone cracks and crumbles to dust.",
    invisibledef = true })
  defs_data:set('simulacrum', { type = 'occultism',
    on = "Cupping your hands before you, you tap into your stores of karma. Focusing your will on an image of yourself, an unearthly violet glow fills your cupped hands and solidifies into an amethyst resembling you.",
    offr = [[^A simulacrum shaped like <fix me, insert character name here> cracks and crumbles to dust\.$]],
    invisibledef = true })
  defs_data:set('transmogrify', { type = 'occultism',
      staysindragon = true,
      --Not useful to track it going up or down, since there's a random delay of 4-10 hours between.
      off = {"You carefully raise a barrier between your soul and the Chaos Lord spirit within you."},
      on = {"You lower the barrier separating your soul from the Chaos Lord spirit within you."},
      defr = [[The spirit of a Chaos (?:Lord|Lady) lies dormant in your soul\.$]] })
end

if svo.haveskillset('tarot') then
  defs_data:set('devil', { type = 'tarot',
      on = {[[You fling the card at the ground, and a red, horned Devil rises from the bowels of the earth to say, "I will serve you but once...Master."]], "You bend your will to the task of tracing the mark of the devil over your heart, but the presence of a devil waiting in service nullifies its effect.", [[The Devil in your service says, "Your will demands I serve you again, and so it shall be."]]},
      off = {"You feel the Devil leave you.", "You lick your finger and then bend your will to the task of tracing the mark of the devil over your heart. There is a slight burning and a black mark forms where you've traced.", "You draw your hand across your heart, releasing any devils in your service and erasing their mark from your skin."},
      invisibledef = true,
      offr = {[[^You quickly fling a Lust card at \w+ and \w+ eyes light up\.$]], [[^You toss the Hanged Man tarot card at \w+ and as it reaches \w+, a huge mass of rope bursts out of it to entrap and hinder \w+\.$]], [[^As you fling the Moon tarot at \w+, it turns an ominous, sickly red, before striking \w+ in the head\.$]], [[^With a prayer to Miramar, the Just, you fling your tarot card at \w+\. A set of scales appears above \w+ head and one side of the scale quickly descends\. Justice will be done\.$]], [[^You stand an Aeon tarot on your palm, and blow it lightly at \w+\.$]], [[^Standing the Aeon on your open palm, you blow it lightly at \w+ and watch as it seems to slow \w+ movement through the time stream\.$]]},
    })
end

if svo.haveskillset('domination') then
  defs_data:set('arctar', { type = 'domination',
    on = {"You command your chaos orb to grant you protection; it pulses once before detonating in a soundless conflagration.", "You cannot summon Arctar, the Defender for you have no pact with that entity."},
    on_only = "The Entity refuses to send another minion to aid you.",
    def = "Surrounded by the power of Arctar.",
    off = "Abruptly, the power rippling across your skin dissipates.",})
  defs_data:set('golgotha', { type = 'domination',
    on = {"You cannot summon Jy'Barrak Golgotha, Emperor of Chaos for you have no pact with that entity.", "Closing your eyes, you focus on your contract with Jy'Barrak Golgotha, Emperor of Chaos, beseeching Him for His aide. For the briefest instant the overpowering stench of sulphur fills your nostrils, then a flash of acknowledgement passes to you. Your skin comes alight with a furious burning, and a dire, inhuman sense of vicious amusement fills you as you are suffused with the power of the Emperor of Darkness. Your muscles lock and a scream claws at your throat, but you can do nothing until the pain leaves you except convulse in abject agony."},
    def = "You are acknowledged by Jy'Barrak Golgotha, Emperor of Chaos."})
end

if svo.haveskillset('zeal') then
  defs_data:set('frostblessing', { type = 'zeal',
    staysindragon = true,
    on = "\"Protected from the ravages of the Outer Cold,\" you murmur.",
    def = "You are protected by the power of a Frost Spiritshield."})
  defs_data:set('willpowerblessing', { type = 'zeal',
    staysindragon = true,
    on = {"\"We shall not falter,\" you murmur.", "\"For we shall not falter,\" you murmur."},
    def = "You are regenerating willpower at an increased rate."})
  defs_data:set('thermalblessing', { type = 'zeal',
    staysindragon = true,
    on = "\"Sheltered by His duty,\" you murmur.",
    def = "You are protected by the power of a Thermal Spiritshield."})
  defs_data:set('earthblessing', { type = 'zeal',
    staysindragon = true,
    on = "\"Their blades shall break upon our shields,\" you murmur.",
    def = "You are protected by the power of an Earth Spiritshield."})
  defs_data:set('enduranceblessing', { type = 'zeal',
    staysindragon = true,
    def = "You are regenerating endurance at an increased rate.",
    on = "\"We will endure until our work is done,\" you murmur."})
  defs_data:set('bedevil', { type = 'zeal',
    on = {"You manipulate the elements to lash at those who would do you harm.", "You are already protected by the bedeviling aura."},
    def = "An aura of bedevilment has been established about your person.",
    off = "The elemental aura surrounding you sputters and dies."})
end

if svo.haveskillset('elementalism') then
  defs_data:set('stoneskin', {
    type = 'elementalism',
    specialskip = function () return not defc.earth end,
    def = "Magically supple granite coats your body.",
    on = {"Calling the powers of the elemental earth to you, you coat yourself in magically-supple granite.", "Your skin is already covered in a protective, amazingly supple, granite coating."}})
  defs_data:set('diamondskin', {
    type = 'elementalism',
    specialskip = function() return not (defc.water and defc.fire and defc.earth) end,
    def = "Diamond-hard skin protects you.",
    on = {"Your skin is already covered in a protective, magically-flexible, diamond-hard coating.", "Calling upon crystalline powers, you wrap your skin in a flexible, diamond-hard coating."}})

  defs_data:set('stonefist', {
    type = 'elementalism',
    on = {"You already possess fists of stone.", "You call upon the powers of the earth to coat your fists in dense granite."},
    off = "The granite enveloping your fists cracks and falls off.",
    def = "Your fists are covered with dense granite."})
  defs_data:set('efreeti', {
    type = 'elementalism',
    invisibledef = true,
    off = "The efreeti begins to spin faster and faster, and suddenly disappears in a blaze of flame.",
    offr = [[^A fiery efreeti, your loyal companion, has been slain by]],
    on = {"You are unable to summon more than one efreeti.", "You rub your hands together briskly, heating them with friction, and with a word, throw them open. A fiery efreeti appears before you, swirling in a vortex of flame."}})
  defs_data:set('waterweird', {
    type = 'elementalism',
    on = {"You do not have the power to summon more than one water weird.", "You summon a water weird to assist you in water crossings."},
    def = "Your water weird allows you to walk on water."})
  defs_data:set('chargeshield', {
    type = 'elementalism',
    on = {"You already have a chargeshield active.", "You call upon the powers of air and earth to weave a non-conducting energy shield around you."},
    def = "You are surrounded by a non-conducting chargeshield."})
  defs_data:set('reflection', {
    type = 'elementalism',
    def = "You are surrounded by one reflection of yourself.",
    defr = [[^You are surrounded by \d+ reflections? of yourself\.$]],
    on = {"You cast a spell of reflection over yourself.", "This spell may only be used to cast one reflection on someone. If he or she already has one, it may not be used."},
    off = {"One of your reflections has been destroyed! You have 0 left.", "All your reflections wink out of existence!"}})

  defs_data:set('simultaneity', {
    type = 'elementalism',
    custom_def_type = 'channel'
  })
  defs_data:set('bindall', {
    type = 'elementalism',
    custom_def_type = 'channel'
  })
  defs_data:set('fortifyall', {
    type = 'elementalism',
    custom_def_type = 'channel'
  })
  defs_data:set('air', {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You already have a channel opened to air.", "The power of air is harnessed to your will."}})
  defs_data:set('fire', {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You already have a channel opened to fire.", "Elemental fire burns at your behest."}})
  defs_data:set('water', {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You already have a channel opened to water.", "Purest water soothes you into calm."}})
  defs_data:set('earth', {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You already have a channel opened to earth.", "The strength of earth is at your command."}})

  defs_data:set('fortifiedair', {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Air channel."}})
  defs_data:set('fortifiedfire', {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel.", "Your magics around the fire channel have been destroyed by the knife sigil."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Fire channel."}})
  defs_data:set('fortifiedwater', {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Water channel."}})
  defs_data:set('fortifiedearth', {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Earth channel."}})

  defs_data:set('boundair', {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You bind all your open elemental channels to you.", "You bind the element of Air to your superior will."}})
  defs_data:set('boundfire', {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel.", "Your magics around the fire channel have been destroyed by the knife sigil."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You bind all your open elemental channels to you.", "You bind the element of Fire to your superior will."}})
  defs_data:set('boundwater', {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You bind all your open elemental channels to you.", "You bind the element of Water to your superior will."}})
  defs_data:set('boundearth', {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = 'elementalism',
    custom_def_type = 'channel',
    on = {"You bind all your open elemental channels to you.", "You bind the element of Earth to your superior will."}})
end

if svo.haveskillset('apostasy') then
  defs_data:set('armour', {
    type = 'apostasy',
    stays_on_death = true,
    on = {"You already are surrounded by unholy armour.", "You ask your Baalzadeen for its protection, and it summons a thin black protecting sheen over you."},
    def = "Your person is surrounded by black demonic armour."})
  defs_data:set('syphon', {
    type = 'apostasy',
    invisibledef = true,
    on = {"Your Baalzadeen begins to shimmer with a demonic red light.", "Your Baalzadeen is already syphoning your diseases."}})
  defs_data:set('mask', {
    type = 'apostasy',
    invisibledef = true,
    stays_on_death = true,
    on = {"You wrap your Baalzadeen in a mask of impenetrable obscurity.", "Your Baalzadeen is already masked."}})
  defs_data:set('daegger', {
    type = 'apostasy',
    invisibledef = true,
    on = {"You call upon the Lords of Hell to bestow the living weapon, the daegger, unto you.", "Your daegger comes racing towards you, stopping unnaturally quickly to land in your grasp."}})
  defs_data:set('pentagram', {
    type = 'apostasy',
    on = {"Using your daegger, you open a vein in your wrist, and let the blood drip to outline a pentagram, floating waist-high.", "There is already a pentagram here."}
  })
  defs_data:set('baalzadeen', {
    type = 'apostasy',
    off = "You must be leading your Baalzadeen.",
    on = {"Imposing your will on Hell itself, you summon forth a Baalzadeen to serve your whim.", "You call out, ordering your Baalzadeen to return to serve your whim."},
    invisibledef = true,
    stays_on_death = true,
  })
end

if svo.haveskillset('weatherweaving') then
  defs_data:set('simultaneity', {
    type = 'weatherweaving',
    custom_def_type = 'channel'
  })
  defs_data:set('bindall', {
    type = 'weatherweaving',
    custom_def_type = 'channel'
  })
  defs_data:set('fortifyall', {
    type = 'weatherweaving',
    custom_def_type = 'channel'
  })
  defs_data:set('air', {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You already have a channel opened to air.", "The power of air is harnessed to your will."}})
  defs_data:set('water', {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You already have a channel opened to water.", "Purest water soothes you into calm."}})
  defs_data:set('earth', {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You already have a channel opened to earth.", "The strength of earth is at your command."}})
  defs_data:set('fortifiedair', {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Air channel."}})
  defs_data:set('fortifiedwater', {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Water channel."}})
  defs_data:set('fortifiedearth', {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Earth channel."}})
  defs_data:set('boundair', {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You bind all your open elemental channels to you.", "You bind the element of Air to your superior will."}})
  defs_data:set('boundwater', {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You bind all your open elemental channels to you.", "You bind the element of Water to your superior will."}})
  defs_data:set('boundearth', {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = 'weatherweaving',
    custom_def_type = 'channel',
    on = {"You bind all your open elemental channels to you.", "You bind the element of Earth to your superior will."}})
  defs_data:set('circulate', { type = 'weatherweaving',
    on = {"You begin circulating electricity throughout your body in a constant cycle.", "You are already circulating electricity throughout your body."},
    def = "You are circulating electricity throughout your body."})
  defs_data:set('reflection', {
    type = 'weatherweaving',
    def = "You are surrounded by one reflection of yourself.",
    defr = [[^You are surrounded by \d+ reflections? of yourself\.$]],
    on = {"You cast a spell of reflection over yourself.", "This spell may only be used to cast one reflection on someone. If he or she already has one, it may not be used."},
    off = {"One of your reflections has been destroyed! You have 0 left.", "All your reflections wink out of existence!"}})
end

if svo.haveskillset('pranks') then
  defs_data:set('arrowcatch', { type = 'pranks',
    mana = 'lots',
    on = {"You have begun to look for arrows to pluck from the air.", "You already have arrowcatching on."},
    def = "You are attempting to pluck arrows from the air.",
    off = "You've turned off arrowcatching."})
  defs_data:set('balancing', { type = 'pranks',
    mana = 'lots',
    on = {"You move onto the balls of your feet and begin to concentrate on balance.", "You're already balancing."},
    def = "You are balancing on the balls of your feet.",
    off = "You cease to balance on the balls of your feet."})
  defs_data:set('acrobatics', { type = 'pranks',
    on = {"You begin leaping and bouncing about, making it more difficult to hit you.", "You are already bouncing around acrobatically."},
    def = "You are bouncing around acrobatically.",
    off = "You cease your acrobatic leaping and bouncing."})
  defs_data:set('slipperiness', { type = 'pranks',
    on = {"You're quite the slippery little fellow aren't you?", "You're already quite slippery.", "You're quite the slippery little gal aren't you?"},
    def = "You are looking a little shady today.",
    })
end

if svo.haveskillset('puppetry') then
  defs_data:set('grip', { type = 'puppetry',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
end


if svo.haveskillset('vodun') then
  defs_data:set('grip', { type = 'vodun',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
end

if svo.haveskillset('curses') then
  defs_data:set('swiftcurse', { type = 'curses',
    on = "You weave your fingers together, calling upon the swiftcurse to aid you.",
    def = "The swiftcurse is upon you.",
    off = "The swiftcurse leaves you."})
end

if svo.haveskillset('kaido') then
  defs_data:set('weathering', { type = 'kaido',
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set('resistance', { type = 'kaido',
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
  defs_data:set('numb', { type = 'kaido',
    on = "You grit your teeth and will your pain out of existence.",
    off = "You cry out in agony as the effects of your numbness fade away and you feel your wounds once more.",
    def = "You are temporarily numbed to damage." })
  defs_data:set('regeneration', { type = 'kaido',
    on = {"You begin to concentrate on regeneration of your wounds.", "Regeneration is already on."},
    def = "You are regenerating lost health through the power of Kaido.",
    off = {"You have no regenerative ability to boost.", "You call a halt to the regenerative process."}})
  defs_data:set('boosting', { type = 'kaido',
    onenable = function (mode, newdef, whereto, echoback)
      if not svo['def'..whereto][mode].regeneration then
        svo['def'..whereto][mode].regeneration = true
        if echoback then svo.echof("Added regeneration to %s, it's necessary for %s.", whereto, newdef) end
      end

      return true
    end,
    specialskip = function() return not defc.regeneration end,
    on = {"You call upon your Kai power to boost your health regeneration.", "Your regeneration is already boosted."},
    def = "Your regeneration is boosted.",
    off = {"You call a halt to the regenerative process."}})
  defs_data:set('kaiboost', { type = 'kaido',
    off = "You are no longer boosting your Kai gain.",
    def = "You have boosted the power of your Kai Trance.",
    on = "You gather up and expend your Kai energy to enhance your sensitivity to its energies."})
  defs_data:set('toughness', { type = 'kaido',
    on = "Flexing your muscles, you concentrate on forcing unnatural toughness over the surface of your skin.",
    def = "Your skin is toughened."})
  -- disabled, better be general for dragons to work
  -- defs_data:set('nightsight', { type = 'kaido',
  --   def = "Your vision is heightened to see in the dark.",
  --   on = {"Your vision sharpens with light as you gain night sight.", "Your eyes already have the benefit of night sight."},
  --   off = {"Your eyes lose the benefit of night sight.", "Your eyes cannot lose the benefit of night sight, since they do not already have it!"}})
  defs_data:set('projectiles', { type = 'kaido',
    mana = 'lots',
    def = "You are alert to incoming projectiles.",
    off = {"You cease your watch for projectiles.", "You are not watching for projectiles."},
    on = "You look about sharply, poised to avoid all incoming projectiles."})
  defs_data:set('trance', { type = 'kaido',
    mana = 'lots',
    on = {"You begin to chant an ancient mantra, preparing your body to become a channel for Kai energy.", "Your mantra is complete - the Kai Trance is upon you."},
    off = "You break out of the Kai Trance, sighing as you feel your accumulated Kai energy vanish.",
    def = "You are utilising the trance to store Kai energy."})
  defs_data:set('dodging', { type = 'kaido',
    mana = 'lots',
    on = "You resolve to keep an eye on the skies for danger.",
    def = "You are watching the skies for danger.",
    off = {"You are not using Shindo Dodging.", "You cease watching the skies."}})
  defs_data:set('constitution', { type = 'kaido',
    def = "You are using your superior constitution to prevent nausea.",
    on = {"You clench the muscles in your stomach, determined to svo.assert your superior constitution.", "You are using your superior constitution to prevent nausea."}})
  defs_data:set('splitmind', { type = 'kaido',
    on = {"You begin to devote a portion of your Kaido-trained mind to constant, unconscious meditation.", "Your mind is already split."},
    def = "Your mind is split, allowing constant meditation.",
    off = {"You cease the process of Kai meditation, joining the split segments of your mind once more.", "Your mind is already whole."}})
  defs_data:set('consciousness', { type = 'kaido',
    def = "You are maintaining consciousness at all times.",
    off = {"You are not maintaining consciousness.", "You will no longer concentrate on retaining full consciousness."},
    on = {"You are already maintaining consciousness.", "You will remain conscious at all times."}})
  defs_data:set('sturdiness', { type = 'kaido',
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you."})
  defs_data:set('vitality', { type = 'kaido',
    on = {"Your body is already aglow with vitality.", "Your body positively glows with health and vitality."},
    def = "You will call upon your fortitude in need.",
    off = {"A surge of rejuvenating energy floods your system, healing your wounds.", "You cannot call upon your vitality again so soon."}})
  defs_data:set('immunity', { type = 'kaido',
    on = "You close your eyes and grit your teeth, feeling the heat of the blood pumping through your veins.",
    off = "You cease concentrating on immunity."})
end

if svo.haveskillset('shikudo') then
  local onenable_shikudo = function (mode, newdef, whereto, echoback)
    local shikudo_forms = {
      'tykonos',
      'willow',
      'rain',
      'oak',
      'gaital',
      'maelstrom'
    }

    local fail_string =
      "Removed %s from %s, it's incompatible with %s to have simultaneously up."

    for _, shikudo_form in ipairs(shikudo_forms) do
      if shikudo_form ~= newdef and svo['def'..whereto][mode][shikudo_form] then
        svo['def'..whereto][mode][shikudo_form] = false
        if echoback then svo.echof(fail_string, shikudo_form, whereto, newdef) end
      end
    end

    return true
  end

  defs_data:set('tykonos', {
    type = 'shikudo',
    onenable = onenable_shikudo,
    def = "You are enacting the Tykonos form.",
    on = {"You spin your staff in the opening sequence of the form of Tykonos, snapping into a ready stance.", "You are already carrying out the form of Tykonos."},
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set('willow', {
    type = 'shikudo',
    onenable = onenable_shikudo,
    def = "You are enacting the Willows shaken by the Wind form.",
    on = {"Twirling your staff, you sink into the calm required for the form of Willows Shaken by the Wind.", "You are already carrying out the form of Willows shaken by the Wind."},
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set('rain', {
    type = 'shikudo',
    onenable = onenable_shikudo,
    def = "You are enacting the Willows in Rain Storm form.",
    on = {"Dropping into a lower stance, you snap your weapon into an offensive position, tensing your muscles in preparation for the form of Willows in Rain Storm.", "You are already carrying out the form of Willows in Rain Storm."},
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set('oak', {
    type = 'shikudo',
    onenable = onenable_shikudo,
    def = "You are enacting the Live Oak form.",
    on = {"Rising onto the balls of your feet, you prepare to begin the deadly form of the Live Oak.", "You are already carrying out the form of Live Oak."},
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set('gaital', {
    type = 'shikudo',
    onenable = onenable_shikudo,
    def = "You are enacting the Gaital form.",
    on = {"You let your eyes fall closed and instinct guide you as you flow into the form of Gaital.", "You are already carrying out the form of Gaital."},
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set('maelstrom', {
    type = 'shikudo',
    onenable = onenable_shikudo,
    def = "You are enacting the Unrelenting Storm form.",
    on = {"You allow your kai to flow through you, circulating throughout your limbs and down your weapon in preparation to begin the form of the Unrelenting Storm.", "You are already carrying out the form of Unrelenting Storm."},
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set('grip', {
    type = 'shikudo',
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
end

if svo.haveskillset('tekura') then
  defs_data:set('guarding', { nodef = true,
    ondef = function ()
      local t = svo.sps.parry_currently
      for limb, _ in pairs(t) do t[limb] = false end
      t[matches[2]] = true
      svo.check_sp_satisfied()

      return "("..matches[2]..")"
    end,
    tooltip = "Completely blocks health and wound damage on a limb if you aren't hindered.",
    defr = [[^You will attempt to throw those who attack your (.+)\.$]]
  })
  defs_data:set('bodyblock', { type = 'tekura',
    mana = 'lots',
    def = "You are trying to absorb blows to your body.",
    on = "You ready yourself to block as best you can.",
    off = {"You drop all your blocks.", "You lower your body block."}})
  defs_data:set('pinchblock', { type = 'tekura',
    mana = 'lots',
    def = "You will try to pinch block a weakened foe.",
    on = "You ready yourself to pinch block to the best of your ability.",
    off = {"You drop all your blocks.", "You lower your pinch block."}})
  defs_data:set('evadeblock', { type = 'tekura',
    mana = 'lots',
    def = "You are using Tekura to evade incoming attacks.",
    on = "You ready yourself to evade incoming blows.",
    off = {"You drop all your blocks.", "You lower your evade block."}})

  defs_data:set('horse', { type = 'tekura',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'horse', 'eagle', 'cat', 'bear', 'rat', 'scorpion', 'dragon'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You drop your legs into a sturdy Horse stance.",
    def = "You are in the Horse stance.",
    off = "You ease yourself out of the Horse stance."})
  defs_data:set('eagle', { type = 'tekura',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'horse', 'eagle', 'cat', 'bear', 'rat', 'scorpion', 'dragon'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You draw back and balance into the Eagle stance.",
    def = "You are in the Eagle stance.",
    off = "You ease yourself out of the Eagle stance."})
  defs_data:set('cat', { type = 'tekura',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'horse', 'eagle', 'cat', 'bear', 'rat', 'scorpion', 'dragon'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You tense your muscles and look about sharply as you take the stance of the Cat.",
    def = "You are in the Cat stance.",
    off = "You ease yourself out of the Cat stance."})
  defs_data:set('bear', { type = 'tekura',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'horse', 'eagle', 'cat', 'bear', 'rat', 'scorpion', 'dragon'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You draw yourself up to full height and roar aloud, adopting the Bear stance.",
    def = "You are in the Bear stance.",
    off = "You ease yourself out of the Bear stance."})
  defs_data:set('rat', { type = 'tekura',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'horse', 'eagle', 'cat', 'bear', 'rat', 'scorpion', 'dragon'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You take the Rat stance.",
    def = "You are in the Rat stance.",
    off = "You ease yourself out of the Rat stance."})
  defs_data:set('scorpion', { type = 'tekura',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'horse', 'eagle', 'cat', 'bear', 'rat', 'scorpion', 'dragon'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You sink back into the menacing stance of the Scorpion.",
    def = "You are in the Scorpion stance.",
    off = "You ease yourself out of the Scorpion stance."})
  defs_data:set('dragon', { type = 'tekura',
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{'horse', 'eagle', 'cat', 'bear', 'rat', 'scorpion', 'dragon'} do
        if morph ~= newdef and svo['def'..whereto][mode][morph] then
          svo['def'..whereto][mode][morph] = false
          if echoback then svo.echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You allow the form of the Dragon to fill your mind and govern your actions.",
    def = "You are in the Dragon stance.",
    off = "You ease yourself out of the Dragon stance."})
end

if svo.haveskillset('telepathy') then
  defs_data:set('mindtelesense', { type = 'telepathy',
    mana = 'lots',
    on = "You attune your mind to tampering from telepathy.",
    off = "You cease to concentrate your mind on mindlock attempts.",
    def = "You are using your telesense."})
  defs_data:set('mindcloak', { type = 'telepathy',
    on = {"You will now begin to concentrate on cloaking your telepathy.", "You are already cloaking your attempts at mindlocking."},
    off = "You allow the mindcloak to drop.",
    def = "You are cloaking your attempts at establishing a mindlock."})
  defs_data:set('mindnet', { type = 'telepathy',
    on = {"You cast an invisible mind net out into the distance, allowing it to settle about the surrounding land.", "You already have mindnet active."},
    off = "You cease concentration and your mind net vanishes.",
    mana = 'little',
    def = "You have cast a mindnet over the local area."})
  defs_data:set('hypersense', { type = 'telepathy',
    mana = 'lots',
    on = "You begin detecting mindlock attempts in your local area.",
    off = "You turn hypersense off.",
    def = "You are using your hypersense."})
end

if svo.haveskillset('woodlore') then
  defs_data:set('barkskin', { type = 'woodlore',
    on = {"You concentrate for a moment, and your skin becomes rough and thick like tree bark.", "Your skin is already covered in protective bark.", "Your skin is already as tough as bark."},
    def = "Your skin is hard and tough like the bark of an oak tree."})
  defs_data:set('hiding', { type = 'woodlore',
    on = {"You conceal yourself using all the guile you possess.", "You are already hidden."},
    def = "You have used great guile to conceal yourself.",
    off = {"You emerge from your hiding place.","You are discovered!","The flash of light illuminates you - you have been discovered!", "From what do you wish to emerge?"}})
  defs_data:set('evasion', { type = 'woodlore',
    on = {"You must be in the air before you can begin evasive flying.", "You begin soaring erratically and frantically, attempting to avoid the eyes gazing up from below.", "You are already attempting to elude the prying eyes below."},
    def = "You are flying evasively.",
    off = {"You cease your aerial acrobatics.", "You are already not attempting to elude the prying eyes below."}})
  defs_data:set('firstaid', { type = 'woodlore',
    on = {"You begin to concentrate on clotting your wounds.", "You have already turned on first aid." },
    off = {"You cease to concentrate on the clotting of your wounds.","You've already turned off first aid."},
    def = "You are concentrating on clotting your wounds."})
  defs_data:set('fleetness', { type = 'woodlore',
    on = "You will seek out the best paths through the forest.",
    def = "You are able to navigate forests more easily."})
end

if svo.haveskillset('propagation') then
  defs_data:set('barkskin', { type = 'propagation',
    on = {"You concentrate for a moment, and your skin becomes rough and thick like tree bark.", "Your skin is already covered in protective bark.", "Your skin is already as tough as bark."},
    def = "Your skin is hard and tough like the bark of an oak tree."})
  defs_data:set('viridian', { type = 'propagation',
    -- the Viridian's form leaves its steed, and whatever exit it blocked
    ongot = function () svo.dict.riding.gone.oncompleted() end,
    def = "You have taken the form of the Viridian.",
    off = "You will the vines to retreat, and you shed the form of the Viridian."})
end

if svo.haveskillset('groves') then
  defs_data:set('panacea', { type = 'groves',
    on = {"You call on the curative powers of Nature. A spiralling helix of wildflowers and lush leaves races up the length of your quarterstaff, before sublimating into a cool mist that drifts about your body.", "A healing mist already surrounds you, Forestwalker."},
    on_only = "You find your sunlight reserves too low to attempt that.",
    off = "The tendrils of delicate mist surrounding you disperse.",
    def = "You are surrounded by a healing mist."})
  defs_data:set('vigour', { type = 'groves',
    on = {"You are bathed in radiant sunlight, its warm glow seeping into your skin.", "You are bathed in an aura of radiant sunlight.", "An aura of sunlight already radiates around that person."},
    off = "The radiant sunlight warming your body fades away.",
    on_only = "You find your sunlight reserves too low to attempt that.",
    def = "You are bathed in an aura of radiant sunlight."})
  defs_data:set('flail', { type = 'groves',
    on = {"You flail the quarterstaff smoothly around in the air about you to summon up a defensive sphere.", "Your quarterstaff has already been flailed."},
    on_only = "You find your sunlight reserves too low to attempt that.",
    def = "You are flailing a wielded quarterstaff."})
  defs_data:set('wildgrowth', { type = 'groves',
    def = "Your movements are trailed by profusions of wild growth.",
    on = {"You quietly recite an incantation calling on all that is wild and green. As you speak the final syllables, you slowly raise your quarterstaff skywards, drawing vibrant new growth from the earth.", "Wild vines already circle your feet."},
    on_only = "You find your sunlight reserves too low to attempt that.",
    off = "Curling in on itself, the tangle of wild green growth surrounding you retreats into the earth."})
  defs_data:set('dampening', { type = 'groves',
    invisibledef = true,
    on_only = "You find your sunlight reserves too low to attempt that.",
    on = "You whirl your quarterstaff in a grand arc, and a distant rustling reaches your ears. Moments later, a flurry of leaves blankets the area with copper tones."})
  defs_data:set('snowstorm', { type = 'groves',
    invisibledef = true,
    on_only = "You find your sunlight reserves too low to attempt that.",
    on = "You grip your quarterstaff tightly and with a whisper invoke winter's icy chill, the vapour of your breath growing visible as you speak. First scattered flakes and then great gusts of snow respond, as the area is overwhelmed by a glacial shroud of white."})
  defs_data:set('roots', { type = 'groves',
    invisibledef = true,
    on_only = "You find your sunlight reserves too low to attempt that.",
    off = "The roots that secured you to the ground fall away and retreat back into the earth.",
    on = "Roots spring up from the rich earth beneath your feet and wreath themselves gently about your form."})
  defs_data:set('concealment', { type = 'groves',
    invisibledef = true,
    off = "The undergrowth parts slightly, and banishes the gloom that seemed to hang here.",
    on_only = "You find your sunlight reserves too low to attempt that.",
    on = {"Your grove fills with gloom as the leaves huddle closer in secrecy.", "This grove is already concealed from prying eyes."}})
  defs_data:set('screen', { type = 'groves',
    invisibledef = true,
    off = "A low fizzle can be heard as the tension in the grove decreases.",
    on_only = "You find your sunlight reserves too low to attempt that.",
    on = {"You call a telepathic screen into being around your grove.", "There is already a mind screen in existence here."}})
  defs_data:set('lyre', { type = 'groves',
    on_only = "You find your sunlight reserves too low to attempt that.",
    specialskip = function() return not conf.lyre end,
    availableindragon = true,
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].meditate then
        svo['def'..whereto][mode].meditate = false
        if echoback then svo.echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].breath then
        svo['def'..whereto][mode].breath = false
        if echoback then svo.echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].flame then
        svo['def'..whereto][mode].flame = false
        if echoback then svo.echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = {"You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.", "You strum a Lasallian lyre, and a prismatic barrier forms around you.", "You deftly shape the wall of light into a barrier surrounding yourself.", "You strum a darkly glowing mandolin, and a prismatic barrier forms around you."},
    def = "You are standing within a prismatic barrier.",
    off = {"Your prismatic barrier dissolves into nothing.", "The stream hits your prismatic barrier, shattering it.", "The breath weapon rips apart your prismatic barrier.", "The breath weapon rips through both your shield and prismatic barrier.", "The spear shatters your prismatic barrier."}})
  defs_data:set('swarm', { type = 'groves',
    invisibledef = true,
    on = {"You already have a swarm in the lands.", "Barely within the range of normal hearing, you utter a buzz-like hum from deep within your throat."}})
  defs_data:set('harmony', { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are under the blessing of the (\w+) environment\.$]]})
end

if svo.haveskillset('alchemy') then
  defs_data:set('lead', { type = 'alchemy',
    on = "Directing the energy of lead, you increase your mass and weigh yourself down.",
    off = "You feel your density return to normal.",
    def = "You are extremely heavy and difficult to move."})
  defs_data:set('tin', { type = 'alchemy',
    on = {"Directing the energy of tin, you erect a reflective barrier about yourself.", "You are already surrounded by a protective barrier."},
    offr = [[^As \w+'s attack falls, your reflective barrier shatters and reflects the attack\.$]],
    def = "You are protected by a reflective barrier."})
  defs_data:set('sulphur', { type = 'alchemy',
    on = {"Directing the energy of sulphur, you surround yourself with an aura of primal energies, bolstering your healing capacity.", "You are already drawing upon the power of sulphur."},
    off = "The symbol of sulphur inscribed about you fades away.",
    tooltip = "Boosts the effect of the vitality tonic.",
    def = "You are bolstered by the energy of sulphur."})
  defs_data:set('mercury', { type = 'alchemy',
    on = {"Directing the energy of mercury, you surround yourself with an aura of primal energies, boosting your mental regeneration.", "You are already drawing upon the power of mercury."},
    off = "The symbol of mercury inscribed about you fades away.",
    tooltip = "Boosts the effect of the mentality tonic.",
    def = "You are bolstered by the energy of mercury."})
  defs_data:set('extispicy', { type = 'alchemy',
    on = {"As you poke through the entrails, a pink and shiny intestine foretells good fortune.", "You've already divined the future, Alchemist.", "As you poke through the entrails, a bleeding ulcer predicts great victories."},
    def = "You have divined the future."})
  defs_data:set('empower', { type = 'alchemy',
    on = {
      "You close your eyes and, calling upon latent alchemical energies, sketch the symbol of the sun in the air. A warm thrill shivers throughout your body, and a halo of pale flames flickers momentarily about your body.",
      "You close your eyes and, calling upon latent alchemical energies, sketch the symbol of the moon in the air. A warm thrill shivers throughout your body, and a halo of pale flames flickers momentarily about your body.",
      "You close your eyes and, calling upon latent alchemical energies, sketch the symbol of Nebula in the air. A warm thrill shivers throughout your body, and a halo of pale flames flickers momentarily about your body.",
      "You close your eyes and, calling upon latent alchemical energies, sketch the symbol of Ethian in the air. A warm thrill shivers throughout your body, and a halo of pale flames flickers momentarily about your body.",
      "<fix me, insert character name here> is already empowered by astronomical energies.",
      "You are already empowered by astronomical energies.",
    },

    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are resonating with (?:the )?(?:Nebula )?(\w+)'s energy\.$]]})
end

if svo.haveskillset('skirmishing') then
  defs_data:set('scout', { type = 'skirmishing',
    on = "You begin scouting ahead for danger.",
    def = {"You are able to scout passed obstructions.", "You are able to scout past obstructions."}})
	defs_data:set('spinning', { type = 'skirmishing',
    onr = [[^You begin to rapidly spin .+ in a defensive pattern\.$]],
    offr = [[^You cease spinning .+\.$]]})
end

if svo.haveskillset('shadowmancy') then
  defs_data:set('shadowcloak', {
    type = 'shadowmancy',
    custom_def_type = 'shadowcloak',
    offline_defence = true,
    invisibledef = true,
    stays_on_death = true,
    staysindragon = true,
    on = {
      "You are now wearing a grim cloak.",
    },
    off = {
      "You remove a grim cloak.",
      "You must be wearing your cloak of darkness in order to perform this ability."
    }
   })
  defs_data:set('disperse', {
    type = 'shadowmancy',
    custom_def_type = 'shadowcloak',
    on = {
      "The shadows swirl about you, masking you from view.",
      "You have already shrouded yourself in beguiling shadow."
    },
    def = "You are masking your egress."
   })
--shadowveil gives both shadowveil and hiding
  defs_data:set('shadowveil', {
    type = 'shadowmancy',
    custom_def_type = 'shadowcloak',
    on = {
      "Summoning the shadows to coalesce about your person, you vanish into their stygian embrace.",
      "You are already veiled within the shadows embrace.",
    },
    def = "Concealed by a shifting veil of shadow.",
   })
  defs_data:set('hiding', {
    type = 'shadowmancy',
    custom_def_type = 'shadowcloak',
    on = {
      "Summoning the shadows to coalesce about your person, you vanish into their stygian embrace.",
      "You are already veiled within the shadows embrace.",
    },
    def = "You have used great guile to conceal yourself.",
    off = {
      "You emerge from your hiding place.",
      "You are discovered!",
      "The flash of light illuminates you - you have been discovered!",
      "From what do you wish to emerge?"
    }
   })

-- signals for shadowcloak tracking
  signals.gmcpcharitemslist:connect(function()
  if gmcp.Char.Status.class == "Depthswalker" then
    if gmcp.Char.Items.List.location ~= 'inv' then
      return
    end
    for _, item in ipairs(gmcp.Char.Items.List.items) do
      if item.name == "a grim cloak" then
        if item.attrib and item.attrib:find('w') then
           defences.got('shadowcloak')
         else
           defences.lost('shadowcloak')
         end
         return
      end
    end
  end
  end, 'add/remove shadowcloak on gmcp items list')
  signals.gmcpcharitemsadd:connect(function()
  if gmcp.Char.Status.class == "Depthswalker" then
    if gmcp.Char.Items.Add.location ~= 'inv' then
      return
    end
    for _, item in ipairs(gmcp.Char.Items.Add.item) do
      if item.name == "a grim cloak" then
        if item.attrib and item.attrib:find('w') then
          defences.got('shadowcloak')
        end
      end
    end
  end
  end, 'add shadowcloak on gmcp items add')
  signals.gmcpcharitemsremove:connect(function()
  if gmcp.Char.Status.class == "Depthswalker" then
    if gmcp.Char.Items.Remove.location ~= 'inv' then
      return
    end
    for _, item in ipairs(gmcp.Char.Items.Remove.item) do
      if item.name == "a grim cloak" then
        defences.lost('shadowcloak')
      end
    end
  end
  end, 'remove shadowcloak on gmcp items remove')
  signals.gmcpcharitemsupdate:connect(function()
  if gmcp.Char.Status.class == "Depthswalker" then
    if gmcp.Char.Items.Update.location ~= 'inv' then
      return
    end
    for _, item in ipairs(gmcp.Char.Items.Update.item) do
      if item.name == "a grim cloak" then
        if item.attrib and item.attrib:find('w') then
          defences.got('shadowcloak')
        end
      end
    end
  end
  end, 'add shadowcloak on gmcp items update')
end


if svo.haveskillset('aeonics') then
  defs_data:set('blur', { type = 'aeonics',
    def = "Travelling the world more quickly due to time dilation.",
    on = {"With a minor application of will, you increase your speed.",},
    off = "Your movements are no longer faster than the relative timestream."
  })
  defs_data:set('reflection', { type = 'aeonics',
    def = {"You are surrounded by two reflections of yourself.","You are surrounded by one reflection of yourself."},
    defr = [[^You are surrounded by \d+ reflections? of yourself\.$]],
  	on =  {"Taking hold of the strands of causality, you attempt to mislead your foes with false images from alternative timelines.", "You are already protected by a magical reflection."},
	  off = {"All your reflections wink out of existence!","One of your reflections has been destroyed! You have 0 left."}
	})
  defs_data:set('dilation', { type = 'aeonics',
    onenable = function (mode, newdef, whereto, echoback)
      if svo['def'..whereto][mode].breath then
        svo['def'..whereto][mode].breath = false
        if echoback then svo.echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].meditate then
        svo['def'..whereto][mode].meditate = false
        if echoback then svo.echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo['def'..whereto][mode].lyre then
        svo['def'..whereto][mode].lyre = false
        if echoback then svo.echof("Removed lyre from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = "Growing very still, you begin to manipulate the flow of time around you, drastically speeding up your rate of regression.",
    off = {"Your concentration broken, you cease dilating time.", "Having fully regressed to your normal age, you cease dilating time."}})
end

if svo.haveskillset('terminus') then
  defs_data:set('trusad', { type = 'terminus',
    on = [[Imbuing your voice with power, you intone, "Trusad".]],
    def = "You are enhancing your precision through the power of Terminus."
  })
  defs_data:set('tsuura', { type = 'terminus',
    on = [[Imbuing your voice with power, you intone, "Tsuura".]],
    def = "You are enhancing your durability against denizens."
  })
  defs_data:set('ukhia', { type = 'terminus',
    defr = "^You are focus?sing on quelling your bleeding more efficiently\\.$"
  })
  defs_data:set('qamad', { type = 'terminus',
    def = "You have a will of iron."
  })
  defs_data:set('mainaas', { type = 'terminus',
    on = {"You have already augmented your body - no need to risk it again.",[[Taking a steadying breath, you turn your focus inward and proclaim, "Mainaas".]]},
    def = "You have augmented your own body for enhanced defence.",
  })
  defs_data:set('gaiartha', {
    type = 'terminus',
    staysindragon = true,
    def = "You are concentrating on maintaining control over your faculties."
  })
else
  defs_data:set('gaiartha', { nodef = true,
    def = "You are concentrating on maintaining control over your faculties."
  })
end


if svo.haveskillset('weaving') then
  defs_data:set('secondskin', { type = 'weaving',
    on = { "You weave a second skin of armour over your body, protecting your vulnerable areas.", "You have already woven a protective layer of armour over your skin." },
    def = "You are protected by a layer of flexible armour."
  })
end

 if svo.haveskillset('psionics') then
  defs_data:set('comprehend', { type = 'psionics',
    on = { "You begin directing your vast intellect to the problem of understanding foreign speech patterns.", "You are already directing your vast intellect to comprehending foreign speech patterns."},
    def = "You are focusing your vast intellect on comprehending language."
  })
  defs_data:set('transcend', {type = 'psionics',
    on = { "You sink into tranquility; your mind and body transcending their limitations as they begin to function in perfect unity.", "Your mind has already transcended its limitations." },
    def = "You are of transcendent mind."
  })
  defs_data:set('breakthrough', { type = 'psionics',
    on = { "A sharp pain behind your eyes is the precursor to an abrupt expansion of consciousness, your mental processes speeding to unnatural levels.", "Your mind is already operating at an extreme capacity." },
    off = "The rapture of your expanded mind abruptly flees you, leaving only the burning pain behind your eyes in its wake.",
    def = "You are pushing your mind beyond its limits."
  })
  defs_data:set('vanish', { type = 'psionics',
    on = { "You begin focussing on destroying knowledge of yourself from the minds of those around you.", "You are already eradicating knowledge of your presence from the minds around you." },
    off = "Your focus breaks, your mind no longer able to sustain the rapid destruction of thought.",
    def = "You are annihilating knowledge from the minds around you."
  })
end

if svo.haveskillset('emulation') then
  defs_data:set('guidedstrike', { type = 'emulation',
    on = { "You focus on enhancing your personal luck.", "Your strikes are already guided by preternatural luck." },
    off = "Your strikes are no longer guided by unnatural luck.",
    def = "Your strikes are guided by unnatural luck."
  })
  defs_data:set('rupture', { type = 'emulation',
    on = { "Your vision sharpens, allowing you to perceive the locations of every vein and artery that lies beneath the skin.",    "Your blows will already rupture veins and arteries."  },
    off = "Your vision returns to normal levels, no longer able to perceive the veins that lie beneath people's skin.",
    def = "Your blows will rupture veins and arteries with every strike."
  })
  defs_data:set('mentalclarity', { type = 'emulation',
    on = { "A total focus overcomes you; the mundanity of everyday distractions unable to penetrate your clarity.", "Your clarity of thought already surpasses natural limits."  },
    off = "Distractions reassert themselves, your mental clarity returning to mundane levels.",
    def = "Your mind is focussed to perfection."
  })
  defs_data:set('indomitability', { type = 'emulation',
    on = { "Power suffuses every limb and strength burns inside of you; you are the indomitable and no blow shall see you fall.", "You are already channeling the indomitable might of the battlemaster." },
    off = "Your miriad image shatters under the onslaught.",
    def = "You is suffused with indomitable might."
  })
end

if svo.haveskillset('sculpting') then
  defs_data:set('strata', { type = 'sculpting',
    def = "You are protected by protective strata.",
    on = {"Calling upon the power of Garash, you form protective strata to cover your entire form.", "You are already protected by a layer of strata."}})
  defs_data:set('tremorsense', { type = 'sculpting',
    def = "You will know who walks upon the earth in your location.",
    on = {"You begin to sense for those that would tread upon the hallowed earth.", "You are already focussing on the tremors caused by those that walk on land."},
    off = {"You cease focussing on the tremors created by those that walk on land.", "You are not focussing on the tremors caused by those who walk on land."}})
  defs_data:set('extrusion', { type = 'sculpting',
    def = "You will restore your form with magma.",
    on = "The magma within your form begins to churn.",
    off = {"Magma explodes from beneath your outer strata, hardening in an instant to form a restored external coating.", "You are not able to extrude your magma to restore yourself so soon after doing it previously."}})
end

if svo.haveskillset('ignition') then
  defs_data:set('fireshroud', { type = 'ignition',
  def = "You have shrouded yourself with flame.",
  on = "A shroud of flame bursts into being, cloaking you in a burning aura of crimson.",
  off = "The burning shroud that cloaks you winks out of existence."})
  
  defs_data:set('torch', { type = 'ignition',
  invisibledef = true,
  on = "You flare your flames, burning ever brighter.",
  off = {"The raging fire about your skin goes out.","Steam rises from your skin as the fires that plague you are extinguished.","Waves of elemental water surge over your body, quenching the tongues of flame."}
  })
  
end

if svo.haveskillset('duress') then
  defs_data:set('skysight', {type = 'duress',
    def = "You are aware of all that transpires in Whiirh's domain.",
    on = {"You begin to focus on the events transpiring within Whiirh's domain.", "You have already enhanced yourself to detect movement through the skies."},
    off = {"You cease to focus on the events transpiring within Whiirh's domain.", "You are not focussing on the events transpiring within Whiirh's domain."}})
  defs_data:set('tempest', {type = 'duress',
    def = "You are surrounded by a raging tempest.",
    on = {"A whirling tempest comes into existence with you at the centre.","A howling tempest already rages about you."}})
  defs_data:set('susurrating', {type = 'duress',
  def = "Susurrations fill the air around you.",
  on = {"A gentle breeze begins to emanate from you, creating a barely audible murmur.","Susurrations already surround you. "}})
end

if svo.haveskillset('pervasion') then
  defs_data:set('cohesion', {type = 'pervasion',
    def = "You have altered the cohesion of your form.",
    on = {"You alter the cohesion of your fluid form.", "You have already altered the cohesiveness of your form."}})
end

if svo.haveskillset('memorium') then
  defs_data:set('traceshield', {type = 'memorium',
    def = "The power of the shield logograph wards damage from you.",
    on = "Your knife moves in perfect harmony with your mind as you trace the image of the shield in the air, its outline bursting into crimson fire."})
    
  defs_data:set('traceleech', {type = 'memorium',
    def = "The power of the leech draws afflictions from you.",
    on = "Your knife moves in perfect harmony with your mind as you trace the image of the leech in the air, its outline bursting into crimson fire.",
    off = "You sense that the power of the leeching logograph has dwindled."})

  defs_data:set('bloodiedknife', {type = 'memorium',
    invisibledef = true,
    offline_defence = true,
    stays_on_death = true,
    staysindragon = true,
    on = "You bring your blade to your opposite hand and blood it in preparation for the work to come.",
    onr = {[[^You sweep your blade in a circle above your head, the point coming to rest pointed at \w+\. A fine crimson spray follows the arc of your blade, and you know that your ensorcelment has born fruit\.$]],
    [[^Reaching into a pouch, you withdraw a small stone jar containing the blood of \w+\. With deft motions, you unscrew the lid and tip some drops onto your ritual blade, your focus drinking hungrily of that which sustains\.$]]},
    off = {"The last of your blood has dried upon your ritual blade.", "A leaf-bladed ritual knife must have been bloodied if you wish to trace a logograph."},
    offr = [[^The last of (\w+)'s blood has dried upon your ritual blade\.$]]
    })    
  
end

if svo.haveskillset('charnel') then
  defs_data:set('accursedresolve', {type = 'charnel',
    def = "Your resolve is something beyond the frailties of the flesh.",
    on = "Your resolve is as eternal as the desert. You will endure.",
    off = "Your resolve wavers, and the pains of existence are once more made manifest."})
end

if svo.haveskillset('anathema') then
--mutations
  defs_data:set('mouths', {type = 'anathema',
    def = "Many mouths have torn open in your flesh.",
    on = "With a gurgling sound, dozens of mouths rip open in your flesh, the soft rasp of impossible breath filling your ears.",
    off = "With the menacing clack of teeth, all of the mouths in your flesh snap abruptly shut."})
  
  defs_data:set('bulk', {type = 'anathema',
    def = "You have grown your bulk to monstrous proportions.",
    on = "Muscle warps and expands, flesh stretches and twists, your body swelling to monstrous proportions as you embrace the benefits of a superior form.",
    off = "Your excess mass drops away, and you return to a form more natural in proportions."})

  defs_data:set('eyes', {type = 'anathema',
    def = "Dozens of lidless eyes cover your body.",
    on = "Dozens of lidless eyes snap open in your flesh, gazing out upon Creation."})
    
  defs_data:set('joints', {type = 'anathema',
    def = "You have developed flexible joints.",
    on = "Your bones crackle and pop as they shift beneath your skin, adapting to a higher range of movement.",
    off = "Your limbs suddenly feel more stiff, your range of motion returning to the mundane."})

  defs_data:set('tentacles', {type = 'anathema',
    def = "You have tentacles flailing from your body.",
    on = "You raise your hands above your head, focusing your will to warp your own body. Ignoring the excruciating pain, tentacles spring out from the sides of your body and flail about of their own accord.",
    off = "You breathe a sigh of comfort as the flailing tentacles recede back into your body."})

--recondite works
  defs_data:set('unnamablepresence', {type = 'anathema',
    defr = [[^You (?:is|are) radiating the presence of the first foe.$]], -- the line has a typo and i don't really want it to break when they fix it!
    on = "You reach out to that which lies beyond, without, untapped; and you take of it into yourself.",
    off = "The presence of the Unnamable lifts, and you walk alone once more."})

  defs_data:set('devour', {type = 'anathema',
    def = "You will feast upon the work of ruin.",
    on = "Power thrums beneath your skin as you prepare for the rampage ahead.",
    off = "You let out a disappointed sigh as you realise the time for ruin is not yet upon you."})
    
--manifestations (these cannot be defup or keepup, it seems like they appear randomly as the Manifestation resource grows (further study needed)
  defs_data:set('brains', {nodef = true,
    def = "Geometric organs have thrust out of the sides of your head.",
    on = "Your head feels as if it shall burst apart as bone parts and warps, twisted geometric shapes formed of grey tissue bursting out of the sides of your skull under the force of your mutation.",
    off = "A measure of relief comes to your pounding skull as the grey tissue finally tears loose of your ravaged head, the geometric formations breaking apart and dissolving into a vile slurry."})
  
  defs_data:set('heads', {nodef = true,
    def = "Multiple heads have sprouted from your shoulders and back.",
    on = "The flesh across your shoulders and back bubbles and writhes, then multiple heads erupt from within your body as you undergo mutation.",
    off = "The multiple heads sprouting from your shoulders and back quake and tremble, before ripping away and falling to the ground in a bloody mess."})
  
  defs_data:set('tumors', {nodef = true,
    def = "Fluid-filled tumors cover your skin.",
    on = "With a series of popping sounds, fluid-filled tumors rapidly grow all over your body as you undergo mutation.",
    off = "The tumors covering your body shrink before vanishing with a series of stabbing pains."})  
  
  defs_data:set('tongues', {nodef = true,
    def = "The mouths in your flesh have sprouted tongues.",
    on = "With a horrible sucking sound, each of the mouths that have opened in your flesh produce a long tongue as you undergo mutation.",
    off = "The mouths in your flesh as one withdraw their tongues."})
    
  defs_data:set('venomsacks', {nodef = true,
    def = "You have grown sacks of venom within your mouth.",
    on = "You feel your jaw and cheeks distorting as you undergo mutation.",
    off = "You feel your face returning to normal, the sacks of toxin concealed within your mouth breaking apart."})

--croon (this is an aggressive ability that gives a temporary passive curing effect
  defs_data:set('croonmirror', {nodef = true,
    invisibledef = true,
    onr = [[^You sense the connection snap into place between the reality of (\w+) and your own.$]],
    on = "You sense no change.",
    offr = [[^You are no longer mirroring the reality of (\w+).$]]})
end

if svo.haveskillset('excision') then
  defs_data:set('fervour', { type = 'excision',
    def = 'Your fervour for the cause is great.',    
    on = 'Righteous fervour fills you; may the enemies of Creation be driven before Their armies.',
    off = 'Your righteous fervour is diminished, though your faith is not.'})
  defs_data:set('dawnhand', { type = 'excision',
    def = 'The light of dawn guides your hand.',    
    on = 'The unbroken strength of the Lightbringer fills you, and you know that you will strike true.',
    off = 'You feel diminished as the strength of the Lightbringer flees you, though you know that it will come again.'})
  defs_data:set('faith', { type = 'excision',
    def = 'You are clad in the armour of your faith.',
    on = 'You utter a soft prayer, and feel the shielding hand of the Bloodsworn protecting you.',
    off = 'The armour of your faith cracks and falls away.'})
  defs_data:set('retributionvow', { type = 'excision',
    def = 'You will take retribution against the enemies of Creation.',    
    on = 'You swear a vow of retribution, and the Bloodsworn acknowledge your prayer.',
    off = 'You will no longer bring retribution against the enemies of Creation.'})
  defs_data:set('unbowed', { type = 'excision',
    def = 'You stand unbowed in the face of all that would harm Creation.',    
    on = 'Planting your feet, you vow that you will stand unbowed.',
    off = 'You let out a great shout of defiance, holy wrath surging through you as your wounds close and your determination grows.'})
end

do 
  function svo.defences.enablemindnet()
    if svo.dict.mindnet then return end

    svo.basicdef('mindnet', "mindnet on")
    defences.register('mindnet', { type = 'general',
    on = {"You cast an invisible mind net out into the distance, allowing it to settle about the surrounding land.", "You already have mindnet active."},
    off = "You cease concentration and your mind net vanishes.",
    mana = 'little',
    def = "You have cast a mindnet over the local area."
    })

    svo.echof("Have Phylactery of Sixth Sense - enabled it for defup/keepup.")
  
end

  function defences.checkmindnet()
    local t = _G.gmcp.Char.Items.List
    -- (not t.location == 'inv' compared a boolean with a string, so a room's
    -- item list was searched as well)
    if t.location ~= 'inv' then return end

    for _, it in pairs(t.items) do
      -- if it.name == "a Veil of the Sphinx" then
      -- svof looked for two spaces after the "a", so runs of spaces count as
      -- one, whichever the game sends
      if (it.name:gsub("%s+", " ")) == "a phylactery of sixth sense" then
        defences.enablemindnet()
        conf.havemindnet = true
        raiseEvent("svo config changed", 'havemindnet')
        signals.gmcpcharitemslist:disconnect(defences.checkmindnet)
      end
    end

  end
  signals.systemstart:connect(function()
    tempTimer(0, function()
      if conf.havemindnet then
        defences.enablemindnet()
        signals.gmcpcharitemslist:disconnect(defences.checkmindnet)
      end
    end)
  end, 'enable mindnet when system loaded')
  signals.gmcpcharitemslist:connect(defences.checkmindnet, 'check mindnet on gmcpcharitemslist')
end

do
  function defences.enablelifevision()
    if svo.dict.lifevision then return end

    defences.register('lifevision', { type = 'general',
      on = {"You narrow your eyes and blink rapidly, enhancing your vision to seek out sources of lifeforce in others.", "You already possess enhanced vision."},
      def = "You have enhanced your vision to be able to see traces of lifeforce."}, {
      physical = {
        name = 'lifevision_physical',
        balance = 'physical',
        action_name = 'lifevision',
        balanceful_act = true,
        aspriority = 0,
        spriority = 0,
        def = true,

        isadvisable = function ()
          return (not defc.lifevision and ((sys.deffing and defdefup[defs.mode].lifevision) or (conf.keepup and defkeepup[defs.mode].lifevision)) and not svo.codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone) or false
        end,

        oncompleted = function ()
          defences.got('lifevision')
        end,

        action = 'lifevision',
        onstart = function ()
          send('lifevision', conf.commandecho)
        end
      }
    })

    svo.echof("Have lifevision mask - enabled it for defup/keepup.")
  end

  function defences.checklifevision()
    local t = _G.gmcp.Char.Items.List
    if t.location ~= 'inv' then return end

    -- feh! Easier to hardcode it for such a miniscule amount of items.
    -- If list enlarges, fix appopriately.
    for _, it in pairs(t.items) do
      -- if it.name == "a Veil of the Sphinx" then
      if it.name == "a mask of lifevision" or it.name == "a painted basilisk mask" or it.name == "a silver mask with gold reliefs" then
        defences.enablelifevision()
        conf.havelifevision = true
        raiseEvent("svo config changed", 'havelifevision')
        signals.gmcpcharitemslist:disconnect(defences.checklifevision)
      end
    end

  end
  signals.systemstart:connect(function()
    tempTimer(0, function()
      if conf.havelifevision then
        defences.enablelifevision()
        signals.gmcpcharitemslist:disconnect(defences.checklifevision)
      end
    end)
  end, 'enable lifevision when system loaded')
  signals.gmcpcharitemslist:connect(defences.checklifevision, 'check lifevision on gmcpcharitemslist')
end

do
  function defences.enableshroud()
    if svo.dict.shroud then return end

    defences.register('shroud', { type = 'general',
      on = {"You draw your Shadowcloak about you and blend into your surroundings.", "You draw a Shadowcloak about you and blend into your surroundings.", "You draw a cloak of the Blood Maiden about you and blend into your surroundings."},
      def = "Your actions are cloaked in secrecy.",
      off = {"Your shroud dissipates and you return to the realm of perception.", "The flash of light illuminates you - you have been discovered!"}}, {
      physical = {
        name = 'shroud_physical',
        balance = 'physical',
        action_name = 'shroud',
        balanceful_act = true,
        aspriority = 0,
        spriority = 0,
        def = true,

        isadvisable = function ()
          return (not defc.shroud and ((sys.deffing and defdefup[defs.mode].shroud) or (conf.keepup and defkeepup[defs.mode].shroud)) and not svo.codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone) or false
        end,

        oncompleted = function ()
          defences.got('shroud')
        end,

        action = 'shroud',
        onstart = function ()
          send('shroud', conf.commandecho)
        end
      }
    })

    svo.echofn("Have Shadowcloak - enabled it for defup/keepup (")
    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true)
    echoLink('disable', [[svo.conf.haveshroud = nil; svo.echof("Alright - won't add shroud to defup/keepup next time.") raiseEvent("svo config changed", 'haveshroud')]], 'Click to disable shroud from getting added to defup/keepup next time', true)
    setUnderline(false)
    echo(")\n")
  end

  function defences.checkshroud()
    local t = _G.gmcp.Char.Items.List
    if t.location ~= 'inv' then return end

    for _, it in pairs(t.items) do
      if it.name:find('Shadowcloak', 1, true) then
        defences.enableshroud()
        conf.haveshroud = true
        raiseEvent("svo config changed", 'haveshroud')
        signals.gmcpcharitemslist:disconnect(defences.checkshroud)
      end
    end

  end
  signals.systemstart:connect(function()
    tempTimer(0, function()
      if conf.haveshroud then
        defences.enableshroud()
        signals.gmcpcharitemslist:disconnect(defences.checkshroud)
      end
    end)
  end, 'enable shroud on login')
  signals.gmcpcharitemslist:connect(defences.checkshroud, 'check shroud on defs list')
end

-- check for both shadowcloak and mask of lifevision
function svo.detect_lifevision()
  sendGMCP("Char.Items.Inv")
  send("")
end

-- TODO: add a validator to make sure all defs have a type

-- quick debug validation
--~ for def, deft in defs_data:iter() do
  --~ if not deft.on and not deft.onr and not deft.nodef then
    --~ echo(def..", ")
  --~ end
--~ end

defences.urlify = function (self)
  local t = string.split(self, " ")
  for i = 1, #t do
    t[i] = string.title(t[i])
  end

  return table.concat(t, '_')
end


defences.complete_def = function(tbl)
  local name, def, defr, tooltip = tbl.name, tbl.def, tbl.defr, tbl.tooltip
  name = name:lower()

  if not defs_data[name] then return end

  defs_data[name].def = def or defs_data[name].def
  defs_data[name].defr = defr or defs_data[name].defr
  defs_data[name].tooltip = tooltip
end

sk.showwaitingdefup = function()
  return svo.concatand(select(2, sk.have_defup_defs()))
end

-- def setup & def-related controllers

-- used in 'vshow' to get the list of available defences
defences.print_def_list = function ()
  local t = {}; for defmode, _ in pairs(defdefup) do t[#t+1] = defmode end
  table.sort(t)

  -- echo each def mode: defence (-),
  for i = 1, #t do
    local defmode = t[i]

    if defmode ~= defs.mode then
      setFgColor(unpack(svo.getDefaultColorNums))
      setUnderline(true) echoLink(defmode, 'svo.defs.switch("'..defmode..'", true)', 'Switch to '..defmode..' defences mode', true) setUnderline(false)
    else
      fg'a_darkgreen'
      setUnderline(true) echoLink(defmode, 'svo.defs.switch("'..defmode..'", true)', 'Currently in this defence mode. Click to redo defup', true) setUnderline(false)
    end

    if sys.deffing and defmode == defs.mode then
      echo(" (currently deffing)")
    end

    echo" ("
    fg'orange_red'setUnderline(true) echoLink('-', 'svo.delete_defmode("'..defmode..'", true)', 'Delete '..defmode.. ' defences mode', true) setUnderline(false) setFgColor(unpack(svo.getDefaultColorNums))
    echo", "
    fg'a_darkgreen' setUnderline(true) echoLink('c', 'printCmdLine("vcopy defmode '..defmode..' TO ")', "Copy "..defmode.." into a new or existing defence mode", true) setUnderline(false) setFgColor(unpack(svo.getDefaultColorNums))
    echo")"

    if i == #t then echo " " else
      echo", "
    end
  end

  -- then an add the (+ add new), if we can
  if printCmdLine then
    echo("(")
    fg'a_darkgreen' setUnderline(true) echoLink("+ add new", 'printCmdLine("vcreate defmode ")', "Create a new defences mode", true) setUnderline(false) setFgColor(unpack(svo.getDefaultColorNums))
    echo(")")
  end

  echo"\n"
end

defences.get_def_list = function ()
  local s = svo.oneconcat(defdefup)

  if sys.deffing then
    s = string.gsub(s, "("..defs.mode..")", "(currently deffing) <0,250,0>%1" .. svo.getDefaultColor())
  else
    s = string.gsub(s, "("..defs.mode..")", "<0,250,0>%1" .. svo.getDefaultColor())
  end
  return s
end

-- nodefup is useful for relogging in, where you don't do defup, but you want keepup to be active
function defs.switch(which, echoback, nodefup)
  local sendf; if echoback then sendf = svo.echof else sendf = svo.errorf end

  if not which then
    sendf("To which mode do you want to switch to?") return
  end

  if not defdefup[which] then
    sendf("%s defence mode doesn't exist - the list is: %s", which, svo.oneconcat(defdefup)) return
  end

  defs.mode = which

  if not nodefup and echoback then
    svo.echof("Deffing up in %s defence mode.", defs.mode)
  end

  rift.precache = rift.precachedata[defs.mode] or {}
  if not nodefup then sys.deffing = true end
  sk.fix_affs_and_defs()
  startStopWatch(defences.defup_timer)

  raiseEvent("svo switched defence mode", defs.mode)
  if not nodefup then raiseEvent("svo started defup", defs.mode) end

  svo.make_gnomes_work()
  if not nodefup then svo.defupfinish() end
end

function defs.quietswitch(which, echoback)
  local sendf; if echoback then sendf = svo.echof else sendf = svo.errorf end

  if not which then
    sendf("To which mode do you want to switch to?") return
  end

  if not defdefup[which] then
    sendf("%s defence mode doesn't exist - the list is: %s", which, svo.oneconcat(defdefup)) return
  end

  defs.mode = which

  if echoback then
    svo.echof("Deffing up in %s defence mode.", defs.mode)
  end

  rift.precache = rift.precachedata[defs.mode] or {}
  sk.fix_affs_and_defs()
end

svo.defupfinish = function ()
  if not sys.deffing then return end

  -- serverside doesn't support defup and Svof doesn't emulate it at the moment
  if sk.have_defup_defs() then
    sys.deffing = false
    local time = stopStopWatch(defences.defup_timer)
    local timestring

    if time > 60 then
      timestring = string.format("%dm, %.1fs", math.floor(time/60), time%60)
    else
      timestring = string.format("%.1fs", time)
    end

    echo"\n"
    svo.echof("Ready for combat! (%s defences mode, took %s)", defs.mode, (timestring == "0.0s" and "no time" or timestring))
    raiseEvent("svo done defup", defs.mode)
    signals.donedefup:emit()
    svo.showprompt()
  end
end

svo.defupcancel = function(echoback)
  if sys.deffing then
    sys.deffing = false
    if echoback then svo.echof("Cancelled defup.") end
  else
    if echoback then svo.echof("Weren't doing defup already.") end
  end

  stopStopWatch(defences.defup_timer)
end

-- whether vshow hidelist hides a defence, itself or with its group
function defences.hidden(which)
  local group = defs_data[which] and sk.ignored_defences[defs_data[which].type]
  return group and (group.status or group.t[which]) and true or false
end

function defs.keepup(which, status, mode, echoback, reshow)
  local sendf; if echoback then sendf = svo.echof else sendf = svo.errorf end

  if not mode then mode = defs.mode end

  if not mode then
    sendf("We aren't in any defence mode yet - switch to one first.")
    return
  end

  if defkeepup[mode][which] == nil then
    sendf("Don't know about a %s defence.", which)
    return
  end

  -- if we were given an explicit option...
  if type(status) == 'string' then
    status = svo.convert_string(status)
  end

  -- if it's invalid or wasn't given to us, toggle
  if status == nil then
    if defkeepup[mode][which] then status = false
    else status = true end
  end

  if status == true and defs_data[which].onenable then
    local s,m = defs_data[which].onenable(mode, which, 'keepup', echoback)
    if not s then svo.echof(m) return end
  end

  defkeepup[mode][which] = status
  raiseEvent("svo keepup changed", mode, which, status)

  if echoback then
    if defkeepup[mode][which] then
      svo.echof("Will keep %s up%s.", which, (svo.ignore[which] and ' (however it\'s on ignore right now)' or ''))
    else
      svo.echof("Won't keep %s up anymore.", which)
    end

    if sys.deffing then
      svo.echof("You're still in defup however, and keepup is after defup. Still waiting on: %s to be put up.", sk.showwaitingdefup())
    elseif not conf.keepup and status == true then
      svo.echof("Keepup needs to be on, though.")
    end
    if status == true and not conf.showhiddendefs and defences.hidden(which) then
      svo.echof("%s is hidden in your defence lists, so vshow keepup won't show it; vshow hidelist shows it again.", which)
    end
  end

  sk.fix_affs_and_defs()
  svo.make_gnomes_work()

  if reshow then svo.show_keepup() echo"\n" end
end

function defs.defup(which, status, mode, echoback, reshow)
  local sendf; if echoback then sendf = svo.echof else sendf = svo.errorf end

  if not mode then mode = defs.mode end

  if not mode then
    sendf("We aren't in any defence mode yet - switch to one first.")
    return
  end

  if defdefup[mode][which] == nil then
    sendf("Don't know about a %s defence.", which)
    return
  end

  -- if we were given an explicit option...
  if type(status) == 'string' then
    status = svo.convert_string(status)
  end

  -- if it's invalid or wasn't given to us, toggle
  if status == nil then
    if defdefup[mode][which] then status = false
    else status = true end
  end

  if status == true and defs_data[which].onenable then
    local s,m = defs_data[which].onenable(mode, which, 'defup', echoback)
    if not s then svo.echof(m) return end
  end

  defdefup[mode][which] = status
  raiseEvent("svo defup changed", mode, which, status)

  if echoback then
    if defdefup[mode][which] then
      svo.echof("Will put %s up in %s mode.", which, mode)
    else
      svo.echof("Won't put %s up anymore in %s mode.", which, mode)
    end
    if status == true and not conf.showhiddendefs and defences.hidden(which) then
      svo.echof("%s is hidden in your defence lists, so vshow defup won't show it; vshow hidelist shows it again.", which)
    end
  end

  if reshow then svo.show_defup() echo"\n" end

  sk.fix_affs_and_defs()
  svo.make_gnomes_work()
end

function svo.create_defmode(which, echoback)
  local sendf; if echoback then sendf = svo.echof end

  svo.assert(which, "Which defences mode do you want to create?", sendf)
  svo.assert(not (defdefup[which] and defkeepup[which]), which .. " defences mode already exists.", sendf)

  defdefup[which] = {}
  defkeepup[which] = {}

  for k,_ in defs_data:iter() do
    defdefup[which][k] = false
    defkeepup[which][k] = false
  end

  rift.precachedata[which] = {}
  for _,herb in pairs(rift.herbsminerals) do
    rift.precachedata[which][herb] = 0
  end

  if echoback then
    sendf("Defences mode created. You may now do vdefs %s!", which)
    printCmdLine("vdefs "..which)
  end
end

function svo.copy_defmode(which, newname, echoback)
  local sendf; if echoback then sendf = svo.echof end

  svo.assert(which, "Which defences mode do you want to copy?", sendf)
  svo.assert(defdefup[which] and defkeepup[which], which .. " defences mode doesn't exist.", sendf)
  svo.assert(newname, "To which name do you want to rename " .. which .. " to?", sendf)

  defdefup[newname] = svo.deepcopy(defdefup[which])
  defkeepup[newname] = svo.deepcopy(defkeepup[which])
  rift.precachedata[newname] = svo.deepcopy(rift.precachedata[which])
  if echoback then svo.echof("Copied %s to %s.", which, newname) end
end

function svo.rename_defmode(which, newmode, echoback)
  local sendf; if echoback then sendf = svo.echof end

  svo.assert(which, "Which defences mode do you want to rename?", sendf)
  svo.assert(defdefup[which] and defkeepup[which], which .. " defences mode doesn't exist.", sendf)
  svo.assert(newmode, "To which name do you want to rename " .. which .. " to?", sendf)

  if defs.mode == which then
    defs.mode = newmode
    if echoback then
      svo.echof("Changed your current defence mode to %s", defs.mode)
    end
  end

  defdefup[newmode], defdefup[which] = defdefup[which], defdefup[newmode]
  defkeepup[newmode], defkeepup[which] = defkeepup[which], defkeepup[newmode]
  rift.precachedata[which], rift.precachedata[newmode] = rift.precachedata[newmode], rift.precachedata[which]
  if echoback then svo.echof("Renamed %s to %s.", which, newmode) end
end

function svo.delete_defmode(which, echoback)
  local sendf; if echoback then sendf = svo.echof end

  svo.assert(which, "Which defences mode do you want to delete?", sendf)
  svo.assert(defdefup[which] and defkeepup[which], which .. " defences mode doesn't exist.", sendf)
  svo.assert(which ~= defs.mode, "You're currently in " .. which .. " defmode already - switch to another one first, and then delete this one.", sendf)

  defdefup[which], defkeepup[which], rift.precachedata[which] = nil, nil, nil

  if math.random(1, 10) == 1 then
    svo.echof("Deleted '%s' defences mode.", which)
  else
    svo.echof("Deleted '%s' defences mode. Forever!", which) end
end

function svo.defload()
  local defdefup_t, defkeepup_t = {}, {}
  local defup_path, keepup_path = getMudletHomeDir() .. "/svo/defup+keepup/defup", getMudletHomeDir() .. "/svo/defup+keepup/keepup"

  if lfs.attributes(defup_path) then table.load(defup_path, defdefup_t) end
  if lfs.attributes(keepup_path) then table.load(keepup_path, defkeepup_t) end
  if lfs.attributes(getMudletHomeDir() .."/svo/defup+keepup/ignored_defences") then
    table.load(getMudletHomeDir() .."/svo/defup+keepup/ignored_defences", sk.ignored_defences)
  end

  if lfs.attributes(getMudletHomeDir() .."/svo/defup+keepup/offline_defences") then
    local t = {}
    table.load(getMudletHomeDir() .."/svo/defup+keepup/offline_defences", t)

    for i = 1, #t do
      defences.got(t[i])
    end

    signals.dragonform:emit()
  end

  return defdefup_t, defkeepup_t
end

signals.relogin:connect(function()
  -- reset defs at login
  local t = {}
  for def in pairs(defc) do
    if def ~= 'dragonform' then
      t[#t+1] = defc
    end
  end

  for i = 1, #t do
    defences.lost(t[i])
  end
end, 'remove defs at login')

-- re-set defences mode to basic upon qqing and relogging in without closing Mudlet
function sk.loginonbasic()
  -- defs.mode = "" -- small hack to have the defup start event be raised when logging in for the first time, can't have the value on "" to begin with because the mode is always expected to be valid
  defs.switch('basic', true, true)

  -- disable initial connect and only use relogin after the first time
  signals.charname:disconnect(sk.loginonbasic)
  signals.gmcpcharname:disconnect(sk.loginonbasic)
end
signals.relogin:connect(sk.loginonbasic, 'change to basic mode at re/login')
signals.charname:connect(sk.loginonbasic, 'change to basic mode at re/login')
signals.gmcpcharname:connect(sk.loginonbasic, 'change to basic mode at re/login')

signals.saveconfig:connect(function ()
  svo.tablesave(getMudletHomeDir() .. "/svo/defup+keepup/defup", defdefup)
  svo.tablesave(getMudletHomeDir() .. "/svo/defup+keepup/keepup", defkeepup)
  svo.tablesave(getMudletHomeDir() .. "/svo/defup+keepup/ignored_defences", sk.ignored_defences)

  local t = {}
  for k,v in defs_data:iter() do if v.offline_defence and defc[k] then t[#t+1] = k end end
  svo.tablesave(getMudletHomeDir() .. "/svo/defup+keepup/offline_defences", t)
end, 'save defs config')

function sk.sanitize(self)
  return string.gsub(self, " ", '_')
end

function sk.desanitize(self)
  return string.gsub(self, '_', " ")
end

-- The balance of def's entry a gain line claims. With inflight, one whose
-- action svof has in flight, or nil. Without, one that raises the defence,
-- the first by name, so the choice does not depend on pairs(): five entries
-- raise their defence on two balances (blind, deaf, deathsight, thirdeye,
-- insomnia), and pairs() picked either, or insomnia's aff block. An entry
-- with no raising balance falls back, as before, to any balance but gone.
function defences.raising_balance(def, inflight)
  local entry = svo.dict[def]
  if type(entry) ~= 'table' then return nil end
  local raising, other = {}, {}
  for bal, act in pairs(entry) do
    if type(act) == 'table' and bal ~= 'gone' then
      if act.def then raising[#raising + 1] = bal else other[#other + 1] = bal end
    end
  end
  table.sort(raising)
  if inflight then
    for _, bal in ipairs(raising) do
      if actions[entry[bal].name] then return bal end
    end
    return nil
  end
  table.sort(other)
  return raising[1] or other[1]
end

-- The temp triggers for a defence record's lines, remembered by defence
-- (defences.triggers_of), so that they can be killed and made again when
-- the lines change: a definition installed again, or a change to svof's
-- own defence.
function defences.wire_triggers(defname, defdata)
    local first = #svo.defencetemptriggers + 1

    if defdata.onr and type(defdata.onr) == 'table' then
      for _, pattern in ipairs(defdata.onr) do
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempRegexTrigger(pattern, 'svo.defs.got_' .. sk.sanitize(defname) .. '()')
      end
    elseif defdata.onr then
      svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempRegexTrigger(defdata.onr, 'svo.defs.got_' .. sk.sanitize(defname) .. '()')
    end

    if defdata.on and type(defdata.on) == 'table' then
      for _, pattern in ipairs(defdata.on) do
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(pattern, 'svo.defs.got_' .. sk.sanitize(defname) .. '()')
      end
    elseif defdata.on then
      svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(defdata.on, 'svo.defs.got_' .. sk.sanitize(defname) .. '()')
    end

    if defdata.on_only and type(defdata.on_only) == 'table' then
      for _,pattern in ipairs(defdata.on_only) do
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(pattern, 'svo.defs.gotonly_' .. sk.sanitize(defname) .. '()')
      end
    elseif defdata.on_only then
      svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(defdata.on_only, 'svo.defs.gotonly_' .. sk.sanitize(defname) .. '()')
    end

    if defdata.on_free then svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(defdata.on_free, 'svo.defs.got_' .. sk.sanitize(defname) .. '()') end

    if defdata.offr and type(defdata.offr) == 'string' then
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempRegexTrigger(defdata.offr, 'svo.defs.lost_' .. sk.sanitize(defname) .. '()')
    elseif defdata.offr then
      for _,pattern in ipairs(defdata.offr) do
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempRegexTrigger(pattern, 'svo.defs.lost_' .. sk.sanitize(defname) .. '()')
      end
    end

    if defdata.off and type(defdata.off) == 'string' then
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(defdata.off, 'svo.defs.lost_' .. sk.sanitize(defname) .. '()')
    elseif defdata.off then
      for _,pattern in ipairs(defdata.off) do
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(pattern, 'svo.defs.lost_' .. sk.sanitize(defname) .. '()')
      end
    end

    -- this is EXACTLY for substring
    if defdata.offs and type(defdata.offs) == 'string' then
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempTrigger(defdata.offs, 'svo.defs.lost_' .. sk.sanitize(defname) .. '()')
    elseif defdata.offs then
      for _,pattern in ipairs(defdata.offs) do
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempTrigger(pattern, 'svo.defs.lost_' .. sk.sanitize(defname) .. '()')
      end
    end

    if defdata.off_free then svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(defdata.off_free, 'svo.defs.lost_' .. sk.sanitize(defname) .. '()') end

    if defdata.def and type(defdata.def) == 'table' then
      for _,pattern in ipairs(defdata.def) do
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(pattern, 'svo.defs.def_' .. sk.sanitize(defname) .. '()')
      end
    elseif defdata.def then
      svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempExactMatchTrigger(defdata.def, 'svo.defs.def_' .. sk.sanitize(defname) .. '()')
    end

    if defdata.defr and type(defdata.defr) == 'table' then
      for _,pattern in ipairs(defdata.defr) do
        svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempRegexTrigger(pattern, 'svo.defs.def_' .. sk.sanitize(defname) .. '()')
      end
    elseif defdata.defr then
      svo.defencetemptriggers[#svo.defencetemptriggers+1] = tempRegexTrigger(defdata.defr, 'svo.defs.def_' .. sk.sanitize(defname) .. '()')
    end

    defences.triggers_of[defname] = {}
    for i = first, #svo.defencetemptriggers do
      defences.triggers_of[defname][#defences.triggers_of[defname] + 1] = svo.defencetemptriggers[i]
    end
end

-- Everything svof makes from one defence record: its temp triggers, its
-- handlers, its place in the defence lists and the defup and keepup slots.
-- systemstart runs it for every record.
function defences.wire(defname, defdata)
    -- sort into def types if applicable
    if defdata.custom_def_type then
      defences.custom_types[defdata.custom_def_type] = defences.custom_types[defdata.custom_def_type] or {}
      defences.custom_types[defdata.custom_def_type][defname] = true
    end

    defences.wire_triggers(defname, defdata)

    if not defs['got_' .. defname] then
      if svo.dict[defname] then
        local bal = defences.raising_balance(defname)
        if bal then
          defs['got_' .. defname] = function (force)
					  -- svo.dict might not know about a defence when you go lesserform
						-- before it's reloaded for the specific class
					  if not svo.dict[defname] then return end

            -- whichever of its raising actions svof has in flight claims the line
            local bal = defences.raising_balance(defname, true) or bal
            if svo.haveskillset('metamorphosis') then
              if defdata.custom_def_type or svo.usingbal(bal) then svo.checkaction(svo.dict[defname][bal], true)
              else svo.checkaction(svo.dict[defname][bal], force) end
            else
              if not defdata.custom_def_type then svo.checkaction(svo.dict[defname][bal], force) else svo.checkaction(svo.dict[defname][bal], true) end
            end
            if actions[defname .. '_' .. bal] then
              if force then --bypass lifevision for gmcp/other 'force' situations
                svo.actionfinished(actions[defname .. '_' .. bal].p)
              else
                lifevision.add(actions[defname .. '_' .. bal].p)
              end
            end
          end
        end
      end

      if not defs['got_' .. defname] then
        defs['got_' .. defname] = function ()
          defences.got(defname)
        end
      end
    end

    if defdata.on_only and not defs['gotonly_' .. defname] then
      if svo.dict[defname] then
        local bal = defences.raising_balance(defname)
        defs['gotonly_' .. defname] = function ()
          local bal = defences.raising_balance(defname, true) or bal
          svo.checkaction(svo.dict[defname][bal], false)
          if actions[defname .. '_' .. bal] then
            lifevision.add(actions[defname .. '_' .. bal].p)
          end
        end
      else
        defs['gotonly_' .. defname] = function ()
          defences.got(defname)
        end
      end
    end

    if not defs['lost_' .. sk.sanitize(defname)] then
      if svo.dict[defname] and svo.dict[defname].gone then
        defs['lost_' .. defname] = function ()
          svo.checkaction(svo.dict[defname].gone, true)
          if actions[defname .. '_gone'] then
            lifevision.add(actions[defname .. '_gone'].p)
          end
        end
      else
        defs['lost_' .. defname] = function ()
          defences.lost(defname)
        end
      end
    end

    if not defdata.nodef and not defdata.custom_def_type then
      defs['def_'..sk.sanitize(defname)] = function ()

        -- if we're in dragonform and this isn't a general or a dragoncraft def, then remember it as an additional def - not a class skill one, since those are not shown in Dragon
        if defc.dragonform and defdata.type ~= 'general' and defdata.type ~= 'dragoncraft' then
          if not defdata.ondef then
            defences.nodef_list[defname] = true
          else
            defences.nodef_list[defname] = defdata.ondef()
          end
        else
          if not defdata.ondef then
            defences.def_def_list[defname] = true
          else
            defences.def_def_list[defname] = defdata.ondef()
          end
        end
        deleteLine()
      end
    elseif not defdata.nodef and defdata.custom_def_type then
      defs['def_'..sk.sanitize(defname)] = function ()
        defences.got(defname)
        deleteLine()
      end

    -- additional defence (nodef)
    else
      defs['def_'..sk.sanitize(defname)] = function ()
      -- only accept the def line if we know that we're parsing the def list currently, so lines similar to ones on the DEFENCES list that show up elsewhere don't mess things up
        if not actions.defcheck_physical then return end

        deleteLine()
        if not defdata.ondef then
          defences.nodef_list[defname] = true
        else
          defences.nodef_list[defname] = defdata.ondef()
        end
      end
    end

    -- fill up our defences.def_types
    if defdata.type then
      defences.def_types[defdata.type] = defences.def_types[defdata.type] or {}
      defences.def_types[defdata.type][#defences.def_types[defdata.type]+1] = defname
    end

    -- create blanks for defup and keepup
    if not defdata.nodef then
      for mode, _ in pairs(defdefup) do
        defdefup[mode][defname] = false
        defkeepup[mode][defname] = false
      end
    end

    if defdata.type then
      sk.ignored_defences[defdata.type] = sk.ignored_defences[defdata.type] or {status = false, t = {}}
      sk.ignored_defences[defdata.type].t[defname] = sk.ignored_defences[defdata.type].t[defname] or false
      sk.ignored_defences_map[defname] = defdata.type
    end
end

-- the key sys.input_to_actions holds a command under, or nil: as curingcommand
-- looks serverside's up, in lower case without the spaces around it
function defences.command_key(command)
  local key = type(command) == 'string' and command:lower():match("^%s*(.-)%s*$")
  if key and key ~= '' then return key end
end

-- puts act in map under its command as serverside sends it and as the
-- player typed it, which processusercommand looks up as it is, unless the
-- map gives either to another action
local function map_command(map, act, command)
  local key = defences.command_key(command)
  if not key then return end
  if not map[key] then map[key] = act end
  if command ~= key and not map[command] then map[command] = act end
end

-- Registers a defence after systemstart, the way systemstart wires every
-- other: its record (what the game prints), its dictionary entry (how svof
-- raises it) when one is given, then defences.wire. For a defence that comes
-- with an item, such as the phylactery's mindnet. dict_setup gives the entry
-- its names and priorities, a player's saved defup and keepup choice for it
-- is kept, and its handlers are remembered with the ones systemstart made,
-- for the next systemstart to clear. definition says it's one the player
-- defined, which no change to svof's own goes on.
function defences.register(name, record, entry, definition)
  defs_data:set(name, record)
  if entry then svo.dict[name] = entry end

  -- create a snapshot of the before state for all balances, since svo.dict_setup might mess with any
  local beforestate = sk.getbeforestateprios()
  svo.dict_setup()
  svo.dict_validate()
  -- notify any prio diffs
  sk.notifypriodiffs(beforestate, sk.getafterstateprios())

  -- an item's defence registers after systemstart put the player's changes
  -- to svof's own into play, so its change goes in here
  if not definition then defences.edit_put(name) end

  -- svof takes its command for its own when the player types it or
  -- serverside sends it ([Curing]: <COMMAND>), as for the defences
  -- systemstart's map made before this one registered. One the map gives
  -- another action stays that action's
  local map = sys.input_to_actions
  if map and type(svo.dict[name]) == 'table' then
    for _, act in pairs(svo.dict[name]) do
      if type(act) == 'table' then map_command(map, act, act.action) end
    end
  end

  -- what systemstart restored from the saved settings, which wire resets
  local saved = {}
  for mode in pairs(defdefup) do saved[mode] = { defdefup[mode][name], defkeepup[mode] and defkeepup[mode][name] } end

  for _, h in ipairs({'got_' .. name, 'lost_' .. name, 'def_' .. sk.sanitize(name), 'gotonly_' .. name}) do
    if defences.generated and defences.generated[h] then defs[h] = nil end
  end
  local existing = {}
  for h in pairs(defs) do existing[h] = true end

  -- (wire remembers its triggers, for defences.unregister)
  defences.wire(name, defs_data[name])

  defences.generated = defences.generated or {}
  for h in pairs(defs) do
    if not existing[h] then defences.generated[h] = true end
  end
  for mode, choice in pairs(saved) do
    defdefup[mode][name] = choice[1] or false
    if defkeepup[mode] then defkeepup[mode][name] = choice[2] or false end
  end

  signals.dragonform:emit()
end
defences.triggers_of = defences.triggers_of or {}

-- Takes out a defence defences.register put in, as deleting a definition
-- or installing it again does: its triggers, handlers, record, entry, places
-- in the defence lists and GMCP name. keepchoices leaves its defup and
-- keepup choices, and whether it's hidden, for the next register to keep.
function defences.unregister(name, keepchoices)
  local rec = defs_data[name]
  for _, id in ipairs(defences.triggers_of[name] or {}) do killTrigger(id) end
  defences.triggers_of[name] = nil
  for _, h in ipairs({'got_' .. name, 'lost_' .. name, 'def_' .. sk.sanitize(name), 'gotonly_' .. name}) do
    if defences.generated and defences.generated[h] then
      defs[h] = nil
      defences.generated[h] = nil
    end
  end
  if rec and rec.type then
    local list = defences.def_types[rec.type] or {}
    for i = #list, 1, -1 do
      if list[i] == name then table.remove(list, i) end
    end
    -- a group of the player's own goes with its last defence
    if #list == 0 then defences.def_types[rec.type] = nil end
    if sk.ignored_defences[rec.type] and not keepchoices then sk.ignored_defences[rec.type].t[name] = nil end
  end
  sk.ignored_defences_map[name] = nil
  if not keepchoices then
    for mode in pairs(defdefup) do
      defdefup[mode][name] = nil
      if defkeepup[mode] then defkeepup[mode][name] = nil end
    end
  end
  local gamename = svo.dict.svotossd[name]
  if gamename and svo.dict.sstosvod[gamename] == name then svo.dict.sstosvod[gamename] = nil end
  svo.dict.svotossd[name] = nil
  -- what the GMCP name meant before a definition took it, such as a copy's
  -- name, which svof's own has in every class
  local held = defences.gmcp_held[name]
  if held then
    svo.dict.sstosvod[held.gmcp] = held.mapped
    svo.dict.svotossd[name] = held.gamename
    defences.gmcp_held[name] = nil
  end

  if type(svo.dict[name]) == 'table' then
    for _, act in pairs(svo.dict[name]) do
      if type(act) == 'table' and act.name then svo.killaction(act) end
      -- and its command, from the map of commands svof takes for its own
      for key, mapped in pairs(sys.input_to_actions or {}) do
        if mapped == act then sys.input_to_actions[key] = nil end
      end
    end
  end
  local beforestate = sk.getbeforestateprios()
  svo.dict[name] = nil
  defs_data:set(name, nil)
  svo.dict_setup()
  svo.dict_validate()
  sk.notifypriodiffs(beforestate, sk.getafterstateprios())

  defc[name] = nil
  signals.dragonform:emit()
end

signals.systemstart:connect(function ()
  local defdefup_t, defkeepup_t = svo.defload()
	
  --Empty the def_type table on startup and class change to prevent duplicate defences.
  defences.def_types = {}
 
  --organise tempTriggers in a table to delete on class change
  svo.defencetemptriggers = svo.defencetemptriggers or {}
  -- and by defence, for the ones made below
  defences.triggers_of = {}

  -- create blank defup modes
  for k,_ in pairs(defdefup_t) do
    defdefup[k] = defdefup[k] or {}
    defkeepup[k] = defkeepup[k] or {}
  end

  -- The handlers this made last time came from the last class's records.
  -- svo.defs outlives a class change, and below a handler is only made where
  -- none exists, so they stayed: a lost_ for a defence the new class does
  -- not have raised, indexing a dictionary entry that was gone. Hand-written
  -- handlers are not in the list, and are left alone.
  for name in pairs(defences.generated or {}) do defs[name] = nil end
  local existing = {}
  for name in pairs(defs) do existing[name] = true end

  -- the player's changes to svof's own defences, so the triggers below are
  -- made from their lines
  defences.edits_start()

  for defname, defdata in defs_data:iter() do
    defences.wire(defname, defdata)
  end -- end of the whole defences svo.dict iteration

  svo.update(defdefup, defdefup_t)
  svo.update(defkeepup, defkeepup_t)

  -- The skillsets this class doesn't have stay in the hide list, which
  -- shows only this class's: removing them here forgot what a player hid
  -- in one class on changing to another and back


  -- simple way of removing all and adding per line
  for name, _ in pairs(defences.custom_types) do
    defs['def'..name..'start'] = function()
      for def, _ in pairs(defences.custom_types[name]) do
        defences.lost(def)
      end
    end
  end

  -- remember what was made here, for the next systemstart to clear
  defences.generated = {}
  for name in pairs(defs) do
    if not existing[name] then defences.generated[name] = true end
  end
end, 'setup def triggers on system start')

-- Defences the player defines (vcustomdef). They are saved under
-- <profile>/svo/custom/defs, which a package update leaves alone, and
-- registered again on every systemstart, as defs_data and svo.dict are both
-- made anew then, before the prio import, so a saved priority for one
-- applies. A definition is a table:
--   class        the class it belongs to, as the game names it, or 'all'
--                for one any class can have, such as an item's
--   skillset     for a class's, the group the defence lists show it in:
--                one of the class's skillsets, or a name the player gives
--                where svof's list of them is out of date (the user's
--                choice, 2026-10-10). One any class can have is general.
--   command      what svof sends to raise it
--   balanceless  true when raising it takes no balance
--   on, off      the exact lines saying you gained it and lost it
--   onr, offr, defr  patterns for gain, loss and DEF lines that vary, as
--                svof's own records have (the user, 2026-10-11), next to
--                the exact lines; only one Mudlet's rex library reads is
--                taken
--   def          the exact line DEF shows for it. Without one, each DEF
--                marks it gone, which test and install warn about
--   notondef     true for a defence DEF doesn't list, such as Pariah's
--                bloodiedknife, which DEF then leaves alone (svof's own
--                invisibledef)
--   gmcp         its name over GMCP, which is its serverside name as well.
--                With one, serverside raises it while serverside is on,
--                and svof does otherwise, unless vshow server leaves it to
--                svof; without one, only svof can (the user, 2026-10-10).
--                Only a name the game confirms is taken (the user,
--                2026-10-10): with a wrong one, svof would leave the
--                defence to serverside, which couldn't raise it either
--   copy         for a copy of svof's own defence from another class:
--                from, a class it was copied from; was, svof's version
--                then, to say when svof has updated it since; lines, the
--                other lines svof watches for, which a copy keeps as they
--                are
-- A name svof already uses is refused (vcustomdef with the name of one of
-- svof's own defences changes that instead, further down), and so is one
-- svof has in another class (defences.catalog), which can be copied in
-- instead. A definition that clashes with this class's defences
-- (defences.clash), or fails to register, is reported and skipped.
-- vconfig customdefinitions off loads none, for a definition that has
-- broken curing.
local custom_path = getMudletHomeDir() .. "/svo/custom/defs"

function defences.custom_load()
  local t = {}
  if lfs.attributes(custom_path) then
    local ok, msg = pcall(table.load, custom_path, t)
    if not ok then
      svo.echof("<250,0,0>Couldn't%s read the defences you defined, in %s: %s", svo.getDefaultColor(), custom_path, tostring(msg))
      t = {}
    end
  end
  defences.custom = t
end

function defences.custom_save()
  svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/custom")
  svo.tablesave(custom_path, defences.custom)
end

-- whether svof already uses the name: a defence this class has, one an
-- item brings, or anything else in the dictionary, such as an affliction.
-- One a definition registered (defences.custom_registered) is the player's.
defences.custom_registered = defences.custom_registered or {}
-- what the GMCP names registered definitions took meant before
defences.gmcp_held = defences.gmcp_held or {}
local item_defences = { mindnet = true, lifevision = true, shroud = true }
function defences.custom_taken(name)
  if defences.custom_registered[name] then return false end
  return (defs_data[name] or svo.dict[name] or item_defences[name]) and true or false
end

-- a record's line or lines, as a new list
local function line_list(v)
  if type(v) == 'string' then return { v } end
  local t = {}
  if type(v) == 'table' then
    for i, l in ipairs(v) do t[i] = l end
  end
  return t
end

-- A lord and a lady of one element are one class: svo.knownskills lists
-- both, with the same skillset. A definition's class is the element's,
-- whichever the player is
local function class_key(class)
  class = tostring(class):lower()
  return class:match("^(%a+ elemental) lord$") or class:match("^(%a+ elemental) lady$") or class
end
defences.class_key = class_key

-- a class's skillsets, from svo.knownskills, or nil for a class svof
-- doesn't know
local function class_skills(class)
  local key = class_key(class)
  return svo.knownskills[key] or svo.knownskills[key .. " lord"]
end

local function class_title(class)
  if class == 'all' then return "every class" end
  return (class_key(class):gsub("(%a)(%a*)", function (a, b) return a:upper() .. b end))
end

function defences.custom_applies(spec)
  return spec.class == 'all' or (type(spec.class) == 'string' and class_key(spec.class) == class_key(me.class))
end

-- vcustomdef's screens: links white, ones that take something out red,
-- and ones that put something into play green; labels in the colour of
-- svof's defence lists, and a part not set yet grey
local link_colours = { remove = { 255, 99, 71 }, go = { 0, 204, 0 } }
local function custom_link(text, code, hint, kind)
  local c = link_colours[kind] or { 255, 255, 255 }
  setUnderline(true)
  setFgColor(c[1], c[2], c[3])
  echoLink(text, code, hint, true)
  resetFormat()
end

local function custom_label(text)
  setFgColor(153, 204, 204)
  echo(string.format("  %-12s ", text))
  resetFormat()
end

local function custom_unset_text(text)
  setFgColor(128, 128, 128)
  echo(text)
  resetFormat()
end

-- a line between a list or screen and the links under it (the user's ask,
-- 2026-10-17)
local function custom_separator()
  custom_unset_text("  " .. string.rep("-", 70) .. "\n")
end

-- Svof's own defences that only some classes have, with each class's
-- version: tools/defence_catalog.lua writes them, from every class, to
-- defence_catalog.lua in Svof's folder. Svof builds only the class it
-- loads, so this is how it knows a name is its own in another class. A
-- definition can't take such a name, and Svof's own can be copied in
-- instead (the user, 2026-10-10), for a class Svof's list is out of date
-- for, or a defence an artefact gives every class. Read once, when first
-- needed.
local catalog
function defences.catalog()
  if catalog then return catalog end
  catalog = {}
  local path = defences.catalog_file or (svo.installationfolder() .. "/defence_catalog.lua")
  local f = io.open(path, "r")
  if not f then return catalog end
  local text = f:read("*a")
  f:close()
  local chunk, err
  if setfenv then
    chunk, err = loadstring(text, "=defence_catalog")
    if chunk then setfenv(chunk, {}) end
  else
    chunk, err = load(text, "=defence_catalog", "t", {})
  end
  local ok, t = false, err
  if chunk then ok, t = pcall(chunk) end
  if ok and type(t) == 'table' then
    catalog = t
  else
    svo.echof("<250,0,0>Couldn't%s read Svof's list of every class's defences, in %s: %s", svo.getDefaultColor(),
      path, tostring(t))
  end
  return catalog
end

-- the classes versions of a defence are for, as the game writes them, an
-- element's lord and lady as one
local function class_names(versions)
  local t, seen = {}, {}
  for _, v in ipairs(versions) do
    for _, c in ipairs(v.classes or {}) do
      local title = class_title(c)
      if not seen[title] then
        seen[title] = true
        t[#t + 1] = title
      end
    end
  end
  return svo.concatand(t)
end

-- whose a defence in this class is, for saying what a clash is with
local function whose(name)
  return (defences.custom_registered[name] and "your " or "Svof's ") .. name
end

-- the record fields that hold exact lines, and the ones that hold
-- patterns, for lines that vary
local exact_fields = { 'on', 'off', 'def', 'on_only', 'on_free', 'off_free' }
local pattern_fields = { 'onr', 'offr', 'defr' }
local kind_of = { on = "gain", off = "loss", def = "DEF", onr = "gain", offr = "loss", defr = "DEF" }

-- Mudlet's PCRE library, which tempRegexTrigger matches patterns with, or
-- nil where there's none
local function pcre()
  return rawget(_G, 'rex')
end

-- each pattern compiled once, since clash matches every pattern against
-- every line; false for one the library can't read
local compiled = setmetatable({}, { __mode = 'k' })

-- whether pattern matches line, by the library the trigger would use
local function pattern_matches(pattern, line)
  local rex = pcre()
  if not rex then return false end
  local byrex = compiled[rex]
  if not byrex then
    byrex = {}
    compiled[rex] = byrex
  end
  local re = byrex[pattern]
  if re == nil then
    local ok, made = pcall(rex.new, pattern)
    re = ok and made or false
    byrex[pattern] = re
  end
  if not re then return false end
  local ok, m = pcall(re.match, re, line)
  return ok and m ~= nil and m ~= false
end

-- why pattern can't be a definition's, or nil
function defences.pattern_problem(pattern)
  local rex = pcre()
  if not rex then return "Svof can't read patterns without Mudlet's rex library" end
  local ok, err = pcall(rex.new, pattern)
  if not ok then return "it isn't a pattern Svof can read (" .. tostring(err) .. ")" end
end

-- why one of spec's patterns can't be used, or nil, for those kept(field,
-- pattern) doesn't keep, such as svof's own. Such as ones a file brought
-- in, as typed ones are checked; svof can only check them where Mudlet's
-- rex library is
local function patterns_problem(spec, kept)
  if not pcre() then return end
  for _, field in ipairs(pattern_fields) do
    for _, p in ipairs(line_list(spec[field])) do
      local why = not (kept and kept(field, p)) and defences.pattern_problem(p)
      if why then return string.format("%s can't be a pattern: %s", p, why) end
    end
  end
end

-- Why a defence's lines, GMCP name or command clash with what this class
-- already has, or nil. A clash makes the game's word on one defence count
-- for another as well, so nothing that clashes goes into play (the user,
-- 2026-10-10). parts holds lines, every exact line the defence watches
-- for, and kinds, the same by kind (on, off, def); subs, the part-lines it
-- watches for (a record's offs); patterns, its patterns, each { field,
-- pattern } (onr, offr, defr); gmcp and command. Its lines are checked
-- against other defences' patterns, and its patterns against other
-- defences' lines and its own lines of another kind, by the library the
-- triggers match with. Two patterns can't be checked against each other.
-- For a change, lines and patterns are what it adds, which the other
-- defences are checked against, and selfpatterns all its patterns, which
-- kinds, all its lines, are
function defences.clash(name, parts)
  -- a pattern of one kind that matches its own line of another, so that
  -- the line would say both
  for _, p in ipairs(parts.selfpatterns or parts.patterns or {}) do
    for kind, lines in pairs(parts.kinds or {}) do
      if kind_of[kind] ~= kind_of[p[1]] then
        for _, line in ipairs(lines) do
          if pattern_matches(p[2], line) then
            return string.format("its %s pattern %q matches its own %s line %q", kind_of[p[1]], p[2], kind_of[kind], line)
          end
        end
      end
    end
  end
  local gmcp = parts.gmcp
  if gmcp then
    local mapped = svo.dict.sstosvod[gmcp]
    -- a registered definition's is mapped too. Saved ones that aren't
    -- aren't counted: as svof loads, two that share a name would each
    -- refuse the other, where this lets the first in
    if type(mapped) == 'string' and mapped ~= name then
      return string.format("GMCP's %s is already %s", gmcp, whose(mapped))
    end
  end
  local lines, subs = parts.lines or {}, parts.subs or {}
  for other, rec in defs_data:iter() do
    if other ~= name then
      for _, field in ipairs(exact_fields) do
        for _, theirs in ipairs(line_list(rec[field])) do
          for _, line in ipairs(lines) do
            if line == theirs then return string.format("%s already watches for %q", whose(other), line) end
          end
          for _, sub in ipairs(subs) do
            if theirs:find(sub, 1, true) then return string.format("%s's line %q has %q in it", whose(other), theirs, sub) end
          end
        end
      end
      for _, sub in ipairs(line_list(rec.offs)) do
        for _, line in ipairs(lines) do
          if line:find(sub, 1, true) then return string.format("%s already watches for lines with %q in them", whose(other), sub) end
        end
      end
      -- its lines against their patterns, and its patterns against their
      -- lines
      for _, field in ipairs(pattern_fields) do
        for _, theirs in ipairs(line_list(rec[field])) do
          for _, line in ipairs(lines) do
            if pattern_matches(theirs, line) then
              return string.format("%s's pattern %q matches %q", whose(other), theirs, line)
            end
          end
        end
      end
      for _, p in ipairs(parts.patterns or {}) do
        for _, field in ipairs(exact_fields) do
          for _, theirs in ipairs(line_list(rec[field])) do
            if pattern_matches(p[2], theirs) then
              return string.format("the pattern %q matches %s's line %q", p[2], whose(other), theirs)
            end
          end
        end
      end
    end
  end
  local command = defences.command_key(parts.command)
  if command then
    -- what svof takes a command for when the player types it or serverside
    -- sends it, the registered definitions' included (defences.register)
    local act = sys.input_to_actions and sys.input_to_actions[command]
    local taken = act and (act.action_name or act.name)
    if taken and taken ~= name and defences.custom_registered[taken] then
      return string.format("your %s is raised with %q too", taken, parts.command)
    elseif taken and taken ~= name then
      return string.format("Svof already takes %q as %s's command", parts.command, taken)
    end
  end
end

-- the lines a copy of Svof's own carries besides the ones a definition
-- has, which come from Svof and can't be changed. Svof's patterns go in
-- the copy's onr, offr and defr, where they can
local copy_line_fields = { 'def', 'onr', 'offr', 'defr', 'on_only', 'on_free', 'off_free', 'offs' }

-- what a definition watches for and sends, for defences.clash
local function custom_parts(spec)
  local lines = {}
  local kinds = { on = line_list(spec.on), off = line_list(spec.off), def = line_list(spec.def) }
  for _, kind in ipairs({ 'on', 'off', 'def' }) do
    for _, l in ipairs(kinds[kind]) do lines[#lines + 1] = l end
  end
  local extra = type(spec.copy) == 'table' and type(spec.copy.lines) == 'table' and spec.copy.lines or {}
  for _, field in ipairs({ 'def', 'on_only', 'on_free', 'off_free' }) do
    for _, l in ipairs(line_list(extra[field])) do lines[#lines + 1] = l end
  end
  local patterns = {}
  for _, field in ipairs(pattern_fields) do
    for _, p in ipairs(line_list(spec[field])) do patterns[#patterns + 1] = { field, p } end
    for _, p in ipairs(line_list(extra[field])) do patterns[#patterns + 1] = { field, p } end
  end
  return { lines = lines, kinds = kinds, subs = line_list(extra.offs), patterns = patterns, gmcp = spec.gmcp,
    command = spec.command }
end

function defences.custom_register(name, spec)
  if type(spec.command) ~= 'string' or spec.command == '' then error("it has no command to raise it", 0) end
  if spec.gmcp then
    local mapped = svo.dict.sstosvod[spec.gmcp]
    if mapped and mapped ~= name then
      error(string.format("GMCP's %s is already Svof's %s", spec.gmcp, mapped), 0)
    end
  end
  svo.basicdef(name, spec.command, spec.balanceless, spec.gmcp, not spec.gmcp)
  if spec.gmcp then
    -- for defences.unregister to put back
    defences.gmcp_held[name] = { gmcp = spec.gmcp, mapped = svo.dict.sstosvod[spec.gmcp],
      gamename = svo.dict.svotossd[name] }
    svo.dict.sstosvod[spec.gmcp] = name
    svo.dict.svotossd[name] = spec.gmcp
  end
  -- a definition saved without a skillset has a group of its own
  local record = { type = spec.class == 'all' and 'general' or spec.skillset or 'custom',
    on = spec.on, off = spec.off, def = spec.def, invisibledef = spec.notondef or nil }
  -- a copy of Svof's own keeps the other lines Svof watches for
  local extra = type(spec.copy) == 'table' and type(spec.copy.lines) == 'table' and spec.copy.lines or {}
  for _, field in ipairs(copy_line_fields) do
    local l = line_list(extra[field])
    if field == 'def' and #l > 0 then
      if type(spec.def) == 'string' then table.insert(l, 1, spec.def) end
      record.def = l
    elseif #l > 0 then
      record[field] = l
    end
  end
  -- its patterns, for lines that vary
  for _, field in ipairs(pattern_fields) do
    local l = line_list(record[field])
    for _, p in ipairs(line_list(spec[field])) do l[#l + 1] = p end
    if #l > 0 then record[field] = l end
  end
  defences.register(name, record, nil, true)
  defences.custom_registered[name] = true
end

signals.systemstart:connect(function ()
  defences.custom_registered, defences.gmcp_held = {}, {}
  -- read whether or not they're added, for vcustomdef to list and change
  if not defences.custom then defences.custom_load() end
  if not conf.customdefinitions then return end

  local names = {}
  for name, spec in pairs(defences.custom) do
    if defences.custom_applies(spec) then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local copy = type(defences.custom[name].copy) == 'table'
    if copy and defs_data[name] and defences.custom[name].class == 'all' then
      -- a copy for every class isn't needed in a class with Svof's own,
      -- which is used instead
    elseif copy and defs_data[name] then
      svo.echofn("Svof has its own %s in this class now, so your copy of it isn't used. ", name)
      custom_link("(delete it)", string.format("svo.defences.custom_delete(%q)", name), "Delete your copy of " .. name,
        'remove')
      echo("\n")
    elseif defences.custom_taken(name) and defs_data[name] then
      -- saved in another class, where svof's own didn't show: it can
      -- become a change to svof's own instead
      svo.echofn("Svof has its own %s in this class, so the one you defined isn't used. ", name)
      custom_link("(make it a change to Svof's own)", string.format("svo.defences.custom_to_change(%q)", name),
        "Put your definition's lines, command and GMCP name into a change to Svof's own " .. name)
      echo(" ")
      custom_link("(delete it)", string.format("svo.defences.custom_delete(%q)", name),
        "Delete your definition of " .. name, 'remove')
      echo("\n")
    elseif defences.custom_taken(name) then
      svo.echof("Svof has its own %s now, so the one you defined isn't used.", name)
    else
      -- one that clashes with this class's defences, which a class change
      -- or an update to Svof can bring, stays out
      local clash = defences.clash(name, custom_parts(defences.custom[name]))
      local ok, err = clash == nil, clash
      if ok then ok, err = pcall(defences.custom_register, name, defences.custom[name]) end
      if not ok then
        svo.echof("<250,0,0>Couldn't%s add the defence %s you defined: %s", svo.getDefaultColor(), name, tostring(err))
      elseif copy then
        defences.copy_check(name)
      end
    end
  end
end, 'register the defences the player defined')

-- vcustomdef, the commands for defining one (the repo owner's, 2026-09-22):
--   vcustomdef [list]                list them, each a link to change it
--   vcustomdef game                  the game's defences Svof doesn't know,
--                                    from DEFENCE LIST
--   vcustomdef <name>                show one, starting it if new
--   vcustomdef <name> <field> <text> set class, skillset, command,
--                                    balanceless, gmcp or def, or add a got
--                                    or lost line
--   vcustomdef <name> gotpattern|lostpattern|defpattern <pattern>
--                                    add a pattern, for a line that varies
--   vcustomdef <name> line <got|lost|def>  pick that line off the screen
--   vcustomdef <name> fetch [game name]  fill its lines from the game's
--                                    DEFENCE SHOW, which a new definition
--                                    and a GMCP name do by themselves
--   vcustomdef <name> test           say what it would do
--   vcustomdef <name> install        put it into play, and save it
--   vcustomdef <name> delete         take it out
--   vcustomdef <svof's name> ...     the same, changing svof's own defence
--   vcustomdef <svof's name> reset   put svof's own back
--   vcustomdef <name> copy           copy svof's own from another class
--   vcustomdef svof [all]            svof's own, this class's or every
--                                    class's, each a link to change it
--   vcustomdef export [file], import <file>
-- Changes go to a draft, kept until Svof reloads; only install changes play.
defences.custom_drafts = defences.custom_drafts or {}
-- words vcustomdef takes in place of a name
local custom_reserved = { export = true, import = true, list = true, game = true, help = true, svof = true }
-- the definitions whose class the player chose, which the game's word on
-- a defence doesn't change
local class_chosen = {}
-- the new definitions whose screen waits for the game's DEFENCE SHOW, so
-- it's shown once, filled in
local show_waits = {}

local function custom_copy(spec)
  local t = {}
  for k, v in pairs(spec) do t[k] = v end
  for _, k in ipairs({'on', 'off'}) do
    if type(spec[k]) == 'table' then
      t[k] = {}
      for i, line in ipairs(spec[k]) do t[k][i] = line end
    elseif type(spec[k]) == 'string' then
      t[k] = { spec[k] }
    else
      t[k] = {}
    end
  end
  -- patterns, for lines that vary, only when it has some
  for _, k in ipairs(pattern_fields) do
    if spec[k] then t[k] = line_list(spec[k]) end
  end
  return t
end

-- why a skillset can't hold a definition, or nil
local function skillset_problem(skillset)
  if type(skillset) ~= 'string' or not skillset:find("^%l+$") then return "a skillset is one word of letters" end
  if skillset == 'general' or skillset == 'dragoncraft' then return skillset .. " is Svof's own group, not a skillset" end
end

-- why a definition can't be installed, or nil
function defences.custom_problem(name, spec)
  if not name:find("^%l[%l%d]*$") then return "a name is lower-case letters and digits, starting with a letter" end
  if custom_reserved[name] then return name .. " is a command here, not a name" end
  if defences.custom_taken(name) then return "Svof already has " .. name end
  local versions = defences.catalog()[name]
  if versions and type(spec.copy) ~= 'table' then
    return string.format("Svof has its own %s for %s, so use vcustomdef %s copy to copy it in instead", name,
      class_names(versions), name)
  end
  if type(spec.copy) == 'table' then
    local why = defences.copy_problem(name, spec)
    if why then return why end
  end
  if spec.class ~= 'all' and not (type(spec.class) == 'string' and class_skills(spec.class)) then
    return "its class isn't one Svof knows"
  end
  if type(spec.command) ~= 'string' or spec.command == '' then return "it has no command to raise it" end
  if not ((type(spec.on) == 'table' and #spec.on > 0) or type(spec.on) == 'string' or #line_list(spec.onr) > 0
      or spec.gmcp) then
    return "it needs a line saying you gained it, or its GMCP name, or Svof can't tell when it's up"
  end
  if spec.class ~= 'all' then
    if not spec.skillset then return "pick which of its class's skillsets to show it under" end
    local why = skillset_problem(spec.skillset)
    if why then return why end
  end
  local why = patterns_problem(spec)
  if why then return why end
  -- its lines, GMCP name and command against the class's other defences
  return defences.clash(name, custom_parts(spec))
end

-- the draft of name, started from the installed one or new; nil and why
-- not when the name can't be a definition
local function custom_draft(name)
  local d = defences.custom_drafts[name]
  if d then return d end
  if defences.custom[name] then
    d = custom_copy(defences.custom[name])
  else
    if not name:find("^%l[%l%d]*$") then
      return nil, "a name is lower-case letters and digits, starting with a letter"
    end
    if custom_reserved[name] then return nil, name .. " is a command here, not a name" end
    if defences.custom_taken(name) then return nil, "Svof already has a defence or action called " .. name end
    local versions = defences.catalog()[name]
    if versions then
      return nil, string.format("Svof has its own %s for %s. vcustomdef %s copy copies it in instead", name,
        class_names(versions), name)
    end
    d = { class = class_key(me.class), on = {}, off = {} }
    defences.custom_drafts[name] = d
    -- if the game knows it by this name, its lines come from the game
    defences.custom_fetch(name, name)
    show_waits[name] = true
    return d
  end
  defences.custom_drafts[name] = d
  return d
end

-- the patterns in field, for lines that vary, under the exact lines: each
-- with a link to remove it, then a link to add one with vcustomdef's verb
local function pattern_rows(name, cmd, patterns, field, verb)
  for i, p in ipairs(patterns) do
    custom_label(i == 1 and "or matches:" or "")
    echo(p .. "  ")
    custom_link("x", string.format("svo.defences.custom_unset(%q, %q, %d)", name, field, i), "Remove this pattern",
      'remove')
    echo("\n")
  end
  custom_label("")
  custom_link("add a pattern", string.format("printCmdLine(%q)", cmd .. verb .. " "),
    "For a line that varies: a pattern, as Mudlet's regex triggers take")
  echo("\n")
end

-- what serverside does about a definition: it knows a defence by its GMCP
-- name, so raises one with a GMCP name while serverside is on, unless
-- vshow server leaves it to Svof
local function custom_serverside(name, d)
  if not d.gmcp then return "can't raise it without a GMCP name, so Svof does" end
  local installed = defences.custom[name]
  if installed and installed.gmcp and not svo.serverignore[name] then return "leaves it to Svof" end
  return "raises it while serverside is on, and Svof otherwise"
end

-- tells serverside to stop raising a definition, by the name it knows it
-- by, in both curing sets: once the definition is gone or renamed, svof's
-- next sync of priorities can't name it
local function custom_server_forget(name)
  if not (conf.serverside and svo.serverignore[name] and svo.dict[name] and svo.dict[name].physical) then return end
  sk.priochangecache = sk.priochangecache or {}
  sk.priochangecache.physical = sk.priochangecache.physical or {}
  sk.priochangecache.slowcuring = sk.priochangecache.slowcuring or {}
  sk.priochangecache.slowcuring.physical = sk.priochangecache.slowcuring.physical or {}
  sk.sendpriorityignore(name, 'physical', {}, {}, sk.priochangecache.physical, false)
  sk.sendpriorityignore(name, 'physical', {}, {}, sk.priochangecache.slowcuring.physical, true)
end

function defences.custom_show(name)
  -- one of svof's own is changed rather than defined
  if defences.is_own(name) then return defences.edit_show(name) end
  -- and one svof has in other classes is copied in
  if not (defences.custom[name] or defences.custom_drafts[name]) and defences.catalog()[name] then
    return defences.copy_offer(name)
  end
  local d, why = custom_draft(name)
  if not d then
    svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
    return
  end
  -- a new one asks the game for its lines, and is shown once it answers
  local waits = show_waits[name]
  show_waits[name] = nil
  if waits and defences.fetch_pending(name) then
    svo.echof("Asking the game for %s's lines.", name)
    return
  end
  local installed = defences.custom[name]
  if type(d.copy) == 'table' then
    svo.echof("%s, a copy of Svof's own from %s%s:", name, class_names({ { classes = { tostring(d.copy.from) } } }),
      installed and "" or " (not installed)")
  else
    svo.echof("%s, a defence you %s:", name, installed and "defined" or "are defining (not installed)")
    -- one defined before Svof had it in another class
    if defences.catalog()[name] then
      svo.echofn("Svof has its own %s for %s now. ", name, class_names(defences.catalog()[name]))
      custom_link("(use Svof's own instead)", string.format("svo.defences.copy_offer(%q)", name),
        "Copy Svof's own " .. name .. ", with your lines")
      echo("\n")
    end
  end
  local cmd = "vcustomdef " .. name .. " "
  -- a value, or a grey placeholder for one not set
  local function value(text, missing)
    if text then echo(text .. "  ") else custom_unset_text(missing .. "  ") end
  end
  local function row(label, text, field, missing)
    custom_label(label)
    value(text, missing)
    custom_link("change", string.format("printCmdLine(%q)", cmd .. field .. " "), "Change " .. label)
    echo("\n")
  end
  row("class:", class_title(d.class), "class")
  -- a class's goes under one of its skillsets: a link for each
  if d.class ~= 'all' then
    custom_label("skillset:")
    value(d.skillset, "(not set)")
    for _, skillset in ipairs(class_skills(d.class) or {}) do
      if skillset ~= d.skillset then
        custom_link(skillset, string.format("svo.defences.custom_set(%q, 'skillset', %q)", name, skillset),
          "Show it under " .. skillset:title())
        echo("  ")
      end
    end
    custom_link("type one", string.format("printCmdLine(%q)", cmd .. "skillset "), "One Svof doesn't list for the class")
    echo("\n")
  end
  row("command:", d.command, "command", "(not set)")
  row("balance:", d.balanceless and "takes none" or "takes balance", "balanceless")
  row("GMCP name:", d.gmcp, "gmcp", "(not set)")
  custom_label("serverside:")
  echo(custom_serverside(name, d))
  if d.gmcp and defences.custom_registered[name] then
    echo("  ")
    custom_link("vshow server", "svo.showserverside()", "Choose whether serverside or Svof raises it")
  end
  echo("\n")
  local function patterns(field, verb) pattern_rows(name, cmd, line_list(d[field]), field, verb) end
  for _, which in ipairs({ { 'on', 'got', "gained when:" }, { 'off', 'lost', "lost when:" } }) do
    local lines = d[which[1]]
    for i, line in ipairs(lines) do
      custom_label(i == 1 and which[3] or "")
      echo(line .. "  ")
      custom_link("x", string.format("svo.defences.custom_unset(%q, %q, %d)", name, which[1], i), "Remove this line",
        'remove')
      echo("\n")
    end
    custom_label(#lines == 0 and which[3] or "")
    if #lines == 0 then custom_unset_text("(no line)  ") end
    custom_link("add a line from the screen", string.format("svo.defences.custom_capture(%q, %q)", name, which[2]), "Pick the line from what's on screen")
    echo("  ")
    custom_link("type one", string.format("printCmdLine(%q)", cmd .. which[2] .. " "), "Type or paste the line")
    echo("\n")
    patterns(which[1] .. 'r', which[2] .. "pattern")
  end
  if d.notondef then
    custom_label("DEF shows:")
    echo("nothing, as DEF doesn't list it  ")
    custom_link("it does", string.format("printCmdLine(%q)", cmd .. "def "), "Type or paste the line DEF shows")
    echo("\n")
  else
    custom_label("DEF shows:")
    value(d.def, "(no line)")
    custom_link("pick from the screen", string.format("svo.defences.custom_capture(%q, 'def')", name), "Pick the line from what's on screen")
    echo("  ")
    custom_link("type it", string.format("printCmdLine(%q)", cmd .. "def "), "Type or paste the line")
    echo("  ")
    custom_link("DEF doesn't list it", string.format("svo.defences.custom_set(%q, 'def', 'none')", name),
      "For a defence DEF doesn't show, which DEF then leaves alone")
    echo("\n")
    patterns('defr', "defpattern")
  end
  -- what a copy keeps from svof's own as it is
  local extra = type(d.copy) == 'table' and type(d.copy.lines) == 'table' and d.copy.lines or {}
  local kept = 0
  for _, field in ipairs(copy_line_fields) do kept = kept + #line_list(extra[field]) end
  if kept > 0 then
    custom_label("also:")
    echo(string.format("%d more of Svof's own lines and patterns, kept as they are\n", kept))
  end
  custom_separator()
  custom_label("Actions:")
  custom_link("get its lines from the game", string.format("svo.defences.custom_fetch(%q, %q)", name, d.gmcp or name),
    "Ask the game with DEFENCE SHOW")
  echo("  ")
  custom_link("test", string.format("svo.defences.custom_test(%q)", name), "Say what it would do")
  echo("  ")
  custom_link("install", string.format("svo.defences.custom_install(%q)", name), "Put it into play", 'go')
  echo("  ")
  custom_link("delete", string.format("svo.defences.custom_delete(%q)", name), "Take it out", 'remove')
  echo("\n")
end

function defences.custom_set(name, field, value)
  if defences.is_own(name) then return defences.edit_set(name, field, value) end
  local d, why = custom_draft(name)
  if not d then
    svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
    return
  end
  value = value or ''
  if field == 'class' then
    local class = class_key(value)
    if class ~= 'all' and not class_skills(class) then
      svo.echof("Svof doesn't know a class called %s. Use a class's name, or all.", value)
      return
    end
    -- a skillset of the class it was for doesn't carry over
    if class ~= class_key(d.class) and d.skillset and not table.contains(class_skills(class) or {}, d.skillset) then
      d.skillset = nil
    end
    d.class = class
    class_chosen[name] = true
  elseif field == 'skillset' then
    local skillset = (value:lower():gsub("%s+", ""))
    local why = skillset_problem(skillset)
    if why then svo.echof("Can't show %s under %s: %s.", name, value, why) return end
    d.skillset = skillset
  elseif field == 'command' then
    if value == '' then svo.echof("What does Svof send to raise %s?", name) return end
    d.command = value
  elseif field == 'balanceless' then
    d.balanceless = svo.convert_string(value) and true or nil
  elseif field == 'serverside' then
    svo.echof("Serverside raises a defence by its GMCP name, so give %s one and it does while serverside is on. vshow server can leave it to Svof.", name)
    return
  elseif field == 'gmcp' then
    local gmcp = (value ~= '' and value:lower() ~= 'none') and value:lower() or nil
    -- only a name the game confirms: one it hasn't yet is asked about,
    -- and the reply sets it
    local known = gmcp and defences.gmcp_known(gmcp)
    if known == false then
      svo.echof("%s", defences.gmcp_refusal(name, gmcp))
      return
    elseif gmcp and known == nil then
      svo.echof("Asking the game whether GMCP knows a defence called %s.", gmcp)
      defences.custom_fetch(name, gmcp, 'gmcp')
      return
    end
    d.gmcp = gmcp
    -- the game shows the defence it reports by that name, and the screen
    -- follows its answer
    if d.gmcp then
      svo.echof("Asking the game for %s's lines.", name)
      defences.custom_fetch(name, d.gmcp)
      return
    end
  elseif field == 'got' or field == 'lost' then
    if value == '' then svo.echof("Which line says you %s %s?", field == 'got' and "gained" or "lost", name) return end
    local lines = d[field == 'got' and 'on' or 'off']
    if not table.contains(lines, value) then lines[#lines + 1] = value end
  elseif field == 'def' then
    -- none: DEF doesn't list it, so DEF leaves it alone
    if value:lower() == 'none' then
      d.def, d.defr, d.notondef = nil, nil, true
    else
      d.def, d.notondef = value ~= '' and value or nil, nil
    end
  elseif field == 'gotpattern' or field == 'lostpattern' or field == 'defpattern' then
    -- a pattern, for a line that varies, as svof's own records have
    local key = field == 'gotpattern' and 'onr' or field == 'lostpattern' and 'offr' or 'defr'
    if value == '' then
      svo.echof("Which pattern matches the line that %s?", field == 'gotpattern' and ("says you gained " .. name)
        or field == 'lostpattern' and ("says you lost " .. name) or ("DEF shows for " .. name))
      return
    end
    local why = defences.pattern_problem(value)
    if why then
      svo.echof("Can't use %s as a pattern: %s.", value, why)
      return
    end
    d[key] = line_list(d[key])
    if not table.contains(d[key], value) then d[key][#d[key] + 1] = value end
    if key == 'defr' then d.notondef = nil end
  else
    svo.echof("A definition has class, skillset, command, balanceless, gmcp, got, lost, def, gotpattern, lostpattern and defpattern; %s isn't one.", field)
    return
  end
  defences.custom_show(name)
end

function defences.custom_unset(name, which, i)
  if defences.is_own(name) then return defences.edit_unset(name, which, i) end
  local d = custom_draft(name)
  if d and d[which] then table.remove(d[which], i) end
  defences.custom_show(name)
end

-- shows the last lines on the screen, to click the one that says it
function defences.custom_capture(name, which)
  if which ~= 'got' and which ~= 'lost' and which ~= 'def' then
    svo.echof("Pick a line for got, lost or def.")
    return
  end
  local last = getLastLineNumber("main")
  local lines = getLines(math.max(0, last - 12), last)
  svo.echof("Click the line that %s:", which == 'got' and ("says you gained " .. name)
    or which == 'lost' and ("says you lost " .. name) or ("DEF shows for " .. name))
  for _, line in ipairs(lines) do
    if line:find("%S") then
      echo("  ")
      custom_link(line, string.format("svo.defences.custom_set(%q, %q, %q)", name, which, line), "Use this line")
      echo("\n")
    end
  end
end

-- The game's own record of a defence it knows, the ones GMCP reports.
-- DEFENCE SHOW <name> prints this (the owner's capture, 2026-10-09):
--   Defence:            Alertness (alertness)
--   Description:        Alertness allows you to see when people move into rooms
--   around you.
--   DefMsg:             Your senses are attuned to nearby movement.
--   EnactMsg:           You prick up your ears.
--   FadeMsg:            You cease your watchful alertness.
--   Profession:         No
--   Strippable:         Yes
-- with a long value carried onto the next line, or "There is no such
-- defence." for one it doesn't have. custom_fetch sends it and fills the
-- draft's empty parts from the reply: the name in brackets as its GMCP
-- name, EnactMsg as a gain line, FadeMsg as a loss line, and DefMsg as its
-- DEF line. Profession says whether it's a class's defence (the owner,
-- 2026-10-09): one that isn't is for every class, and for one that is the
-- player is asked which class, as the game doesn't say. A defence the game
-- doesn't have keeps the player's lines.
--
-- A GMCP name is only taken once the game confirms it (the user,
-- 2026-10-10): by DEFENCE SHOW's reply, by DEFENCE LIST, or by GMCP
-- sending it. Asked to set one the game hasn't confirmed this session,
-- custom_fetch asks DEFENCE SHOW (mode 'gmcp'), and the reply sets it, or
-- says the game has no such defence.
local fetching = {}
defences.gmcp_confirmed = defences.gmcp_confirmed or {}
defences.gmcp_unknown = defences.gmcp_unknown or {}

-- whether the game knows name as a defence over GMCP: true, false, or nil
-- when svof can't tell without asking it
function defences.gmcp_known(name)
  if svo.gdefc[name] or sk.gmcp_defs_seen[name] or defences.gmcp_confirmed[name] then return true end
  local list = defences.game_defences
  if list and list.names[name] then return true end
  if defences.gmcp_unknown[name] or (list and list.complete) then return false end
  return nil
end

-- what svof says refusing a GMCP name the game doesn't know
function defences.gmcp_refusal(name, gmcp)
  return string.format("The game has no defence called %s over GMCP, so it can't be %s's GMCP name. Check the name, or use vcustomdef %s gmcp none for a defence GMCP doesn't report.",
    gmcp, name, name)
end
local fetch_labels = { Description = true, DefMsg = true, EnactMsg = true, FadeMsg = true,
  Profession = true, Strippable = true }
local fetch_wraps = { Description = true, DefMsg = true, EnactMsg = true, FadeMsg = true }

local function fetch_stop()
  if fetching.trigger then killTrigger(fetching.trigger) end
  if fetching.timer then killTimer(fetching.timer) end
  fetching = {}
end

-- whether svof is waiting on the game's DEFENCE SHOW for name, to fill it
-- in, so its screen waits for the answer
function defences.fetch_pending(name)
  return fetching.name == name and fetching.mode ~= 'gmcp' and not fetching.fields
end

-- starts svof's output on a line of its own, rather than after a prompt
local function fresh_line()
  moveCursorEnd("main")
  if getCurrentLine() ~= "" then echo("\n") end
end

-- The game's reply is gagged as it's read, and the prompt after it
-- (svo.deleteLineP). Echoed from the trigger, svof's output would go with
-- the line being deleted, so it waits until the line is gone
local function after_gag(f)
  tempTimer(0, function ()
    fresh_line()
    f()
  end)
end

-- shows what's being defined or changed, once the game has had its say
local function show_after_fetch(name)
  if defences.custom_drafts[name] or defences.edit_drafts[name] then defences.custom_show(name) end
end

-- fills in name's draft from the game's DEFENCE SHOW fields f, asked about
-- as asked
local function fetch_fill(name, asked, f, mode)
  -- a definition's draft, or a change being made to svof's own
  local d = name and (defences.custom_drafts[name] or defences.edit_drafts[name])
  if not (f and d) then return end
  local changing = d == defences.edit_drafts[name]
  local function value(label) return f[label] and f[label]:match("^%s*(.-)%s*$") or "" end
  local gmcpname = f.keyword or asked
  -- the game knows a defence by this GMCP name
  defences.gmcp_confirmed[gmcpname] = true
  local mapped = svo.dict.sstosvod[gmcpname]
  if mapped and mapped ~= name then
    if changing then
      svo.echof("Can't give %s the GMCP name %s: GMCP's %s is Svof's %s.", name, gmcpname, gmcpname, mapped)
    else
      svo.echof("The game's %s is Svof's own %s, so there's no need to define it.", gmcpname, mapped)
    end
    return show_after_fetch(name)
  end
  if mode == 'gmcp' then
    -- asked to set the GMCP name: the game's own spelling of it
    if gmcpname ~= asked then svo.echof("The game knows %s as %s over GMCP.", asked, gmcpname) end
    d.gmcp = gmcpname
    -- a change to svof's own takes the name and nothing else
    if changing then return defences.custom_show(name) end
  elseif not d.gmcp then
    d.gmcp = gmcpname
  end
  local on, off, def = value('EnactMsg'), value('FadeMsg'), value('DefMsg')
  if on ~= '' and not table.contains(d.on, on) then d.on[#d.on + 1] = on end
  if off ~= '' and not table.contains(d.off, off) then d.off[#d.off + 1] = off end
  -- a change's DEF lines are a list; and one DEF doesn't list keeps none
  if def ~= '' and type(d.def) == 'table' and not d.notondef then
    if not table.contains(d.def, def) then d.def[#d.def + 1] = def end
  elseif def ~= '' and not d.def and not d.notondef then
    d.def = def
  end
  svo.echof("Filled in %s from the game's DEFENCE SHOW %s.", name, gmcpname)
  -- svof's own keeps its class
  if d == defences.edit_drafts[name] then return defences.custom_show(name) end
  local profession = value('Profession'):lower()
  local chosen = class_chosen[name] or defences.custom[name]
  if profession == 'no' and not chosen then d.class = 'all' end
  defences.custom_show(name)
  if profession == 'no' and not chosen then
    svo.echof("The game says it isn't a profession defence, so any class can have it.")
  elseif profession == 'yes' and not chosen then
    defences.custom_ask_class(name)
  end
end

local function fetch_done()
  local name, asked, f, mode = fetching.name, fetching.keyword, fetching.fields, fetching.mode
  fetch_stop()
  after_gag(function () fetch_fill(name, asked, f, mode) end)
end

-- asks which class a profession defence belongs to, a link for each, an
-- element's lord and lady as one
function defences.custom_ask_class(name)
  local d = defences.custom_drafts[name]
  if not d then return end
  svo.echof("The game says %s is a profession defence. Which class has it? It's set to %s now:", name,
    class_title(d.class))
  local classes, seen = {}, {}
  for class in pairs(svo.knownskills) do
    local key = class_key(class)
    if key ~= 'none' and not seen[key] then
      seen[key] = true
      classes[#classes + 1] = key
    end
  end
  table.sort(classes)
  echo("  ")
  for i, class in ipairs(classes) do
    local title = class_title(class)
    custom_link(title, string.format("svo.defences.custom_set(%q, 'class', %q)", name, class), "It's " .. title .. "'s")
    echo(i < #classes and ", " or "\n")
    if i % 6 == 0 and i < #classes then echo("\n  ") end
  end
end

-- mode 'gmcp' asks in order to set the GMCP name, which only the reply does
function defences.custom_fetch(name, keyword, mode)
  if type(keyword) ~= 'string' or not keyword:find("%S") then return end
  fetch_stop()
  fetching = { name = name, keyword = keyword:lower(), mode = mode }
  fetching.trigger = tempRegexTrigger("^", "svo.defences.custom_fetch_line()")
  fetching.timer = tempTimer(5 + svo.getping(), function()
    fetching.timer = nil
    if fetching.fields then fetch_done() return end
    local asked, defining = tostring(fetching.keyword), fetching.name
    local gmcp = fetching.mode == 'gmcp'
    fetch_stop()
    fresh_line()
    if gmcp then
      svo.echof("The game didn't answer about %s, so Svof can't take it as %s's GMCP name. Try again, or use vcustomdef %s gmcp none for a defence GMCP doesn't report.",
        asked, defining, defining)
    else
      svo.echof("The game didn't answer about a defence called %s, so add its lines yourself.", asked)
      show_after_fetch(defining)
    end
  end)
  -- svof says what it's asking, so the command isn't echoed
  send("defence show " .. fetching.keyword, false)
end

-- every line while a fetch waits: the reply starts at its Defence: line
-- and ends at Strippable: or the prompt, and is gagged, with the prompt
-- after it
function defences.custom_fetch_line()
  if not fetching.name then return end
  if isPrompt and isPrompt() then
    if fetching.fields then fetch_done() end
    return
  end
  local text = line
  local label, rest = text:match("^(%a+):%s+(.*)$")
  if not fetching.fields then
    if label == 'Defence' then
      local keyword = rest:match("%((%S+)%)%s*$")
      fetching.fields = { keyword = keyword and keyword:lower() }
      svo.deleteLineP()
    elseif text == "There is no such defence." then
      local asked, name, mode = fetching.keyword, fetching.name, fetching.mode
      fetch_stop()
      svo.deleteLineP()
      defences.gmcp_unknown[asked] = true
      after_gag(function ()
        if mode == 'gmcp' then
          svo.echof("%s", defences.gmcp_refusal(name, asked))
        else
          svo.echof("The game has no defence called %s, so add its lines yourself.", tostring(asked))
          show_after_fetch(name)
        end
      end)
    end
    return
  end
  svo.deleteLineP()
  if label and fetch_labels[label] then
    fetching.fields[label] = rest
    fetching.last = label
    if label == 'Strippable' then fetch_done() end
  elseif fetching.last and fetch_wraps[fetching.last] then
    local prev = fetching.fields[fetching.last]
    fetching.fields[fetching.last] = prev .. (prev:find("%s$") and "" or " ") .. text
  end
end

-- DEFENCE LIST shows every defence the game reports over GMCP, a name to a
-- line and a page at a time (the owner's capture, 2026-10-09):
--   All defences
--   ------------------------------------------------
--   Accursedresolve
--   Acrobatics
--   [Type MORE if you wish to continue reading. (8% shown)]
-- and MORE past its end gets (the user, 2026-10-10):
--   An unseen presence whispers in your ear, "There is no more, friend."
-- custom_gamelist sends it, and MORE after each page, hiding the list as it
-- reads it, then shows the defences Svof doesn't track, each a link to
-- define it.
local list_end = 'An unseen presence whispers in your ear, "There is no more, friend."'
local listing = {}

local function list_stop()
  if listing.trigger then killTrigger(listing.trigger) end
  if listing.timer then killTimer(listing.timer) end
  listing = {}
end

local function list_show(names)
  local custom_gmcp = {}
  for _, spec in pairs(defences.custom) do
    if type(spec.gmcp) == 'string' then custom_gmcp[spec.gmcp:lower()] = true end
  end
  local unknown, ignored = {}, {}
  for _, name in ipairs(names) do
    local mapped = svo.dict.sstosvod[name]
    if not custom_gmcp[name] then
      if mapped == nil then unknown[#unknown + 1] = name
      elseif mapped == false then ignored[#ignored + 1] = name end
    end
  end
  local function links(list)
    echo("  ")
    for i, name in ipairs(list) do
      custom_link(name, string.format("svo.defences.custom_show(%q)", name), "Define " .. name)
      if i < #list then echo(i % 6 == 0 and "\n  " or ", ") end
    end
    echo("\n")
  end
  if #unknown == 0 and #ignored == 0 then
    svo.echof("Svof tracks all %d defences the game lists, or you've defined them.", #names)
    return
  end
  if #unknown > 0 then
    svo.echof("Of the %d defences the game lists, Svof doesn't know these %d. Click one to define it:", #names, #unknown)
    links(unknown)
  end
  if #ignored > 0 then
    svo.echof("Svof knows these, but leaves them alone:")
    links(ignored)
  end
end

-- The list read, or as much of it as came: kept for the session, so a GMCP
-- name can be checked against it (complete when its last page came), then
-- shown, or handed to what asked for it (after)
local function list_done(complete)
  local names, after = listing.names, listing.after
  list_stop()
  if names and #names > 0 then
    local set = {}
    for _, name in ipairs(names) do set[name] = true end
    defences.game_defences = { names = set, complete = complete }
  end
  after_gag(function ()
    if after then return after() end
    if names and #names > 0 then
      list_show(names)
    else
      svo.echof("The game didn't send its list of defences.")
    end
  end)
end

local function list_wait()
  if listing.timer then killTimer(listing.timer) end
  listing.timer = tempTimer(8 + svo.getping(), function()
    listing.timer = nil
    list_done(false)
  end)
end

-- after, when given, runs once the list is read, instead of showing it
function defences.custom_gamelist(after)
  list_stop()
  listing = { pages = 0, after = after }
  listing.trigger = tempRegexTrigger("^", "svo.defences.custom_gamelist_line()")
  list_wait()
  svo.echof("Asking the game for its list of defences.")
  -- svof says what it's asking, so the command isn't echoed
  send("defence list", false)
end

-- every line while the list is read: it starts at "All defences", a MORE
-- line asks for the next page, and a prompt with no MORE before it, or the
-- game saying there's no more, ends it. Every line of it is gagged, with
-- the prompts between and after its pages (svo.deleteLineP), and the
-- "[File continued via MORE]" each page after the first starts with
function defences.custom_gamelist_line()
  if not listing.pages then return end
  if isPrompt and isPrompt() then
    if listing.names and not listing.more then list_done(true) end
    return
  end
  local text = line
  if listing.names and text == list_end then
    svo.deleteLineP()
    list_done(true)
    return
  end
  if not listing.names then
    if text == "All defences" then
      listing.names = {}
      svo.deleteLineP()
    end
    return
  end
  if text:find("^%[File continued via MORE%]") then
    svo.deleteLineP()
    return
  end
  if text:find("^%[Type MORE if you wish to continue reading") then
    svo.deleteLineP()
    listing.pages = listing.pages + 1
    if listing.pages > 50 then
      list_done(false)
      return
    end
    listing.more = true
    list_wait()
    send("more", false)
    return
  end
  local name = text:match("^(%a+)%s*$")
  if name then
    listing.names[#listing.names + 1] = name:lower()
    listing.more = false
    svo.deleteLineP()
  elseif text:find("^%-+%s*$") then
    svo.deleteLineP()
  end
end

-- what svof says of a defence DEF lists, with no DEF line: a warning, not
-- a refusal, as some defences DEF doesn't show, such as Pariah's
-- bloodiedknife (the user, 2026-10-10)
local function no_def_warning(name)
  return string.format("Without a DEF line, each DEF marks %s gone, and keepup raises it again. Add the line DEF shows for it, or use vcustomdef %s def none if DEF doesn't list it.",
    name, name)
end

-- what test says a defence knows it's up or gone from: its lines, its
-- patterns (a count) and GMCP
local function known_from(lines, patterns, gmcp)
  local parts = {}
  if #lines > 0 then parts[#parts + 1] = string.format("%d line%s", #lines, #lines == 1 and "" or "s") end
  if patterns > 0 then parts[#parts + 1] = string.format("%d pattern%s", patterns, patterns == 1 and "" or "s") end
  if gmcp then parts[#parts + 1] = gmcp end
  return #parts > 0 and svo.concatand(parts) or "nothing, until DEF"
end

function defences.custom_test(name)
  if defences.is_own(name) then return defences.edit_test(name) end
  local d = defences.custom_drafts[name] or defences.custom[name]
  if not d then svo.echof("You haven't defined %s.", name) return end
  local on = type(d.on) == 'string' and { d.on } or d.on or {}
  local off = type(d.off) == 'string' and { d.off } or d.off or {}
  svo.echof("%s, for %s, %s:", name, class_title(d.class),
    d.class == 'all' and "in the main defence list" or d.skillset and ("under " .. d.skillset:title())
    or "under no skillset yet")
  svo.echof("Svof raises it by sending %q, which %s. Serverside %s.", tostring(d.command),
    d.balanceless and "takes no balance" or "takes balance", custom_serverside(name, d))
  svo.echof("It knows it's up from %s.", known_from(on, #line_list(d.onr), d.gmcp and ("GMCP's " .. d.gmcp)))
  svo.echof("It knows it's gone from %s.", known_from(off, #line_list(d.offr), d.gmcp and "GMCP"))
  if d.notondef then
    svo.echof("DEF doesn't list it, so DEF leaves it alone.")
  elseif not d.def and #line_list(d.defr) == 0 then
    svo.echof("%s", no_def_warning(name))
  end
  local problem = defences.custom_problem(name, d)
  if problem then
    svo.echof("<250,0,0>It can't%s be installed yet: %s.", svo.getDefaultColor(), problem)
  else
    svo.echof("It's ready to install.")
  end
end

function defences.custom_install(name)
  if defences.is_own(name) then return defences.edit_install(name) end
  local d = defences.custom_drafts[name] or (defences.custom[name] and custom_copy(defences.custom[name]))
  if not d then svo.echof("You haven't defined %s.", name) return false end
  local problem = defences.custom_problem(name, d)
  if problem then
    svo.echof("<250,0,0>Can't%s install %s: %s.", svo.getDefaultColor(), name, problem)
    return false
  end
  local had = defences.custom[name]
  if defences.custom_registered[name] then
    if had and had.gmcp ~= d.gmcp then custom_server_forget(name) end
    defences.unregister(name, true)
    defences.custom_registered[name] = nil
  end
  defences.custom[name] = d
  defences.custom_drafts[name] = nil
  defences.custom_save()

  -- serverside raises one with a GMCP name, as it does svof's own, from
  -- when it first has one, until vshow server says otherwise. Without one
  -- it can't, and left to serverside nothing would raise it. A copy of
  -- svof's own shares vshow server's choice with svof's own, which is
  -- by name in every class, so keeps it
  if defences.catalog()[name] then
    -- (the choice made for svof's own)
  elseif d.gmcp and not (had and had.gmcp) then
    svo.setserverignore(name)
  elseif not d.gmcp and svo.serverignore[name] then
    svo.unsetserverignore(name)
  end

  if not conf.customdefinitions then
    svo.echof("Saved %s. vconfig customdefinitions is off, so Svof doesn't add it.", name)
  elseif not defences.custom_applies(d) then
    svo.echof("Saved %s. It's for %s, so Svof adds it when you're one.", name, class_title(d.class))
  else
    local ok, err = pcall(defences.custom_register, name, d)
    if not ok then
      svo.echof("<250,0,0>Couldn't%s add %s: %s.", svo.getDefaultColor(), name, tostring(err))
      return false
    end
    svo.echof("Installed %s. Add it to defup with vdefup %s, or to keepup with vkeep %s.", name, name, name)
  end
  if not d.def and #line_list(d.defr) == 0 and not d.notondef then svo.echof("%s", no_def_warning(name)) end
  return true
end

function defences.custom_delete(name)
  -- for one of svof's own, delete is reset, unless it names a definition
  -- saved for a class that doesn't have svof's
  if not (defences.custom[name] or defences.custom_drafts[name]) and defences.is_own(name) then
    return defences.edit_reset(name)
  end
  if not (defences.custom[name] or defences.custom_drafts[name]) then
    svo.echof("You haven't defined %s.", name)
    return
  end
  -- a name svof has in other classes, which a copy of svof's own takes
  local svofs = defences.catalog()[name] ~= nil
  if defences.custom_registered[name] then
    custom_server_forget(name)
    defences.unregister(name)
    defences.custom_registered[name] = nil
  end
  defences.custom[name] = nil
  defences.custom_drafts[name] = nil
  defences.custom_save()
  -- a copy's vshow server choice is svof's own's too, which stays
  if svo.serverignore[name] and not svofs then svo.unsetserverignore(name) end
  svo.echof("Deleted %s.", name)
end

function defences.custom_export(path)
  path = (path and path ~= '') and path or (getMudletHomeDir() .. "/svo/custom/defs-export")
  local t, n, c = {}, 0, 0
  for name, spec in pairs(defences.custom) do t[name] = spec n = n + 1 end
  -- the changes to svof's own go too, under a key no name can be
  for _, names in pairs(defences.edits or {}) do
    for _ in pairs(names) do c = c + 1 end
  end
  if c > 0 then t._changes = defences.edits end
  svo.tablesave(path, t)
  svo.echof("Saved the %d defence%s you defined%s to %s.", n, n == 1 and "" or "s",
    c > 0 and string.format(" and %d change%s to Svof's own", c, c == 1 and "" or "s") or "", path)
end

-- why a GMCP name in a file can't be taken, or nil: the game has to
-- confirm it, as when it's typed
local function imported_gmcp_problem(gmcp)
  if type(gmcp) ~= 'string' then return nil end
  local known = defences.gmcp_known(gmcp:lower())
  if known then return nil end
  if known == false then return "the game has no defence called " .. gmcp:lower() .. " over GMCP" end
  return "Svof couldn't check its GMCP name " .. gmcp:lower() .. " with the game"
end

local function import_from(t, path)
  local names = {}
  for name, spec in pairs(t) do
    if type(name) == 'string' and name ~= '_changes' and type(spec) == 'table' then names[#names + 1] = name end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local problem = imported_gmcp_problem(t[name].gmcp)
    if defences.custom[name] then
      svo.echof("You already have %s, so the one in %s isn't used.", name, path)
    elseif defences.is_own(name) then
      svo.echof("Svof has its own %s, so the one in %s isn't used.", name, path)
    elseif problem then
      svo.echof("Didn't import %s from %s: %s. Check the name, or leave it out for a defence GMCP doesn't report.",
        name, path, problem)
    else
      local d = custom_copy(t[name])
      d.gmcp = type(d.gmcp) == 'string' and d.gmcp:lower() or nil
      defences.custom_drafts[name] = d
      if not defences.custom_install(name) then defences.custom_drafts[name] = nil end
    end
  end
  if type(t._changes) == 'table' then defences.edits_import(t._changes, path) end
end

function defences.custom_import(path)
  if not path or path == '' or not lfs.attributes(path) then
    svo.echof("There's no file at %s.", tostring(path ~= '' and path or nil))
    return
  end
  local t = {}
  local ok, msg = pcall(table.load, path, t)
  if not ok then
    svo.echof("<250,0,0>Couldn't%s read %s: %s", svo.getDefaultColor(), path, tostring(msg))
    return
  end
  -- GMCP names the game hasn't confirmed this session are checked against
  -- its DEFENCE LIST first
  local unchecked = false
  local function check(gmcp)
    if type(gmcp) == 'string' and defences.gmcp_known(gmcp:lower()) == nil then unchecked = true end
  end
  for name, spec in pairs(t) do
    if name == '_changes' and type(spec) == 'table' then
      for _, changes in pairs(spec) do
        for _, edit in pairs(type(changes) == 'table' and changes or {}) do
          if type(edit) == 'table' then check(edit.gmcp) end
        end
      end
    elseif type(spec) == 'table' then
      check(spec.gmcp)
    end
  end
  if unchecked then
    svo.echof("Checking the GMCP names in %s against the game's list of defences.", path)
    return defences.custom_gamelist(function () import_from(t, path) end)
  end
  import_from(t, path)
end

-- vcustomdef or vcustomdef list: every definition, a link to show and change
-- each
function defences.customdef_menu()
  local names, seen = {}, {}
  for name in pairs(defences.custom) do names[#names + 1] = name seen[name] = true end
  for name in pairs(defences.custom_drafts) do if not seen[name] then names[#names + 1] = name end end
  table.sort(names)
  if #names == 0 then
    svo.echof("You haven't defined any defences.")
  else
    svo.echof("Defences you defined (click one to see or change it):")
    for _, name in ipairs(names) do
      local spec = defences.custom_drafts[name] or defences.custom[name]
      local state = not defences.custom[name] and "not installed"
        or defences.custom_drafts[name] and "changes not installed"
        or defences.custom_registered[name] and "in use"
        or "installed, for another class"
      echo("  ")
      custom_link(name, string.format("svo.defences.custom_show(%q)", name), "See or change " .. name)
      echo(string.format(": %s%s, %s  ", type(spec.copy) == 'table' and "Svof's own, copied, for " or "",
        spec.class == 'all' and "every class"
        or class_title(spec.class) .. (spec.skillset and (" (" .. spec.skillset .. ")") or ""), state))
      custom_link("test", string.format("svo.defences.custom_test(%q)", name), "Say what it would do")
      echo("  ")
      custom_link("delete", string.format("svo.defences.custom_delete(%q)", name), "Take it out", 'remove')
      echo("\n")
    end
  end
  defences.edits_menu()
  -- vconfig customdefinitions, with a link to turn it the other way (the
  -- user's ask, 2026-10-16)
  if conf.customdefinitions then
    svo.echofn("Svof uses your definitions and changes (vconfig customdefinitions is on). ")
    custom_link("turn it off", 'svo.config.set("customdefinitions", false, true)',
      "Leave out your definitions and changes, from when Svof next loads", 'remove')
  else
    svo.echofn("Svof leaves out your definitions and changes (vconfig customdefinitions is off). ")
    custom_link("turn it on", 'svo.config.set("customdefinitions", true, true)',
      "Use your definitions and changes, from when Svof next loads", 'go')
  end
  echo("\n")
  echo("  ")
  custom_link("define a new one", "printCmdLine('vcustomdef <name>')",
    "Put vcustomdef <name> on the command line: replace <name> with its name, or one of Svof's to change it")
  echo("  ")
  custom_link("change one of Svof's own", "svo.defences.own_list()", "List Svof's own defences for your class")
  echo("  ")
  custom_link("see the game's defences Svof doesn't know", "svo.defences.custom_gamelist()", "Compare with DEFENCE LIST")
  echo("\n")
  defences.customdef_usage()
end

-- the classes that have skillset, as the game writes them, an element's
-- lord and lady as one
local function skillset_classes(skillset)
  local t, seen = {}, {}
  for class, skills in pairs(svo.knownskills) do
    local title = class_title(class)
    if not seen[title] and table.contains(skills, skillset) then
      seen[title] = true
      t[#t + 1] = title
    end
  end
  table.sort(t)
  return t
end

-- vcustomdef svof [all]: Svof's own defences, by skillset, each a link to
-- change it, or for another class's, to copy it in (the user's ask,
-- 2026-10-16). Without all, this class's, the way the defence lists show
-- them; with all, every class's from the catalog too. The player's own
-- definitions are vcustomdef's list, not this one
function defences.own_list(all)
  local groups = {}
  local function add(group, name)
    if defences.custom_registered[name] then return end
    groups[group] = groups[group] or {}
    groups[group][name] = true
  end
  for group, names in pairs(defences.def_types) do
    for _, name in ipairs(names) do add(group, name) end
  end
  if all then
    for name, versions in pairs(defences.catalog()) do
      for _, v in ipairs(versions) do
        if v.type then add(v.type, name) end
      end
    end
  end
  -- general, then this class's skillsets, then the rest by name
  local order, seen = {}, {}
  local function put(group)
    if groups[group] and not seen[group] then
      order[#order + 1] = group
      seen[group] = true
    end
  end
  put('general')
  for _, skillset in ipairs(class_skills(me.class) or {}) do put(skillset) end
  local rest = {}
  for group in pairs(groups) do
    if not seen[group] then rest[#rest + 1] = group end
  end
  table.sort(rest)
  for _, group in ipairs(rest) do put(group) end

  local mine = class_skills(me.class) or {}
  if all then
    svo.echof("Svof's own defences, every class's, by skillset (click one to change it, or to copy another class's in):")
  else
    svo.echof("Svof's own defences for %s (click one to change it):", class_title(me.class))
  end
  local marked = {}
  for _, group in ipairs(order) do
    local names = {}
    for name in pairs(groups[group]) do names[#names + 1] = name end
    table.sort(names)
    local heading = ""
    if all and group == 'general' then
      heading = " (every class)"
    elseif all and not table.contains(mine, group) then
      local classes = skillset_classes(group)
      if #classes > 0 then heading = " (" .. table.concat(classes, ", ") .. ")" end
    end
    svo.echof("%s%s:", group:title(), heading)
    for i, name in ipairs(names) do
      local mark = defences.mark(name)
      if mark ~= '' then marked[mark] = true end
      echo("  ")
      local hint = defences.is_own(name) and defences.markhint("See or change Svof's own " .. name, name)
        or defences.custom[name] and "See your copy of " .. name
        or "Copy Svof's own " .. name .. " from another class"
      custom_link(name, string.format("svo.defences.custom_show(%q)", name), hint)
      if mark ~= '' then
        setFgColor(255, 170, 0)
        echo(mark)
        resetFormat()
      end
      if i % 3 == 0 or i == #names then
        echo("\n")
      else
        echo(string.rep(" ", math.max(1, 22 - #name - #mark)))
      end
    end
  end
  local key = defences.mark_key(marked, "<153,204,204>")
  if key then decho(key) end
  custom_separator()
  echo("  ")
  if all then
    custom_link("show only " .. class_title(me.class) .. "'s defences", "svo.defences.own_list()",
      "List Svof's own defences for your class (vcustomdef svof)")
  else
    custom_link("show every class's defences", "svo.defences.own_list(true)",
      "List Svof's own defences for every class, by skillset (vcustomdef svof all)")
  end
  -- hiding them is vshow hidelist's (the user's choice, 2026-10-16)
  echo("  ")
  custom_link("hide defences", all and "svo.showhidelist(true)" or "svo.showhidelist()",
    "Choose which skillsets and defences the defence lists show (vshow hidelist)")
  echo("\n")
end

-- every form of vcustomdef, each with what it does (the user's ask,
-- 2026-10-14). One command sets one thing; the screen vcustomdef <name>
-- shows has a link for each
local customdef_forms = {
  { "<name>", "see one, or start it, filling it in from the game" },
  { "<name> class|skillset|command|gmcp <value>", "set one of those" },
  { "<name> balanceless yes|no", "whether raising it takes balance" },
  { "<name> got|lost <line>", "add a line saying it's gained or lost" },
  { "<name> def <line>|none", "the line DEF shows, or none if DEF doesn't list it" },
  { "<name> gotpattern|lostpattern|defpattern <pattern>", "add a pattern, for a line that varies" },
  { "<name> line got|lost|def", "pick that line off the screen" },
  { "<name> fetch [game name]", "fill it in from the game's DEFENCE SHOW" },
  { "<name> test|install|delete", "say what it would do, put it into play, or take it out" },
  { "<name> copy", "copy Svof's own from another class" },
  { "<Svof's name> ...|reset", "change one of Svof's own, or put Svof's back" },
  { "svof [all]", "Svof's own defences to change: your class's, or every class's by skillset" },
  { "game", "the game's defences Svof doesn't know" },
  { "export [file]|import <file>", "save your definitions and changes to a file, or read them in" },
}

-- the values the forms above leave to fill in
local customdef_placeholders = { ["<value>"] = true, ["yes|no"] = true, ["<line>"] = true, ["<line>|none"] = true,
  ["<pattern>"] = true, ["got|lost|def"] = true, ["[game name]"] = true, ["[file]"] = true, ["<file>"] = true,
  ["[all]"] = true }

function defences.customdef_usage()
  svo.echof("vcustomdef takes (click one to put it on the command line):")
  for _, form in ipairs(customdef_forms) do
    echo("  ")
    custom_link("vcustomdef " .. form[1], string.format("printCmdLine(%q)", "vcustomdef " .. form[1]), form[2])
    setFgColor(128, 128, 128)
    echo("  " .. form[2] .. "\n")
    resetFormat()
  end
end

-- what the vcustomdef alias passes on: everything after its name
function defences.customdef_command(rest)
  rest = (rest or ''):match("^%s*(.-)%s*$")
  local name, tail = rest:match("^(%S+)%s*(.-)$")
  if not name then return defences.customdef_menu() end
  name = name:lower()
  if name == 'list' then return defences.customdef_menu() end
  if name == 'help' then return defences.customdef_usage() end
  -- a form from the usage, sent with its placeholders still in. Only the
  -- usage's own: a line or pattern can hold < > or |, such as a named group
  local verb, value = tail:match("^(%S*)%s*(.-)$")
  if name:find("^<") or verb:find("|", 1, true) or customdef_placeholders[verb] or customdef_placeholders[value] then
    svo.echof("Replace each <...> with what it stands for, and pick one of each a|b, such as vcustomdef shimmer command shimmer on.")
    return defences.customdef_usage()
  end
  if name == 'game' then return defences.custom_gamelist() end
  if name == 'svof' then
    if verb == '' or verb:lower() == 'all' then return defences.own_list(verb ~= '') end
    svo.echof("vcustomdef svof lists Svof's own defences for your class, and vcustomdef svof all every class's.")
    return
  end
  if name == 'export' then return defences.custom_export(tail) end
  if name == 'import' then return defences.custom_import(tail) end
  verb = verb:lower()
  if verb == '' then return defences.custom_show(name) end
  if verb == 'test' then return defences.custom_test(name) end
  if verb == 'install' then return defences.custom_install(name) end
  if verb == 'delete' then return defences.custom_delete(name) end
  if verb == 'copy' then return defences.copy_offer(name) end
  if verb == 'reset' then
    if defences.is_own(name) then return defences.edit_reset(name) end
    svo.echof("reset puts back a defence of Svof's own that you changed, and %s isn't one. delete takes out one you defined.", name)
    return
  end
  if verb == 'line' then return defences.custom_capture(name, value:lower()) end
  if verb == 'fetch' then
    if defences.is_own(name) then return defences.edit_fetch(name, value) end
    local d, why = custom_draft(name)
    if not d then
      svo.echof("<250,0,0>Can't%s define %s: %s.", svo.getDefaultColor(), name, why)
      return
    end
    return defences.custom_fetch(name, value ~= '' and value or d.gmcp or name)
  end
  return defences.custom_set(name, verb, value)
end

-- Svof's own defences, changed by the player: vcustomdef <svof's name>,
-- for a defence the game changed before svof caught up (the user's ask,
-- 2026-10-10). A change replaces svof's exact gain, loss and DEF lines and
-- its GMCP name, which serverside knows it by too, and for a defence
-- basicdef made, whose action only sends its command, the command, and its
-- patterns for lines that vary (the user, 2026-10-11). Svof's other ways
-- of raising a defence and the logic around it stay, and the change's
-- screen says which. Changes are saved under
-- <profile>/svo/custom/edits, apart from definitions, by whose they are
-- (the class, or 'all' for a defence every class has the same) and name.
-- Each holds only what differs from svof's own, and svof's version of that
-- when it was changed (was), so svof can say when an update has changed it
-- since. vconfig customdefinitions off leaves them out too.
local edits_path = getMudletHomeDir() .. "/svo/custom/edits"
-- notondef: DEF doesn't list it (svof's invisibledef), as definitions have
-- skillset: the one a class's defence is listed under, for a class update
-- that moved it (the user's ask, 2026-10-17)
local edit_fields = { 'on', 'off', 'def', 'onr', 'offr', 'defr', 'notondef', 'command', 'gmcp', 'skillset' }
local edit_labels = { on = "gain lines", off = "loss lines", def = "DEF lines", onr = "gain patterns",
  offr = "loss patterns", defr = "DEF patterns", notondef = "whether DEF lists it", command = "command",
  gmcp = "GMCP name", skillset = "skillset" }
-- svof's own version of each defence a change is in use for, to put back
defences.own = defences.own or {}
defences.edit_drafts = defences.edit_drafts or {}

function defences.edits_load()
  local t = {}
  if lfs.attributes(edits_path) then
    local ok, msg = pcall(table.load, edits_path, t)
    if not ok then
      svo.echof("<250,0,0>Couldn't%s read your changes to Svof's defences, in %s: %s", svo.getDefaultColor(),
        edits_path, tostring(msg))
      t = {}
    end
  end
  defences.edits = t
end

function defences.edits_save()
  svo.pl.dir.makepath(getMudletHomeDir() .. "/svo/custom")
  svo.tablesave(edits_path, defences.edits)
end

-- whether two parts of a defence are the same: lines in any order, and no
-- GMCP name the same as none
local function same(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then return (a or nil) == (b or nil) end
  if #a ~= #b then return false end
  local x, y = line_list(a), line_list(b)
  table.sort(x) table.sort(y)
  for i = 1, #x do
    if x[i] ~= y[i] then return false end
  end
  return true
end

-- whose a change to svof's own defence is: one from a class's skillsets is
-- the class's, and one every class has the same, such as a general one,
-- is every class's
local function edit_key(rec)
  local group = rec and rec.type
  if group == nil or group == 'general' or group == 'dragoncraft' then return 'all' end
  return class_key(me.class)
end

-- whether name is svof's own defence in this class, which the player can
-- change, rather than one they defined
function defences.is_own(name)
  return defs_data[name] ~= nil and not defences.custom_registered[name]
end

-- the change saved for svof's own defence name in this class, and whose
-- it is
local function edit_of(name)
  local key = edit_key(defs_data[name])
  return defences.edits and defences.edits[key] and defences.edits[key][name], key
end

local function physical_of(name)
  local entry = svo.dict[name]
  return type(entry) == 'table' and type(entry.physical) == 'table' and entry.physical or nil
end

-- svof's own version of a defence, which a change is made from and reset
-- puts back
local function own_version(name)
  local snap, phys = defences.own[name], physical_of(name)
  if snap then
    return { on = line_list(snap.on), off = line_list(snap.off), def = line_list(snap.def),
      onr = line_list(snap.onr), offr = line_list(snap.offr), defr = line_list(snap.defr),
      notondef = snap.invisibledef and true or nil, command = snap.command, gmcp = snap.gmcp,
      skillset = snap.type, sendsaction = phys and phys.sendsaction }
  end
  local rec = defs_data[name]
  return { on = line_list(rec.on), off = line_list(rec.off), def = line_list(rec.def),
    onr = line_list(rec.onr), offr = line_list(rec.offr), defr = line_list(rec.defr),
    notondef = rec.invisibledef and true or nil, command = phys and phys.action, gmcp = svo.dict.svotossd[name],
    skillset = rec.type, sendsaction = phys and phys.sendsaction }
end

-- the command that raises it, which svof also takes for its own when the
-- player types it or serverside sends it (sys.input_to_actions)
local function set_command(phys, command, onstart)
  local map = sys.input_to_actions
  -- the old command's, as it is and in lower case
  for _, old in ipairs({ phys.action, defences.command_key(phys.action) }) do
    if map[old] == phys then map[old] = nil end
  end
  phys.action = command
  phys.onstart = onstart or function () send(command, conf.commandecho) end
  local key = defences.command_key(command)
  if key then map[key] = phys end
  if key and command ~= key then map[command] = phys end
end

-- its GMCP name, which serverside knows it by too
local function set_gmcp(name, gmcp, gamename)
  local old = svo.dict.svotossd[name]
  if old and svo.dict.sstosvod[old] == name then svo.dict.sstosvod[old] = nil end
  svo.dict.svotossd[name] = gmcp
  if gmcp then svo.dict.sstosvod[gmcp] = name end
  if type(svo.dict[name]) == 'table' then svo.dict[name].gamename = gamename end
end

-- moves a defence the lists already have from one skillset to another:
-- its place in the lists, and whether it's hidden. One svof hasn't listed
-- yet, as it loads, is listed under its record's
local function regroup(name, from, to)
  if from == to then return end
  -- listed already: def_types starts again each load, and the hide list's
  -- map of defences to groups doesn't
  local list, listed = defences.def_types[from] or {}, false
  for i = #list, 1, -1 do
    if list[i] == name then
      table.remove(list, i)
      listed = true
    end
  end
  if not listed then return end
  if #list == 0 then defences.def_types[from] = nil end
  defences.def_types[to] = defences.def_types[to] or {}
  defences.def_types[to][#defences.def_types[to] + 1] = name
  local old = sk.ignored_defences[from]
  local hidden = old and old.t[name] or false
  if old then old.t[name] = nil end
  sk.ignored_defences[to] = sk.ignored_defences[to] or { status = false, t = {} }
  sk.ignored_defences[to].t[name] = hidden
  sk.ignored_defences_map[name] = to
end

-- puts a change into play over svof's own version, keeping that to put
-- back. A GMCP name svof has since given another defence stays that one's
local function edit_apply(name, edit)
  local rec, entry, phys = defs_data[name], svo.dict[name], physical_of(name)
  local snap = { on = rec.on, off = rec.off, def = rec.def, onr = rec.onr, offr = rec.offr, defr = rec.defr,
    invisibledef = rec.invisibledef, gmcp = svo.dict.svotossd[name],
    gamename = type(entry) == 'table' and entry.gamename or nil, command = phys and phys.action,
    onstart = phys and phys.onstart, type = rec.type }
  defences.own[name] = snap
  for _, field in ipairs({ 'on', 'off', 'def', 'onr', 'offr', 'defr' }) do
    if edit[field] then rec[field] = line_list(edit[field]) end
  end
  if edit.notondef ~= nil then rec.invisibledef = edit.notondef or nil end
  if edit.command and phys and phys.sendsaction then set_command(phys, edit.command) end
  if edit.skillset then
    regroup(name, rec.type, edit.skillset)
    rec.type = edit.skillset
  end
  local taken = edit.gmcp and svo.dict.sstosvod[edit.gmcp]
  if edit.gmcp ~= nil and not (taken and taken ~= name) then
    -- what the name meant before, such as a defence svof leaves alone
    if edit.gmcp then snap.held = taken end
    set_gmcp(name, edit.gmcp or nil, edit.gmcp or nil)
  end
end

-- puts svof's own version back
local function edit_restore(name)
  local snap = defences.own[name]
  if not snap then return end
  defences.own[name] = nil
  local rec, phys = defs_data[name], physical_of(name)
  if rec then
    rec.on, rec.off, rec.def, rec.invisibledef = snap.on, snap.off, snap.def, snap.invisibledef
    rec.onr, rec.offr, rec.defr = snap.onr, snap.offr, snap.defr
    if snap.type and rec.type ~= snap.type then
      regroup(name, rec.type, snap.type)
      rec.type = snap.type
    end
  end
  if phys and phys.action ~= snap.command then set_command(phys, snap.command, snap.onstart) end
  local mine = svo.dict.svotossd[name]
  if mine ~= snap.gmcp then
    set_gmcp(name, snap.gmcp, snap.gamename)
    if mine then svo.dict.sstosvod[mine] = snap.held end
  end
end

-- makes a defence's triggers again from its record's lines
local function rewire(name)
  for _, id in ipairs(defences.triggers_of[name] or {}) do killTrigger(id) end
  defences.wire_triggers(name, defs_data[name])
end

-- serverside knows a defence by its GMCP name: once that changes, svof's
-- next sync of priorities gives the server the new one. Before it changes,
-- custom_server_forget tells the server to stop raising the old one
local function server_renamed(name)
  if not (conf.serverside and sk.priosbeforechange) then return end
  for _, state in pairs(sk.priosbeforechange) do
    for prio, action in pairs(state.data or {}) do
      if action == name or action == name .. '_physical' then state.data[prio] = nil end
    end
  end
  sk.handleserversideswitch()
end

-- puts a change into play now, after svof loaded: over svof's own, or over
-- the change it replaces, telling serverside of a new GMCP name
local function edit_live(name, edit)
  local before = svo.dict.svotossd[name]
  local after = own_version(name).gmcp
  if edit and edit.gmcp ~= nil then after = edit.gmcp or nil end
  local renamed = before ~= after
  if renamed then custom_server_forget(name) end
  edit_restore(name)
  if edit then edit_apply(name, edit) end
  rewire(name)
  if renamed then server_renamed(name) end
end

-- the parts of a change svof has changed its own version of since: the
-- ones whose was isn't svof's now
local function edit_moved(name, edit)
  local own, moved = own_version(name), {}
  for _, field in ipairs(edit_fields) do
    if edit[field] ~= nil and not same((edit.was or {})[field], own[field]) then moved[#moved + 1] = field end
  end
  return moved
end

-- what a change adds to svof's own name, for defences.clash: the lines and
-- patterns svof's own doesn't have, and a command svof's own doesn't send,
-- against the class's other defences; and all its patterns against all
-- its lines of another kind. Its GMCP name is checked where it's set
local function edit_parts(name, edit)
  local own, lines, patterns, every, kinds = own_version(name), {}, {}, {}, {}
  for _, field in ipairs({ 'on', 'off', 'def' }) do
    kinds[field] = edit[field] and line_list(edit[field]) or own[field]
    for _, l in ipairs(line_list(edit[field])) do
      if not table.contains(own[field], l) then lines[#lines + 1] = l end
    end
  end
  for _, field in ipairs(pattern_fields) do
    for _, p in ipairs(edit[field] and line_list(edit[field]) or own[field]) do
      every[#every + 1] = { field, p }
      if not table.contains(own[field], p) then patterns[#patterns + 1] = { field, p } end
    end
  end
  local command = own.sendsaction and edit.command ~= own.command and edit.command or nil
  return { lines = lines, patterns = patterns, kinds = kinds, selfpatterns = every, command = command }
end

-- Puts this class's change to svof's own name into play, as svof loads or
-- registers the defence, saying if svof's own has changed since
function defences.edit_put(name)
  if not conf.customdefinitions or not defences.edits then return end
  local edit = edit_of(name)
  if not edit or defences.own[name] then return end
  -- one that clashes with this class's other defences, which a class
  -- change or an update to Svof can bring, stays out
  local clash = defences.clash(name, edit_parts(name, edit))
  if clash then
    svo.echofn("<250,0,0>Didn't%s use your change to Svof's own %s: %s. ", svo.getDefaultColor(), name, clash)
    custom_link("(see it)", string.format("svo.defences.custom_show(%q)", name), "See your change next to Svof's own")
    echo("\n")
    return
  end
  local moved = edit_moved(name, edit)
  edit_apply(name, edit)
  if #moved == 0 then return end
  for i, field in ipairs(moved) do moved[i] = edit_labels[field] end
  svo.echofn("Svof has updated the %s of its own %s since you changed it. Yours %s still in use: ",
    svo.concatand(moved), name, #moved == 1 and "is" or "are")
  custom_link("see both", string.format("svo.defences.custom_show(%q)", name), "See your change next to Svof's own")
  echo(", ")
  custom_link("use Svof's", string.format("svo.defences.edit_reset(%q)", name), "Delete your change and use Svof's",
    'remove')
  echo(", ")
  custom_link("keep yours", string.format("svo.defences.edit_keep(%q)", name), "Keep your change, and stop saying so")
  echo("\n")
end

-- At systemstart, before anything is made from the records: puts this
-- class's changes into play
function defences.edits_start()
  defences.own, defences.edit_drafts, defences.edit_converting = {}, {}, {}
  if not defences.edits then defences.edits_load() end
  if not conf.customdefinitions then return end
  for name in defs_data:iter() do defences.edit_put(name) end

  -- a change to a defence svof doesn't have any more. An item's defence
  -- registers later
  for _, key in ipairs({ 'all', class_key(me.class) }) do
    local names = {}
    for name in pairs(defences.edits[key] or {}) do
      if not defs_data[name] and not item_defences[name] then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
      svo.echofn("Svof doesn't have %s any more, so your change to it isn't used. ", name)
      custom_link("(forget it)", string.format("svo.defences.edit_reset(%q, %q)", name, key),
        "Delete your change to " .. name, 'remove')
      echo("\n")
    end
  end
end

-- the change being made to svof's own name, started from the one saved or
-- from svof's own
local function edit_draft(name)
  local d = defences.edit_drafts[name]
  if d then return d end
  local own, edit = own_version(name), edit_of(name)
  local function from(field)
    if edit and edit[field] ~= nil then return edit[field] end
    return own[field]
  end
  d = { on = line_list(from('on')), off = line_list(from('off')), def = line_list(from('def')),
    onr = line_list(from('onr')), offr = line_list(from('offr')), defr = line_list(from('defr')),
    notondef = from('notondef') or nil, command = from('command'), gmcp = from('gmcp') or nil,
    skillset = from('skillset') }
  defences.edit_drafts[name] = d
  return d
end

-- whether a draft is what's installed: the change saved, or svof's own
local function draft_installed(name, d)
  local own, edit = own_version(name), edit_of(name)
  for _, field in ipairs(edit_fields) do
    local installed = own[field]
    if edit and edit[field] ~= nil then installed = edit[field] end
    if not same(d[field], installed) then return false end
  end
  return true
end

-- whether a change leaves a defence DEF lists with no DEF line or pattern
-- where svof's own had one, which test and install warn about
local function edit_drops_def(name, d)
  local own = own_version(name)
  return #d.def == 0 and #d.defr == 0 and (#own.def > 0 or #own.defr > 0) and not d.notondef
end

-- why a change can't be installed, or nil
local function edit_problem(name, d)
  local own = own_version(name)
  local mapped = d.gmcp and svo.dict.sstosvod[d.gmcp]
  if mapped and mapped ~= name then return "GMCP's " .. d.gmcp .. " is Svof's " .. mapped end
  if #d.on == 0 and #d.onr == 0 and (#own.on > 0 or #own.onr > 0) and not d.gmcp then
    return "it needs a line saying you gained it, or its GMCP name, or Svof can't tell when it's up"
  end
  -- its patterns svof's own doesn't have
  local why = patterns_problem(d, function (field, p) return table.contains(own[field], p) end)
  if why then return why end
  return defences.clash(name, edit_parts(name, d))
end

-- what svof does with a defence that lies elsewhere, outside its record and
-- entry
local outside_rules = {
  torch = "the ablaze affliction counting as torch for a fire Elemental Lord",
  dragonform = "your race over GMCP saying whether you're a dragon",
  shadowcloak = "your inventory over GMCP saying whether you wear your cloak",
  block = "losing it when you leave the room",
  listen = "losing it when you leave the room",
  eavesdrop = "losing it when you leave the room",
  lyre = "losing it when you leave the room",
}

-- the balances other than physical that svof raises name with, such as
-- rebounding's smoke
local function raised_with(name)
  local entry, others = svo.dict[name], {}
  if type(entry) ~= 'table' then return others end
  for balance, act in pairs(entry) do
    if type(act) == 'table' and act.def and balance ~= 'physical' then others[#others + 1] = balance end
  end
  table.sort(others)
  return others
end

-- why a change can't reach the command of svof's own name
local function fixed_command(name)
  local others = raised_with(name)
  if physical_of(name) then return "Svof makes it as it raises it, so a change can't reach it" end
  if #others > 0 then return "Svof raises it with " .. svo.concatand(others) .. ", so it has no command to change" end
  return "Svof doesn't raise it, it only tracks it"
end

-- what a change to svof's own defence doesn't reach, as svof does more
-- with it than the lines, GMCP name and command
local function edit_notes(name)
  local rec, phys = defs_data[name], physical_of(name)
  local notes = {}
  local function add(note) notes[#notes + 1] = note end
  if rec.on_only or rec.on_free or rec.off_free or rec.offs then add("other lines it watches for") end
  if rec.ongot or rec.onlost then add("what gaining or losing it does to your other defences and afflictions") end
  if rec.onenable then add("the defences it can't be up with on defup and keepup") end
  if rec.specialskip then add("when it holds off raising it") end
  if rec.ondef then add("what it reads from its DEF line") end
  if rec.custom_def_type then add(string.format("counting it with your other %s defences", rec.custom_def_type)) end
  -- (without physical, the command row says how svof raises it)
  local others = raised_with(name)
  if phys and #others > 0 then add("raising it with " .. svo.concatand(others) .. " as well") end
  if defences.waits[name] then add("the wait for it after its command") end
  for _, h in ipairs({ 'got_', 'lost_' }) do
    if defs[h .. name] and not (defences.generated and defences.generated[h .. name]) then
      add("its own handling of its lines")
      break
    end
  end
  if defences.prompt_decides[name] then add("deciding on each prompt whether it's a defence or an affliction") end
  if outside_rules[name] then add(outside_rules[name]) end
  return notes
end

function defences.edit_show(name)
  local d, own, edit, phys = edit_draft(name), own_version(name), edit_of(name), physical_of(name)
  svo.echof("%s, Svof's own defence%s%s:", name, edit and ", which you changed" or "",
    draft_installed(name, d) and "" or " (changes not installed)")
  svo.echof("A change replaces Svof's version, and Svof's updates to %s don't reach you while it's in use.", name)
  local cmd = "vcustomdef " .. name .. " "
  -- Svof's own, under a part the change differs in
  local function svofs(values)
    if #values == 0 then values = { "(none)" } end
    for i, value in ipairs(values) do
      custom_label("")
      custom_unset_text(string.format("%s %s\n", i == 1 and "Svof's:" or "       ", value))
    end
  end
  if phys and phys.sendsaction then
    custom_label("command:")
    echo(tostring(d.command) .. "  ")
    custom_link("change", string.format("printCmdLine(%q)", cmd .. "command "), "Change the command")
    echo("\n")
    if d.command ~= own.command then svofs({ tostring(own.command) }) end
  else
    custom_label("command:")
    echo(fixed_command(name) .. "\n")
  end
  custom_label("GMCP name:")
  if d.gmcp then echo(d.gmcp .. "  ") else custom_unset_text("(none)  ") end
  custom_link("change", string.format("printCmdLine(%q)", cmd .. "gmcp "), "Change the GMCP name")
  echo("\n")
  if not same(d.gmcp, own.gmcp) then svofs({ own.gmcp }) end
  -- the skillset it's listed under, which a class update can move it from
  custom_label("skillset:")
  if edit_key(defs_data[name]) == 'all' then
    echo(tostring(d.skillset) .. ", which every class has, so it stays there\n")
  else
    echo(tostring(d.skillset) .. "  ")
    for _, skillset in ipairs(class_skills(me.class) or {}) do
      if skillset ~= d.skillset then
        custom_link(skillset, string.format("svo.defences.custom_set(%q, 'skillset', %q)", name, skillset),
          "List it under " .. skillset:title())
        echo("  ")
      end
    end
    custom_link("type one", string.format("printCmdLine(%q)", cmd .. "skillset "), "One Svof doesn't list for the class")
    echo("\n")
    if d.skillset ~= own.skillset then svofs({ tostring(own.skillset) }) end
  end
  local unlisted = "nothing, as DEF doesn't list it"
  for _, which in ipairs({ { 'on', 'got', "gained when:" }, { 'off', 'lost', "lost when:" }, { 'def', 'def', "DEF shows:" } }) do
    local lines, isdef = d[which[1]], which[1] == 'def'
    if isdef and d.notondef then
      custom_label(which[3])
      echo(unlisted .. "  ")
      custom_link("it does", string.format("printCmdLine(%q)", cmd .. "def "), "Type or paste the line DEF shows")
      echo("\n")
    else
      for i, line in ipairs(lines) do
        custom_label(i == 1 and which[3] or "")
        echo(line .. "  ")
        custom_link("x", string.format("svo.defences.custom_unset(%q, %q, %d)", name, which[1], i), "Remove this line",
          'remove')
        echo("\n")
      end
      custom_label(#lines == 0 and which[3] or "")
      if #lines == 0 then custom_unset_text("(no line)  ") end
      custom_link("add a line from the screen", string.format("svo.defences.custom_capture(%q, %q)", name, which[2]),
        "Pick the line from what's on screen")
      echo("  ")
      custom_link("type one", string.format("printCmdLine(%q)", cmd .. which[2] .. " "), "Type or paste the line")
      if isdef then
        echo("  ")
        custom_link("DEF doesn't list it", string.format("svo.defences.custom_set(%q, 'def', 'none')", name),
          "For a defence DEF doesn't show, which DEF then leaves alone")
      end
      echo("\n")
    end
    if isdef and not (same(lines, own.def) and same(d.notondef, own.notondef)) then
      svofs(own.notondef and { unlisted } or own.def)
    elseif not isdef and not same(lines, own[which[1]]) then
      svofs(own[which[1]])
    end
    -- its patterns, for lines that vary, and svof's own where they differ
    if not (isdef and d.notondef) then
      local field = which[1] .. 'r'
      pattern_rows(name, cmd, d[field], field, which[2] .. "pattern")
      if not same(d[field], own[field]) then svofs(own[field]) end
    end
  end
  for i, note in ipairs(edit_notes(name)) do
    custom_label(i == 1 and "Svof keeps:" or "")
    echo(note .. "\n")
  end
  custom_separator()
  custom_label("Actions:")
  custom_link("get its lines from the game", string.format("svo.defences.edit_fetch(%q)", name), "Ask the game with DEFENCE SHOW")
  echo("  ")
  custom_link("test", string.format("svo.defences.custom_test(%q)", name), "Say what it would do")
  echo("  ")
  custom_link("install", string.format("svo.defences.custom_install(%q)", name), "Put it into play", 'go')
  echo("  ")
  custom_link("reset to Svof's", string.format("svo.defences.edit_reset(%q)", name), "Put Svof's own back", 'remove')
  echo("\n")
end

function defences.edit_set(name, field, value)
  local d, own = edit_draft(name), own_version(name)
  value = value or ''
  if field == 'command' then
    if not own.sendsaction then
      svo.echof("Can't change %s's command: %s.", name, fixed_command(name))
      return
    end
    if value == '' then svo.echof("What does Svof send to raise %s?", name) return end
    d.command = value
  elseif field == 'gmcp' then
    local gmcp = (value ~= '' and value:lower() ~= 'none') and value:lower() or nil
    local mapped = gmcp and svo.dict.sstosvod[gmcp]
    if mapped and mapped ~= name then
      svo.echof("Can't give %s the GMCP name %s: GMCP's %s is Svof's %s.", name, gmcp, gmcp, mapped)
      return
    end
    -- only a name the game confirms, or svof's own back again
    local new = gmcp and gmcp ~= own.gmcp
    local known = new and defences.gmcp_known(gmcp)
    if new and known == false then
      svo.echof("%s", defences.gmcp_refusal(name, gmcp))
      return
    elseif new and known == nil then
      svo.echof("Asking the game whether GMCP knows a defence called %s.", gmcp)
      defences.custom_fetch(name, gmcp, 'gmcp')
      return
    end
    d.gmcp = gmcp
  elseif field == 'def' and value:lower() == 'none' then
    -- DEF doesn't list it, so DEF leaves it alone
    d.def, d.defr, d.notondef = {}, {}, true
  elseif field == 'gotpattern' or field == 'lostpattern' or field == 'defpattern' then
    local key = field == 'gotpattern' and 'onr' or field == 'lostpattern' and 'offr' or 'defr'
    if value == '' then
      svo.echof("Which pattern matches the line that %s?", field == 'gotpattern' and ("says you gained " .. name)
        or field == 'lostpattern' and ("says you lost " .. name) or ("DEF shows for " .. name))
      return
    end
    -- svof's own back again needs no reading
    local why = not table.contains(own[key], value) and defences.pattern_problem(value)
    if why then
      svo.echof("Can't use %s as a pattern: %s.", value, why)
      return
    end
    if not table.contains(d[key], value) then d[key][#d[key] + 1] = value end
    if key == 'defr' then d.notondef = nil end
  elseif field == 'got' or field == 'lost' or field == 'def' then
    if value == '' then
      svo.echof("Which line %s?", field == 'got' and ("says you gained " .. name)
        or field == 'lost' and ("says you lost " .. name) or ("does DEF show for " .. name))
      return
    end
    local lines = d[field == 'got' and 'on' or field == 'lost' and 'off' or 'def']
    if not table.contains(lines, value) then lines[#lines + 1] = value end
    if field == 'def' then d.notondef = nil end
  elseif field == 'skillset' then
    if edit_key(defs_data[name]) == 'all' then
      svo.echof("Svof's own %s is a %s defence, which every class has, so its skillset stays.", name, tostring(own.skillset))
      return
    end
    local skillset = value:lower()
    if skillset == '' then svo.echof("Which skillset is %s in now?", name) return end
    local why = skillset_problem(skillset)
    if why then
      svo.echof("Can't list %s under %s: %s.", name, skillset, why)
      return
    end
    d.skillset = skillset
  elseif field == 'class' or field == 'balanceless' or field == 'serverside' then
    svo.echof("Svof's own %s keeps its class and balance. A change can replace its lines, patterns, GMCP name and skillset, and for some defences the command.", name)
    return
  else
    svo.echof("A change to Svof's own defence has command, gmcp, skillset, got, lost, def, gotpattern, lostpattern and defpattern; %s isn't one.", field)
    return
  end
  defences.edit_show(name)
end

function defences.edit_unset(name, which, i)
  local d = edit_draft(name)
  if d[which] then table.remove(d[which], i) end
  defences.edit_show(name)
end

-- asks the game for its lines, with DEFENCE SHOW, into the change
function defences.edit_fetch(name, keyword)
  local d = edit_draft(name)
  defences.custom_fetch(name, (keyword and keyword ~= '') and keyword or d.gmcp or name)
end

function defences.edit_test(name)
  local d, own, rec = edit_draft(name), own_version(name), defs_data[name]
  local key = edit_key(rec)
  svo.echof("%s, Svof's own, for %s:", name, key == 'all' and "every class" or key)
  local changes = {}
  for _, field in ipairs(edit_fields) do
    if not same(d[field], own[field]) then changes[#changes + 1] = edit_labels[field] end
  end
  if #changes == 0 then
    svo.echof("It's the same as Svof's own.")
  else
    svo.echof("Your change replaces its %s.", svo.concatand(changes))
  end
  svo.echof("It knows it's up from %s.", known_from(d.on, #d.onr, d.gmcp and ("GMCP's " .. d.gmcp)))
  svo.echof("It knows it's gone from %s.", known_from(d.off, #d.offr, d.gmcp and "GMCP"))
  if d.notondef then
    svo.echof("DEF doesn't list it, so DEF leaves it alone.")
  elseif edit_drops_def(name, d) then
    svo.echof("%s", no_def_warning(name))
  end
  local problem = edit_problem(name, d)
  if problem then
    svo.echof("<250,0,0>It can't%s be installed yet: %s.", svo.getDefaultColor(), problem)
  else
    svo.echof("It's ready to install.")
  end
end

-- Installs the change being made to svof's own name. The first time, it
-- says what a change does and asks again (sure)
function defences.edit_install(name, sure)
  if not defences.edits then defences.edits_load() end
  local d = defences.edit_drafts[name]
  if not d then svo.echof("You haven't changed anything in Svof's own %s.", name) return false end
  local problem = edit_problem(name, d)
  if problem then
    svo.echof("<250,0,0>Can't%s change %s: %s.", svo.getDefaultColor(), name, problem)
    return false
  end
  local own, edit, key = own_version(name), edit_of(name)
  -- only what differs from svof's own, and svof's own of that
  local new, was = {}, {}
  for _, field in ipairs(edit_fields) do
    if not (field == 'command' and not own.sendsaction) and not same(d[field], own[field]) then
      if type(d[field]) == 'table' then new[field] = line_list(d[field]) else new[field] = d[field] or false end
      if type(own[field]) == 'table' then was[field] = line_list(own[field]) else was[field] = own[field] end
    end
  end
  if not next(new) then
    defences.edit_drafts[name] = nil
    if edit then return defences.edit_reset(name) end
    svo.echof("That's the same as Svof's own %s, so there's nothing to change.", name)
    return true
  end
  if not edit and not sure then
    svo.echofn("Changing Svof's own %s replaces Svof's version of it, and Svof's updates to %s won't reach you until you reset it. ",
      name, name)
    custom_link("(change it)", string.format("svo.defences.edit_install(%q, true)", name), "Put your change into play",
      'go')
    echo("\n")
    return false
  end
  new.was = was
  local drops = edit_drops_def(name, d)
  defences.edits[key] = defences.edits[key] or {}
  defences.edits[key][name] = new
  defences.edit_drafts[name] = nil
  defences.edits_save()
  if not conf.customdefinitions then
    svo.echof("Saved your change to %s. vconfig customdefinitions is off, so Svof doesn't use it.", name)
  else
    edit_live(name, new)
    svo.echof("Changed Svof's own %s. vcustomdef %s reset puts Svof's back.", name, name)
  end
  if drops then svo.echof("%s", no_def_warning(name)) end
  -- a definition turned into this change goes now
  if defences.edit_converting[name] and defences.custom and defences.custom[name] then
    defences.custom[name] = nil
    defences.custom_save()
    svo.echof("Deleted your definition of %s, which this change replaces.", name)
  end
  defences.edit_converting[name] = nil
  return true
end

-- Puts svof's own version of name back, deleting the change. key, from
-- the list, names another class's change, which is only deleted
function defences.edit_reset(name, key)
  if not defences.edits then defences.edits_load() end
  local here = defs_data[name] and edit_key(defs_data[name])
  key = key or here
  -- a change being made, and not installed, is thrown away
  local draft = key == here and defences.edit_drafts[name]
  local drafted = draft and not draft_installed(name, draft)
  if key == here then defences.edit_drafts[name] = nil end
  local edit = key and defences.edits[key] and defences.edits[key][name]
  if not edit then
    svo.echof(drafted and "Threw away your change to %s." or "You haven't changed Svof's own %s.", name)
    return
  end
  defences.edits[key][name] = nil
  if not next(defences.edits[key]) then defences.edits[key] = nil end
  defences.edits_save()
  if key ~= here then
    svo.echof("Deleted your change to %s for %s.", name, class_title(key))
    return
  end
  if defences.own[name] then edit_live(name, nil) end
  svo.echof("Put Svof's own %s back.", name)
end

-- keeps the change to name after svof updated its own, and stops saying so
function defences.edit_keep(name)
  local edit = edit_of(name)
  if not edit then return end
  local own = own_version(name)
  edit.was = edit.was or {}
  for _, field in ipairs(edit_fields) do
    if edit[field] ~= nil then
      if type(own[field]) == 'table' then edit.was[field] = line_list(own[field]) else edit.was[field] = own[field] end
    end
  end
  defences.edits_save()
  svo.echof("Kept your change to %s.", name)
end

-- Turns a definition saved in another class, whose name is svof's own
-- defence in this one, into a change to svof's own: its lines join svof's,
-- and its command and GMCP name are taken where a change can have them.
-- The definition goes once the change is installed.
defences.edit_converting = defences.edit_converting or {}
function defences.custom_to_change(name)
  local spec = defences.custom and defences.custom[name]
  if not (spec and defences.is_own(name)) then return end
  defences.edit_drafts[name] = nil
  local d, own = edit_draft(name), own_version(name)
  local function add(list, lines)
    for _, l in ipairs(line_list(lines)) do
      if not table.contains(list, l) then list[#list + 1] = l end
    end
  end
  add(d.on, spec.on)
  add(d.off, spec.off)
  for _, field in ipairs(pattern_fields) do add(d[field], spec[field]) end
  if spec.def then
    add(d.def, spec.def)
    d.notondef = nil
  elseif spec.notondef then
    d.def, d.notondef = {}, true
  end
  if spec.command and own.sendsaction then
    d.command = spec.command
  elseif spec.command and spec.command ~= own.command then
    svo.echof("Svof makes %s's command itself, so the one you defined, %s, isn't used.", name, spec.command)
  end
  local mapped = spec.gmcp and svo.dict.sstosvod[spec.gmcp]
  if spec.gmcp and not (mapped and mapped ~= name) then d.gmcp = spec.gmcp end
  defences.edit_converting[name] = true
  svo.echof("Your definition of %s is in a change to Svof's own now. Install it to use it, and the definition goes.", name)
  defences.edit_show(name)
end

-- vcustomdef's list of the changes to svof's own, every class's, and the
-- ones being made
function defences.edits_menu()
  local changes = {}
  for key, names in pairs(defences.edits or {}) do
    for name in pairs(names) do changes[#changes + 1] = { name = name, key = key } end
  end
  for name, d in pairs(defences.edit_drafts) do
    local edit, key = edit_of(name)
    if not edit and not draft_installed(name, d) then changes[#changes + 1] = { name = name, key = key, draft = true } end
  end
  if #changes == 0 then return end
  table.sort(changes, function (a, b) return a.name < b.name or (a.name == b.name and a.key < b.key) end)
  svo.echof("Svof's own defences you changed:")
  for _, c in ipairs(changes) do
    local here = defs_data[c.name] ~= nil and edit_key(defs_data[c.name]) == c.key
    local state = c.draft and "not installed"
      or not here and "not for this class"
      or defences.edit_drafts[c.name] and not draft_installed(c.name, defences.edit_drafts[c.name]) and "changes not installed"
      or defences.own[c.name] and "in use"
      or "not in use, as vconfig customdefinitions is off"
    echo("  ")
    if here then
      custom_link(c.name, string.format("svo.defences.custom_show(%q)", c.name), "See or change " .. c.name)
    else
      echo(c.name)
    end
    echo(string.format(": %s, %s  ", class_title(c.key), state))
    custom_link(c.draft and "discard" or "reset", string.format("svo.defences.edit_reset(%q, %q)", c.name, c.key),
      c.draft and "Throw the change away" or "Delete the change, for Svof's own", 'remove')
    echo("\n")
  end
end

-- the changes to svof's own in a file vcustomdef export wrote
function defences.edits_import(changes, path)
  if not defences.edits then defences.edits_load() end
  local keys = {}
  for key, names in pairs(changes) do
    if type(key) == 'string' and type(names) == 'table' then keys[#keys + 1] = key end
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local names = {}
    for name, edit in pairs(changes[key]) do
      if type(name) == 'string' and type(edit) == 'table' then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
      local edit = changes[key][name]
      local here = defs_data[name] and edit_key(defs_data[name]) == key
      local problem = imported_gmcp_problem(edit.gmcp)
      -- its patterns, which must read, and for this class, a clash
      if not problem then
        problem = patterns_problem(edit, here and function (field, p) return table.contains(own_version(name)[field], p) end)
      end
      if not problem and here then problem = defences.clash(name, edit_parts(name, edit)) end
      if defences.edits[key] and defences.edits[key][name] then
        svo.echof("You already changed Svof's own %s, so the change in %s isn't used.", name, path)
      elseif problem then
        svo.echof("Didn't import the change to Svof's own %s from %s: %s.", name, path, problem)
      else
        if type(changes[key][name].gmcp) == 'string' then changes[key][name].gmcp = changes[key][name].gmcp:lower() end
        defences.edits[key] = defences.edits[key] or {}
        defences.edits[key][name] = changes[key][name]
        if conf.customdefinitions and defs_data[name] and edit_key(defs_data[name]) == key then
          edit_live(name, changes[key][name])
        end
        svo.echof("Added the change to Svof's own %s from %s.", name, path)
      end
    end
  end
  defences.edits_save()
end

-- Copies of svof's own defences from other classes (the user, 2026-10-10):
-- for a defence the game gave a class svof's list is out of date for, or
-- one an artefact gives every class, as the phylactery's mindnet does. A
-- copy is a definition (copy, in the definition's table) started from
-- svof's own version in another class, defences.catalog: its lines, DEF
-- line, GMCP name, command and balance, and its other lines and patterns
-- kept as they are. Only a defence svof raises by sending its command and
-- tracks by its lines can be copied: svof's other rules for it, such as
-- the defences it can't be up with, don't come with a copy. Artefact
-- versions so far have the GMCP name of the class's (the user,
-- 2026-10-10).
local copy_rules = {
  tracked = "Svof only tracks it there, it doesn't raise it",
  own_code = "Svof's action for it there does more than send its command",
  ongot = "gaining it changes your other defences or afflictions",
  onlost = "losing it changes your other defences or afflictions",
  onenable = "it can't be up with some of your other defences",
  specialskip = "Svof holds off raising it at times",
  ondef = "Svof reads what its DEF line says",
  handlers = "Svof handles its lines with code of its own",
  wait = "Svof waits for it after its command",
}
local item_configs = { mindnet = 'havemindnet', lifevision = 'havelifevision', shroud = 'haveshroud' }

-- why svof's own version v of name can't be copied, or nil
local function copy_refusal(name, v)
  if item_configs[name] then
    return string.format("it comes with an item, and vconfig %s adds Svof's own for that", item_configs[name])
  end
  local why = {}
  for _, rule in ipairs(v.rules or {}) do
    if rule == 'balances' then
      why[#why + 1] = "Svof raises it with " .. svo.concatand(v.raisedwith or {}) .. ", not a command"
    elseif rule == 'counted' then
      why[#why + 1] = string.format("Svof counts it with your other %s defences", tostring(v.counted))
    elseif copy_rules[rule] then
      why[#why + 1] = copy_rules[rule]
    else
      why[#why + 1] = "Svof does more with it than a copy can carry"
    end
  end
  if defences.prompt_decides[name] then
    why[#why + 1] = "Svof decides on each prompt whether it's a defence or an affliction"
  end
  if outside_rules[name] then why[#why + 1] = "Svof keeps " .. outside_rules[name] end
  if #why == 0 and type(v.command) ~= 'string' then why[#why + 1] = "Svof has no command for it" end
  if #why > 0 then return svo.concatand(why) end
end

-- the version of name from class, or nil, and its place in the list
local function version_from(name, class)
  for i, v in ipairs(defences.catalog()[name] or {}) do
    for _, c in ipairs(v.classes or {}) do
      if c == class then return v, i end
    end
  end
end

-- why a copy can't be installed, or nil: svof's own in the class it came
-- from has to be one a copy can carry
function defences.copy_problem(name, spec)
  local v = version_from(name, spec.copy.from)
  if not v then return string.format("Svof doesn't have %s for %s, which it was copied from", name, tostring(spec.copy.from)) end
  local why = copy_refusal(name, v)
  if why then return "it can't be copied: " .. why end
end

-- svof's own version v, as a copy keeps it to tell when it changes
local copy_fields = { 'type', 'command', 'balanceless', 'gmcp', 'notondef', 'on', 'off', 'def', 'onr', 'offr',
  'defr', 'on_only', 'on_free', 'off_free', 'offs' }
local function copy_was(v)
  local was = {}
  for _, field in ipairs(copy_fields) do
    if type(v[field]) == 'table' then was[field] = line_list(v[field]) else was[field] = v[field] end
  end
  return was
end

local function copy_same(a, b)
  for _, field in ipairs(copy_fields) do
    if not same(a[field], b[field]) then return false end
  end
  return true
end

-- vcustomdef <name> copy: svof's own versions of name in other classes,
-- each a link to copy it
function defences.copy_offer(name)
  if defences.is_own(name) then
    svo.echof("Svof has its own %s in this class, so there's nothing to copy. vcustomdef %s changes it.", name, name)
    return
  end
  local versions = defences.catalog()[name]
  if not versions then
    svo.echof("Svof doesn't have a defence called %s in any class, so define it with vcustomdef %s.", name, name)
    return
  end
  svo.echof("Svof has its own %s for %s, so it can't be defined again. If you have it as %s too, or from an artefact, copy Svof's own:",
    name, class_names(versions), tostring(me.class))
  for i, v in ipairs(versions) do
    echo(string.format("  for %s: %s  ", class_names({ v }),
      type(v.command) == 'string' and string.format("raised with %q", v.command) or "not raised by a command"))
    local why = copy_refusal(name, v)
    if why then
      echo("can't be copied: " .. why .. "\n")
    else
      custom_link("copy it", string.format("svo.defences.copy_own(%q, %d)", name, i),
        "Copy Svof's own " .. name .. " for " .. class_names({ v }), 'go')
      echo("\n")
    end
  end
end

-- Starts a copy of svof's own name, the ith version: into the definition
-- of name if there is one, keeping its class and skillset, and the lines
-- one the player defined had
function defences.copy_own(name, i)
  local versions = defences.catalog()[name]
  local v = versions and versions[tonumber(i) or 1]
  if not v or defences.is_own(name) then
    svo.echof("Svof doesn't have %s in another class to copy.", name)
    return
  end
  local why = copy_refusal(name, v)
  if why then
    svo.echof("Can't copy Svof's own %s: %s.", name, why)
    return
  end
  local had = defences.custom_drafts[name] or defences.custom[name]
  local d = { class = had and had.class or class_key(me.class), command = v.command,
    balanceless = v.balanceless, gmcp = v.gmcp, notondef = v.notondef,
    on = line_list(v.on), off = line_list(v.off),
    copy = { from = v.classes[1], was = copy_was(v), lines = {} } }
  local defs = line_list(v.def)
  d.def = table.remove(defs, 1)
  if #defs > 0 then d.copy.lines.def = defs end
  -- svof's patterns, which the copy shows and can change, and its other
  -- lines, kept as they are
  for _, field in ipairs(pattern_fields) do
    if v[field] then d[field] = line_list(v[field]) end
  end
  for _, field in ipairs(copy_line_fields) do
    if field ~= 'def' and not kind_of[field] and v[field] then d.copy.lines[field] = line_list(v[field]) end
  end
  if had and had.skillset then
    d.skillset = had.skillset
  elseif d.class ~= 'all' and table.contains(class_skills(d.class) or {}, v.type) then
    d.skillset = v.type
  end
  -- a definition the player made of it: its lines join svof's
  if had and type(had.copy) ~= 'table' then
    for _, field in ipairs({ 'on', 'off', 'onr', 'offr', 'defr' }) do
      for _, l in ipairs(line_list(had[field])) do
        d[field] = d[field] or {}
        if not table.contains(d[field], l) then d[field][#d[field] + 1] = l end
      end
    end
    if not d.def and had.def then d.def = had.def end
  end
  if had then class_chosen[name] = true end
  defences.custom_drafts[name] = d
  svo.echof("Copied Svof's own %s for %s. Check it, and install it to use it.", name, class_names({ v }))
  defences.custom_show(name)
end

-- After a copy registers as svof loads: says if svof's own has changed
-- since it was copied, or isn't in that class any more
function defences.copy_check(name)
  local spec = defences.custom[name]
  local v, i = version_from(name, spec.copy.from)
  if not v then
    svo.echofn("Svof doesn't have %s for %s any more. Your copy of it is still in use. ", name,
      class_names({ { classes = { tostring(spec.copy.from) } } }))
    custom_link("(delete it)", string.format("svo.defences.custom_delete(%q)", name), "Delete your copy of " .. name,
      'remove')
    echo("\n")
    return
  end
  if copy_same(spec.copy.was or {}, v) then return end
  svo.echofn("Svof has updated its own %s since you copied it. Your copy is still in use: ", name)
  custom_link("see Svof's", string.format("svo.defences.copy_offer(%q)", name), "See Svof's own " .. name)
  echo(", ")
  custom_link("copy it again", string.format("svo.defences.copy_own(%q, %d)", name, i), "Copy Svof's own again, to install")
  echo(", ")
  custom_link("keep yours", string.format("svo.defences.copy_keep(%q)", name), "Keep your copy, and stop saying so")
  echo("\n")
end

-- keeps a copy after svof updated its own, and stops saying so
function defences.copy_keep(name)
  local spec = defences.custom[name]
  local v = spec and type(spec.copy) == 'table' and version_from(name, spec.copy.from)
  if not v then return end
  spec.copy.was = copy_was(v)
  defences.custom_save()
  svo.echof("Kept your copy of %s.", name)
end

-- customize for gag
defs['lost_shield'] = function ()
  svo.checkaction(svo.dict.shield.gone, true)
  if actions['shield_gone'] then
    lifevision.add(actions['shield_gone'].p)
  end

  -- local line = getCurrentLine()
  -- selectCurrentLine() replace''
  -- cecho(string.format("<DarkOrange>><red>> <white:sienna>%s<:black> <red><<DarkOrange><", line))
  if selectString(line, 1) ~= -1 then
    replace("")
    cecho(string.format("<DarkOrange>><red>> <white:sienna>%s<:black> <red><<DarkOrange><", line))
  end
end

-- customize for riding_physical
defs['lost_riding'] = function()
  -- force it so unwilling dismount is counted
  svo.checkaction(svo.dict.riding.physical, true)
  if actions['riding_physical'] then
    lifevision.add(actions['riding_physical'].p, 'dismount')
  end
end

defs['block_failed'] = function()
  svo.checkaction(svo.dict.block.physical, true)
  if actions['block_physical'] then
    lifevision.add(actions['block_physical'].p, 'failed')
  end
end

function defs.defprompt()
  svo.show_current_defs()

  -- see if we need to show any additional defences
  local function check_additionals()
    for def, _ in defences.nodef_list:pairs() do
      if defs_data[def] and (defs_data[def].nodef or (defc.dragonform and defs_data[def].type ~= 'dragoncraft' and defs_data[def].type ~= 'general')) then return true end
    end
  end

  if check_additionals() then
    svo.echof("Additional defences:")
    local count = 1
    local marked = {}
    for def, value in defences.nodef_list:pairs() do
      if defs_data[def] and (defs_data[def].nodef or (defc.dragonform and defs_data[def].type ~= 'dragoncraft' and defs_data[def].type ~= 'general')) then
        if value == true then
          decho(defences.withmark(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", sk.desanitize(def)),
            sk.desanitize(def), "<153,204,204>", marked))
        else
          decho(defences.withmark(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", sk.desanitize(def) .. " " .. tostring(value)),
            sk.desanitize(def), "<153,204,204>", marked))
        end

        if count % 3 == 0 then echo("\n") end
        count = count + 1
      end
    end
    echo("\n")
    local key = defences.mark_key(marked, "<153,204,204>")
    if key then decho(key) end

  end
  defences.nodef_list = svo.phpTable()
  defences.def_def_list = {}
  svo.showprompt()
end

function defs.defstart()
  svo.checkaction(svo.dict.defcheck.physical)
  if actions.defcheck_physical then
    deleteLine()

    -- reset parry, as no parry won't show a line
    local t = svo.sps.parry_currently
    for limb, _ in pairs(t) do t[limb] = false end
    svo.check_sp_satisfied()
  end
end

-- last line of 'def' that shows your count
function defs.defline()
  svo.checkaction(svo.dict.defcheck.physical)
  if actions.defcheck_physical then
    deleteLine()
    tempLineTrigger(1, 1, 'selectString(line, 1) replace""')
    lifevision.add(actions.defcheck_physical.p)
  end
end

svo.process_defs = function ()
  local addback = {}

  for defname, _ in pairs(defc) do
    -- clear ones we don't have
    if defc[defname] and not defences.def_def_list[defname] and not (defs_data[defname] and (defs_data[defname].invisibledef or defs_data[defname].custom_def_type)) then
      if svo.dict[defname] and svo.dict[defname].gone then
        svo.checkaction(svo.dict[defname].gone, true)
        lifevision.add(actions[defname..'_gone'].p)
      else
        defences.lost(defname)
      end
    elseif defc[defname] and defences.def_def_list[defname] and not (defs_data[defname] and defs_data[defname].custom_def_type) then -- if we do have it, remove from def list
      addback[defname] = defences.def_def_list[defname]
      defences.def_def_list[defname] = nil
    end
  end

  -- add left over ones. DEF is the game's own list, not svof's command for
  -- any of them finishing, so a balance pairs() happened to pick was
  -- booked for nothing: rebounding's smoke and a puff, blind's herb
  for defname,_ in pairs(defences.def_def_list) do
    defences.confirm(defname)
  end

  for k,v in pairs(addback) do defences.def_def_list[k] = v end


  tempTimer(0, defs.defprompt)
end

-- the groups of defences this class has, in the order the defence lists
-- show them: general, then the class's skillsets in the order svof lists
-- them, then any other by name. pairs() gave an order no one chose
function defences.group_order()
  local order, seen = {}, {}
  local function add(group)
    if defences.def_types[group] and not seen[group] then
      order[#order+1] = group
      seen[group] = true
    end
  end
  add('general')
  for _, skillset in ipairs(svo.knownskills[me.class:lower()] or {}) do add(skillset) end
  local rest = {}
  for group in pairs(defences.def_types) do
    if not seen[group] then rest[#rest+1] = group end
  end
  table.sort(rest)
  for _, group in ipairs(rest) do add(group) end
  return order
end

-- The mark the defence and priority lists put after a defence's name, in
-- a colour of its own: * for one the player defined, + for one of svof's
-- own they changed (the user's choice, 2026-10-10)
defences.mark_colour = "<255,170,0>"
function defences.mark(name)
  if defences.custom_registered[name] then return '*' end
  if defences.own[name] then return '+' end
  return ''
end

-- text with def's mark after def's name, which prefix comes before, then
-- colour again. The mark takes one of the spaces padding a column, so the
-- columns stay. marked notes the marks put, for the key under the list
function defences.withmark(text, def, colour, marked, prefix)
  local mark = defences.mark(def)
  prefix = prefix or "] "
  local at = mark ~= '' and text:find(prefix .. def, 1, true)
  if not at then return text end
  local after = at + #prefix + #def
  local rest = text:sub(after)
  if rest:sub(-1) == " " then rest = rest:sub(1, -2) end
  if marked then marked[mark] = true end
  return text:sub(1, after - 1) .. defences.mark_colour .. mark .. colour .. rest
end

-- what a list's marks mean, for under it, in its colour; nil without any
function defences.mark_key(marked, colour)
  local parts = {}
  if marked['*'] then parts[#parts + 1] = defences.mark_colour .. "*" .. colour .. " you defined it" end
  if marked['+'] then parts[#parts + 1] = defences.mark_colour .. "+" .. colour .. " Svof's own, changed by you" end
  if #parts == 0 then return nil end
  return colour .. table.concat(parts, "   ") .. "   (vcustomdef)\n"
end

-- a link's hint, saying what def's mark means
function defences.markhint(hint, def)
  local mark = defences.mark(def)
  if mark == '*' then return hint .. " (you defined it)" end
  if mark == '+' then return hint .. " (Svof's own, changed by you)" end
  return hint
end

-- prints out a def table
local function show_defs(tbl, linkcommand, cmdname)
  local count = 1
  -- the defence being shown, and the marks shown, for the key
  local current, marked = nil, {}

  local olddechoLink, olddecho = dechoLink, decho
  local function dechoLink(text, command, hint)
    olddechoLink(defences.withmark(text, current, "<153,204,204>", marked), command,
      defences.markhint(hint, current), true)
  end
  local function decho(text)
    olddecho(defences.withmark(text, current, "<153,204,204>", marked))
  end

  local function show_em(skillset, what)
    -- the main list is general's, which vshow hidelist hides as a group too
    local group = sk.ignored_defences[skillset or 'general']
    local hiddengroup = group and group.status
    if skillset and (conf.showhiddendefs or not hiddengroup) then
      svo.echof("%s defences%s:", skillset:title(), hiddengroup and " (hidden)" or "")
    end
    for _,def in ipairs(what) do
      current = def
      local disabled = (hiddengroup and true or (sk.ignored_defences[sk.ignored_defences_map[def]].t[def]))
      -- vconfig showhiddendefs lists them anyway
      if conf.showhiddendefs then disabled = false end

      if not disabled and not tbl[def] and not defences.nodef_list[def] then
        if (count % 3) ~= 0 then
          if not linkcommand or not dechoLink then
            decho(string.format("<153,204,204>[ ] %-23s", def))
          else
            dechoLink(string.format("<153,204,204>[ ] %-23s", def), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Add %s to %s", def, cmdname))
          end
        else
          if not linkcommand or not dechoLink then
            decho(string.format("<153,204,204>[ ] %s", def))
          else
            dechoLink(string.format("<153,204,204>[ ] %s", def), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Add %s to %s", def, cmdname))
          end
        end
      elseif not disabled then
        if (count % 3) ~= 0 then
          if not defs_data[def].mana then
            if type(defences.nodef_list[def]) == 'string' then
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def.." ("..defences.nodef_list[def]..")"))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def.." ("..defences.nodef_list[def]..")"), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
              defences.nodef_list[def] = nil
            elseif type(defences.def_def_list[def]) == 'string' then
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def.." "..defences.def_def_list[def]))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def.." "..defences.def_def_list[def]), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
              defences.nodef_list[def] = nil
            elseif defs_data[def].onshow then
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def.." ("..defs_data[def].onshow()..")"))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def.." ("..defs_data[def].onshow()..")"), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
            else
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
            end
          elseif defs_data[def].mana == 'little' then
            if not linkcommand or not dechoLink then
              decho(string.format("<153,204,204>[<0,0,140>m<153,204,204>] %-23s", def))
            else
              dechoLink(string.format("<153,204,204>[<0,0,140>m<153,204,204>] %-23s", def), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
            end
          else
            if not linkcommand or not dechoLink then
              decho(string.format("<153,204,204>[<0,0,204>M<153,204,204>] %-23s", def))
            else
              dechoLink(string.format("<153,204,204>[<0,0,204>M<153,204,204>] %-23s", def), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
            end
          end
        else
          if not defs_data[def].mana then
            if type(defences.nodef_list[def]) == 'string' then
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %s", def.." ("..defences.nodef_list[def]..")"))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %s", def.." ("..defences.nodef_list[def]..")"), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
              defences.nodef_list[def] = nil
            elseif type(defences.def_def_list[def]) == 'string' then
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] % s", def.." "..defences.def_def_list[def]))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] % s", def.." "..defences.def_def_list[def]), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
              defences.nodef_list[def] = nil
            elseif defs_data[def].onshow then
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %s", def.." ("..defs_data[def].onshow()..")"))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %s", def.." ("..defs_data[def].onshow()..")"), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
            else
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %s", def))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %s", def), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
            end
          elseif defs_data[def].mana == 'little' then
            if not linkcommand or not dechoLink then
              decho(string.format("<153,204,204>[<0,0,140>m<153,204,204>] %s", def))
            else
              dechoLink(string.format("<153,204,204>[<0,0,140>m<153,204,204>] %s", def), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
            end
          else
            if not linkcommand or not dechoLink then
              decho(string.format("<153,204,204>[<0,0,204>M<153,204,204>] %s", def))
            else
              dechoLink(string.format("<153,204,204>[<0,0,204>M<153,204,204>] %s", def), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
            end
          end
        end
      end

      if not disabled and count % 3 == 0 then echo("\n") end
      if not disabled then count = count + 1 end
    end

    if count %3 ~= 1 then echo("\n") end; count = 1
  end

  setFgColor(153,204,204)
  local underline = setUnderline; _G.setUnderline = function () end

  show_em(nil, defences.def_types.general)

  if defc.dragonform then
    show_em('dragoncraft', defences.def_types.dragoncraft)
  else

    for _, skillset in ipairs(defences.group_order()) do
      if skillset ~= 'general' and skillset ~= 'dragoncraft' then show_em (skillset, defences.def_types[skillset]) end
    end
  end

  local key = defences.mark_key(marked, "<153,204,204>")
  if key then olddecho(key) end

  _G.setUnderline = underline
end

function svo.show_current_defs(window)
  svo.echof(window or 'main', "Your current defences (%d):", (function ()
    local count = 0
    for _,v in pairs(defc) do if v then count = count + 1 end end
    for _,v in defences.nodef_list:pairs() do
      if v then count = count + 1 end end
    return count
  end)())
	
  if not window then
    show_defs(defc)
  else
    sk.echofwindow = window
    local olddecho, oldecho = decho, echo
    _G.decho, _G.echo = svo.ofs.windowdecho, svo.ofs.windowecho

    show_defs(defc)

    _G.decho, _G.echo = olddecho, oldecho
  end
end

function svo.show_defup()
  svo.echof("%s defup defences (click to toggle):", defs.mode:title())
  show_defs(defdefup[defs.mode], "svo.defs.defup", 'defup')
  svo.showprompt()
end

function svo.show_keepup()
  if not conf.serverside then
    svo.echof("%s keepup defences (click to toggle):", defs.mode:title())
  else
    svo.echofn("%s keepup defences (click to toggle) (", defs.mode:title())

    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true)
    echoLink("view serverside keepup", [[send'CURING PRIORITY DEFENCE LIST']], "Click to view serverside's keepup list - which'll be the same as Svof's", true)
    setUnderline(false)
    echo(")\n")
  end
  show_defs(defkeepup[defs.mode], "svo.defs.keepup", 'keepup')
  svo.showprompt()
end

-- can't just check if we need and don't have, because some might have conflicts.
-- hence, just check isadvisable; this checks it for us and skips conflicts.
-- check have defup on prompt so it's not called many times.
function sk.have_defup_defs()
  local waitingon = {}
  for def,deft in defs_data:iter() do
    if defdefup[defs.mode][def] and not defc[def]
     -- if we have to skip it
    and not ((deft.specialskip and deft.specialskip())
     -- or if it's ignored
    or svo.ignore[def]
      -- or it's not a general or dragon defence and we're in dragon
    or (defc.dragonform and not (deft.type == 'general' or deft.type == 'dragoncraft'))) and not deft.nodef then
      if svo.dict[def] then
        if svo.dict[def].physical and not svo.dict_balanceful_def[def] and not svo.dict_balanceless_def[def] then
          waitingon[#waitingon+1] = string.format("%s (?)", def)
        else
          waitingon[#waitingon+1] = def
        end
      else
        waitingon[#waitingon+1] = string.format("%s (?)", def)
      end
    end
  end

  -- sort them according to aspriority
  table.sort(waitingon,
    function(a,b)
      if svo.dict[a] and svo.dict[b] and svo.dict[a].physical and svo.dict[b].physical then
        return svo.dict[a].physical.aspriority > svo.dict[b].physical.aspriority
      end
    end)

  if #waitingon > 0 then return false, waitingon
  else return true end
end;

-- Hiding a defence takes it off defup and keepup in every mode, so svof
-- doesn't raise what the lists don't show (the user's choice, 2026-10-10).
-- Says what it took off, with a link, undo, that shows it and puts it all
-- back.
local function takeoff_hidden(undo, names)
  local off, back = {}, { undo }
  for _, def in ipairs(names) do
    local where = {}
    for _, list in ipairs({ { defdefup, 'defup' }, { defkeepup, 'keepup' } }) do
      for mode, t in pairs(list[1]) do
        if t[def] then
          defs[list[2]](def, false, mode)
          where[#where+1] = mode .. " " .. list[2]
          back[#back+1] = string.format("svo.defs.%s(%q, true, %q)", list[2], def, mode)
        end
      end
    end
    if #where > 0 then
      table.sort(where)
      off[#off+1] = string.format("%s (%s)", def, table.concat(where, ", "))
    end
  end
  if #off == 0 then return end
  svo.echofn("Took %s off, so Svof doesn't raise what it hides. ", svo.concatand(off))
  setUnderline(true)
  echoLink("(undo)", table.concat(back, " "), "Show it again and put it all back", true)
  setUnderline(false)
  echo("\n")
end

-- the defences in group: this class's, or for a group it doesn't have,
-- every class's from the catalog
local function hide_group_names(group)
  local names = {}
  if defences.def_types[group] then
    for _, def in ipairs(defences.def_types[group]) do names[#names+1] = def end
  else
    for name, versions in pairs(defences.catalog()) do
      for _, v in ipairs(versions) do
        if v.type == group then names[#names+1] = name break end
      end
    end
  end
  table.sort(names)
  return names
end

-- whether group is a skillset or group of defences: this class's, or any
-- class's svof knows
local function is_hide_group(group)
  if sk.ignored_defences[group] or defences.def_types[group] then return true end
  for _, skills in pairs(svo.knownskills) do
    if table.contains(skills, group) then return true end
  end
  return false
end

-- what hiding name means: { group } for a skillset, or the groups a
-- defence is in, as { group, def }: this class's group if it has the
-- defence, or every other class's it's in
local function hide_targets(name)
  name = name:lower()
  if is_hide_group(name) then return { { name } } end
  local rec = defs_data[name]
  if rec and rec.type then return { { rec.type, name } } end
  local targets, seen = {}, {}
  for _, v in ipairs(defences.catalog()[name] or {}) do
    if v.type and not seen[v.type] then
      seen[v.type] = true
      targets[#targets+1] = { v.type, name }
    end
  end
  -- a defence a class had before, such as one defined there
  if #targets == 0 then
    for group, g in pairs(sk.ignored_defences) do
      if g.t[name] ~= nil then targets[#targets+1] = { group, name } end
    end
    table.sort(targets, function (a, b) return a[1] < b[1] end)
  end
  return targets
end

-- Hides def in group, or the whole group without def, or shows it again;
-- what's hidden is kept for a group or class this one doesn't have, for
-- when you change to it. show, if given, runs before hiding takes the
-- defences off defup and keepup, so that comes under the list
function defences.set_hidden(group, def, status, show)
  status = status and true or false
  local g = sk.ignored_defences[group]
  if not g then
    g = { status = false, t = {} }
    sk.ignored_defences[group] = g
  end
  if def then g.t[def] = status else g.status = status end
  if show then show() end
  if status then
    takeoff_hidden(def and string.format("svo.defences.set_hidden(%q, %q, false)", group, def)
      or string.format("svo.defences.set_hidden(%q, nil, false)", group), def and { def } or hide_group_names(group))
  end
end

-- the hide list's links: hide or show one, then the list again
function defences.hide_click(group, def, status, all)
  defences.set_hidden(group, def, status, function () svo.showhidelist(all) end)
end

-- vshow hide <name> and vshow unhide <name>, for the command line
function defences.hide_command(verb, name)
  local status = verb == 'hide'
  name = (name or ''):match("^%s*(.-)%s*$")
  if name == '' then
    svo.echof("vshow %s takes a skillset or a defence, such as vshow %s tekura or vshow %s rebounding.", verb, verb, verb)
    return
  end
  local targets = hide_targets(name)
  if #targets == 0 then
    svo.echof("Svof doesn't know a skillset or defence called %s. vshow hidelist all lists every class's.", name:lower())
    return
  end
  local where = {}
  for _, t in ipairs(targets) do
    if t[2] then where[#where+1] = t[1] end
  end
  if targets[1][2] then
    svo.echof("%s %s, in %s, %s the defence lists.", status and "Hid" or "Showed", targets[1][2],
      svo.concatand(where), status and "from" or "in")
  else
    svo.echof("%s %s, the whole skillset, %s the defence lists.", status and "Hid" or "Showed", targets[1][1],
      status and "from" or "in")
  end
  for _, t in ipairs(targets) do defences.set_hidden(t[1], t[2], status) end
end

-- the hide list's own vocabulary, kept for scripts and links from before:
-- hides or shows a skillset or defence, as vshow hide does
function svo.ignoreskill(skill, newstatus)
  local targets = hide_targets(skill)
  if #targets == 0 then return end
  local shown = false
  for _, t in ipairs(targets) do
    defences.set_hidden(t[1], t[2], newstatus, not shown and function () svo.showhidelist() end or nil)
    shown = true
  end
end

-- vshow hidelist [all]: every skillset and defence of this class, or with
-- all every class's, each a link to hide it from the defence lists or
-- show it again, and the commands that do the same
function svo.showhidelist(all)
  all = all and true or false
  local enabled_c, disabled_c = "<242,218,218>", "<128,128,128>"
  -- the marks shown, for the key under the list
  local marked = {}

  local function show_em(name, names, whose)
    local what = sk.ignored_defences[name] or { status = false, t = {} }
    decho(string.format("%s%s%s defences%s: ", what.status and disabled_c or enabled_c, name:title(), whose or "",
      what.status and " (hidden)" or ""))
    setUnderline(true)
    echoLink(what.status and "show them" or "hide them",
      string.format("svo.defences.hide_click(%q, nil, %s, %s)", name, tostring(not what.status), tostring(all)),
      (what.status and "Show " or "Hide ") .. name .. " in the defence lists", true)
    setUnderline(false)
    echo("\n")
    for i, def in ipairs(names) do
      local hidden = what.t[def] and true or false
      local colour = (what.status or hidden) and disabled_c or enabled_c
      if i % 3 == 1 then echo("  ") end
      -- the link is the name and its mark, the padding after it plain
      local mark = defences.mark(def)
      dechoLink(defences.withmark(colour .. def .. (mark ~= '' and " " or ""), def, colour, marked, colour), string.format("svo.defences.hide_click(%q, %q, %s, %s)",
        name, def, tostring(not hidden), tostring(all)), (hidden and "Show " or "Hide ") .. def .. " in the defence lists"
        .. (what.status and " (its skillset is hidden, though)" or ""), true)
      if i % 3 == 0 or i == #names then
        echo("\n")
      else
        echo(string.rep(" ", math.max(1, 24 - #def - #mark)))
      end
    end
  end

  svo.echof("Click a skillset or defence to hide it from the defence lists, or to show it again. Grey ones are hidden:")
  -- this class's groups, in order, with its own defences in each; the list
  -- keeps other classes' too, for when you change to one
  local here = {}
  for _, group in ipairs(defences.group_order()) do
    here[group] = true
    local names = {}
    for _, def in ipairs(defences.def_types[group] or {}) do names[#names+1] = def end
    table.sort(names)
    show_em(group, names)
  end
  if all then
    local others = {}
    for _, versions in pairs(defences.catalog()) do
      for _, v in ipairs(versions) do
        if v.type and not here[v.type] then here[v.type] = true others[#others+1] = v.type end
      end
    end
    table.sort(others)
    for _, group in ipairs(others) do
      local classes = skillset_classes(group)
      show_em(group, hide_group_names(group), #classes > 0 and (" (" .. table.concat(classes, ", ") .. ")") or nil)
    end
  end
  local key = defences.mark_key(marked, enabled_c)
  if key then decho("  " .. key) end

  custom_separator()
  -- hiding one takes it off defup and keepup; vconfig showhiddendefs
  -- lists hidden ones anyway, to see what's there
  svo.echofn("Hiding a defence takes it off defup and keepup. ")
  setUnderline(true)
  echoLink(conf.showhiddendefs and "Leave them out of the defence lists" or "Show them in the defence lists anyway",
    string.format("svo.config.set('showhiddendefs', %s, true)", conf.showhiddendefs and "false" or "true"),
    "vconfig showhiddendefs", true)
  setUnderline(false)
  echo("\n")
  svo.echof("Or type vshow hide <skillset or defence> to hide one, and vshow unhide <skillset or defence> to show it again.")
  echo("  ")
  setUnderline(true)
  if all then
    echoLink("show only " .. class_title(me.class) .. "'s skillsets", "svo.showhidelist()",
      "List your class's skillsets (vshow hidelist)", true)
  else
    echoLink("show every class's skillsets", "svo.showhidelist(true)",
      "List every class's skillsets, to hide one or its defences (vshow hidelist all)", true)
  end
  setUnderline(false)
  echo("\n")
end

end -- end of svo defences loader

if svo.systemloaded then svo.loader.defences() end