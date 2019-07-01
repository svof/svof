-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

pl.dir.makepath(getMudletHomeDir() .. "/svo/defup+keepup")

--[[ a small dictionary to know which defences belong to which skillset ]]
defences.def_types = {}

-- the list from 'def'
defences.def_def_list = {}
defences.defup_timer = createStopWatch()

function defences.gettime(defence, max)
  if not defc[defence] then return "" end

  local time = max-math.ceil(getStopWatchTime(dict[defence].stopwatch)/max)
  if time < 0 then return "" else
    return time.."m"
  end
end

-- functions to handle the defc table events updates
function defences.got(def)
  if not defc[def] then defc[def] = true; raiseEvent("svo got def", def) end
end

function defences.lost(def)
  if defc[def] then defc[def] = false; raiseEvent("svo lost def", def) end
end

-- custom def types like channels
defences.custom_types = {}

defences.nodef_list = phpTable()

defdefup = {
  basic  = {},
  combat = {},
  empty  = {},
}

defkeepup = {
  basic  = {},
  combat = {},
  empty  = {},
}

-- set an initial mode to something, as it always needs to be a valid mode
defs.mode = "basic"

-- defc = current defs

-- specialskip: if this function returns true, that defence will be ignored for defup
defs_data = pl.OrderedMap {}
  defs_data:set("softfocus", { type = "general",
    mana = "lots",
    def = "You have softened the focus of your eyes.",
    on = {"You let your eyes go out of focus, causing you to miss some details.", "Your eyes are already out of focus."},
    off = {"You bring your eyes back into focus.", "Your eyes are already in focus."}})
  defs_data:set("metawake", { type = "general",
    def = "You are concentrating on maintaining distance from the dreamworld.",
    mana = "lots",
    on = {"You order your mind to ensure you will not journey far into the dreamworld.", "You already have metawake turned on."},
    off = {"You cease concentrating on maintaining distance from the dreamworld.", "You already have metawake turned off."}})
  defs_data:set("mass", { type = "general",
    def = "You are extremely heavy and difficult to move.",
    offr = {[[^You are pulled out of the room by \w+ and (?:his|her) whip\!$]],
            [[^A large handaxe comes flying into the room, arcs toward you, and carries you away with it to \w+!$]]},
    off = {"You feel your density return to normal.", "The savage winds pick you up and toss you through the air."}})
  defs_data:set("magicresist", { type = "general",
    on_only = "That resistance already suffuses your form.",
    def = "You are enchanted against magic damage."})
  defs_data:set("fireresist", { type = "general",
    on_only = "That resistance already suffuses your form.",
    def = "You are enchanted against fire damage."})
  defs_data:set("electricresist", { type = "general",
    on_only = "That resistance already suffuses your form.",
    def = "You are enchanted against electric damage."})
  defs_data:set("coldresist", { type = "general",
    on_only = "That resistance already suffuses your form.",
    def = "You are enchanted against cold damage."})
  defs_data:set("skywatch", { type = "general",
    mana = "little",
    def = "You are aware of movement in the skies.",
    on = {"You are now watching the skies.", "You are already watching the skies."},
    off = "You are no longer watching the skies."})
  defs_data:set("toughness", { nodef = true,
    def = "Your skin is toughened." })
  defs_data:set("chivalry defended", { nodef = true,
    def = "You are being defended by a stalwart ally." })
  defs_data:set("waterbubble", { type = "general",
    def = "You are surrounded by a pocket of air."})
  defs_data:set("resistance", { nodef = true,
    def = "You are resisting magical damage."})
#if not skills.alchemy then
  defs_data:set("empower", { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    on = "You are already empowered by astronomical energies.",
    defr = [[^You are resonating with (?:the )?(?:Nebula )?(\w+)'s energy\.$]]})
#end
#if not skills.elementalism then
  defs_data:set("reflection", { nodef = true,
    def = "You are surrounded by one reflection of yourself.",
    defr = [[^You are surrounded by \d+ reflections? of yourself\.$]]})
#end
  defs_data:set("shipwarning", { nodef = true,
    def = "You are aware of all nearby ship movements."})
  defs_data:set("constitution", { nodef = true,
    def = "You are using your superior constitution to prevent nausea." })
  defs_data:set("preaching", { nodef = true,
    def = "You have accepted a blessing for aid in times of need." })
  defs_data:set("frostblessing", { nodef = true,
    def = "You are protected by the power of a Frost Spiritshield."})
  defs_data:set("willpowerblessing", { nodef = true,
    def = "You are regenerating willpower at an increased rate."})
  defs_data:set("thermalblessing", { nodef = true,
    def = "You are protected by the power of a Thermal Spiritshield."})
  defs_data:set("earthblessing", { nodef = true,
    def = "You are protected by the power of an Earth Spiritshield."})
#if not skills.groves then
  defs_data:set("harmony", { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are under the blessing of the (\w+) environment\.$]]})
#end
  defs_data:set("enduranceblessing", { nodef = true,
    def = "You are regenerating endurance at an increased rate.",})
  defs_data:set("thirdeye", { type = "general", def = "You possess the sight of the third eye.",
    on = {"You now possess the gift of the third eye.", "You already possess the thirdeye.", "You already possess the gift of the third eye."}})
  defs_data:set("treewatch", { type = "general",
    mana = "little",
    def = "You are watching the trees or rigging above for signs of movement.",
    on = {"You begin to keep a watchful eye on the treeline.", "You begin to keep a watchful eye on the rigging."},
    off = "You cease to watch the treeline."})
  defs_data:set("groundwatch", { type = "general",
    mana = "little",
    def = "You are aware of movement on the ground.",
    on = {"You begin to keep a watchful eye on the ground below.", "You are already keeping a watchful eye on the ground."},
    off = "You cease keeping a watchful eye on the ground below."})
  defs_data:set("alertness", { type = "general",
    mana = "little",
    def = "Your senses are attuned to nearby movement.",
    on = {"You prick up your ears.", "Alertness is already on!", "Your sense of hearing is already heightened."},
    off = {"You cease your watchful alertness.", "Alertness is already off!"}})
  defs_data:set("curseward", { type = "general",
    def = "A curseward has been established about your person.",
    off = "Your curseward has been breached!",
    on = {"You bring a curseward into being to protect you from harm.", "You already have curseward up."}})
  defs_data:set("bell", { type = "general",
    on = {"You will now attempt to detect attempts to spy on your person.", "You touch the bell tattoo."},
    def = "You are protected by the bell tattoo."})
  defs_data:set("cloak", { type = "general",
    on = {"You caress the tattoo and immediately you feel a cloak of protection surround you.", "You are already protected by the cloak tattoo."},
    def = "You are surrounded by a cloak of protection."})
  defs_data:set("favour", { nodef = true,
    ondef = function () return string.format("(%s by %s, %sh)",matches[2],matches[3], matches[4]) end,
    defr = [[^You are (\w+)favoured by (\w+) for over \d+ Achaean month \(which is about (\d+) hours?\)$]] })
  defs_data:set("telesense", { type = "general",
    mana = "little",
    def = "You are attuned to local telepathic interference.",
    on = {"You attune your mind to local telepathic interference.", "Your mind is already attuned to local telepathic interference."},
    off = {"Your mind is no longer concentrating on telepathic interference.", "Your mind is already not attuned to local telepathic interference."}})
  defs_data:set("hypersight", { type = "general",
    mana = "little",
    def = "You are utilising hypersight.",
    on = {"You concentrate your mind and engage your ability of hypersight.", "You are already concentrating on hypersight."},
    off = {"You cease to concentrate on hypersight.", "You are already not concentrating on hypersight."}})
  defs_data:set("parry", { nodef = true,
    ondef = function ()
      local t = sps.parry_currently
      for limb, _ in pairs(t) do t[limb] = false end
      t[matches[2]] = true
      check_sp_satisfied()

      return "("..matches[2]..")"
    end,
    tooltip = "Completely blocks health and wound damage on a limb if you aren't hindered.",
    defr = [[^You will attempt to parry attacks to your (.+)\.$]]
  })

  defs_data:set("nightsight", { type = "general",
    def = "Your vision is heightened to see in the dark.",
    on = {"Your vision sharpens with light as you gain night sight.", "Your eyes already have the benefit of night sight."},
    off = {"Your eyes lose the benefit of night sight.", "Your eyes cannot lose the benefit of night sight, since they do not already have it!"}})
  defs_data:set("block", { type = "general",
    specialskip = function ()
      return (not sys.enabledgmcp) or not (gmcp.Room and gmcp.Room.Info.exits[conf.blockingdir])
    end,
    ondef = function ()
      dict.block.physical.blockingdir = sk.anytoshort(matches[2])
      return "("..dict.block.physical.blockingdir..")"
    end,
    defr = [[^You are blocking the exit (.+)\.$]],
    off = {"You stop blocking.", "You were not blocking.", "You cease blocking the exit.", "You begin to flap your wings powerfully, and rise quickly up into the firmament."},
    })
  defs_data:set("targetting", { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    tooltip = "Focuses hits on the targetted limb.",
    defr = [[^You are aiming your attacks to the (.+)\.$]]
  })
  defs_data:set("breath", { type = "general",
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].meditate then
        svo["def"..whereto][mode].meditate = false
        if echoback then echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].dilation then
        svo["def"..whereto][mode].dilation = false
        if echoback then echof("Removed dilation from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].flame then
        svo["def"..whereto][mode].flame = false
        if echoback then echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].lyre then
        svo["def"..whereto][mode].lyre = false
        if echoback then echof("Removed lyre from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end}) -- added in xml w/ conf.gagbreath
  defs_data:set("vigilance", { type = "general",
    on = {"You squint your eyes, more alert to potential danger.", "You are already vigilant."},
    mana = "little",
    def = "You are vigilantly watching for potential danger.",
    off = {"You relax your vigilance.", "You are not maintaining vigilance."}})
  defs_data:set("satiation", { type = "general",
    invisibledef = true,
    on = {"You begin concentrating on efficient digestion.", "You are already concentrating on efficient digestion."},
    off = "Your digestive efficiency returns to normal."})
  defs_data:set("clinging", { type = "general",
    on = {"You begin to use your entire body to cleverly cling to the branches of the tree while still maintaining a great deal of freedom of action.","You are already clinging to the trees.", "You must be in the trees to cling to branches, or in the rigging of a ship to cling to the ropes."},
    off = "You cease your clinging behaviour and release the tree.",
    def = {"You are clinging tightly to the trees.", "You are clinging tightly to a ship's rigging."}})
  defs_data:set("selfishness", { type = "general", def = "You are feeling quite selfish.",
    onenable = function (mode, newdef, whereto, echoback)
      if conf.serverside and svo.serverignore.selfishness then
        svo.serverignore.selfishness = nil
        echof("Setting Selfishness to be handled by Svof - serverside can't auto-generosity.")
      end

      return true
    end,
    on = {"You rub your hands together greedily.", "You already are a selfish bastard."},
    off = {"A feeling of generosity spreads throughout you.", "No worries. You're not a selfish bastard as is."}})
  defs_data:set("flying", { nodef = true,
    def = "You are soaring high above the ground." })
  defs_data:set("starburst", { nodef = true,
    def = "You are walking with the grace of the stars." })
  defs_data:set("chameleon", { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are assuming the identity of (\w+)\.$]]})
  defs_data:set("insomnia", { type = "general",
    def = "You have insomnia, and cannot easily go to sleep.",
    -- insomnia curing it is done in trigs as well
    -- "Your insomnia has cleared up.": done in triggers for loki
  })
  defs_data:set("kola", { type = "general",
    def = "You are feeling extremely energetic." })
  defs_data:set("extra crits", { nodef = true,
    def = "You are surrounded by a lucky green aura."})
  defs_data:set("rebounding", { type = "general",
    def = "You are protected from hand-held weapons with an aura of rebounding.",
    off = {"Your defensive barriers disappear.", "Your aura of weapons rebounding disappears.", "A small brown lemming rips apart your aura of rebounding defence with its claws.", "The vines rip apart the aura of rebounding surrounding you."},
    offr = {[[^\w+'s cantata shatters the defences surrounding you\.$]], [[^\w+ delivers a single, powerful blow to the aura of rebounding surrounding you, shattering it\.$]], [[^\w+ brings .+? down in a single diagonal stroke, carving cleanly through your aura of rebounding\.$]], [[^\w+ whirls .+? over (?:her|his) head, before bringing it down upon your aura of rebounding, shattering it instantly\.$]], [[^The point of .+? strikes your aura of rebounding, and rapid cracks begin to spread outward from the point of impact\. Moments later, the protection shatters\.$]]}})
  defs_data:set("blind", { type = "general",
    def = "You are blind." })
  defs_data:set("xpboost", { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are experiencing a (\d+) percent experience boost\.$]] })
  defs_data:set("xpbonus", { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = {[[^You are benefitt?ing from a (\d+)% experience bonus\.$]], [[^You are benefitting from a (\d+)% bonus to experience gain\.$]] }})
  defs_data:set("deaf", { type = "general",
    def = "You are deaf.",
    off = "The unnatural sound rips through your defences against auditory attacks." })
  defs_data:set("xp gain", { nodef = true,
    def = "You are surrounded by a vibrant white aura." })
  defs_data:set("myrrh", { type = "general",
    def = "Your mind is racing with enhanced speed." })
  defs_data:set("deathsight", { type = "general",
    def = "Your mind has been attuned to the realm of Death.",
    on = {"Your mind is already attuned to the realm of Death.", "You shut your eyes and concentrate on the Soulrealms. A moment later, you feel inextricably linked with the realm of Death."},
    onr = "^A miasma of darkness passes over your eyes and you feel a link to the realm of Death,? form in your mind\.$",
    off = {"You relax your link with the realm of Death.", "You are not linked with the realm of Death."}})
  defs_data:set("mindseye", { type = "general",
    on = {"Touching the mindseye tattoo, your senses are suddenly heightened.", "You already possess the mindseye defence."},
    def = "Your senses are magically heightened."})
  defs_data:set("lyre", { type = "general",
    specialskip = function() return not conf.lyre end,
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].meditate then
        svo["def"..whereto][mode].meditate = false
        if echoback then echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].breath then
        svo["def"..whereto][mode].breath = false
        if echoback then echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].dilation then
        svo["def"..whereto][mode].dilation = false
        if echoback then echof("Removed dilation from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = "You deftly shape the wall of light into a barrier surrounding yourself.",
    onr = [[^You strum .+, and a prismatic barrier forms around you\.$]],
    def = "You are standing within a prismatic barrier.",
    off = {"Your prismatic barrier dissolves into nothing.", "The stream hits your prismatic barrier, shattering it.", "The breath weapon rips apart your prismatic barrier.", "The breath weapon rips through both your shield and prismatic barrier.", "The spear shatters your prismatic barrier."}})
  defs_data:set("speed", { type = "general",
    def = "Your sense of time is heightened, and your reactions are speeded."})
  defs_data:set("frost", { type = "general", def = "You are tempered against fire damage.",
    on = "A chill runs over your icy skin.",
    off = "Forks of flame lick against your skin, melting away your protection against fire."})
  defs_data:set("venom", { type = "general", def = "Your resistance to damage by poison has been increased.",
    on = "You feel a momentary dizziness as your resistance to damage by poison increases."})
  defs_data:set("levitation", { type = "general", def = "You are walking on a small cushion of air.",
    on = {"Your body begins to feel lighter and you feel that you are floating slightly.", "Your body grows light and buoyant as you touch the feather tattoo, and you begin hovering above the ground."}})
  defs_data:set("caloric", { type = "general",
    def = "You are coated in an insulating unguent."})
  defs_data:set("sileris", { type = "general",
    def = "You are protected from the fangs of serpents."})
  defs_data:set("chargeshield", { nodef = true,
    def = "You are surrounded by a non-conducting chargeshield."})
  defs_data:set("meditate", { type = "general",
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].breath then
        svo["def"..whereto][mode].breath = false
        if echoback then echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].dilation then
        svo["def"..whereto][mode].dilation = false
        if echoback then echof("Removed dilation from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].flame then
        svo["def"..whereto][mode].flame = false
        if echoback then echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].lyre then
        svo["def"..whereto][mode].lyre = false
        if echoback then echof("Removed lyre from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = "You close your eyes, bow your head, and empty your mind of all thought.",
    off = {"You snap your head up as you break your meditation.", "You cease your meditation having achieved full will and mana."}})
  defs_data:set("shield", { type = "general",
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
        [[^\w+ continues (?:his|her) assault, coming around for a second blow that scythes straight through your magical shield\.$]],
        [[^\w+ brings .+? down in a single diagonal stroke, carving cleanly through your magical shield\.$]],
        [[^\w+ continues (?:his|his) attack, coming back around with a bone rattling blow with .+? that causes your magical shield to explode in a shower of twinkling shards\.$]],
        [[^\w+ whirls .+ over (?:her|his) head, before bringing it down upon your magical shield, shattering it instantly\.$]],
        [[^\w+ summons a blade of condensed air and shears cleanly through the magical shield surrounding you\.$]],
        [[^The shadow of \w+ suddenly comes alive, leaping forward to hammer at your shield in a silent frenzy of blows\. Your protection lasts mere moments before exploding in a shower of prismatic shards\.$]],
    },
    def = "You are surrounded by a nearly invisible magical shield."})
  defs_data:set("riding", { type = "general",
    specialskip = function() return defc.dragonform end,
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
    offr = {[[^You step down off of .+\.$]], [[^You lose purchase on .+\.$]], [[^\w+ waves (?:his|her) palm in your direction, and you can only watch as your surroundings dissolve and fade from existence\.$]], [[^You feel your blessed soul drawn toward \w+ as you are delivered out of harm's way\.$]], [[^\w+ steps into the attack, grabs your arm, and throws you violently to the ground\.$]], [[^You feel a strong tug in the pit of your stomach\. Your surroundings dissolve into the featureless swirl of the ether, resolving once more into a recognisable landscape as you land before \w+\.$]]},
    off = {"You are not currently riding anything.", "You are not currently riding that.", "You must be mounted to trample.", "You are thrown from the room by the sheer force of the fiery blast.", "You're drawn screaming into its hellish maw.", "The ring of shining metal carries you up into the skies.", "You clamber off of your mount.","You need to be riding a proper mount to gallop.",
#if skills.necromancy then
          "You call upon your dark power, and instantly a black wind descends upon you. In seconds your body begins to dissipate, and you are one with the odious vapour.",
#end
#if skills.tarot then
          "You vaguely make out a large, square doorway of light and you step through it.",
#end
    }})

#if not skills.groves then
  defs_data:set("grove vigour", { nodef = true,
    def = "You are bathed in an aura of radiant sunlight."})
#end

-- Dragoncraft: everyone gets it
  defs_data:set("dragonform", { type = "dragoncraft",
    offline_defence = true,
    invisibledef = true,
    stays_on_death = true,
    on = "You already maintain the form of the Dragon.",
    off = "Your draconic form melts away, leaving you suddenly weaker and more vulnerable." })
  defs_data:set("dragonarmour", { type = "dragoncraft",
    specialskip = function() return not defc.dragonform end,
    def = "You are surrounded by draconic armour.",
    off = "You relax your draconic armour.",
    on = {"With a low rumbling from deep within your belly, you beseech Ashaxei for protection. Your skin ripples as a web of crackling magical energy dances like fire across its surface, settling to solidify into a flexible, translucent shell.", "You are already surrounded by draconic armour, Wyrm."}})
  defs_data:set("dragonbreath", { type = "dragoncraft",
    specialskip = function() return not defc.dragonform end,
    def = "You have summoned your draconic breath weapon.",
    off = {"You have not summoned your breath weapon.", "As the strain on your inflated lungs reaches extremity, you open your glistening, tooth-lined maw wide and rain a great tempest of venom down upon the ground below."},
    offr = {[[^As the strain on your inflated lungs reaches extremity, you open your glistening, tooth-lined maw wide and rain .+]], [[^Focusing your breath into a concentrated stream, you direct a blast of]], [[^Opening your great maw, you unleash an overpowering blast of flesh-searing lightning at .+, whose body goes rigid as s?he screams in agony\.$]], [[^Opening your dragon's mouth to its fullest, you blast .+ with your toxic wrath, damaging (?:her|his) very essence\.$]], [[^Opening your massive maw, you throw your head forward and blast wave after wave of deadly, all-consuming cold at .+\.$]], [[^Opening your maw, you force out a tremendous stream of acid, blasting the flesh from the very bones of .+\.$]], [[^Drawing a mighty breath to fill your lungs, you crane your neck backwards and send a screaming volley of \w+-infused vapour into the air\.$]], [[^You rear back your head, and with a keening roar unleash incandescent hell upon]], [[^With a roar of triumph, you unleash a cataclysm of crushing psi energy, laying waste to .+'s mind\.]], [[^Summoning a torpid cloud of \w+ deep within your belly, you expel your breath toward]] }})

#if skills.necromancy then
  defs_data:set("deathsight", { type = "necromancy",
    staysindragon = true,
    availableindragon = true,
    def = "Your mind has been attuned to the realm of Death.",
    on = {"Your mind is already attuned to the realm of Death.", "You shut your eyes and concentrate on the Soulrealms. A moment later, you feel inextricably linked with realm of Death."},
    onr = "^A miasma of darkness passes over your eyes and you feel a link to the realm of Death,? form in your mind\.$",
    off = {"You relax your link with the realm of Death.", "You are not linked with the realm of Death."}})
  defs_data:set("soulcage", { type = "necromancy",
    staysindragon = true,
    offline_defence = true,
    on = {"Your soul is already protected by the soulcage.", "You lower the barrier between your spirit and the soulcage.", "You begin to spin a web of necromantic power about your soul, drawing on your vast reserves of life essence. Moment by moment the bonds grow stronger, until your labours are complete. Your soul is entirely safe from harm, fortified in a cage of immortal power."},
    off = {"You have not caged your soul in life essence.", "You carefully raise a barrier between your spirit and the soulcage.", "As you feel the last remnants of strength ebb from your tormented body, you close your eyes and let darkness embrace you. Suddenly, you feel your consciousness wrenched from its pitiful mortal frame and your soul is free. You feel your form shifting, warping and changing as you whirl and spiral outward, ever outward. A jolt of sensation awakens you, and you open your eyes tentatively to find yourself trapped within a physical body once more."},
    onr = [[^You may not use soulcage for another \d+ Achaean day\(s\)\.$]],
    def = "Your being is protected by the soulcage."})
  defs_data:set("deathaura", { type = "necromancy",
    on = {"You let the blackness of your soul pour forth.", "You already possess an aura of death."},
    def = "You are emanating an aura of death.",
    off = "Your aura of death has worn off."})
  defs_data:set("shroud", { type = "necromancy",
    on = {"Calling on your dark power, you draw a thick shroud of concealment about yourself to cover your every action.", "You draw a Shadowcloak about you and blend into your surroundings.", "You draw a cloak of the Blood Maiden about you and blend into your surroundings."},
    def = "Your actions are cloaked in secrecy.",
    off = {"Your shroud dissipates and you return to the realm of perception.", "The flash of light illuminates you - you have been discovered!"}})
  defs_data:set("lifevision", { type = "necromancy",
    on = {"You narrow your eyes and blink rapidly, enhancing your vision to seek out sources of lifeforce in others.", "You already possess enhanced vision."},
    def = "You have enhanced your vision to be able to see traces of lifeforce."})
  defs_data:set("putrefaction", { type = "necromancy",
    on = {"You concentrate for a moment and your flesh begins to dissolve away, becoming slimy and wet.", "You have already melted your flesh. Why do it again?"},
    def = "You are bathed in the glorious protection of decaying flesh.",
    off = "You concentrate briefly and your flesh is once again solid."})
  defs_data:set("vengeance", { type = "necromancy",
    staysindragon = true,
    offline_defence = true,
    on = {"You swear to yourself that you will wreak vengeance on your slayer.", "Vengeance already burns within your heart, Necromancer."},
    def = "You have sworn vengeance upon those who would slay you.",
    off = {"You forswear your previous oath for vengeance, sudden forgiveness entering your heart.", "You have sworn vengeance against none, Necromancer."}})
#end

#if skills.chivalry then
  defs_data:set("weathering", { type = "chivalry",
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set("fury", { type = "chivalry",
    on = {"Your eyes rage with fury.", "You're already raged with fury!", "Too much fury in a day is unhealthy!"},
    off = {"You suddenly lose the fury in your eyes.", "You are already calm and not feeling any fury."},
    def = "Fury rages in your eyes."})
  defs_data:set("sturdiness", { type = "chivalry",
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you."})
  defs_data:set("grip", { type = "chivalry",
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set("mastery", { type = "chivalry",
    on = {"You have begun exercising true mastery of the blades through superior concentration.", "You already have mastery on."},
    def = "You are concentrating on mastery of bladecraft.",
    off = "You relax your mastery of the blades a bit, finding it too taxing to maintain."})
  defs_data:set("resistance", { type = "chivalry",
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
#end

#if skills.evileye then
  defs_data:set("truestare", { type = "evileye",
    on = {"A sharp pain spikes through your skull, before settling into a dull throbbing just behind your eyes.", "You are already enhancing your ocular prowess. Lost: Your truestare defence erodes away."},
    def = "You are enhancing your ocular prowess."})
#end

#if skills.weaponmastery then
  defs_data:set("deflect", { type = "weaponmastery",
    on = "You will now attempt to deflect arrows toward less vital areas.",
    def = "You are attempting to deflect arrows toward less vital areas."})
#end

#if skills.shindo then
  defs_data:set("weathering", { type = "shindo",
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set("sturdiness", { type = "shindo",
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you." })
  defs_data:set("toughness", { type = "shindo",
    def = "Your skin is toughened.",
    on = "Flexing your muscles, you concentrate on forcing unnatural toughness over the surface of your skin."})
  defs_data:set("clarity", { type = "shindo",
    on = {"You are already concentrating on a clearer awareness of your environs.", "As you focus upon your visual field, the shadows grow faint, details become pronounced, and the world seems somehow more real."},
    def = "You are seeing the world around you with greater clarity of vision." })
  defs_data:set("mindnet", { type = "shindo",
    on = {"You cast an invisible mind net out into the distance, allowing it to settle about the surrounding land.", "Extending your well-trained senses, you focus upon the movements of others nearby.", "You already have mindnet active."},
    def = "You have cast a mindnet over the local area.",
    off = "You cease concentration and your mind net vanishes."})
  defs_data:set("constitution", { type = "shindo",
    def = "You are using your superior constitution to prevent nausea.",
    on = {"You clench the muscles in your stomach, determined to assert your superior constitution.", "You are using your superior constitution to prevent nausea."}})
  defs_data:set("waterwalk", { type = "shindo",
    def = "You are poised to glide across the surface of water.",
    on = {"You are already poised to glide across the surface of water.", "Dancing lightly on your feet, you prepare to run across the surface of water."}})
  defs_data:set("shintrance", { type = "shindo",
    on = {"You are already focused upon gaining shindo energy.", "You centre your focus inwards, slowly opening yourself up to the energy of Shindo."},
    off = "You break out of the Shin Trance, sighing as you feel your accumulated Shin energy vanish.",
    def = "You are deep within the Shin trance."})
  defs_data:set("consciousness", { type = "shindo",
    def = "You are maintaining consciousness at all times.",
    off = {"You are not maintaining consciousness.", "You will no longer concentrate on retaining full consciousness."},
    on = {"You are already maintaining consciousness.", "You will remain conscious at all times."}})
  defs_data:set("bind", { type = "shindo",
    on = {"You bind Shin energy to your form, willing your body to accept its restorative power.", "You are already binding Shin energy."},
    def = "You are diverting excess Shin energy into regeneration.",
    off = "You cease binding excess Shin energy towards regeneration."})
  defs_data:set("projectiles", { type = "shindo",
    def = "You are alert to incoming projectiles.",
    off = {"You cease your watch for projectiles.", "You are not watching for projectiles."},
    on = "You look about sharply, poised to avoid all incoming projectiles."})
  defs_data:set("dodging", { type = "shindo",
    on = "You resolve to keep an eye on the skies for danger.",
    def = "You are watching the skies for danger.",
    off = {"You are not using Shindo Dodging.", "You cease watching the skies."}})
  defs_data:set("grip", { type = "shindo",
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set("immunity", { type = "shindo",
    on = "You close your eyes and grit your teeth, feeling the heat of the blood pumping through your veins.",
    off = "You cease concentrating on immunity."})
#end

#if skills.twoarts then
  defs_data:set("retaliationstrike", { type = "twoarts",
    def = "You are performing retaliatory strikes against your attackers.",
    off = "You will no longer strike in retaliation.",
    onr = [[Grasping the hilt of \w+ \w+, you prepare to counterattack when the opportunity arises\.$]]})
  defs_data:set("doya", { type = "twoarts",
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Lowering your centre of gravity, you drop into the Doya stance.",
    def = "You are in the Doya stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{"thyr", "mir", "arash", "sanya", "doya"} do
        if stance ~= newdef and svo["def"..whereto][mode][stance] then
          svo["def"..whereto][mode][stance] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.thyr or defc.mir or defc.arash or defc.sanya)
    end })
  defs_data:set("thyr", { type = "twoarts",
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Readying yourself with a flourish, you flow into the Thyr stance.",
    def = "You are in the Thyr stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{"thyr", "mir", "arash", "sanya", "doya"} do
        if stance ~= newdef and svo["def"..whereto][mode][stance] then
          svo["def"..whereto][mode][stance] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.doya or defc.mir or defc.arash or defc.sanya)
    end })
  defs_data:set("mir", { type = "twoarts",
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Resolving to move as water, you enter the Mir stance.",
    def = "You are in the Mir stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{"thyr", "mir", "arash", "sanya", "doya"} do
        if stance ~= newdef and svo["def"..whereto][mode][stance] then
          svo["def"..whereto][mode][stance] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.thyr or defc.doya or defc.arash or defc.sanya)
    end })
  defs_data:set("arash", { type = "twoarts",
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Mind set on the dancing flame, you take up the Arash stance.",
    def = "You are in the Arash stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{"thyr", "mir", "arash", "sanya", "doya"} do
        if stance ~= newdef and svo["def"..whereto][mode][stance] then
          svo["def"..whereto][mode][stance] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.thyr or defc.mir or defc.doya or defc.sanya)
    end })
  defs_data:set("sanya", { type = "twoarts",
    off = {"You adopt a neutral stance.", "You are not in any stance, Warrior."},
    on = "Clearing your mind, you sink into the Sanya stance.",
    def = "You are in the Sanya stance.",
    onenable = function (mode, newdef, whereto, echoback)
      for _, stance in ipairs{"thyr", "mir", "arash", "sanya", "doya"} do
        if stance ~= newdef and svo["def"..whereto][mode][stance] then
          svo["def"..whereto][mode][stance] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", stance, whereto, newdef) end
        end
      end

      return true
    end,
    specialskip = function ()
      return (defc.thyr or defc.mir or defc.arash or defc.doya)
    end })
#end

#if skills.subterfuge then
  defs_data:set("phase", { type = "subterfuge",
    on = {"A short burst of azure light fills your vision and when it is gone, you find yourself phased out of sync with the rest of reality." , "You are already phased!"},
    def = "Phased slightly out of reality, you are effectively untouchable.",
    off = {"There's a flash of light and you're pulled back into phase with reality." , "Your surroundings shatter into a cloud of glowing stars which dissipate to leave you back where you began." , "You are suddenly and unexpectedly pulled back into phase with reality."}})
  defs_data:set("hiding", { type = "subterfuge",
    on = {"You conceal yourself using all the guile you possess.", "You are already hidden.", "Too many prying eyes prevent you from finding a suitable hiding place."},
    def = "You have used great guile to conceal yourself.",
    off = {"You emerge from your hiding place.","You are discovered!","The flash of light illuminates you - you have been discovered!", "From what do you wish to emerge?"}})
  defs_data:set("scales", { type = "subterfuge",
    on = {"You concentrate and slowly your body is covered by protective, serpentine scales.","You are already covered in protective, serpentine scales."},
    def = "Serpentine scales protect your body.",
    off = "You ripple your muscles and as you watch, your skin turns white and peels off, taking your protective scaling with it."})
  defs_data:set("pacing", { type = "subterfuge",
    on = {"You begin to pace yourself and prepare for sudden bursts of exertion.","You are already pacing."},
    def = "You are paced for bursts of exertion.",
    off = "You are no longer pacing yourself."})
  defs_data:set("bask", { type = "subterfuge",
    on = {"You lie down and stretch yourself out, ready to bask beneath the blazing sun.", "The stresses and strains of existence gradually fall from you.", "The rays of sunlight spread a healing warmth through your body."},
    def = "Your blood is being heated by the sun.",
    off = "You rise to your feet."})
  defs_data:set("listen", { type = "subterfuge",
    onr = [[^You listen intently to the (.+)\.$]],
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].eavesdrop then
        svo["def"..whereto][mode].eavesdrop = false
        if echoback then echof("Removed eavesdrop from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    def = "You are listening in on another conversation.",
    specialskip = function ()
      return (defc.eavesdrop)
    end
    })
  defs_data:set("eavesdrop", { type = "subterfuge",
    onr = [[^You listen intently to the (.+)\.$]],
    def = "You are listening in on another conversation."}) --this ability completely replaces listen
  defs_data:set("lipread", { type = "subterfuge",
    on = {"You will now lip read to overcome the effects of deafness.", "You are already lipreading."},
    def = "You are lipreading to overcome deafness.",
    specialskip = function()
      return ((not defc.deaf and not affs.deafaff) or defc.mindseye)
    end })
  defs_data:set("weaving", { type = "subterfuge",
    mana = "lots",
    on = {"You picture a cobra in your mind, and slowly begin to weave back and forth agilely.", "You are already imitating the cobra."},
    def = "Cobra-like, you are weaving back and forth to dodge blows.",
    off = "You cease your cobra-like weaving.",  --this vanishes when mana is 0 without a message, just like alertness
    })
  defs_data:set("cloaking", { type = "subterfuge",
    on = "You toss a sparkling cloud of dust over yourself and as it settles you shimmer into invisibility.",
    def = "Your actions are cloaked in secrecy.",
    off = {"You dispel all illusion magics that were woven about yourself.","Your shroud dissipates and you return to the realm of perception."},
    -- not compatible with ghost per Alyssea
    offr = [[^\w+ points a finger at you and you feel anti-magic sweep over you\.$]] })
  defs_data:set("ghost", { type = "subterfuge",
    on = "You project a net of light about yourself until your image becomes faded and ghostly.",
    def = "You are shimmering with a ghostly light.",
    off = {"You dispel all illusion magics that were woven about yourself.", "Your ghostly image slowly intensifies until you appear flesh and blood again."},
    offr = [[^\w+ points a finger at you and you feel anti-magic sweep over you\.$]], })
  defs_data:set("secondsight", { type = "subterfuge",
    on = {"You narrow your eyes, allowing your vision to extend beyond the normal spectrum.", "You already possess the second sight."},
    def = "You are able to detect wormholes due to possessing the second sight.",})
#end

#if skills.swashbuckling then
  defs_data:set("drunkensailor", { type = "swashbuckling",
    on = {"You start swaying to and fro seemingly unpredictably as you enter the stance of the Drunken Sailor.", "You are already in the stance of the Drunken Sailor."},
    def = "The Drunken Sailor stance protects you.",
    off = "You relax into your normal fighting stance.",
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].heartsfury then
        svo["def"..whereto][mode].heartsfury = false
        if echoback then echof("Removed heartsfury from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    specialskip = function ()
      return (defc.heartsfury)
    end})
  defs_data:set("arrowcatch", { type = "swashbuckling",
    mana = "lots",
    on = {"You have begun to look for arrows to pluck from the air.", "You already have arrowcatching on."},
    def = "You are attempting to pluck arrows from the air.",
    off = "You've turned off arrowcatching."})
  defs_data:set("balancing", { type = "swashbuckling",
    mana = "lots",
    on = {"You move onto the balls of your feet and begin to concentrate on balance.", "You're already balancing."},
    def = "You are balancing on the balls of your feet.",
    off = "You cease to balance on the balls of your feet."})
  defs_data:set("acrobatics", { type = "swashbuckling",
    on = {"You begin leaping and bouncing about, making it more difficult to hit you.", "You are already bouncing around acrobatically."},
    def = "You are bouncing around acrobatically.",
    off = "You cease your acrobatic leaping and bouncing."})
  defs_data:set("dodging", { type = "swashbuckling",
    on = {"You resolve to keep an eye on the skies for danger.", "You are already watching the skies."},
    def = "You are watching the skies for danger.",
    off = "You cease watching the skies."})
  defs_data:set("grip", { type = "swashbuckling",
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
  defs_data:set("heartsfury", { type = "swashbuckling",
    on = {"Taut with rage, you enter the Heart's Fury stance.", "You are already in the Heart's Fury stance."},
    def = "The Heart's Fury stance protects you.",
    off = "You relax into your normal fighting stance.",
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].drunkensailor then
        svo["def"..whereto][mode].drunkensailor = false
        if echoback then echof("Removed drunkensailor from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    specialskip = function ()
      return (defc.drunkensailor)
    end})

  --[[trueparry = { type = "swashbuckling",
    on = "You will now attempt to parry attacks on your arms", --arms replaceable with legs/centre/right/left
    def = {"You will attempt to parry attacks to your left arm.", "You will attempt to parry attacks to your right arm."} --DEF shows both limbs being parried when trueparrying
    off = "You cease your attempts at parrying."]]
#end

#if skills.voicecraft then
  defs_data:set("lay", { type = "voicecraft",
    on = {"You sing a powerful Lay of distortion, protecting against the creation of physical images of yourself.", "You sing a powerful Lay of distortion."},
    def = "You are protected from the creation of physical images of yourself.",
    offr = [[^Your Lay of distortion is destroyed by \w+'s attempted fashion\.$]]})
  defs_data:set("tune", { type = "voicecraft",
    on = "Singing a powerful tune of safety and protection, you weave musical defences around yourself.",
    def = "You are protected from damage by a tune of safety."})
  defs_data:set("songbird", { type = "voicecraft",
    on = {"Lifting your head, you whistle an intricate, lilting tune. You are soon answered by a blue-feathered songbird that wings swiftly in and perches upon your shoulder.", "Your songbird twitters upon your shoulder, reminding you of its presence."},
    def = "A songbird is perched upon your shoulder.",
    off = "With a final chirp, the songbird upon your shoulder takes flight and wings swiftly away."})
  defs_data:set("aria", { type = "voicecraft",
    on = {"Your voice rises to the heavens with your instrument as you sing an Aria of healing to yourself.", "Your voice rises to the heavens with your instrument, but without your audience, as you sing an Aria of healing to yourself."},
    def = "Your health is enhanced by the beauties of an Aria.",
    off = "The heavenly strains of the Aria slowly fall silent."})
#end

#if skills.harmonics then
  defs_data:set("lament", {type = "harmonics", custom_def_type = "harmonic",
    on = "Slowly you take up the dark and sombre tones of a Lament.",
    off = "A burdensome sense of oppression lifts as the Lament arrives at its mournful conclusion."})
  defs_data:set("anthem", {type = "harmonics", custom_def_type = "harmonic",
    on = "An Anthem fills the air with its mighty fortress of protective influences as you take up its stately music.",
    off = "The structure of protection afforded by the Anthem decays with the final notes of the composition."})
  defs_data:set("harmonius", {type = "harmonics", custom_def_type = "harmonic",
    on = "Blending several seemingly distinct musical ideas into one majestic whole, you begin the Harmonius.",
    off = "The individual strands blended by the Harmonius slowly disintegrate into cacophony as the song ends."})
  defs_data:set("contradanse", {type = "harmonics", custom_def_type = "harmonic",
    on = "An elaborate Contradanse melody begins to pervade the room.",
    off = "Melody slows, simplifies, and comes to an end, terminating the elaborate Contradanse."})
  defs_data:set("paxmusicalis", {type = "harmonics", custom_def_type = "harmonic",
    on = "You experience true rest and relief as you gently enter into the first soothing passage of the Pax Musicalis.",
    off = "The peaceful strains of the Paxmusicalis slowly fade to silence."})
  defs_data:set("gigue", {type = "harmonics", custom_def_type = "harmonic",
    on = "You dash off a few bars, launching into the detailed patterns of a Gigue.",
    off = "Your thoughts return to their normal order as the Gigue's airs fade from the room."})
  defs_data:set("bagatelle", {type = "harmonics", custom_def_type = "harmonic",
    on = "Through a series of musical twists and turns you begin the Bagatelle.",
    off = "Twisting and turning no more, the Bagatelle ends suddenly."})
  defs_data:set("partita", {type = "harmonics", custom_def_type = "harmonic",
    on = "Delicate and precise, you take up a Partita.",
    off = "The Partita ends without fanfare, precisely as it began."})
  defs_data:set("berceuse", {type = "harmonics", custom_def_type = "harmonic",
    on = "You begin a delicate Berceuse, playing with great tenderness.",
    off = "The Berceuse drifts faintly away as its final notes float softly through the area."})
  defs_data:set("continuo", {type = "harmonics", custom_def_type = "harmonic",
    on = "Your feelings rise with a Continuo's opening movement.",
    off = "The Continuo falters and dies and, along with it, the thrilling feeling it had brought."})
  defs_data:set("wassail", {type = "harmonics", custom_def_type = "harmonic",
    on = "The Wassail's first notes stir and strengthen you.",
    off = "The Wassail trails slowly off, coming to a melancholy conclusion."})
  defs_data:set("canticle", {type = "harmonics", custom_def_type = "harmonic",
    on = "You enter into the realms of the divine as you play the opening strains of a sacred Canticle.",
    off = "The instabilities of the world again impinge upon you as the Canticle draws to a close."})
  defs_data:set("reel", {type = "harmonics", custom_def_type = "harmonic",
    on = "With a hop you enter into the complex, up-tempo dance melody of a Reel.",
    off = "The Reel comes around again, sounding as though ready to begin another step, and suddenly stops."})
  defs_data:set("hallelujah", {type = "harmonics", custom_def_type = "harmonic",
    on = "With a powerful fanfare, you begin a resounding Hallelujah.",
    off = "The Hallelujah's final amen fills you with awe at its power, and sorrow for the ending of this uplifting piece."})
#end

#if skills.devotion then
  defs_data:set("inspiration", { type = "devotion",
    on = {"You bow your head and, praying to the gods for inspiration, you are soon rewarded as your body is suffused with strength."},
    def = "Your limbs are suffused with divinely-inspired strength.",
    off = "You slump slightly as the divinely-inspired strength leaves your body." })
  defs_data:set("bliss", { type = "devotion",
    staysindragon = true,
    on = {"You pour blessings of bliss over yourself, granting visions of the majesty of the divine.", "The divine choir lingers on in your mind, and your spirit soars.", "That person is already experiencing bliss."},
    onr = [[^(\w+) pours blessings over you, and divine choirs begin to sing joyously at the edge of your hearing\.]],
    invisibledef = true })
  defs_data:set("bloodsworn", { type = "devotion",
    onr = [[^You are bloodsworn to \w+\.$]],
    on = "The true power of the bloodsworn begins to rage in your veins.",
    invisibledef = true,
    off = "The power of the bloodsworn leaves you." })
#end

#if skills.spirituality then
  defs_data:set("mace", { type = "spirituality",
    invisibledef = true})
  defs_data:set("heresy", { type = "spirituality",
    def = "You are hunting heretics.",
    off = "Your rage to destroy heretics subsides.",
    on = {"Rage fills you as the thought of heresy inspires you to greater efforts.", "You are already hunting the heretics."}})
  defs_data:set("summon", { type = "spirituality",
    def = "You are regenerating endurance at an increased rate.",
    custom_def_type = "angel",
    off = {"The light of the guardian angel dims quietly out of existence.", "Your guardian angel must be visible before you can communicate with her.", "Your guardian angel shimmers silently away."},
    on = {"A flower of white light blooms in the air beside you, and your guardian is by your side.", "You feel confusion radiate from your guardian, who hovers already at your side."}})
  defs_data:set("empathy", { type = "spirituality",
    specialskip = function() return not defc.summon end,
    off = {"You stop using your guardian angel's empathic link.", "You're not using your guardian angel's empathic link.", "Your empathic link with your angel is severed."},
    custom_def_type = "angel",
    on = {"A feeling of deep peace fills you as your fate is bound with that of your guardian angel.", "Your guardian informs you sadly that she lacks the power to obey your command."}})
  defs_data:set("care", { type = "spirituality",
    specialskip = function() return not defc.summon end,
    off = {"Your guardian angel ceases healing your afflictions.", "Your guardian angel is not currently healing your afflictions.", "Your guardian ceases to pass on her care."},
    custom_def_type = "angel",
    on = {"Your guardian angel begins to shimmer with a soft red light.", "Your guardian informs you sadly that she lacks the power to obey your command."}})
  defs_data:set("watch", { type = "spirituality",
    on = "You bid your angel to watch over you.",
    off = {"You order your angel to cease tracking the movements of your enemies.", "Your guardian angel is not currently watching your enemies.", "Your guardian ceases to watch."},
    custom_def_type = "angel",
    })
#end

#if skills.metamorphosis then
  defs_data:set("affinity", { type = "metamorphosis",
    on = {"You are already embracing the spirit that dwells within you.", "You embrace the spirit that dwells within you and are overcome with the joy of true unity."},
    def = "You have a great affinity with your spirit form." })
    --general meta ability,

  defs_data:set("bonding", { type = "metamorphosis",
    on = {"You are already bonding with the spirits, Metamorph.", "Your soul draws inexorably closer to its spirit host as the spiritual bonding magic works about you."},
    def = "You are bonded to your spirit totem.",
    off = {"Your soul is not under the influence of a spiritual bond to its spirit host", "You shiver briefly as the spiritual bonding of your soul to its spirit host ends."}})
    --general meta ability

  defs_data:set("elusiveness", { type = "metamorphosis",
    specialskip = function() return not sk.morphsforskill.elusiveness end,
    on = {"You are already watching for pursuit.", "Your eyes flicker this way and that as you watch for pursuers."},
    def = "You are alert to those who would pursue you.",
    off = {"You are not watching for pursuers, Metamorph.", "You cease watching for pursuit."},
    })
    --Basilisk, Hyena, Wolverine, Jaguar

  defs_data:set("flame", { type = "metamorphosis",
    specialskip = function() return not sk.morphsforskill.flame end,
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "hydra"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    invisibledef = true,
    on = {"You take a deep breath and realise your error - you sputter and engulf yourself in fire!", "You take a deep breath and feel the heat begin to build within you.", "You are ready to breathe yellow fire.", "You are ready to breathe blue fire.","You are ready to breathe white fire.", "With a roar you channel your reserves into your inner flame, instantly summoning forth a raging inferno."},
    offr = [[^You inhale deeply, allowing the raging flames to build up inside you. With an earth-shaking roar, you release a white-hot jet of fire directly at \w+\.$]],
    off = {"A small gout of fire erupts harmlessly from your mouth.", "You take a deep breath and realise your error - you sputter and engulf yourself in fire!", "Unleashing white-hot flames in a reckless burst of fire, you create a roaring inferno about your person.", "Your inner fire does not burn with sufficient intensity, Metamorph.", "You take a deep breath and realise your error - you splutter and engulf yourself in fire!"},
    })
    --Wyvern, Basilisk

  defs_data:set("lyre", { type = "metamorphosis",
    specialskip = function() return not conf.lyre or not sk.morphsforskill.lyre end,
    availableindragon = true,
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].meditate then
        svo["def"..whereto][mode].meditate = false
        if echoback then echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].breath then
        svo["def"..whereto][mode].breath = false
        if echoback then echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].flame then
        svo["def"..whereto][mode].flame = false
        if echoback then echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = {"You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.", "You strum a Lasallian lyre, and a prismatic barrier forms around you.", "You deftly shape the wall of light into a barrier surrounding yourself.", "You strum a darkly glowing mandolin, and a prismatic barrier forms around you."},
    def = "You are standing within a prismatic barrier.",
    off = {"Your prismatic barrier dissolves into nothing.", "The stream hits your prismatic barrier, shattering it.", "The breath weapon rips apart your prismatic barrier.", "The breath weapon rips through both your shield and prismatic barrier.", "The spear shatters your prismatic barrier."}})
    --Nightingale Only

  -- defs_data:set("nightsight", { type = "metamorphosis",
  --   specialskip = function() return not sk.morphsforskill.nightsight end,
  --   on = "Your vision sharpens with light as you gain night sight.",
  --   def = "Your vision is heightened to see in the dark.",
  --   off = "Your eyes lose the benefit of night sight.",
  --   })
    --Wildcat, Wolf, Cheetah, Owl, Hyena, Condor, Wolverine, Jaguar, Eagle, Icewyrm, Wyvern, Hydra

  defs_data:set("rest", { type = "metamorphosis",
    specialskip = function() return not sk.morphsforskill.rest end,
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].flame then
        svo["def"..whereto][mode].flame = false
        if echoback then echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = {"You find a quiet corner, curl up and settle down to rest.","You feel the strains of the world falling away from your weary limbs.", "But you're already resting, O sloth!"},
    invisibledef = true,
    off = "Your rest is interrupted.","You rise from your rest, refreshed and full of energy."})
    --Sloth only

  defs_data:set("resistance", { type = "metamorphosis",
    specialskip = function() return not sk.morphsforskill.resistance end,
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
    --Basilisk, Jaguar, Hydra

  defs_data:set("stealth", { type = "metamorphosis",
    specialskip = function() return not sk.morphsforskill.stealth end,
    on = {"You are already moving in total silence.", "You will now move in total silence."},
    def = "Your movements are incredibly stealthy.",
    off = {"You are not currently moving silently, Metamorph.", "You cease concentrating on stealth."},
    })
    --Basilisk, Hyena, Jaguar

  defs_data:set("temperance", { type = "metamorphosis",
    specialskip = function() return not sk.morphsforskill.temperance end,
    on = {"Your skin is already chilled, Metamorph.", "A chill runs over your icy skin."},
    def = "You are tempered against fire damage.",
    })
    --Icewyrm, Wyvern, Hydra

  defs_data:set("vitality", { type = "metamorphosis",
    specialskip = function() return not sk.morphsforskill.vitality end,
    on = {"Your body is already aglow with vitality.", "Your body positively glows with health and vitality."},
    def = "You will call upon your fortitude in need.",
    off = {"You cannot call upon your vitality again so soon.", "A surge of rejuvenating energy floods your system, healing your wounds."}})
    --Bear, Elephant, Jaguar, Icewyrm, Wyvern, Hydra

  defs_data:set("squirrel", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A squirrel spirit co-habits your body." })
  defs_data:set("wildcat", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A wildcat spirit co-habits your body." })
  defs_data:set("wolf", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A wolf spirit co-habits your body." })
  defs_data:set("turtle", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A turtle spirit co-habits your body." })
  defs_data:set("jackdaw", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A jackdaw spirit co-habits your body." })
  defs_data:set("cheetah", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A cheetah spirit co-habits your body." })
  defs_data:set("owl", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "An owl spirit co-habits your body." })
  defs_data:set("hyena", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A hyena spirit co-habits your body." })
  defs_data:set("condor", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A condor spirit co-habits your body." })
  defs_data:set("gopher", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A gopher spirit co-habits your body." })
  defs_data:set("sloth", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A sloth spirit co-habits your body." })
#if class == "sentinel" then
  defs_data:set("basilisk", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A basilisk spirit co-habits your body." })
#end
  defs_data:set("bear", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A bear spirit co-habits your body." })
  defs_data:set("nightingale", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A nightingale spirit co-habits your body." })
  defs_data:set("elephant", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "An elephant spirit co-habits your body." })
  defs_data:set("wolverine", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A wolverine spirit co-habits your body." })
#if class == "sentinel" then
  defs_data:set("jaguar", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A jaguar spirit co-habits your body." })
#end
  defs_data:set("eagle", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "An eagle spirit co-habits your body." })
  defs_data:set("gorilla", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A gorilla spirit co-habits your body." })
  defs_data:set("icewyrm", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "An icewyrm spirit co-habits your body." })
#if class == "druid" then
  defs_data:set("wyvern", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A wyvern spirit co-habits your body." })

  defs_data:set("hydra", { type = "metamorphosis",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"squirrel", "wildcat", "wolf", "turtle", "jackdaw", "cheetah", "owl", "hyena", "condor", "gopher", "sloth", "basilisk", "bear", "nightingale", "elephant", "wolverine", "jaguar", "eagle", "gorilla", "icewyrm", "wyvern", "hydra", "flame"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,
    def = "A hydra spirit co-habits your body."})
#end
#end

#if skills.occultism then
  defs_data:set("shroud", { type = "occultism",
    on = "Calling on your dark power, you draw a thick shroud of concealment about yourself to cover your every action.",
    off = {"Your shroud dissipates and you return to the realm of perception.", "The flash of light illuminates you - you have been discovered!"},
    offr = [[^\w+ points a finger at you and you feel anti-magic sweep over you\.$]],
    def = "Your actions are cloaked in secrecy." })
  defs_data:set("astralvision", { type = "occultism",
    on = {"Gritting your teeth, you focus your will and expand your aura throughout the surroundings about you, seeking out the aura of others.", "You already possess enhanced vision."},
    --astralvision gives both deathsight and lifevision at the same time, there is no way to manually lower lifevision
    def = "You have enhanced your vision to be able to see traces of lifeforce." })
  defs_data:set("distortedaura", { type = "occultism",
    on = {"Clenching your fists, you focus your will on distorting your own aura. Your mind reels as your aura twists the very air around you.", "Your aura is already distorted, Occultist."},
    off = {"You concentrate on calming your distorted aura, breathing a sigh of relief as it subsides to its normal state.","Your aura is not distorted, Occultist."},
    def = "You have distorted your own aura." })
  defs_data:set("tentacles", { type = "occultism",
    on = {"You raise your hands above your head, focusing your will to warp your own body. Ignoring the excruciating pain, tentacles spring out from the sides of your body and flail about of their own accord.","Tentacles are already flailing from your body."},
    off = "You breathe a sigh of comfort as the flailing tentacles recede back into your body.",
    def = "You have tentacles flailing from your body." })
  defs_data:set("devilmark", { type = "occultism",
    on = {"You lick your finger and then bend your will to the task of tracing the mark of the devil over your heart. There is a slight burning and a black mark forms where you've traced.","You already have the mark of the devil upon your heart.", [[The Devil in your service says, "Your will demands I serve you again, and so it shall be."]]},
    off = {"You do not bear the mark of the devil.", "You draw your hand across your heart, releasing any devils in your service and erasing their mark from your skin.", "You feel the devilmark fade from your heart.", "You bend your will to the task of tracing the mark of the devil over your heart, but the presence of a devil waiting in service nullifies its effect."},
    specialskip = function() return defc.devil end,
    def = "The devilmark is upon your breast." })
  defs_data:set("astralform", { type = "occultism",
    on = {"You summon all your will to focus your aura. In a flash of blazing light, your aura consumes your body and nothing is left except your disembodied presence.","You have taken the astralform and can not do that."},
    offr = {[[^You concentrate and are once again \w+\.$]],[[You are already in \w+ form\.$]]},
    def = "As an insubstantial astral light, you are immune from many attacks." })
  defs_data:set("heartstone", { type = "occultism",
    on = "Cupping your hands before you, you tap into your stores of karma. Focusing your will on the image of your own heart, an unearthly crimson glow fills your cupped hands and solidifies into a heart-shaped ruby.",
    off = "A heartstone cracks and crumbles to dust.",
    invisibledef = true })
  defs_data:set("simulacrum", { type = "occultism",
    on = "Cupping your hands before you, you tap into your stores of karma. Focusing your will on an image of yourself, an unearthly violet glow fills your cupped hands and solidifies into an amethyst resembling you.",
    offr = [[^A simulacrum shaped like <fix me, insert character name here> cracks and crumbles to dust\.$]],
    invisibledef = true })
  defs_data:set("transmogrify", { type = "occultism",
      staysindragon = true,
      --Not useful to track it going up or down, since there's a random delay of 4-10 hours between.
      off = {"You carefully raise a barrier between your soul and the Chaos Lord spirit within you."},
      on = {"You lower the barrier separating your soul from the Chaos Lord spirit within you."},
      defr = [[The spirit of a Chaos (?:Lord|Lady) lies dormant in your soul\.$]] })
#end

#if skills.tarot then
  defs_data:set("devil", { type = "tarot",
      on = {[[You fling the card at the ground, and a red, horned Devil rises from the bowels of the earth to say, "I will serve you but once...Master."]], "You bend your will to the task of tracing the mark of the devil over your heart, but the presence of a devil waiting in service nullifies its effect.", [[The Devil in your service says, "Your will demands I serve you again, and so it shall be."]]},
      off = {"You feel the Devil leave you.", "You lick your finger and then bend your will to the task of tracing the mark of the devil over your heart. There is a slight burning and a black mark forms where you've traced.", "You draw your hand across your heart, releasing any devils in your service and erasing their mark from your skin."},
      invisibledef = true,
      offr = {[[^You quickly fling a Lust card at \w+ and (?:his|her) eyes light up\.$]], [[^You toss the Hanged Man tarot card at \d+ and as it reaches (?:him|her), a huge mass of rope bursts out of it to entrap and hinder (?:him|her)\.$]], [[^As you fling the Moon tarot at \w+, it turns an ominous, sickly red, before striking (?:him|her) in the head\.$]], [[^With a prayer to Miramar, the Just, you fling your tarot card at \w+\. A set of scales appears above (?:his|her) head and one side of the scale quickly descends\. Justice will be done\.$]], [[^You stand an Aeon tarot on your palm, and blow it lightly at \w+\.$]], [[^Standing the Aeon on your open palm, you blow it lightly at \w+ and watch as it seems to slow (?:his|her) movement through the time stream\.$]]},
    })
#end

#if skills.domination then
  defs_data:set("arctar", { type = "domination",
    on = {"You command your chaos orb to grant you protection; it pulses once before detonating in a soundless conflagration.", "You cannot summon Arctar, the Defender for you have no pact with that entity."},
    on_only = "The Entity refuses to send another minion to aid you.",
    def = "Surrounded by the power of Arctar.",
    off = "Abruptly, the power rippling across your skin dissipates.",})
  defs_data:set("golgotha", { type = "domination",
    on = {"You cannot summon Jy'Barrak Golgotha, Emperor of Chaos for you have no pact with that entity.", "Closing your eyes, you focus on your contract with Jy'Barrak Golgotha, Emperor of Chaos, beseeching Him for His aide. For the briefest instant the overpowering stench of sulphur fills your nostrils, then a flash of acknowledgement passes to you. Your skin comes alight with a furious burning, and a dire, inhuman sense of vicious amusement fills you as you are suffused with the power of the Emperor of Darkness. Your muscles lock and a scream claws at your throat, but you can do nothing until the pain leaves you except convulse in abject agony."},
    def = "You are acknowledged by Jy'Barrak Golgotha, Emperor of Chaos."})
#end

#if skills.healing then
  defs_data:set("simultaneity", {
    type = "healing",
    custom_def_type = "channel"
  })
  defs_data:set("bindall", {
    type = "healing",
    custom_def_type = "channel"
  })
  defs_data:set("fortifyall", {
    type = "healing",
    custom_def_type = "channel"
  })
  defs_data:set("air", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You already have a channel opened to air.", "The power of air is harnessed to your will."}})
  defs_data:set("fire", {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You already have a channel opened to fire.", "Elemental fire burns at your behest."}})
  defs_data:set("water", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You already have a channel opened to water.", "Purest water soothes you into calm."}})
  defs_data:set("earth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You already have a channel opened to earth.", "The strength of earth is at your command."}})
  defs_data:set("spirit", {
    off = {"You sever the link to the realm of spirit.", "The power of the knife sigil cuts your spirit channel."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You already have a channel opened to spirit.", "You merge the four elemental channels and the formidable powers of the spirit realms are yours."}})

  defs_data:set("fortifiedair", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Air channel."}})
  defs_data:set("fortifiedfire", {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel.", "Your magics around the fire channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Fire channel."}})
  defs_data:set("fortifiedwater", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Water channel."}})
  defs_data:set("fortifiedearth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Earth channel."}})
  defs_data:set("fortifiedspirit", {
    off = {"You sever the link to the realm of spirit.", "The power of the knife sigil cuts your spirit channel.", "Your magics around the spirit channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Spirit channel."}})

  defs_data:set("boundair", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Air to your superior will."}})
  defs_data:set("boundfire", {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel.", "Your magics around the fire channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Fire to your superior will."}})
  defs_data:set("boundwater", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Water to your superior will."}})
  defs_data:set("boundearth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Earth to your superior will."}})
  defs_data:set("boundspirit", {
    off = {"You sever the link to the realm of spirit.", "The power of the knife sigil cuts your spirit channel.", "Your magics around the spirit channel have been destroyed by the knife sigil."},
    type = "healing",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Spirit to your superior will."}})
  defs_data:set("frostblessing", { type = "healing",
    on = "You call upon the elements Air and Water and bestow the Frost Spiritshield blessing upon yourself.",
    def = "You are protected by the power of a Frost Spiritshield."})
  defs_data:set("willpowerblessing", { type = "healing",
    on = "You call upon the elements Air, Water, and Fire and bestow the Willpower blessing upon yourself.",
    def = "You are regenerating willpower at an increased rate."})
  defs_data:set("thermalblessing", { type = "healing",
    on = "You call upon the elements Fire and Spirit and bestow the Thermal Spiritshield blessing upon yourself.",
    def = "You are protected by the power of a Thermal Spiritshield."})
  defs_data:set("earthblessing", { type = "healing",
    on = "You call upon the elements Earth and Spirit and bestow the Earth Spiritshield blessing upon yourself.",
    def = "You are protected by the power of an Earth Spiritshield."})
  defs_data:set("enduranceblessing", { type = "healing",
    def = "You are regenerating endurance at an increased rate.",
    on = "You call upon the elements Water, Earth, and Fire and bestow the Endurance blessing upon yourself."})
  defs_data:set("bedevil", { type = "healing",
    on = {"You manipulate the elements to lash at those who would do you harm.", "You are already protected by the bedeviling aura."},
    def = "An aura of bedevilment has been established about your person.",
    off = "The elemental aura surrounding you sputters and dies."})
#end

#if skills.elementalism then
  defs_data:set("stoneskin", {
    type = "elementalism",
    specialskip = function () return not defc.earth end,
    def = "Magically supple granite coats your body.",
    on = {"Calling the powers of the elemental earth to you, you coat yourself in magically-supple granite.", "Your skin is already covered in a protective, amazingly supple, granite coating."}})
  defs_data:set("diamondskin", {
    type = "elementalism",
    specialskip = function() return not (defc.water and defc.fire and defc.earth) end,
    def = "Diamond-hard skin protects you.",
    on = {"Your skin is already covered in a protective, magically-flexible, diamond-hard coating.", "Calling upon crystalline powers, you wrap your skin in a flexible, diamond-hard coating."}})

  defs_data:set("stonefist", {
    type = "elementalism",
    on = {"You already possess fists of stone.", "You call upon the powers of the earth to coat your fists in dense granite."},
    off = "The granite enveloping your fists cracks and falls off.",
    def = "Your fists are covered with dense granite."})
  defs_data:set("efreeti", {
    type = "elementalism",
    invisibledef = true,
    off = "The efreeti begins to spin faster and faster, and suddenly disappears in a blaze of flame.",
    offr = [[^A fiery efreeti, your loyal companion, has been slain by]],
    on = {"You are unable to summon more than one efreeti.", "You rub your hands together briskly, heating them with friction, and with a word, throw them open. A fiery efreeti appears before you, swirling in a vortex of flame."}})
  defs_data:set("waterweird", {
    type = "elementalism",
    on = {"You do not have the power to summon more than one water weird.", "You summon a water weird to assist you in water crossings."},
    def = "Your water weird allows you to walk on water."})
  defs_data:set("chargeshield", {
    type = "elementalism",
    on = {"You already have a chargeshield active.", "You call upon the powers of air and earth to weave a non-conducting energy shield around you."},
    def = "You are surrounded by a non-conducting chargeshield."})
  defs_data:set("reflection", {
    type = "elementalism",
    def = "You are surrounded by one reflection of yourself.",
    defr = [[^You are surrounded by \d+ reflections? of yourself\.$]],
    on = {"You cast a spell of reflection over yourself.", "This spell may only be used to cast one reflection on someone. If he or she already has one, it may not be used."},
    off = {"One of your reflections has been destroyed! You have 0 left.", "All your reflections wink out of existence!"}})

  defs_data:set("simultaneity", {
    type = "elementalism",
    custom_def_type = "channel"
  })
  defs_data:set("bindall", {
    type = "elementalism",
    custom_def_type = "channel"
  })
  defs_data:set("fortifyall", {
    type = "elementalism",
    custom_def_type = "channel"
  })
  defs_data:set("air", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You already have a channel opened to air.", "The power of air is harnessed to your will."}})
  defs_data:set("fire", {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You already have a channel opened to fire.", "Elemental fire burns at your behest."}})
  defs_data:set("water", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You already have a channel opened to water.", "Purest water soothes you into calm."}})
  defs_data:set("earth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You already have a channel opened to earth.", "The strength of earth is at your command."}})

  defs_data:set("fortifiedair", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Air channel."}})
  defs_data:set("fortifiedfire", {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel.", "Your magics around the fire channel have been destroyed by the knife sigil."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Fire channel."}})
  defs_data:set("fortifiedwater", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Water channel."}})
  defs_data:set("fortifiedearth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Earth channel."}})

  defs_data:set("boundair", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Air to your superior will."}})
  defs_data:set("boundfire", {
    off = {"You sever the link to the realm of fire.", "The power of the knife sigil cuts your fire channel.", "Your magics around the fire channel have been destroyed by the knife sigil."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Fire to your superior will."}})
  defs_data:set("boundwater", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Water to your superior will."}})
  defs_data:set("boundearth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = "elementalism",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Earth to your superior will."}})
#end

#if skills.apostasy then
  defs_data:set("armour", {
    type = "apostasy",
    stays_on_death = true,
    on = {"You already are surrounded by unholy armour.", "You ask your Baalzadeen for its protection, and it summons a thin black protecting sheen over you."},
    def = "Your person is surrounded by black demonic armour."})
  defs_data:set("syphon", {
    type = "apostasy",
    invisibledef = true,
    on = {"Your Baalzadeen begins to shimmer with a demonic red light.", "Your Baalzadeen is already syphoning your diseases."}})
  defs_data:set("mask", {
    type = "apostasy",
    invisibledef = true,
    stays_on_death = true,
    on = {"You wrap your Baalzadeen in a mask of impenetrable obscurity.", "Your Baalzadeen is already masked."}})
  defs_data:set("daegger", {
    type = "apostasy",
    invisibledef = true,
    on = {"You call upon the Lords of Hell to bestow the living weapon, the daegger, unto you.", "Your daegger comes racing towards you, stopping unnaturally quickly to land in your grasp."}})
  defs_data:set("pentagram", {
    type = "apostasy",
    on = {"Using your daegger, you open a vein in your wrist, and let the blood drip to outline a pentagram, floating waist-high.", "There is already a pentagram here."}
  })
  defs_data:set("baalzadeen", {
    type = "apostasy",
    off = "You must be leading your Baalzadeen.",
    on = {"Imposing your will on Hell itself, you summon forth a Baalzadeen to serve your whim.", "You call out, ordering your Baalzadeen to return to serve your whim."},
    invisibledef = true,
    stays_on_death = true,
  })
#end

#if skills.weatherweaving then
  defs_data:set("simultaneity", {
    type = "weatherweaving",
    custom_def_type = "channel"
  })
  defs_data:set("bindall", {
    type = "weatherweaving",
    custom_def_type = "channel"
  })
  defs_data:set("fortifyall", {
    type = "weatherweaving",
    custom_def_type = "channel"
  })
  defs_data:set("air", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You already have a channel opened to air.", "The power of air is harnessed to your will."}})
  defs_data:set("water", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You already have a channel opened to water.", "Purest water soothes you into calm."}})
  defs_data:set("earth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You already have a channel opened to earth.", "The strength of earth is at your command."}})
  defs_data:set("fortifiedair", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Air channel."}})
  defs_data:set("fortifiedwater", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Water channel."}})
  defs_data:set("fortifiedearth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You weave a layer of protective magic about your open elemental channels.", "You weave a layer of protective magic about the Earth channel."}})
  defs_data:set("boundair", {
    off = {"You sever the link to the realm of air.", "The power of the knife sigil cuts your air channel.", "Your magics around the air channel have been destroyed by the knife sigil."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Air to your superior will."}})
  defs_data:set("boundwater", {
    off = {"You sever the link to the realm of water.", "The power of the knife sigil cuts your water channel.", "Your magics around the water channel have been destroyed by the knife sigil."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Water to your superior will."}})
  defs_data:set("boundearth", {
    off = {"You sever the link to the realm of earth.", "The power of the knife sigil cuts your earth channel.", "Your magics around the earth channel have been destroyed by the knife sigil."},
    type = "weatherweaving",
    custom_def_type = "channel",
    on = {"You bind all your open elemental channels to you.", "You bind the element of Earth to your superior will."}})
  defs_data:set("circulate", { type = "weatherweaving",
    on = {"You begin circulating electricity throughout your body in a constant cycle.", "You are already circulating electricity throughout your body."},
    def = "You are circulating electricity throughout your body."})
  defs_data:set("reflection", {
    type = "weatherweaving",
    def = "You are surrounded by one reflection of yourself.",
    defr = [[^You are surrounded by \d+ reflections? of yourself\.$]],
    on = {"You cast a spell of reflection over yourself.", "This spell may only be used to cast one reflection on someone. If he or she already has one, it may not be used."},
    off = {"One of your reflections has been destroyed! You have 0 left.", "All your reflections wink out of existence!"}})
#end

#if skills.pranks then
  defs_data:set("arrowcatch", { type = "pranks",
    mana = "lots",
    on = {"You have begun to look for arrows to pluck from the air.", "You already have arrowcatching on."},
    def = "You are attempting to pluck arrows from the air.",
    off = "You've turned off arrowcatching."})
  defs_data:set("balancing", { type = "pranks",
    mana = "lots",
    on = {"You move onto the balls of your feet and begin to concentrate on balance.", "You're already balancing."},
    def = "You are balancing on the balls of your feet.",
    off = "You cease to balance on the balls of your feet."})
  defs_data:set("acrobatics", { type = "pranks",
    on = {"You begin leaping and bouncing about, making it more difficult to hit you.", "You are already bouncing around acrobatically."},
    def = "You are bouncing around acrobatically.",
    off = "You cease your acrobatic leaping and bouncing."})
  defs_data:set("slipperiness", { type = "pranks",
    on = {"You're quite the slippery little fellow aren't you?", "You're already quite slippery.", "You're quite the slippery little gal aren't you?"},
    def = "You are looking a little shady today.",
    })
#end

#if skills.puppetry then
  defs_data:set("grip", { type = "puppetry",
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
#end


#if skills.vodun then
  defs_data:set("grip", { type = "vodun",
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
#end

#if skills.curses then
  defs_data:set("swiftcurse", { type = "curses",
    on = "You weave your fingers together, calling upon the swiftcurse to aid you.",
    def = "The swiftcurse is upon you.",
    off = "The swiftcurse leaves you."})
#end

#if skills.kaido then
  defs_data:set("weathering", { type = "kaido",
    on = "A brief shiver runs through your body.",
    def = "Your body is weathering the storm of life a little better."})
  defs_data:set("resistance", { type = "kaido",
    on = "You call aloud and feel an aura of resistance shroud itself silently about you.",
    def = "You are resisting magical damage."})
  defs_data:set("numb", { type = "kaido",
    on = "You grit your teeth and will your pain out of existence.",
    off = "You cry out in agony as the effects of your numbness fade away and you feel your wounds once more.",
    def = "You are temporarily numbed to damage." })
  defs_data:set("regeneration", { type = "kaido",
    on = {"You begin to concentrate on regeneration of your wounds.", "Regeneration is already on."},
    def = "You are regenerating lost health through the power of Kaido.",
    off = {"You have no regenerative ability to boost.", "You call a halt to the regenerative process."}})
  defs_data:set("boosting", { type = "kaido",
    onenable = function (mode, newdef, whereto, echoback)
      if not svo["def"..whereto][mode].regeneration then
        svo["def"..whereto][mode].heartsfury = true
        if echoback then echof("Added regeneration to %s, it's necessary for %s.", whereto, newdef) end
      end

      return true
    end,
    specialskip = function() return not defc.regeneration end,
    on = {"You call upon your Kai power to boost your health regeneration.", "Your regeneration is already boosted."},
    def = "Your regeneration is boosted.",
    off = {"You call a halt to the regenerative process."}})
  defs_data:set("kaiboost", { type = "kaido",
    off = "You are no longer boosting your Kai gain.",
    def = "You have boosted the power of your Kai Trance.",
    on = "You gather up and expend your Kai energy to enhance your sensitivity to its energies."})
  defs_data:set("toughness", { type = "kaido",
    on = "Flexing your muscles, you concentrate on forcing unnatural toughness over the surface of your skin.",
    def = "Your skin is toughened."})
  -- disabled, better be general for dragons to work
  -- defs_data:set("nightsight", { type = "kaido",
  --   def = "Your vision is heightened to see in the dark.",
  --   on = {"Your vision sharpens with light as you gain night sight.", "Your eyes already have the benefit of night sight."},
  --   off = {"Your eyes lose the benefit of night sight.", "Your eyes cannot lose the benefit of night sight, since they do not already have it!"}})
  defs_data:set("projectiles", { type = "kaido",
    mana = "lots",
    def = "You are alert to incoming projectiles.",
    off = {"You cease your watch for projectiles.", "You are not watching for projectiles."},
    on = "You look about sharply, poised to avoid all incoming projectiles."})
  defs_data:set("trance", { type = "kaido",
    mana = "lots",
    on = {"You begin to chant an ancient mantra, preparing your body to become a channel for Kai energy.", "Your mantra is complete - the Kai Trance is upon you."},
    off = "You break out of the Kai Trance, sighing as you feel your accumulated Kai energy vanish.",
    def = "You are utilising the trance to store Kai energy."})
  defs_data:set("dodging", { type = "kaido",
    mana = "lots",
    on = "You resolve to keep an eye on the skies for danger.",
    def = "You are watching the skies for danger.",
    off = {"You are not using Shindo Dodging.", "You cease watching the skies."}})
  defs_data:set("constitution", { type = "kaido",
    def = "You are using your superior constitution to prevent nausea.",
    on = {"You clench the muscles in your stomach, determined to assert your superior constitution.", "You are using your superior constitution to prevent nausea."}})
  defs_data:set("splitmind", { type = "kaido",
    on = {"You begin to devote a portion of your Kaido-trained mind to constant, unconscious meditation.", "Your mind is already split."},
    def = "Your mind is split, allowing constant meditation.",
    off = {"You cease the process of Kai meditation, joining the split segments of your mind once more.", "Your mind is already whole."}})
  defs_data:set("consciousness", { type = "kaido",
    def = "You are maintaining consciousness at all times.",
    off = {"You are not maintaining consciousness.", "You will no longer concentrate on retaining full consciousness."},
    on = {"You are already maintaining consciousness.", "You will remain conscious at all times."}})
  defs_data:set("sturdiness", { type = "kaido",
    on = "You cross your arms, standing firm and resolute.",
    def = "You are standing firm against attempts to move you.",
    off = "You cease to stand firm against attempts to move you."})
  defs_data:set("vitality", { type = "kaido",
    on = {"Your body is already aglow with vitality.", "Your body positively glows with health and vitality."},
    def = "You will call upon your fortitude in need.",
    off = {"A surge of rejuvenating energy floods your system, healing your wounds.", "You cannot call upon your vitality again so soon."}})
  defs_data:set("immunity", { type = "kaido",
    on = "You close your eyes and grit your teeth, feeling the heat of the blood pumping through your veins.",
    off = "You cease concentrating on immunity."})
#end

#if skills.shikudo then
  local onenable_shikudo = function (mode, newdef, whereto, echoback)
    local shikudo_forms = {
      "tykonos",
      "willow",
      "rain",
      "oak",
      "gaital",
      "maelstrom"
    }

    local fail_string =
      "Removed %s from %s, it's incompatible with %s to have simultaneously up."

    for _, shikudo_form in ipairs(shikudo_forms) do
      if shikudo_form ~= newdef and svo["def"..whereto][mode][shikudo_form] then
        svo["def"..whereto][mode][shikudo_form] = false
        if echoback then echof(fail_string, shikudo_form, whereto, newdef) end
      end
    end

    return true
  end

  defs_data:set("tykonos", {
    type = "shikudo",
    onenable = onenable_shikudo,
    def = "You are enacting the Tykonos form.",
    on = "You spin your staff in the opening sequence of the form of Tykonos, snapping into a ready stance.",
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set("willow", {
    type = "shikudo",
    onenable = onenable_shikudo,
    def = "You are enacting the Willows shaken by the Wind form.",
    on = "Twirling your staff, you sink into the calm required for the form of Willows Shaken by the Wind.",
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set("rain", {
    type = "shikudo",
    onenable = onenable_shikudo,
    def = "You are enacting the Willows in Rain Storm form.",
    on = "Dropping into a lower stance, you snap your weapon into an offensive position, tensing your muscles in preparation for the form of Willows in Rain Storm.",
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set("oak", {
    type = "shikudo",
    onenable = onenable_shikudo,
    def = "You are enacting the the Live Oak form.",
    on = "Rising onto the balls of your feet, you prepare to begin the deadly form of the Live Oak.",
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set("gaital", {
    type = "shikudo",
    onenable = onenable_shikudo,
    def = "You are enacting the Gaital form.",
    on = "You let your eyes fall closed and instinct guide you as you flow into the form of Gaital.",
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set("maelstrom", {
    type = "shikudo",
    onenable = onenable_shikudo,
    def = "You are enacting the the Unrelenting Storm form.",
    on = "You allow your kai to flow through you, circulating throughout your limbs and down your weapon in preparation to begin the form of the Unrelenting Storm.",
    off = [[^You clumsily transition from the form of \w+ into the form of]]
  })
  defs_data:set("grip", {
    type = "shikudo",
    on = {"You concentrate on gripping tightly with your hands.", "You are already tightly gripping with your hands."},
    def = "Your hands are gripping your wielded items tightly.",
    off = "You relax your grip."})
#end

#if skills.tekura then
  defs_data:set("guarding", { nodef = true,
    ondef = function ()
      local t = sps.parry_currently
      for limb, _ in pairs(t) do t[limb] = false end
      t[matches[2]] = true
      check_sp_satisfied()

      return "("..matches[2]..")"
    end,
    tooltip = "Completely blocks health and wound damage on a limb if you aren't hindered.",
    defr = [[^You will attempt to throw those who attack your (.+)\.$]]
  })
  defs_data:set("bodyblock", { type = "tekura",
    mana = "lots",
    def = "You are trying to absorb blows to your body.",
    on = "You ready yourself to block as best you can.",
    off = {"You drop all your blocks.", "You lower your body block."}})
  defs_data:set("pinchblock", { type = "tekura",
    mana = "lots",
    def = "You will try to pinch block a weakened foe.",
    on = "You ready yourself to pinch block to the best of your ability.",
    off = {"You drop all your blocks.", "You lower your pinch block."}})
  defs_data:set("evadeblock", { type = "tekura",
    mana = "lots",
    def = "You are using Tekura to evade incoming attacks.",
    on = "You ready yourself to evade incoming blows.",
    off = {"You drop all your blocks.", "You lower your evade block."}})

  defs_data:set("horse", { type = "tekura",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You drop your legs into a sturdy Horse stance.",
    def = "You are in the Horse stance.",
    off = "You ease yourself out of the Horse stance."})
  defs_data:set("eagle", { type = "tekura",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You draw back and balance into the Eagle stance.",
    def = "You are in the Eagle stance.",
    off = "You ease yourself out of the Eagle stance."})
  defs_data:set("cat", { type = "tekura",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You tense your muscles and look about sharply as you take the stance of the Cat.",
    def = "You are in the Cat stance.",
    off = "You ease yourself out of the Cat stance."})
  defs_data:set("bear", { type = "tekura",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You draw yourself up to full height and roar aloud, adopting the Bear stance.",
    def = "You are in the Bear stance.",
    off = "You ease yourself out of the Bear stance."})
  defs_data:set("rat", { type = "tekura",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You take the Rat stance.",
    def = "You are in the Rat stance.",
    off = "You ease yourself out of the Rat stance."})
  defs_data:set("scorpion", { type = "tekura",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You sink back into the menacing stance of the Scorpion.",
    def = "You are in the Scorpion stance.",
    off = "You ease yourself out of the Scorpion stance."})
  defs_data:set("dragon", { type = "tekura",
    onenable = function (mode, newdef, whereto, echoback)
      for _, morph in ipairs{"horse", "eagle", "cat", "bear", "rat", "scorpion", "dragon"} do
        if morph ~= newdef and svo["def"..whereto][mode][morph] then
          svo["def"..whereto][mode][morph] = false
          if echoback then echof("Removed %s from %s, it's incompatible with %s to have simultaneously up.", morph, whereto, newdef) end
        end
      end

      return true
    end,

    on = "You allow the form of the Dragon to fill your mind and govern your actions.",
    def = "You are in the Dragon stance.",
    off = "You ease yourself out of the Dragon stance."})
#end

#if skills.telepathy then
  defs_data:set("mindtelesense", { type = "telepathy",
    mana = "lots",
    on = "You attune your mind to tampering from telepathy.",
    off = "You cease to concentrate your mind on mindlock attempts.",
    def = "You are using your telesense."})
  defs_data:set("mindcloak", { type = "telepathy",
    on = {"You will now begin to concentrate on cloaking your telepathy.", "You are already cloaking your attempts at mindlocking."},
    off = "You allow the mindcloak to drop.",
    def = "You are cloaking your attempts at establishing a mindlock."})
  defs_data:set("mindnet", { type = "telepathy",
    on = {"You cast an invisible mind net out into the distance, allowing it to settle about the surrounding land.", "You already have mindnet active."},
    off = "You cease concentration and your mind net vanishes.",
    mana = "little",
    def = "You have cast a mindnet over the local area."})
  defs_data:set("hypersense", { type = "telepathy",
    mana = "lots",
    on = "You begin detecting mindlock attempts in your local area.",
    off = "You turn hypersense off.",
    def = "You are using your hypersense."})
#end

#if skills.woodlore then
  defs_data:set("barkskin", { type = "woodlore",
    on = {"You concentrate for a moment, and your skin becomes rough and thick like tree bark.", "Your skin is already covered in protective bark.", "Your skin is already as tough as bark."},
    def = "Your skin is hard and tough like the bark of an oak tree."})
  defs_data:set("hiding", { type = "woodlore",
    on = {"You conceal yourself using all the guile you possess.", "You are already hidden."},
    def = "You have used great guile to conceal yourself.",
    off = {"You emerge from your hiding place.","You are discovered!","The flash of light illuminates you - you have been discovered!", "From what do you wish to emerge?"}})
  defs_data:set("spinning", { type = "woodlore",
    onr = [[^You begin to rapidly spin .+ in a defensive pattern\.$]],
    off = [[^You cease spinning .+\.$]]})
  defs_data:set("impaling", { type = "woodlore",
    onr = [[^You plant the butt end of .+ firmly on the ground and ready yourself to impale any charging enemies\.$]],
    def = "You are preparing to impale onrushing attackers.",
    off = "You cease your preparations to impale any charging enemies."})
  defs_data:set("evasion", { type = "woodlore",
    on = {"You must be in the air before you can begin evasive flying.", "You begin soaring erratically and frantically, attempting to avoid the eyes gazing up from below.", "You are already attempting to elude the prying eyes below."},
    def = "You are flying evasively.",
    off = {"You cease your aerial acrobatics.", "You are already not attempting to elude the prying eyes below."}})
  defs_data:set("firstaid", { type = "woodlore",
    on = {"You begin to concentrate on clotting your wounds.", "You have already turned on first aid." },
    off = {"You cease to concentrate on the clotting of your wounds.","You've already turned off first aid."},
    def = "You are concentrating on clotting your wounds."})
  defs_data:set("fleetness", { type = "woodlore",
    on = "You will seek out the best paths through the forest.",
    def = "You are able to navigate forests more easily."})
#end

#if skills.propagation then
  defs_data:set("barkskin", { type = "propagation",
    on = {"You concentrate for a moment, and your skin becomes rough and thick like tree bark.", "Your skin is already covered in protective bark.", "Your skin is already as tough as bark."},
    def = "Your skin is hard and tough like the bark of an oak tree."})
  defs_data:set("viridian", { type = "propagation",
    def = "You have taken the form of the Viridian.",
    off = "You will the vines to retreat, and you shed the form of the Viridian."})
#end

#if skills.groves then
  defs_data:set("panacea", { type = "groves",
    on = {"You call on the curative powers of Nature. A spiralling helix of wildflowers and lush leaves races up the length of your quarterstaff, before sublimating into a cool mist that drifts about your body.", "A healing mist already surrounds you, Forestwalker."},
    on_only = "You find your sunlight reserves too low to attempt that.",
    off = "The tendrils of delicate mist surrounding you disperse.",
    def = "You are surrounded by a healing mist."})
  defs_data:set("vigour", { type = "groves",
    on = {"You are bathed in radiant sunlight, its warm glow seeping into your skin.", "You are bathed in an aura of radiant sunlight.", "An aura of sunlight already radiates around that person."},
    off = "The radiant sunlight warming your body fades away.",
    on_only = "You find your sunlight reserves too low to attempt that.",
    def = "You are bathed in an aura of radiant sunlight."})
  defs_data:set("flail", { type = "groves",
    on = {"You flail the quarterstaff smoothly around in the air about you to summon up a defensive sphere.", "Your quarterstaff has already been flailed."},
    on_only = "You find your sunlight reserves too low to attempt that.",
    def = "You are flailing a wielded quarterstaff."})
  defs_data:set("wildgrowth", { type = "groves",
    def = "Your movements are trailed by profusions of wild growth.",
    on = {"You quietly recite an incantation calling on all that is wild and green. As you speak the final syllables, you slowly raise your quarterstaff skywards, drawing vibrant new growth from the earth.", "Wild vines already circle your feet."},
    on_only = "You find your sunlight reserves too low to attempt that.",
    off = "Curling in on itself, the tangle of wild green growth surrounding you retreats into the earth."})
  defs_data:set("dampening", { type = "groves",
    invisibledef = true,
    on_only = "You find your sunlight reserves too low to attempt that.",
    on = "You whirl your quarterstaff in a grand arc, and a distant rustling reaches your ears. Moments later, a flurry of leaves blankets the area with copper tones."})
  defs_data:set("snowstorm", { type = "groves",
    invisibledef = true,
    on_only = "You find your sunlight reserves too low to attempt that.",
    on = "You grip your quarterstaff tightly and with a whisper invoke winter's icy chill, the vapour of your breath growing visible as you speak. First scattered flakes and then great gusts of snow respond, as the area is overwhelmed by a glacial shroud of white."})
  defs_data:set("roots", { type = "groves",
    invisibledef = true,
    on_only = "You find your sunlight reserves too low to attempt that.",
    off = "The roots that secured you to the ground fall away and retreat back into the earth.",
    on = "Roots spring up from the rich earth beneath your feet and wreath themselves gently about your form."})
  defs_data:set("concealment", { type = "groves",
    invisibledef = true,
    off = "The undergrowth parts slightly, and banishes the gloom that seemed to hang here.",
    on_only = "You find your sunlight reserves too low to attempt that.",
    on = {"Your grove fills with gloom as the leaves huddle closer in secrecy.", "This grove is already concealed from prying eyes."}})
  defs_data:set("screen", { type = "groves",
    invisibledef = true,
    off = "A low fizzle can be heard as the tension in the grove decreases.",
    on_only = "You find your sunlight reserves too low to attempt that.",
    on = {"You call a telepathic screen into being around your grove.", "There is already a mind screen in existence here."}})
  defs_data:set("lyre", { type = "groves",
    on_only = "You find your sunlight reserves too low to attempt that.",
    specialskip = function() return not conf.lyre end,
    availableindragon = true,
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].meditate then
        svo["def"..whereto][mode].meditate = false
        if echoback then echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].breath then
        svo["def"..whereto][mode].breath = false
        if echoback then echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].flame then
        svo["def"..whereto][mode].flame = false
        if echoback then echof("Removed flame from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = {"You begin to weave a melody of magical, heart-rending beauty and a beautiful barrier of prismatic light surrounds you.", "You strum a Lasallian lyre, and a prismatic barrier forms around you.", "You deftly shape the wall of light into a barrier surrounding yourself.", "You strum a darkly glowing mandolin, and a prismatic barrier forms around you."},
    def = "You are standing within a prismatic barrier.",
    off = {"Your prismatic barrier dissolves into nothing.", "The stream hits your prismatic barrier, shattering it.", "The breath weapon rips apart your prismatic barrier.", "The breath weapon rips through both your shield and prismatic barrier.", "The spear shatters your prismatic barrier."}})
  defs_data:set("swarm", { type = "groves",
    invisibledef = true,
    on = {"You already have a swarm in the lands.", "Barely within the range of normal hearing, you utter a buzz-like hum from deep within your throat."}})
  defs_data:set("harmony", { nodef = true,
    ondef = function () return "("..matches[2]..")" end,
    defr = [[^You are under the blessing of the (\w+) environment\.$]]})
#end

#if skills.alchemy then
  defs_data:set("lead", { type = "alchemy",
    on = "Directing the energy of lead, you increase your mass and weigh yourself down.",
    off = "You feel your density return to normal.",
    def = "You are extremely heavy and difficult to move."})
  defs_data:set("tin", { type = "alchemy",
    on = {"Directing the energy of tin, you erect a reflective barrier about yourself.", "You are already surrounded by a protective barrier."},
    offr = [[^As \w+'s attack falls, your reflective barrier shatters and reflects the attack\.$]],
    def = "You are protected by a reflective barrier."})
  defs_data:set("sulphur", { type = "alchemy",
    on = {"Directing the energy of sulphur, you surround yourself with an aura of primal energies, bolstering your healing capacity.", "You are already drawing upon the power of sulphur."},
    off = "The symbol of sulphur inscribed about you fades away.",
    tooltip = "Boosts the effect of the vitality tonic.",
    def = "You are bolstered by the energy of sulphur."})
  defs_data:set("mercury", { type = "alchemy",
    on = {"Directing the energy of mercury, you surround yourself with an aura of primal energies, boosting your mental regeneration.", "You are already drawing upon the power of mercury."},
    off = "The symbol of mercury inscribed about you fades away.",
    tooltip = "Boosts the effect of the mentality tonic.",
    def = "You are bolstered by the energy of mercury."})
  defs_data:set("extispicy", { type = "alchemy",
    on = {"As you poke through the entrails, a pink and shiny intestine foretells good fortune.", "You've already divined the future, Alchemist.", "As you poke through the entrails, a bleeding ulcer predicts great victories."},
    def = "You have divined the future."})
  defs_data:set("empower", { type = "alchemy",
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
#end

#if skills.skirmishing then
  defs_data:set("scout", { type = "skirmishing",
    on = "You begin scouting ahead for danger.",
    def = {"You are able to scout passed obstructions.", "You are able to scout past obstructions."}})
#end

#if skills.shadowmancy then
  defs_data:set("shadowcloak", {
    type = "shadowmancy",
    custom_def_type = "shadowcloak",
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
  defs_data:set("disperse", {
    type = "shadowmancy",
    custom_def_type = "shadowcloak",
    on = {
      "The shadows swirl about you, masking you from view.",
      "You have already shrouded yourself in beguiling shadow."
    },
    def = "You are masking your egress."
   })
--shadowveil gives both shadowveil and hiding
  defs_data:set("shadowveil", {
    type = "shadowmancy",
    custom_def_type = "shadowcloak",
    on = {
      "Summoning the shadows to coalesce about your person, you vanish into their stygian embrace.",
      "You are already veiled within the shadows embrace.",
    },
    def = "Concealed by a shifting veil of shadow.",
   })
  defs_data:set("hiding", {
    type = "shadowmancy",
    custom_def_type = "shadowcloak",
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
    if gmcp.Char.Items.List.location ~= "inv" then
      return
    end
    for _, item in ipairs(gmcp.Char.Items.List.items) do
      if item.name == "a grim cloak" then
        if item.attrib and item.attrib:find("w") then
           defences.got("shadowcloak")
         else
           defences.lost("shadowcloak")
         end
         return
      end
    end
  end)
  signals.gmcpcharitemsadd:connect(function()
    if gmcp.Char.Items.Add.location ~= "inv" then
      return
    end
    for _, item in ipairs(gmcp.Char.Items.Add.item) do
      if item.name == "a grim cloak" then
        if item.attrib and item.attrib:find("w") then
          defences.got("shadowcloak")
        end
      end
    end
  end)
  signals.gmcpcharitemsremove:connect(function()
    if gmcp.Char.Items.Remove.location ~= "inv" then
      return
    end
    for _, item in ipairs(gmcp.Char.Items.Remove.item) do
      if item.name == "a grim cloak" then
        defences.lost("shadowcloak")
      end
    end
  end)
  signals.gmcpcharitemsupdate:connect(function()
    if gmcp.Char.Items.Update.location ~= "inv" then
      return
    end
    for _, item in ipairs(gmcp.Char.Items.Update.item) do
      if item.name == "a grim cloak" then
        if item.attrib and item.attrib:find("w") then
          defences.got("shadowcloak")
        end
      end
    end
  end)
#end


#if skills.aeonics then
  defs_data:set("blur", { type = "aeonics",
    def = "Travelling the world more quickly due to time dilation."
  })
  defs_data:set("dilation", { type = "aeonics",
    onenable = function (mode, newdef, whereto, echoback)
      if svo["def"..whereto][mode].breath then
        svo["def"..whereto][mode].breath = false
        if echoback then echof("Removed breath from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].meditate then
        svo["def"..whereto][mode].meditate = false
        if echoback then echof("Removed meditate from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end
      if svo["def"..whereto][mode].lyre then
        svo["def"..whereto][mode].lyre = false
        if echoback then echof("Removed lyre from %s, it's incompatible with %s to have simultaneously up.", whereto, newdef) end
      end

      return true
    end,
    on = "Growing very still, you begin to manipulate the flow of time around you, drastically speeding up your rate of regression.",
    off = {"Your concentration broken, you cease dilating time.", "Having fully regressed to your normal age, you cease dilating time."}})
#end

#if skills.terminus then
  defs_data:set("trusad", { type = "terminus",
    def = "You are enhancing your precision through the power of Terminus."
  })
  defs_data:set("tsuura", { type = "terminus",
    def = "You are enhancing your durability against denizens."
  })
  defs_data:set("ukhia", { type = "terminus",
    defr = "^You are focus?sing on quelling your bleeding more efficiently\.$"
  })
  defs_data:set("qamad", { type = "terminus",
    def = "You have a will of iron."
  })
  defs_data:set("mainaas", { type = "terminus",
    def = "You have augmented your own body for enhanced defence."
  })
  defs_data:set("gaiartha", {
    type = "terminus",
    staysindragon = true,
    def = "You are concentrating on maintaining control over your faculties."
  })
#else
  defs_data:set("gaiartha", { nodef = true,
    def = "You are concentrating on maintaining control over your faculties."
  })
#end

#if skills.weaving then
  defs_data:set("secondskin", { type = "weaving",
    on = { "You weave a second skin of armour over your body, protecting your vulnerable areas.",
      "You have already woven a protective layer of armour over your skin."
    },
    def = "You are protected by a layer of flexible armour."
  })
#end

#if skills.psionics then
  defs_data:set("comprehend", { type = "psionics",
    on = { "You begin directing your vast intellect to the problem of understanding foreign speech patterns.",
      "You are already directing your vast intellect to comprehending foreign speech patterns."
    },
    def = "You are focussing your vast intellect on comprehending language."
  })
  defs_data:set("transcend", {type = "psionics",
    on = { "You sink into tranquility; your mind and body transcending their limitations as they begin to function in perfect unity.",
    "Your mind has already transcended its limitations."
    },
    def = "You are of transcendent mind."
  })
  defs_data:set("breakthrough", { type = "psionics",
    on = { "A sharp pain behind your eyes is the precursor to an abrupt expansion of consciousness, your mental processes speeding to unnatural levels.",
      "Your mind is already operating at an extreme capacity."
    },
    off = "The rapture of your expanded mind abruptly flees you, leaving only the burning pain behind your eyes in its wake.",
    def = "You are pushing your mind beyond its limits."
  })
  defs_data:set("vanish", { type = "psionics",
    on = { "You begin focussing on destroying knowledge of yourself from the minds of those around you.",
    "You are already eradicating knowledge of your presence from the minds around you."
    },
    off = "Your focus breaks, your mind no longer able to sustain the rapid destruction of thought.",
    def = "You are annihilating knowledge from the minds around you."
  })
#end

#if skills.emulation then
  defs_data:set("guidedstrike", { type = "emulation",
    on = { "You focus on enhancing your personal luck.",
      "Your strikes are already guided by preternatural luck."
    },
    off = "Your strikes are no longer guided by unnatural luck.",
    def = "Your strikes are guided by unnatural luck."
  })
  defs_data:set("rupture", { type = "emulation",
    on = { "Your vision sharpens, allowing you to perceive the locations of every vein and artery that lies beneath the skin.",
      "Your blows will already rupture veins and arteries."
    },
    off = "Your vision returns to normal levels, no longer able to perceive the veins that lie beneath people's skin.",
    def = "Your blows will rupture veins and arteries with every strike."
  })
  defs_data:set("mentalclarity", { type = "emulation",
    on = { "A total focus overcomes you; the mundanity of everyday distractions unable to penetrate your clarity.",
      "Your clarity of thought already surpasses natural limits."
    },
    off = "Distractions reassert themselves, your mental clarity returning to mundane levels.",
    def = "Your mind is focussed to perfection."
  })
  defs_data:set("indomitability", { type = "emulation",
    on = { "Power suffuses every limb and strength burns inside of you; you are the indomitable and no blow shall see you fall.",
      "You are already channeling the indomitable might of the battlemaster."
    },
    off = "Your miriad image shatters under the onslaught.",
    def = "You is suffused with indomitable might."
  })
#end

do
  function defences.enablelifevision()
    if dict.lifevision then return end

    defs_data:set("lifevision", { type = "general",
      on = {"You narrow your eyes and blink rapidly, enhancing your vision to seek out sources of lifeforce in others.", "You already possess enhanced vision."},
      def = "You have enhanced your vision to be able to see traces of lifeforce."})

    dict.lifevision = {
      physical = {
        name = "lifevision_physical",
        balance = "physical",
        action_name = "lifevision",
        balanceful_act = true,
        aspriority = 0,
        spriority = 0,
        def = true,

        isadvisable = function ()
          return (not defc.lifevision and ((sys.deffing and defdefup[defs.mode].lifevision) or (conf.keepup and defkeepup[defs.mode].lifevision)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone) or false
        end,

        oncompleted = function ()
          defences.got("lifevision")
        end,

        action = "lifevision",
        onstart = function ()
          send("lifevision", conf.commandecho)
        end
      }
    }

    for mode,modet in pairs(defdefup) do
      defdefup[mode].lifevision = defdefup[mode].lifevision or false
      defkeepup[mode].lifevision = defkeepup[mode].lifevision or false
    end

    sk.ignored_defences.general.t.lifevision = sk.ignored_defences.general.t.lifevision or false
    sk.ignored_defences_map["lifevision"] = "general"

    defences.def_types["general"][#defences.def_types["general"]+1] = "lifevision"

    local v = defs_data.lifevision;
    local k = "lifevision";
    if v.on and type(v.on) == "table" then
      for n,m in ipairs(v.on) do
        (tempExactMatchTrigger or tempTrigger)(m, 'svo.defs.got_' .. sk.sanitize(k) .. '()')
      end
    elseif v.on then
      (tempExactMatchTrigger or tempTrigger)(v.on, 'svo.defs.got_' .. sk.sanitize(k) .. '()')
    end

    (tempExactMatchTrigger or tempTrigger)(v.def, 'svo.defs.def_' .. sk.sanitize(k) .. '()');

    defs["def_"..sk.sanitize(k)] = function ()
      if not v.ondef then
        defences.def_def_list[k] = true
      else
        defences.def_def_list[k] = v.ondef()
      end
      deleteLine()
    end
    defs["got_" .. k] = function ()
      defences.got(k)
    end
    defs["lost_" .. k] = function ()
      defences.lost(k)
    end

    -- create a snapshot of the before state for all balances, since dict_setup might mess with any
    local beforestate = sk.getbeforestateprios()

    dict_setup()
    dict_validate()

    -- notify any prio diffs
    local afterstate = sk.getafterstateprios()
    sk.notifypriodiffs(beforestate, afterstate)

    signals.dragonform:emit()

    echof("Have lifevision mask - enabled it for defup/keepup.")
  end

  function defences.checklifevision()
    local t = _G.gmcp.Char.Items.List
    if not t.location == "inv" then return end

    -- feh! Easier to hardcode it for such a miniscule amount of items.
    -- If list enlarges, fix appopriately.
    for _, it in pairs(t.items) do
      -- if it.name == "a Veil of the Sphinx" then
      if it.name == "a mask of lifevision" or it.name == "a painted basilisk mask" or it.name == "a silver mask with gold reliefs" then
        defences.enablelifevision()
        conf.havelifevision = true
        raiseEvent("svo config changed", "havelifevision")
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
  end)
  signals.gmcpcharitemslist:connect(defences.checklifevision)
end

do
  function defences.enableshroud()
    if dict.shroud then return end

    defs_data:set("shroud", { type = "general",
      on = {"You draw your Shadowcloak about you and blend into your surroundings.", "You draw a Shadowcloak about you and blend into your surroundings.", "You draw a cloak of the Blood Maiden about you and blend into your surroundings."},
      def = "Your actions are cloaked in secrecy.",
      off = {"Your shroud dissipates and you return to the realm of perception.", "The flash of light illuminates you - you have been discovered!"}})

    dict.shroud = {
      physical = {
        name = "shroud_physical",
        balance = "physical",
        action_name = "shroud",
        balanceful_act = true,
        aspriority = 0,
        spriority = 0,
        def = true,

        isadvisable = function ()
          return (not defc.shroud and ((sys.deffing and defdefup[defs.mode].shroud) or (conf.keepup and defkeepup[defs.mode].shroud)) and not codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.prone) or false
        end,

        oncompleted = function ()
          defences.got("shroud")
        end,

        action = "shroud",
        onstart = function ()
          send("shroud", conf.commandecho)
        end
      }
    }

    for mode,modet in pairs(defdefup) do
      defdefup[mode].shroud = defdefup[mode].shroud or false
      defkeepup[mode].shroud = defkeepup[mode].shroud or false
    end

    sk.ignored_defences.general.t.shroud = sk.ignored_defences.general.t.shroud or false
    sk.ignored_defences_map["shroud"] = "general"

    defences.def_types["general"][#defences.def_types["general"]+1] = "shroud"

    local v = defs_data.shroud;
    local k = "shroud";
    -- FIXME not to be such a hack!
    (tempExactMatchTrigger or tempTrigger)(v.on[1], 'svo.defs.got_' .. sk.sanitize(k) .. '()');
    (tempExactMatchTrigger or tempTrigger)(v.on[2], 'svo.defs.got_' .. sk.sanitize(k) .. '()');
    (tempExactMatchTrigger or tempTrigger)(v.def, 'svo.defs.def_' .. sk.sanitize(k) .. '()');
    (tempExactMatchTrigger or tempTrigger)(v.off[1], 'svo.defs.lost_' .. sk.sanitize(k) .. '()');
    (tempExactMatchTrigger or tempTrigger)(v.off[2], 'svo.defs.lost_' .. sk.sanitize(k) .. '()');

    defs["def_"..sk.sanitize(k)] = function ()
      if not v.ondef then
        defences.def_def_list[k] = true
      else
        defences.def_def_list[k] = v.ondef()
      end
      deleteLine()
    end
    defs["got_" .. k] = function ()
      defences.got(k)
    end
    defs["lost_" .. k] = function ()
      defences.lost(k)
    end

    -- create a snapshot of the before state for all balances, since dict_setup might mess with any
    local beforestate = sk.getbeforestateprios()

    dict_setup()
    dict_validate()

    -- notify any prio diffs
    local afterstate = sk.getafterstateprios()
    sk.notifypriodiffs(beforestate, afterstate)

    signals.dragonform:emit()

    echofn("Have Shadowcloak - enabled it for defup/keepup (")
    setFgColor(unpack(getDefaultColorNums))
    setUnderline(true)
    echoLink("disable", [[svo.conf.haveshroud = nil; svo.echof("Alright - won't add shroud to defup/keepup next time.") raiseEvent("svo config changed", "haveshroud")]], 'Click to disable shroud from getting added to defup/keepup next time', true)
    setUnderline(false)
    echo(")\n")
  end

  function defences.checkshroud()
    local t = _G.gmcp.Char.Items.List
    if not t.location == "inv" then return end

    for _, it in pairs(t.items) do
      if it.name:find("Shadowcloak", 1, true) then
        defences.enableshroud()
        conf.haveshroud = true
        raiseEvent("svo config changed", "haveshroud")
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
  end)
  signals.gmcpcharitemslist:connect(defences.checkshroud)
end

-- check for both shadowcloak and mask of lifevision
function detect_lifevision()
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

  return table.concat(t, "_")
end


defences.complete_def = function(tbl)
  local name, def, defr, tooltip = tbl.name, tbl.def, tbl.defr, tbl.tooltip
  local name = name:lower()

  if not defs_data[name] then return end

  defs_data[name].def = def or defs_data[name].def
  defs_data[name].defr = defr or defs_data[name].defr
  defs_data[name].tooltip = tooltip
end

sk.showwaitingdefup = function()
  return concatand(select(2, sk.have_defup_defs()))
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
      setFgColor(unpack(getDefaultColorNums))
      setUnderline(true) echoLink(defmode, '$(sys).defs.switch("'..defmode..'", true)', 'Switch to '..defmode..' defences mode', true) setUnderline(false)
    else
      fg"a_darkgreen"
      setUnderline(true) echoLink(defmode, '$(sys).defs.switch("'..defmode..'", true)', 'Currently in this defence mode. Click to redo defup', true) setUnderline(false)
    end

    if sys.deffing and defmode == defs.mode then
      echo(" (currently deffing)")
    end

    echo" ("
    fg"orange_red"setUnderline(true) echoLink('-', '$(sys).delete_defmode("'..defmode..'", true)', 'Delete '..defmode.. ' defences mode', true) setUnderline(false) setFgColor(unpack(getDefaultColorNums))
    echo", "
    fg"a_darkgreen" setUnderline(true) echoLink("c", 'printCmdLine("vcopy defmode '..defmode..' TO ")', "Copy "..defmode.." into a new or existing defence mode", true) setUnderline(false) setFgColor(unpack(getDefaultColorNums))
    echo")"

    if i == #t then echo " " else
      echo", "
    end
  end

  -- then an add the (+ add new), if we can
  if printCmdLine then
    echo("(")
    fg"a_darkgreen" setUnderline(true) echoLink("+ add new", 'printCmdLine("vcreate defmode ")', "Create a new defences mode", true) setUnderline(false) setFgColor(unpack(getDefaultColorNums))
    echo(")")
  end

  echo"\n"
end

defences.get_def_list = function ()
  local s = oneconcat(defdefup)

  if sys.deffing then
    s = string.gsub(s, "("..defs.mode..")", "(currently deffing) <0,250,0>%1" .. getDefaultColor())
  else
    s = string.gsub(s, "("..defs.mode..")", "<0,250,0>%1" .. getDefaultColor())
  end
  return s
end

-- nodefup is useful for relogging in, where you don't do defup, but you want keepup to be active
function defs.switch(which, echoback, nodefup)
  local sendf; if echoback then sendf = echof else sendf = errorf end

  if not which then
    sendf("To which mode do you want to switch to?") return
  end

  if not defdefup[which] then
    sendf("%s defence mode doesn't exist - the list is: %s", which, oneconcat(defdefup)) return
  end

  defs.mode = which

  if not nodefup and echoback then
    echof("Deffing up in %s defence mode.", defs.mode)
  end

  rift.precache = rift.precachedata[defs.mode]
  if not nodefup then sys.deffing = true end
  sk.fix_affs_and_defs()
  startStopWatch(defences.defup_timer)

  raiseEvent("svo switched defence mode", defs.mode)
  if not nodefup then raiseEvent("svo started defup", defs.mode) end

  make_gnomes_work()
  if not nodefup then defupfinish() end
end

function defs.quietswitch(which, echoback)
  local sendf; if echoback then sendf = echof else sendf = errorf end

  if not which then
    sendf("To which mode do you want to switch to?") return
  end

  if not defdefup[which] then
    sendf("%s defence mode doesn't exist - the list is: %s", which, oneconcat(defdefup)) return
  end

  defs.mode = which

  if echoback then
    echof("Deffing up in %s defence mode.", defs.mode)
  end

  rift.precache = rift.precachedata[defs.mode]
  sk.fix_affs_and_defs()
end

defupfinish = function ()
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
    echof("Ready for combat! (%s defences mode, took %s)", defs.mode, (timestring == "0.0s" and "no time" or timestring))
    raiseEvent("svo done defup", defs.mode)
    signals.donedefup:emit()
    showprompt()
  end
end

defupcancel = function(echoback)
  if sys.deffing then
    sys.deffing = false
    if echoback then echof("Cancelled defup.") end
  else
    if echoback then echof("Weren't doing defup already.") end
  end

  stopStopWatch(defences.defup_timer)
end

function defs.keepup(which, status, mode, echoback, reshow)
  local sendf; if echoback then sendf = echof else sendf = sendf end

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
  if type(status) == "string" then
    status = convert_string(status)
  end

  -- if it's invalid or wasn't given to us, toggle
  if status == nil then
    if defkeepup[mode][which] then status = false
    else status = true end
  end

  if status == true and defs_data[which].onenable then
    local s,m = defs_data[which].onenable(mode, which, "keepup", echoback)
    if not s then echof(m) return end
  end

  defkeepup[mode][which] = status
  raiseEvent("svo keepup changed", mode, which, status)

  if echoback then
    if defkeepup[mode][which] then
      echof("Will keep %s up%s.", which, (ignore[which] and ' (however it\'s on ignore right now)' or ''))
    else
      echof("Won't keep %s up anymore.", which)
    end

    if sys.deffing then
      echof("You're still in defup however, and keepup is after defup. Still waiting on: %s to be put up.", sk.showwaitingdefup())
    elseif not conf.keepup and status == true then
      echof("Keepup needs to be on, though.")
    end
  end

  sk.fix_affs_and_defs()
  make_gnomes_work()

  if reshow then show_keepup() echo"\n" end
end

function defs.defup(which, status, mode, echoback, reshow)
  local sendf; if echoback then sendf = echof else sendf = errorf end

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
  if type(status) == "string" then
    status = convert_string(status)
  end

  -- if it's invalid or wasn't given to us, toggle
  if status == nil then
    if defdefup[mode][which] then status = false
    else status = true end
  end

  if status == true and defs_data[which].onenable then
    local s,m = defs_data[which].onenable(mode, which, "defup", echoback)
    if not s then echof(m) return end
  end

  defdefup[mode][which] = status
  raiseEvent("svo defup changed", mode, which, status)

  if echoback then
    if defdefup[mode][which] then
      echof("Will put %s up in %s mode.", which, mode)
    else
      echof("Won't put %s up anymore in %s mode.", which, mode)
    end
  end

  if reshow then show_defup() echo"\n" end

  sk.fix_affs_and_defs()
  make_gnomes_work()
end


function create_defmode(which, echoback)
  local sendf; if echoback then sendf = echof end

  assert(which, "Which defences mode do you want to create?", sendf)
  assert(not (defdefup[which] and defkeepup[which]), which .. " defences mode already exists.", sendf)

  defdefup[which] = {}
  defkeepup[which] = {}

  for k,v in defs_data:iter() do
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

function copy_defmode(which, newname, echoback)
  local sendf; if echoback then sendf = echof end

  assert(which, "Which defences mode do you want to copy?", sendf)
  assert(defdefup[which] and defkeepup[which], which .. " defences mode doesn't exist.", sendf)
  assert(newname, "To which name do you want to rename " .. which .. " to?", sendf)

  defdefup[newname] = deepcopy(defdefup[which])
  defkeepup[newname] = deepcopy(defkeepup[which])
  rift.precachedata[newname] = deepcopy(rift.precachedata[which])
  if echoback then echof("Copied %s to %s.", which, newname) end
end

function rename_defmode(which, newmode, echoback)
  local sendf; if echoback then sendf = echof end

  assert(which, "Which defences mode do you want to rename?", sendf)
  assert(defdefup[which] and defkeepup[which], which .. " defences mode doesn't exist.", sendf)
  assert(newmode, "To which name do you want to rename " .. which .. " to?", sendf)

  if defs.mode == which then
    defs.mode = newmode
    if echoback then
      echof("Changed your current defence mode to %s", defs.mode)
    end
  end

  defdefup[newmode], defdefup[which] = defdefup[which], defdefup[newmode]
  defkeepup[newmode], defkeepup[which] = defkeepup[which], defkeepup[newmode]
  rift.precachedata[which], rift.precachedata[newmode] = rift.precachedata[newname], rift.precachedata[which]
  if echoback then echof("Renamed %s to %s.", which, newmode) end
end

function delete_defmode(which, echoback)
  local sendf; if echoback then sendf = echof end

  assert(which, "Which defences mode do you want to delete?", sendf)
  assert(defdefup[which] and defkeepup[which], which .. " defences mode doesn't exist.", sendf)
  assert(which ~= defs.mode, "You're currently in " .. which .. " defmode already - switch to another one first, and then delete this one.", sendf)

  defdefup[which], defkeepup[which], rift.precachedata[which] = nil, nil, nil

  if math.random(1, 10) == 1 then
    echof("Deleted '%s' defences mode.", which)
  else
    echof("Deleted '%s' defences mode. Forever!", which) end
end



function defload()
  local defdefup_t, defkeepup_t = {}, {}
  local defup_path, keepup_path = getMudletHomeDir() .. "/svo/defup+keepup/defup", getMudletHomeDir() .. "/svo/defup+keepup/keepup"

  if lfs.attributes(defup_path) then table.load(defup_path, defdefup_t) end
  if lfs.attributes(keepup_path) then table.load(keepup_path, defkeepup_t) end
  if lfs.attributes(getMudletHomeDir() .."/svo/defup+keepup/ignored_defences") then table.load(getMudletHomeDir() .."/svo/defup+keepup/ignored_defences", sk.ignored_defences) end

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
    if def ~= "dragonform" then
      t[#t+1] = defc
    end
  end

  for i = 1, #t do
    defences.lost(t[i])
  end
end)

-- re-set defences mode to basic upon qqing and relogging in without closing Mudlet
function sk.loginonbasic()
  -- defs.mode = "" -- small hack to have the defup start event be raised when logging in for the first time, can't have the value on "" to begin with because the mode is always expected to be valid
  defs.switch("basic", true, true)

  -- disable initial connect and only use relogin after the first time
  signals.charname:disconnect(sk.loginonbasic)
  signals.gmcpcharname:disconnect(sk.loginonbasic)
end
signals.relogin:connect(sk.loginonbasic)
signals.charname:connect(sk.loginonbasic)
signals.gmcpcharname:connect(sk.loginonbasic)

signals.saveconfig:connect(function ()
  table.save(getMudletHomeDir() .. "/svo/defup+keepup/defup", defdefup)
  table.save(getMudletHomeDir() .. "/svo/defup+keepup/keepup", defkeepup)
  table.save(getMudletHomeDir() .. "/svo/defup+keepup/ignored_defences", sk.ignored_defences)

  local t = {}
  for k,v in defs_data:iter() do if v.offline_defence and defc[k] then t[#t+1] = k end end
  table.save(getMudletHomeDir() .. "/svo/defup+keepup/offline_defences", t)
end)

function sk.sanitize(self)
  return string.gsub(self, " ", "_")
end

function sk.desanitize(self)
  return string.gsub(self, "_", " ")
end

signals.systemstart:connect(function ()
  local defdefup_t, defkeepup_t = {}, {}
  defdefup_t, defkeepup_t = defload()

  -- create blank defup modes
  for k,v in pairs(defdefup_t) do
    defdefup[k] = defdefup[k] or {}
    defkeepup[k] = defkeepup[k] or {}
  end


  for k,v in defs_data:iter() do
    -- sort into def types if applicable
    if v.custom_def_type then
      defences.custom_types[v.custom_def_type] = defences.custom_types[v.custom_def_type] or {}
      defences.custom_types[v.custom_def_type][k] = true
    end

    if v.onr and type(v.onr) == "table" then
      for n,m in ipairs(v.onr) do
        tempRegexTrigger(m, 'svo.defs.got_' .. sk.sanitize(k) .. '()')
      end
    elseif v.onr then
      tempRegexTrigger(v.onr, 'svo.defs.got_' .. sk.sanitize(k) .. '()')
    end

    if v.on and type(v.on) == "table" then
      for n,m in ipairs(v.on) do
        (tempExactMatchTrigger or tempTrigger)(m, 'svo.defs.got_' .. sk.sanitize(k) .. '()')
      end
    elseif v.on then
      (tempExactMatchTrigger or tempTrigger)(v.on, 'svo.defs.got_' .. sk.sanitize(k) .. '()')
    end

    if v.on_only and type(v.on_only) == "table" then
      for n,m in ipairs(v.on_only) do
        (tempExactMatchTrigger or tempTrigger)(m, 'svo.defs.gotonly_' .. sk.sanitize(k) .. '()')
      end
    elseif v.on_only then
      (tempExactMatchTrigger or tempTrigger)(v.on_only, 'svo.defs.gotonly_' .. sk.sanitize(k) .. '()')
    end

    if v.on_free then (tempExactMatchTrigger or tempTrigger)(v.on_free, 'svo.defs.got_' .. sk.sanitize(k) .. '()') end

    if v.offr and type(v.offr) == "string" then
        tempRegexTrigger(v.offr, 'svo.defs.lost_' .. sk.sanitize(k) .. '()')
    elseif v.offr then
      for n,m in ipairs(v.offr) do
        tempRegexTrigger(m, 'svo.defs.lost_' .. sk.sanitize(k) .. '()')
      end
    end

    if v.off and type(v.off) == "string" then
        (tempExactMatchTrigger or tempTrigger)(v.off, 'svo.defs.lost_' .. sk.sanitize(k) .. '()')
    elseif v.off then
      for n,m in ipairs(v.off) do
        (tempExactMatchTrigger or tempTrigger)(m, 'svo.defs.lost_' .. sk.sanitize(k) .. '()')
      end
    end

    -- this is EXACTLY for substring
    if v.offs and type(v.offs) == "string" then
        tempTrigger(v.offs, 'svo.defs.lost_' .. sk.sanitize(k) .. '()')
    elseif v.offs then
      for n,m in ipairs(v.offs) do
        tempTrigger(m, 'svo.defs.lost_' .. sk.sanitize(k) .. '()')
      end
    end

    if v.off_free then (tempExactMatchTrigger or tempTrigger)(v.off_free, 'svo.defs.lost_' .. sk.sanitize(k) .. '()') end

    if v.def and type(v.def) == "table" then
      for n,m in ipairs(v.def) do
        (tempExactMatchTrigger or tempTrigger)(m, 'svo.defs.def_' .. sk.sanitize(k) .. '()')
      end
    elseif v.def then
      (tempExactMatchTrigger or tempTrigger)(v.def, 'svo.defs.def_' .. sk.sanitize(k) .. '()')
    end

    if v.defr and type(v.defr) == "table" then
      for n,m in ipairs(v.defr) do
        tempRegexTrigger(m, 'svo.defs.def_' .. sk.sanitize(k) .. '()')
      end
    elseif v.defr then
      tempRegexTrigger(v.defr, 'svo.defs.def_' .. sk.sanitize(k) .. '()')
    end

    if not defs["got_" .. k] then
      if dict[k] then
        -- rely on the fact that defs only have 1 item in them
        local bal
        for kk,vv in pairs(dict[k]) do if type(vv) == "table" and kk ~= "gone" then bal = kk break end end
        if bal then
          defs["got_" .. k] = function (force)
#if skills.metamorphosis then
            if v.custom_def_type or usingbal(bal) then checkaction(dict[k][bal], true)
            else checkaction(dict[k][bal], force) end
#else
            if not v.custom_def_type then checkaction(dict[k][bal], force) else checkaction(dict[k][bal], true) end
#end
            if actions[k .. "_" .. bal] then
              if force then --bypass lifevision for gmcp/other "force" situations
                actionfinished(actions[k .. "_" .. bal].p)
              else
                lifevision.add(actions[k .. "_" .. bal].p)
              end
            end
          end
        end
      end

      if not defs["got_" .. k] then
        defs["got_" .. k] = function ()
          defences.got(k)
        end
      end
    end

    if v.on_only and not defs["gotonly_" .. k] then
      if dict[k] then
        -- rely on the fact that defs only have 1 item in them
        local bal
        for kk,vv in pairs(dict[k]) do
          if type(vv) == "table" and kk ~= "gone" then bal = kk break end
        end
        defs["gotonly_" .. k] = function ()
          checkaction(dict[k][bal], false)
          if actions[k .. "_" .. bal] then
            lifevision.add(actions[k .. "_" .. bal].p)
          end
        end
      else
        defs["gotonly_" .. k] = function ()
          defences.got(k)
        end
      end
    end

    if not defs["lost_" .. sk.sanitize(k)] then
      if dict[k] and dict[k].gone then
        defs["lost_" .. k] = function ()
          checkaction(dict[k].gone, true)
          if actions[k .. "_gone"] then
            lifevision.add(actions[k .. "_gone"].p)
          end
        end
      else
        defs["lost_" .. k] = function ()
          defences.lost(k)
        end
      end
    end

    if not v.nodef and not v.custom_def_type then
      defs["def_"..sk.sanitize(k)] = function ()

        -- if we're in dragonform and this isn't a general or a dragoncraft def, then remember it as an additional def - not a class skill one, since those are not shown in Dragon
        if defc.dragonform and v.type ~= "general" and v.type ~= "dragoncraft" then
          if not v.ondef then
            defences.nodef_list[k] = true
          else
            defences.nodef_list[k] = v.ondef()
          end
        else
          if not v.ondef then
            defences.def_def_list[k] = true
          else
            defences.def_def_list[k] = v.ondef()
          end
        end
        deleteLine()
      end
    elseif not v.nodef and v.custom_def_type then
      defs["def_"..sk.sanitize(k)] = function ()
        defences.got(k)
        deleteLine()
      end

    -- additional defence (nodef)
    else
      defs["def_"..sk.sanitize(k)] = function ()
      -- only accept the def line if we know that we're parsing the def list currently, so lines similar to ones on the DEFENCES list that show up elsewhere don't mess things up
        if not actions.defcheck_physical then return end

        deleteLine()
        if not v.ondef then
          defences.nodef_list[k] = true
        else
          defences.nodef_list[k] = v.ondef()
        end
      end
    end

    -- fill up our defences.def_types
    if v.type then
      defences.def_types[v.type] = defences.def_types[v.type] or {}
      defences.def_types[v.type][#defences.def_types[v.type]+1] = k
    end

    -- create blanks for defup and keepup
    if not v.nodef then
      for mode,modet in pairs(defdefup) do
        defdefup[mode][k] = false
        defkeepup[mode][k] = false
      end
    end


    if v.type then
      sk.ignored_defences[v.type] = sk.ignored_defences[v.type] or {status = false, t = {}}
      sk.ignored_defences[v.type].t[k] = sk.ignored_defences[v.type].t[k] or false
      sk.ignored_defences_map[k] = v.type
    end
  end

  update(defdefup, defdefup_t)
  update(defkeepup, defkeepup_t)

  -- remove skillsets from ignorelist that we don't have, for people that change
  for skillset, _ in pairs(sk.ignored_defences) do
    if skillset ~= "general" and skillset ~= "enchantment" and skillset ~= "dragoncraft" and not me.skills[skillset] then
      sk.ignored_defences[skillset] = nil
    end
  end


  -- simple way of removing all and adding per line
  for name, data in pairs(defences.custom_types) do
    defs["def"..name.."start"] = function()
      for def, _ in pairs(defences.custom_types[name]) do
        defences.lost(def)
      end
    end
  end
end)

-- customize for gag
defs["lost_shield"] = function ()
  checkaction(dict.shield.gone, true)
  if actions["shield_gone"] then
    lifevision.add(actions["shield_gone"].p)
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
defs["lost_riding"] = function()
  -- force it so unwilling dismount is counted
  checkaction(dict.riding.physical, true)
  if actions["riding_physical"] then
    lifevision.add(actions["riding_physical"].p, "dismount")
  end
end

defs["block_failed"] = function()
  checkaction(dict.block.physical, true)
  if actions["block_physical"] then
    lifevision.add(actions["block_physical"].p, "failed")
  end
end

function defs.defprompt()
  show_current_defs()

  -- see if we need to show any additional defences
  local function check_additionals()
    for def, _ in defences.nodef_list:pairs() do
      if defs_data[def] and (defs_data[def].nodef or (defc.dragonform and defs_data[def].type ~= "dragoncraft" and defs_data[def].type ~= "general")) then return true end
    end
  end

  if check_additionals() then
    echof("Additional defences:")
    local count = 1
    for def, value in defences.nodef_list:pairs() do
      if defs_data[def] and (defs_data[def].nodef or (defc.dragonform and defs_data[def].type ~= "dragoncraft" and defs_data[def].type ~= "general")) then
        if value == true then
          decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", sk.desanitize(def)))
        else
          decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", sk.desanitize(def) .. " " .. tostring(value)))
        end

        if count % 3 == 0 then echo("\n") end
        count = count + 1
      end
    end
    count = 1 echo("\n")

  end
  defences.nodef_list = phpTable()
  defences.def_def_list = {}
  showprompt()
end

function defs.defstart()
  checkaction(dict.defcheck.physical)
  if actions.defcheck_physical then
    deleteLine()

    -- reset parry, as no parry won't show a line
    local t = sps.parry_currently
    for limb, _ in pairs(t) do t[limb] = false end
    check_sp_satisfied()
  end
end

-- last line of 'def' that shows your count
function defs.defline()
  checkaction(dict.defcheck.physical)
  if actions.defcheck_physical then
    deleteLine()
    tempLineTrigger(1, 1, 'selectString(line, 1) replace""')
    lifevision.add(actions.defcheck_physical.p)
  end
end

process_defs = function ()
  local addback = {}

  for defn, deft in pairs(defc) do
    -- clear ones we don't have
    if defc[defn] and not defences.def_def_list[defn] and not (defs_data[defn] and (defs_data[defn].invisibledef or defs_data[defn].custom_def_type)) then
      if dict[defn] and dict[defn].gone then
        checkaction(dict[defn].gone, true)
        lifevision.add(actions[defn.."_gone"].p)
      else
        defences.lost(defn)
      end
    elseif defc[defn] and defences.def_def_list[defn] and not (defs_data[defn] and defs_data[defn].custom_def_type) then -- if we do have it, remove from def list
      addback[defn] = defences.def_def_list[defn]
      defences.def_def_list[defn] = nil
    end
  end

  -- add left over ones
  for j,k in pairs(defences.def_def_list) do
    local bal
    for kk,vv in pairs(dict[j] or {}) do if type(vv) == "table" and kk ~= "gone" then bal = kk break end end
    if bal and dict[j][bal].oncompleted then
        dict[j][bal].oncompleted(true)
    else
      defences.got(j)
    end
  end

  for k,v in pairs(addback) do defences.def_def_list[k] = v end


  tempTimer(0, defs.defprompt)
end

-- prints out a def table
local function show_defs(tbl, linkcommand, cmdname)
  local count = 1

  local olddechoLink = dechoLink
  local function dechoLink(text, command, hint)
    olddechoLink(text, command, hint, true)
  end

  local function show_em(skillset, what)
    if skillset and not sk.ignored_defences[skillset].status then echof("%s defences:", skillset:title()) end
    for c,def in ipairs(what) do
      local disabled = ((sk.ignored_defences[skillset] and sk.ignored_defences[skillset].status) and true or (sk.ignored_defences[sk.ignored_defences_map[def]].t[def]))

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
            if type(defences.nodef_list[def]) == "string" then
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def.." ("..defences.nodef_list[def]..")"))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %-23s", def.." ("..defences.nodef_list[def]..")"), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
              defences.nodef_list[def] = nil
            elseif type(defences.def_def_list[def]) == "string" then
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
          elseif defs_data[def].mana == "little" then
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
            if type(defences.nodef_list[def]) == "string" then
              if not linkcommand or not dechoLink then
                decho(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %s", def.." ("..defences.nodef_list[def]..")"))
              else
                dechoLink(string.format("<153,204,204>[<0,204,0>X<153,204,204>] %s", def.." ("..defences.nodef_list[def]..")"), string.format("%s('%s', nil, nil, false, true)", linkcommand, def), string.format("Remove %s from %s", def, cmdname))
              end
              defences.nodef_list[def] = nil
            elseif type(defences.def_def_list[def]) == "string" then
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
          elseif defs_data[def].mana == "little" then
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
    show_em("dragoncraft", defences.def_types.dragoncraft)
  else

    for skillset,s in pairs(defences.def_types) do
      if skillset ~= "general" and skillset ~= "dragoncraft" then show_em (skillset, s) end
    end
  end

  _G.setUnderline = underline
end

function show_current_defs(window)
  svo.echof(window or "main", "Your current defences (%d):", (function ()
    local count = 0
    for k,v in pairs(defc) do if v then count = count + 1 end end
    for k,v in defences.nodef_list:pairs() do
      if v then count = count + 1 end end
    return count
  end)())

  if not window then
    show_defs(defc)
  else
    sk.echofwindow = window
    local olddecho, oldecho = decho, echo
    decho, echo = ofs.windowdecho, ofs.windowecho

    show_defs(defc)

    decho, echo = olddecho, oldecho
  end
end

function show_defup()
  svo.echof("%s defup defences (click to toggle):", defs.mode:title())
  show_defs(defdefup[defs.mode], "svo.defs.defup", "defup")
  showprompt()
end

function show_keepup()
  if not conf.serverside then
    echof("%s keepup defences (click to toggle):", defs.mode:title())
  else
    echofn("%s keepup defences (click to toggle) (", defs.mode:title())

    setFgColor(unpack(getDefaultColorNums))
    setUnderline(true)
    echoLink("view serverside keepup", [[send'CURING PRIORITY DEFENCE LIST']], "Click to view serverside's keepup list - which'll be the same as Svof's", true)
    setUnderline(false)
    echo(")\n")
  end
  show_defs(defkeepup[defs.mode], "svo.defs.keepup", "keepup")
  showprompt()
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
    or ignore[def]
      -- or it's not a general or dragon defence and we're in dragon
    or (defc.dragonform and not (deft.type == "general" or deft.type == "dragoncraft"))) and not deft.nodef then
      if dict[def] then
        if dict[def].physical and not dict_balanceful_def[def] and not dict_balanceless_def[def] then
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
      if dict[a] and dict[b] and dict[a].physical and dict[b].physical then
        return dict[a].physical.aspriority > dict[b].physical.aspriority
      end
    end)

  if #waitingon > 0 then return false, waitingon
  else return true end
end;

function ignoreskill(skill, newstatus, echoback)
  local skill = skill:lower()

  -- first, check if this is a group we're disabling as a whole
  if sk.ignored_defences[skill] then
    sk.ignored_defences[skill].status = newstatus
    showhidelist() return
  end

  -- otherwise, loop through all skillsets, looking for the skill
  for _, group in pairs(sk.ignored_defences) do
    for skills, _ in pairs(group.t) do
      if skills == skill then
        group.t[skill] = newstatus
        showhidelist() return
      end
    end
  end
end

function showhidelist()
  local enabled_c, disabled_c = "<242,218,218>", "<156,140,140>"

  -- adds in the link with a proper tooltip
  local function makelink(skill, sign, groupstatus)
    if sign == "+" then
      echoLink(sign, [[svo.ignoreskill("]]..skill..[[", false, true)]],
        string.format("Click to start showing " .. skill.."%s", groupstatus and " (won't do anything since the group is disabled, though)" or ""), true)
    elseif sign == "-" then
      echoLink(sign, [[svo.ignoreskill("]]..skill..[[", true, true)]],
        string.format("Click to hide " .. skill.."%s", groupstatus and " (won't do anything since the group is disabled, though)" or ""), true)
    else
      echo " "
    end

    return ""
  end

  local count = 1
  -- shows a specific defences group
  local function show_em(name, what)
    decho(string.format("%s%s %s defences:\n",
      (what.status and disabled_c or enabled_c),
      makelink(name, (what.status and "+" or "-")),
      name:title()))

    -- loops through all defences within the group
    for def,disabled in pairs(what.t) do
      -- if the whole group is disabled, then all things inside it should be as well
      local skill_color = (what.status and true or disabled)

      if count % 3 == 1 then echo"  " end
      if (count % 3) ~= 0 then
        decho(string.format("%s%s %-23s",
          (skill_color and disabled_c or enabled_c),
          makelink(def, (disabled and "+" or "-"), what.status),
          def))
      else
        decho(string.format("%s%s %s",
          (skill_color and disabled_c or enabled_c),
          makelink(def, (disabled and "+" or "-"), what.status),
          def))
      end

      if count % 3 == 0 then echo("\n") end
      --~ if count % 3 ~= 1 then echo("  ") end
      count = count + 1
    end

    if count %3 ~= 1 then echo("\n") end
    count = 1
  end

  echof("Select which skillsets or skills to show in defence display lists:")
  show_em("general", sk.ignored_defences.general)

  local function f()
    for j,k in pairs(sk.ignored_defences) do
      if j ~= "general" then show_em (j, k) end
    end
  end

  local s,_ = pcall(f)
  if not s then echof("Your Mudlet version doesn't seem to be new enough to display this; please update to latest (http://forums.mudlet.org/viewtopic.php?f=5&t=1874)") end
end
