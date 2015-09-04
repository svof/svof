# Source code layout

    bin/                                 = preprocessed files + Lua libraries
    bin/notify                           = LuaNotify library for signal processing
    bin/pl                               = Penlight library for a miscellany of useful features, cut=down version
    bin/default_prios                    = default priorities for Svof
    bin/*.lua                            = pre-processed Lua files - don't edit these, but the raw-svo.*.lua ones instead.
    doc/                                 = documentation in Sphinx.
    output/                              = storage location for build systems
    own svo/                             = your own Svof that your Mudlet profile loads
    svo template/                        = tempalte folder containing things that need to be packed up into the final Svof
    compile.lua                          = pulls Svof files together into one big one that can be loaded in, used by generate.lua
    file.lua                             = Lua library with basic file functions, used by generate.lua
    luapp.lua                            = Lua preprocessing libraries, allows compile-time modification of Lua code - helps with some of the monotonous and repeating functions
    classlist.lua                        = List of classes and their skillsets, used by generate.lua
    raw-*                                = original Svof core files, that are transformed into postprocessed ones and stored in bin/
    raw-end.lua                          = Last file run by Svof when loading, does minor cleanup only.
    raw-actionsystem.lua                 = Svof's action system. Every single thing that Svof does like cure an affliction, put up a defence, regain a balance, is an action. Rule of thumb is that all send()'s should be an action (there's just an exception to send commands to serverside to be done, as those commands cannot be interrupted in any way)
    raw-svo.aliases.lua                  = functions for Svof's aliases, that should call other core functions as necessary to do their work.
    raw-svo.burncounter.lua              = Magi burn counter addon
    raw-svo.config.lua                   = Svof's configuration (vconfig) and tn/tf system
    raw-svo.controllers.lua              = core system functions that can be behind aliases/triggers - includes prompt function, GMCP stats function, affliction lock tracking, aeon/retardation deny/override system, etc.
    raw-svo.customprompt.lua             = Svof's custom prompt feature
    raw-svo.defs.lua                     = everything to do about Svof's defences - database, tracking, switching, etc.
    raw-svo.dict.lua                     = brains of Svof, where it knows every action (affliction, defence, balance, etc) - when to use it, how to use it
    raw-svo.dor.lua                      = Svof's DOR system, implemented as a balanceless and a balancefun action
    raw-svo.dragonlimbcounter.lua        = Dragon limbcounter addon
    raw-svo.elistsorter.lua              = Elist sorter addon
    raw-svo.empty.lua                    = functions tracking all of the empty cures
    raw-svo.enchanter.lua                = Jenny's enchanter addon
    raw-svo.fishdist.lua                 = Trilliana's fishing distance addon
    raw-svo.funnies.lua                  = Svof's humour - welcome message, protips and dying messages
    raw-svo.inker.lua                    = Inker addon
    raw-svo.install.lua                  = Installation procedure - audotects skills (before GMCP came along, by ABing and gagging) and asks questions for things it couldn't
    raw-svo.knightlimbcounter.lua        = Knight limbcounter addon
    raw-svo.logger.lua                   = Svof's logger (startlog / stoplog aliases)
    raw-svo.magilimbcounter.lua          = Magi limbcounter addon
    raw-svo.metalimbcounter.lua          = Sentinel/Sylvan/Druid limbcounter addon
    raw-svo.mindnet.lua                  = Mindnet addon
    raw-svo.misc.lua                     = Miscallaneous functions that don't have a place elsewhere plus a few Lua helpers
    raw-svo.monklimbcounter.lua          = Monk limbcounter addon
    raw-svo.namedb.lua                   = NameDB addon
    raw-svo.offering.lua                 = Offering/defiling/sanctifying addon
    raw-svo.peopletracker.lua            = Peopletracker addon, integrates with Mudlet's mapper
    raw-svo.pipes.lua                    = pipe tracking
    raw-svo.priesthealing.lua            = Svof's built-in priest Healing. Was really amazing before healing balance was introduced, but still has uses in good hands
    raw-svo.priestlimbcounter.lua        = Priest limbcounter addon
    raw-svo.priestreport.lua             = Priest reporting addon
    raw-svo.prio.lua                     = Svof's priority handling functions
    raw-svo.reboundingsileristracker.lua = Rebounding & sileris tracker addon
    raw-svo.refiller.lua                 = Forestal refiller addon
    raw-svo.rift.lua                     = rift, inventory tracking and use of right actions depending on normal/aeon curing and previously with minerals, appropriate herb/mineral use
    raw-svo.runeidentifier.lua           = Rune identifier addon
    raw-svo.serverside.lua               = Integration with serverside curing - mirroring of Svof's priorities to serverside in most efficient manner
    raw-svo.setup.lua                    = Svof loading files
    raw-svo.skeleton.lua                 = essential core files, including balance checks that decide what should be done
    raw-svo.sp.lua                       = parry system
    raw-svo.sparkstracker.lua            = Sparks tracker addon
    raw-svo.stormhammertarget.lua        = Stormhammer target addon
    raw-svo.valid.diag.lua               = Diagnose tracking
    raw-svo.valid.main.lua               = Definitions of all trigger functions - recording in-game data in most accurate way, while not getting tricked by illusions
    raw-svo.valid.simple.lua             = functions for adding afflictions directly from triggers


This the order that things happen on the prompt function:

    \
     |onprompt
     |signals.before_prompt_processing
     |  \
     |   |prompt_stats (stores new prompt stats)
     |   |sk.acrobatics_pronecheckf (toggled)
     |   |valid.check_life
     |   |sk.onprompt_beforelifevision_do (-> svo.aiprompt())
     |
     |send_in_the_gnomes
     |  \
     |   |lifevision.validate
     |   |signals.after_lifevision_processing
     |      \
     |       |sk.onprompt_beforeaction_do / prompttrigger
     |       |cnrl.checkwarning
     |       |sp_checksp
     |   |make_gnomes_work (curing commands)
     |
     |signals.after_prompt_processing
     |  \
     |   |custom prompt
     |   |cnrl.dolockwarning


# How to's

## How to add a new affliction
1. add it in raw-svo.dict.lua in the dict table, with the appropriate functions and curing logic
1. add it in raw-svo.empty.lua
1. add it in raw-svo.diag.lua and add a new diagnose trigger for it
1. add gaining affliction raw-svo.simple.lua, and if there's any complicated logic around it, to raw-svo.main.lua. Add triggers receiving the affliction.
1. add losing/curing affliction in raw-svo.main.lua and the appropriate triggers
1. add in tree curing system (touchtree action  in raw-svo.dict.lua and raw-svo.main.lua)
1. check failure conditions and add them, ie salves fizzling off balance

## How to update madness status of an affliction
1. update raw-svo.dict for the affliction - check every balance
1. update madness_affs table in raw-svo.empty

## View system debug log
1. install [Logger](http://forums.mudlet.org/viewtopic.php?f=6&t=1424)
1. view mudlet-data/profiles/\<profile>/log/svof.txt

## Gotcha with luapp
If luapp, the pre-processor has an error compiling, it doesn't seem to print any errors. The preprocessed file will just stop at the erroring line.

