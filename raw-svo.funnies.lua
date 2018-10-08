-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local life = svo.life
life.hellotrigs = {}

life.hellodata = {
  ["Dusk has overtaken the light in Achaea."] = function ()
    local t = {"Good evening.", "Good evening, " .. svo.sys.charname..".", "Hello!"}
    svo.echof(t[math.random(1, #t)])
  end,
  ["It is dusk in Achaea."] = function ()
    local t = {"Good evening.", "Good evening, " .. svo.sys.charname..".", "Hello!"}
    svo.echof(t[math.random(1, #t)])
  end,

  ["It is deep night in Achaea, before midnight."] = function ()
    local t = {"*yawn*. Hi.", "Ello. It's a lovely night tonight.", "What a night. Look at the stars!"}
    svo.echof(t[math.random(1, #t)])
  end,
  ["It is early morning in Achaea."] = function ()
    local t = {"*yawn*. Morning!", "Gooood morning, " .. svo.sys.charname .. "!", "Hello!", "Morning!"}
    svo.echof(t[math.random(1, #t)])
  end,
  ["It is early afternoon in Achaea."] = function ()
    local t = {"Good afternoon.", "Good afternoon, " .. svo.sys.charname .. ".", "Hello!", "hi!"}
    svo.echof(t[math.random(1, #t)])
  end,
}

life.hellodata["It is the middle of the night in Achaea."] = life.hellodata["It is deep night in Achaea, before midnight."]
life.hellodata["You think that it is currently night-time up above."] = life.hellodata["It is deep night in Achaea, before midnight."]
life.hellodata["Darkness rules the land. It is deepest midnight."] = life.hellodata["It is deep night in Achaea, before midnight."]
life.hellodata["It is late night, approaching dawn."] = life.hellodata["It is deep night in Achaea, before midnight."]
life.hellodata["The shadows have lengthened. It is late afternoon in Achaea."] = life.hellodata["It is early afternoon in Achaea."]
life.hellodata["It's mid-morning in Achaea."] = life.hellodata["It is early morning in Achaea."]
life.hellodata["The sun has awakened from its long slumber. It is dawn."] = life.hellodata["It is early morning in Achaea."]
life.hellodata["The sun sits at its apex. It is exactly noon."] = life.hellodata["It is early afternoon in Achaea."]
life.hellodata["You think that it is currently day-time up above."] = life.hellodata["It is early afternoon in Achaea."]

svo.protips = {
  "You can do 'vconfig warningtype right' to have the instakill warnings be less spammy",
  "You can toggle sbites and stabs to ignore bites or doublestabs with only one venom from Serpents",
  "You can toggle 'tsc' to toggle command overriding or denying in aeon or retardation. The autotsc will also automatically toggle this for you",
  "'lp' will relight all pipes manually",
  "'inra' will store away all riftables in the rift",
  "You can customize when the system uses the tree tattoo with your own custom scenarios",
  "You can customize when the system uses the restore skill with your own custom scenarios",
  "You can use 'vdefs cancel' to cancel defup",
  "You can use 'fl' to get to full stats, and chain it with commands to do after you're good - ie 'fl write journal', 'fl board ship, 'fl challenge person'",
  "You can use 'pva' to toggle quickly between paralysis and asthma priority",
  "You can use 'pvd' to toggle quickly between paralysis and darkshade priority",
  "You can use 'avs' to toggle quickly between impatience and slickness priority (apostate vs serpent)",
  "You can use svo.prompttrigger() to trigger actions to be done on the next prompt. Can come in very handy in scripting",
  "Basic keepup is done at login for you, so you might want to be conservative about what you put on basic keepup - and instead put most of the defs on defup, or in another mode",
  "You can create your own priority lists, and swap them in depending on your fighting conditions",
  "You can add names not to be autorejected with vconfig lustlist <name>",
  "You can add names not to writhe against with vconfig hoistlist <name>",
  "No illusions will be checked with anti-illusion off. If you're worried, it's best to leave it on",
  "If you attach flame sigils to your pipes, you can't be forced to put them in your container",
  "Be extra careful in blackout. People use it, obviously enough, to hide things from you",
  "Review your fight logs. There's always room for improvement",
  "This is a game, and it should be entertaining. If it's not - consider something else",
  "Pay attention in raids! Group cohesiveness demands attention and quick action",
  "When your group leader is spamming into your block to move, take that as a hint to unblock quickly",
  "You can use vconfig showbaltimes to see how long your balance & equilibrium actions took",
  "With vconfig gagpipes on, the system will light all 3 pipes whenever one goes out for better assurance",
  "It might be a good idea to clear your target if they raise deliverance - can save you from accidentally hitting them. Search for Svof's \"Deliverance\" trigger for the pattern on that",
  "Svof can plot people on the mapper for you! With the peopletracker addon you have, open the Mudlet map and make sure you have the latest mapper script",
  "You can do 'qwho' with the peopletracker addon to plot people on the map",
  "You can do 'qwhom' to see a nicer list of where everyone is located, along with 'qwhom <area>'",
  "You can do 'ppin <area>' after doing qwho to report on your ccto what people are in an area",
  "You can do 'ppwith <person>' after doing qwho to report the people grouped with someone to your ccto",
  "You can do vconfig ccto pt, vconfig ccto tell <person>, vconfig ccto ot, vconfig ccto echo and vconfig ccto <short clan name> to configure where ccto messages go",
  "You can use gotop or gotop <person> with the peopletracker addon after locating them to go to them",
  "If a name is on the map, you can gotop <name> to get to it",
  "With the peopletracker addon, you can just use 'gotop' to go to the last known location of the person in the 'target' variable",
  "hh quickly toggles between health and mana priority",
  "Some limbcounters (not Svof's) reset when you apply a salve to a limb after an attack - if you know that's the case, you could trigger to randomly apply mending to a limb they just hit!",
  "You can make colour logs by selecting text, right-clicking and selecting 'copy to HTML'. Then paste it into pastehtml.com and share the link",
  "Find out which of your abilities are completely hidden in blackout - you can cause blackout by obtaining dust bombs and throwing them at the ground",
  "You can make your own echos colour schemes and select them with 'vshow colors'. See docs on how!",
  "You can customize which defences, or even skillsets, show up in def lists with vshow hidelist",
  "Svof comes with a built-in logger: you can do 'startlog' to log, and 'stoplog' to stop logging",
  "You might want to turn focus use off against experienced Priests to save on mana",
  "It'd be good to adjust your vconfig manause amount to something above 50 against Apostates, Alchemists or Priests - this'll sure the system doesn't use mana for curing when you're getting close to instakill levels",
  "cll (and cll on, cll off) is a shortcut for vconfig clot - toggles clotting on/off",
  "va (and va on, va off) is a shortcut for vkeep riding - toggles auto-mounting or auto-dismounting. If you'd like to disable this, you can do vignore riding",
  "Disabling clotting against an Apostate might be a good idea - this'll save you precious mana. Just keep tabs on how much you're bleeding for",
  "Noticed an opponent stopped hitting certain limbs of yours? They're likely prepped now. You could break them yourself by bouncing off their rebounding aura on that limb",
  "You can use svo.boxDisplay(\"message here\", \"foreground color:background color\") to make giant echoes",
  "The system is your tool; it's in your interest to master it",
  "You can use vconfig manause # to mod the % of mana below which the system won't be using mana skills and will be trying for alternatives. You want to be upping this against Apostates, Alchemists, Priests",
  "Svof doesn't make you edit text files for any settings - everything is accessible from vconfig options, or clickable menus of vshow, vconfig, vconfig2",
  "To lock areas in the mapper, type 'arealock' or 'arealock area' and click on the Lock! buttons",
  "Mudlet's errors view is in Scripts -> Errors, the button is bottom-left",
  "You can use Svof's echos by doing svo.echof(\"stuff\")",
  "Need to catch a breather in retardation and cure up? Tumble out - Svof will send all curing commands right when you get out of the room. Good chance you'll get braziered back in though",
  "You can use svo.concatand(mytable) to bring all the items together in a list, with a proper 'and' at the end",
  "You can use svo.deleteLineP() to completely gag the line and the prompt coming after it",
  "'vshow herbstat' shows what Svof thinks of your herb inventory and updates real-time!",
  "You can do \"vlua svo.protips\" to see all of the svo.protips",
  "The extra Svof's in the Package Manager are OK - those are the addons",
  [[When you're scripting, you can make Svof do an action for you in the proper way via the svo.doaction("<action>", "<balance>") function - for example svo.doaction('healmana', 'sip') will properly sip mana or mentality, depending on the users settings and what they actually have]],
  [[vconfig lag 4 - for those times when you're on a hawaiian mountainside catching DSL wifi through a rain catchment tank during a heavy jungle rain]],
  "You can look at vshow curelist for a forestal <-> alchemist equivalents table, and configure prefercustom curemethod from right there",
  "vlua can work as a calculator - try it, do vlua 2+2",
  "If bleeding a ton, switch your sipping priority to mana as long as you can afford it to clot away quicker",
  "Use qwho <area> to see if any ungemmed people are bashing in an area before walking there",
  "Svof is designed to be a platform for your system - there's loads of things you can build on top of it. Check out the docs for anything you'd like to do!",
  "Attach flame sigils to your pipes so you can't be forced to put them away in your pack. You can still be forced to drop them, though",
  "You can pre-block a direction with b <direction> before moving, to help combat beckon triggered on alertness (you can also spam manual block to help with that too)",
  "You can use dop to toggle the do queue - useful in bashing, when you don't want to dor off/dor <bashing alias> again",
  "Svof is not an acronym! Just a short name...",
  "'ndb' shows you a cheatsheet for NameDB! You can hover over or click on aliases to see an explanation.",
  "'ndb long' shows you a cheatsheet for NameDB!",
  "Svof has a very thorough Lyre mode built-in - check the manual on how to make use of it",
  "You can make use of the 'svo system loaded' event to stop having to shuffle your scripts down after upgrading",
  "Proning your hoister is the quickest way to get down - if you're setup for that, you can do 'vignore hoisted' to have the system not autowrithe for you",
  "You can sit and sleep without needing to pause the system",
  "You can use 'shh' to toggle sipping health before all prios in retardation curing mode",
  "You can use vp <balance> to view & change priorities for a balance",
  "The (a) that pops up on aeon/retardation is clickable - clicking on it will show what actions was the system considering/doing",
  "You can use vset <aff name> <balance> <priority number> to move a prio to a position and shift the rest down, ie vset wristfractures sip 5",
  "'tn raid' will switch into combat defs mode for you and ensure that a few essential defs are on keepup",
  "'vconfig repeatcmd #' will have Svof repeat all curing commands # amount of times",
  "'ppof <city>' will report the citizens online of that city",
  "'qwc' will sort qw by citizenry",
  "'qwm' shows ungemmed marks on qw",
  "'qwic' shows ungemmed Infamous on qw. 'qwi' re-checks all people and then shows the ungemmed Infamous",
  "You can toggle vconfig gagservercuring to show/hide [CURING] messages from serverside",
  "You can use 'ndb delete unranked' to wipe unranked (dormant / newbies) players from NameDB",
  "You can export all priorities in a file and edit them there, see 'vshow'",
  "Svof comes with some scripting examples of the API built-in - take a look at Svof's scripts folder",
}
if svo.haveskillset('spirituality') then
  svo.protips[#svo.protips+1] = "You can do 'fx' or 'fxx' to fix up your angel (if you have Angels in Vision)"
end
if svo.haveskillset('elementalism') then
  svo.protips[#svo.protips+1] = "'rfl' toggles self-reflect mode"
end
if svo.haveskillset('devotion') then
  svo.protips[#svo.protips+1] = "The vconfig bloodswornoff <health %> feature of Svof will automatically unlink you from Bloodswon if you call below that health amount"
end

svo.lifep.sayhello = function()
  for _, id in ipairs(life.hellotrigs) do
    killTrigger(tostring(id))
  end
  life.hellotrigs = nil
  svo.deleteAllP()

  for pattern, func in pairs(life.hellodata) do
    if line:find(pattern) then
      tempTimer(.1, function () func() svo.showprompt() end)

      tempTimer(math.random(2,5), function () math.randomseed(os.time()) svo.echof("protip: ".. svo.protips[math.random(1, #svo.protips)]..".") svo.showprompt() end)
      break
    end
  end
end

life.sayhello = function ()

  tempTimer(math.random(2, 7), function ()
    if svo.conf.paused then svo.echof("Hey!") return end

    life.hellotrigs = {}
    for pattern, _ in pairs(life.hellodata) do
      life.hellotrigs[#life.hellotrigs+1] = (tempExactMatchTrigger or tempTrigger)(pattern, 'svo.lifep.sayhello()')
    end
    send("time raw", false)
  end)
end
svo.signals.charname:connect(life.sayhello)
svo.signals.gmcpcharname:connect(life.sayhello)
