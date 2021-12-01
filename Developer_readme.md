
# Source code layout

    doc/                                                  = documentation in Sphinx.
    default_prios                                         = default priorities for Svof
    svo (actions dictionary).xml                          = brains of Svof, where it knows every action (affliction, defence, balance, etc) - when to use it, how to use it. For the core functions that validates these actions, see 'Action system' below.
    svo (alias and defence functions).xml                 = functions for Svof's aliases, that should call other core functions as necessary to do their work as well as everything to do about Svof's defences - database, tracking, switching, etc.
    svo (aliases, triggers).xml                           = the actual Mudlet aliases and triggers that uses the functions from the script mentioned above.
    svo (burncounter).xml                                 = Magi burn counter addon
    svo (curing skeleton, controllers, action system).xml
        curing skeleton                                   = essential core files, including balance checks that decide what should be done
        controllers                                       = core system functions that can be behind aliases/triggers - includes prompt function, GMCP stats function, affliction lock tracking, aeon/retardation deny/override system, etc.
        action system                                     = Svof's action system. Every single thing that Svof does like cure an affliction, put up a defence, regain a balance, is an action - defined in the actions dictionary. These functions manages and validates those actions.
    svo (custom prompt, serverside).xml 
        custom prompt                                     = Svof's custom prompt feature
        serverside                                        = Integration with serverside curing - mirroring of Svof's priorities to serverside in most efficient manner
    svo (elistsorter).xml                                 = Elist sorter addon
    svo (enchanter).xml                                   = Jenny's enchanter addon
    svo (fishdist).xml                                    = Trilliana's fishing distance addon
    svo (inker).xml                                       = Inker addon
    svo (install me in module manager).xml                = The core system functions to install/uninstall modules, initialization, updates, classchange for multiclass, event handlers, utilities and other things necessary for the system to function. Also contains a few scripting examples.
    svo (install, config, pipes, rift, parry, prios).xml
        install                                           = Installation procedure (vinstall) - autodetects skills and asks questions for things it couldn't
        config                                            = Svof's configuration (vconfig) and tn/tf system
        pipes                                             = pipe tracking
        rift                                              = rift, inventory tracking and use of right actions depending on normal/aeon curing and previously with minerals, appropriate herb/mineral use
        parry                                             = parry system (sp)
        prios                                             = Svof's priority handling functions
    svo (limbcounter).xml                                 = Limbcounter addon for the classes that uses it
    svo (logger).xml                                      = Svof's logger (startlog / stoplog aliases)
    svo (mindnet).xml                                     = Mindnet addon
    svo (namedb).xml                                      = NameDB addon
    svo (offering).xml                                    = Offering addon
    svo (peopletracker).xml                               = Peopletracker addon, integrates with Mudlet's mapper
    svo (priestreport).xml                                = Priest reporting addon
    svo (reboundingsileristracker).xml                    = Rebounding & sileris tracker addon
    svo (refiller).xml                                    = Refiller addon
    svo (runeidentifier).xml                              = Rune identifier addon
    svo (setup, misc, empty, funnies, dor).xml
        setup                                             = Svof loading files
        misc                                              = Miscallaneous functions that don't have a place elsewhere plus a few Lua helpers
        empty                                             = functions tracking all of the empty cures
        funnies                                           = Svof's humour - welcome message, protips and dying messages
        dor                                               = Svof's DOR system, implemented as a balanceless and a balancefun action
    svo (stormhammertarget).xml                           = Stormhammer target addon
    svo (trigger functions).xml                           = Diagnose tracking; definitions of all trigger functions - recording in-game data in most accurate way, while not getting tricked by illusions; functions for adding afflictions directly from triggers


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
1. add it in **svo (actions dictionary)** in the dict table, with the appropriate functions and curing logic.
1. add it in empty cures on **svo (setup, misc, empty, funnies, dor) > Empty cure handling* script.
2. add to the herb cures 
3. add new diagnose trigger for it on **svo (aliases, triggers)**.
4. (Optional) add triggers receiving and losing affliction. Note: This should only be necessary for afflictions that are not shown on GMCP for some reason (best example I can think of is Pariah's latency), the system already handles gaining/removing aff through GMCP so no need to add triggers for that on normal circumstances.
5. add to herb cures/restoration/smoke/focus/humour/etc tables (whatever that is applicable) on **svo (trigger functions) > Main trigger functions** (the comment lines `-- normal herbs`, `-- normal smokes`. `-- focus`, etc can help you find your way)
6. add to generic cures (passive cures or cures that happen in blackout) (generic_cures_data in **Main trigger functions** on **svo (trigger functions)**)
7. check failure conditions and add them, ie salves fizzling off balance

## How to update madness status of an affliction
1. update the dict entry for the affliction to account for madness - check every balance
1. update madness_affs table in empty cures on **svo (setup, misc, empty, funnies, dor) > Empty cure handling**.

## View system debug log
1. install [Logger](http://forums.mudlet.org/viewtopic.php?f=6&t=1424)
1. view mudlet-data/profiles/\<profile>/log/svof.txt

## Gotcha with luapp
If luapp, the pre-processor has an error compiling, it doesn't seem to print any errors. The preprocessed file will just stop at the erroring line.
