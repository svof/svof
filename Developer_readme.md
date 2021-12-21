
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
1. add it in empty cures on **svo (setup, misc, empty, funnies, dor) > Empty cure handling** script.
3. add new diagnose trigger for it on **svo (aliases, triggers)**.
5. add to herb cures/restoration/smoke/focus/humour/etc tables (whatever that is applicable) on **svo (trigger functions) > Main trigger functions** (the comment lines `-- normal herbs`, `-- normal smokes`. `-- focus`, etc can help you find your way).
7. add to generic cures (passive cures or cures that happen in blackout) (generic_cures_data in **Main trigger functions** on **svo (trigger functions)**)
8. add its definition on svof-serverside integration (sstosvoa on dict).
9. (Optional) add triggers receiving and losing affliction. Note: This should only be necessary for afflictions that are not shown on GMCP for some reason (best example I can think of is Pariah's latency), the system already handles gaining/removing aff through GMCP so no need to add triggers for that on normal circumstances.
10. (Optional) check failure conditions and add them (in case it is an affliction that is not trackeable on gmcp). You can add the logic on the dict entry or on triggers, wherever applicable.
<details>
    <summary>This is an example of how an affliction entry is structured: </summary>
    
```lua
  paralysis = {
    herb = { -- balance to cure / do the action with - in this case, cure paralysis with herbs
      isadvisable = function() -- add all the conditions necessary for the system to consider that you can & should cure it with this balance. Some checks common to all actions on this balance aren't repeated here (for example herbs won't check if you have herb balance here, that'd be repetitive)
        return (affs.paralysis) or false -- run this action if you've got paralysis, some of these can get pretty complex
      end,

      oncompleted = function() -- affliction got cured, signal svo to remove it from the affs list and that herb balance has been lost since you just ate the herb to cure this, add other logic if necessary
        svo.rmaff('paralysis')
        svo.lostbal_herb()
        svo.killaction(svo.dict.checkparalysis.misc)
      end,

      eatcure = {'bloodroot', 'magnesium'}, -- tells svo what kind of cure to make this go away
      onstart = function() svo.eat(svo.dict.paralysis.herb) end, -- svo started the curing procedure because `isadvisable()` above said it should, tell it what it should do (in this case, it will eat the specified `eatcure`)

      empty = function() empty.eat_bloodroot() end -- what to do when you ate the herb but no affliction got cured
    },
    aff = { -- additional affliction behavior logic
      oncompleted = function() -- to be executed upon gaining this aff
        svo.addaffdict(svo.dict.paralysis)
        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      end,
    },
    gone = { -- logic to be executed when we get a line from the game saying the aff is gone/cured, in this case, just remove it from the aff list
      oncompleted = function() svo.rmaff('paralysis') end,
    },
    onremoved = function() svo.affsp.paralysis = nil svo.donext() end -- additional logic to be executed after paralysis has been removed from the aff list (so after the gone.oncompleted right above ran), means the system can now do any schedule 'do' actions
},
```
    
</details>

## How to update madness status of an affliction
1. update the dict entry for the affliction to account for madness - check every balance
1. update madness_affs table in empty cures on **svo (setup, misc, empty, funnies, dor) > Empty cure handling**.


## How to add a new defence
1. add it in **svo (actions dictionary)** in the dict table, with the appropriate functions and defup/keepup logic.
    - There are two ways of making svo recognize a defence dict entry: through the basicdef function and through a hardcoded entry. Use basicdef whenever you have a simple defence that can be turned on or off without any special logic required. Alternatively, use a dictionary entry whenever you need custom defence logic. Examples:
    
    basicdef example:
    
    ```lua
    if svo.haveskillset('curses') then
      basicdef('swiftcurse', 'swiftcurse') -- refer to the notes on the svo.basicdef function to see the usage, this basically means 'defencename', 'command'
    end
    ```
    
    dictionary entry with custom defence logic:
    ```lua
      svo.dict.devour = {
        gamename = 'devour', -- ingame name
        physical = {
          balanceful_act = true, def = true, -- means it is a def that takes balance and flags this dict entry as a defence entry

          isadvisable = function() -- logic that tells svo when to put up this defence
            return (not defc.dragonform and not defc.devour and ((sys.deffing and defdefup[defs.mode].devour) or (conf.keepup and defkeepup[defs.mode].devour)) and not codepaste.balanceful_defs_codepaste() and not affs.paralysis and not affs.prone and (defc.mouths and defc.tentacles) and bals.anathema) or false
          end,
          -- ^ means svo will only put this defence if the user is not dragon, don't already have devour up, is not in the process of putting up or keeping up a defence at the time, has passed balanceful defs checks, is not paralysed and not prone, has the mouths and tentacles defences already up and has anathema balance available. 

          oncompleted = function() defences.got('devour') end, -- defence is sucessfully up? tell svo you got it.

          action = "unnamable devour", -- defines the action that will put this defence up
          onstart = function() -- logic to put the defence up, add what needs to be sent and any other applicable logic to it here.
            send('unnamable devour', conf.commandecho) 
          end
        }
      }
    ```
    
3. add its entry in the defences dataset (defs_data) in **svo (alias and defence functions) > Defences**  with all the on/off lines as well as the appropriate configurations.
<details>
    <summary>For example, you want to add entries for defs of a class specific skill, let's see how Necromancy defences are set, with comments!</summary>
    
```lua
if svo.haveskillset('necromancy') then --this is important, as you don't want the defence list to be cluttered with a lot of defences that the user's current class cannot put up! Always check if the skillset is available before populating it!
  defs_data:set('deathsight', { type = 'necromancy', -- the type determines from what skillset the defence will be put into, usually you want the type to be the same name as the skillset you are adding it for
    staysindragon = true, -- means that the defence will stay on even after dragonforming
    availableindragon = true, -- means it can be putup while in dragonform. For this specific case, 'deathsight' is also a general defence that can be put up in dragonform so this flag this defence so svo to not unnecessarily drop it after the defence table is repopulated upon dragonforming
    def = "Your mind has been attuned to the realm of Death.", -- the line that appears when you check DEF ingame
    on = {"Your mind is already attuned to the realm of Death.", "You shut your eyes and concentrate on the Soulrealms. A moment later, you feel inextricably linked with realm of Death."}, -- these are the lines that are fired when you put the defence up. 
    onr = "^A miasma of darkness passes over your eyes and you feel a link to the realm of Death,? form in your mind\\.$", --same as above, except that it uses regex. Use onr anytime you need regex instead of a normal trigger.
    off = {"You relax your link with the realm of Death.", "You are not linked with the realm of Death."}}) -- the lines for when the defence is dropped so svo can properly recognize it.
  defs_data:set('soulcage', { type = 'necromancy',
    staysindragon = true,
    offline_defence = true, -- means that the defence will stay on even after disconnecting. This is useful, for example, to tag defences that are items, like shadowmancy cloak or pariah blood on knife.
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
```
</details>

Important notes:
- You can use `defr`, `onr` and `offr` whenever you need to use regex for def, defup and defoff messages respectively. They are not mutually exclusive with normal `def`, `on`, `off` messages so you can use normal and regex triggers on the same entry.
- Available flags and configuration functions are:
    - `availableindragon` -> boolean value that flags when a defence is available and can be put up even in dragonform (usually only for defences that also shares a general or dragon equivalent with the same name and behavior, like deathsight.
    - `invisibledef` -> boolean value that determines whether the defence is invisible (not recognized as a real defence by achaea). This is useful for certain abilities that are not naturally defences per se, but still useful to keep track of.
    - `offline_defence` -> boolean value that flags defences that can stay up even after logging out, see the comments in the code above for example
    - `on_enable` -> custom function, this is mostly only used for monks and blademasters to assure the form they are in can use said defence. See `retaliationstrike` as an example. Can become useful in case new classes that contain different forms as well are launched.
    - `specialskip` -> flags defences that for some reason you want to ignore from defup in order not to get stuck (meaning svo will skip them instead of trying to put them up before proceeding to the next defences in queue to be put up)
    - `stays_in_dragon` -> boolean value that determines whether or not the defence stays up after dragonforming
    - `stays_on_death` -> boolean value that flags this defence as one that stays up even upon death
    - `mana` -> optional setting that sets the mana usage for said defence: 'lots' for high mana usag, 'little' for low mana usage. This will put an uppercase 'M' or a lowercase 'm' respectively on vshow defup/keepup for defences that drains mana.

3. add the definition for serverside-svof integration (sstosvod)
4. (Optional) add any extra triggers for special interactions with this defence in case any exists and add proper logic to handle them.

## How to add a new class
1. Add any new afflictions given by the new class as explained above.
2. Add the class and its skills in **svo.knownskills** table located in **svo (setup, misc, empty, funnies, dor) > Setup** so that svof can recognize them
3. Add all of the class defences as explained above.
4. Add all of the class resources as well as new balances if applicable to the resources in **svo (setup, misc, empty, funnies, dor) > Setup**. Find the `-- Class resources` commentary if you are lost.
    - In case of new balances or any useable resource that should be tracked whether they are on/off, create a svo.valid function for it in **svo (trigger functions) > Main trigger functions**. 
6. Add the class' prompttags (resources, balances, special forms, etc) for the custom prompt in **svo (custom prompt, serverside) > Custom prompt**.
7. Update the public documentation with all the changes implemented.

### Halp! I'm still lost, can you please give me a full example?
Sure thingy!! Head over to my [Anathema](https://github.com/svof/svof/pull/742) and [Pariah](https://github.com/svof/svof/pull/717) PRs to see how I implemented all the changes that introduced support for these classes in svof, their affs, defs and all the other stuffs! 


## View system debug log
1. install [Logger](http://forums.mudlet.org/viewtopic.php?f=6&t=1424)
1. view mudlet-data/profiles/\<profile>/log/svof.txt
