-- Svof (c) 2011-2015 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.


#local function encode (what)
#  return "dict." .. what .. ".herb"
#end

#local function encodesm (what)
#  return "dict." .. what .. ".smoke"
#end

#local function encodes (what)
#  return "dict." .. what .. ".salve"
#end

#local function encodef (what)
#  return "dict." .. what .. ".focus"
#end

#local function encodep (what)
#  return "dict." .. what .. ".purgative"
#end

#local function encodew (what)
#  return "dict." .. what .. ".waitingfor"
#end

function valid.caught_illusion()
  sys.flawedillusion = true
  me.haveillusion = true
end

function not_illusion(reason)
  sys.not_illusion = reason or true
end

function ignore_illusion(reason, moveback)
  -- don't spam with multiple (i)'s
  if sys.flawedillusion then return end

  sys.flawedillusion = true
  me.haveillusion = reason or true
  local currentline = getLineNumber()

  if reason == "not first" then
    local previousline = getLines(currentline-1, currentline)[1]
    moveCursor(#getCurrentLine(), currentline)
    insertText(" ") moveCursor(#getCurrentLine(), currentline) insertLink("(i)", '', string.format("Ignored this illusion because '%s' can't come together with '%s' at once.", line, previousline))
  else
    if moveback then moveCursor(0, currentline-1) end
    moveCursor(#getCurrentLine(), currentline)
    insertText(" ") moveCursor(#getCurrentLine(), currentline) insertLink("(i)", '', reason or '')
  end

  moveCursorEnd("main")
  debugf("ignore_illusion()")
end

function show_info(shortmsg, message, moveback)
  if moveback then moveCursor(0, getLineNumber()-1) end
  moveCursor(#getCurrentLine(), getLineNumber())
  insertText(" ") moveCursor(#getCurrentLine(), getLineNumber())
  deselect()
  fg("green")
  insertLink("("..shortmsg..")", '', message or '') -- can't format, https://bugs.launchpad.net/mudlet/+bug/1027732
  resetFormat()
end

-- +2 if we do stuff on the prompt
function vm.last_line_was_prompt(onprompt)
  return (paragraph_length == 1) and true or false
end

function valid.symp_asleep()
  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then
    ignore_illusion("not first")
    return
  end

  if not affs.sleep and not actions.sleep_aff then
    checkaction(dict.sleep.aff, true)
    lifevision.add(actions["sleep_aff"].p, "symptom", nil, 1)
  end

  -- reset non-wait things we were doing, because they got cancelled by the sleep
  if affs.asleep or actions.asleep_aff then
    for k,v in actions:iter() do
      if v.p.balance ~= "waitingfor" and v.p.balance ~= "aff" then
        killaction(dict[v.p.action_name][v.p.balance])
      end
    end
  end
end

function valid.cured_lovers()
  checkaction(dict.lovers.physical)
  if actions.lovers_physical then
    lifevision.add(actions.lovers_physical.p, nil, multimatches[2][2])
  end
end

function valid.cured_lovers_nobody()
  checkaction(dict.lovers.physical)
  if actions.lovers_physical then
    lifevision.add(actions.lovers_physical.p, "nobody")
  end
end


function valid.bloodsworn_gone()
#if skills.devotion then
  checkaction(dict.bloodsworntoggle.misc)
  if actions.bloodsworntoggle_misc then
    lifevision.add(actions.bloodsworntoggle_misc.p)
  end
#end
end

function defs.sileris_start()
  checkaction(dict.sileris.misc)
  if actions.sileris_misc then
    lifevision.add(actions.sileris_misc.p)
  end
end

function defs.sileris_finished()
  checkaction(dict.waitingforsileris.waitingfor)
  if actions.waitingforsileris_waitingfor then
    lifevision.add(actions.waitingforsileris_waitingfor.p)
  end
end

function defs.sileris_slickness()
  checkaction(dict.sileris.misc)
  if actions.sileris_misc then
    if dict.sileris.applying == "quicksilver" and not line:find("quicksilver", 1, true) then
      ignore_illusion("Ignored this illusion because we're applying quicksilver, not sileris right now (or we were forced).")
    elseif dict.sileris.applying == "sileris" and not line:find("berry", 1, true) then
      ignore_illusion("Ignored this illusion because we're applying sileris, not quicksilver right now (or we were forced).")
    else
      lifevision.add(actions.sileris_misc.p, "slick", nil, 1)
    end
  end
end

function valid.sileris_flayed()
  if not conf.aillusion then
    defs.lost_sileris()
  elseif paragraph_length == 1 then
    checkaction(dict.sileris.gone, true)
    lifevision.add(actions.sileris_gone.p, nil, getLastLineNumber("main"), 1)
  else
    ignore_illusion("not first")
  end
end

function valid.insomnia_relaxed()
  if not conf.aillusion then
    defs.lost_insomnia()
  else
    checkaction(dict.insomnia.gone, true)
    lifevision.add(actions.insomnia_gone.p, "relaxed", getLastLineNumber("main"))
  end
end

function valid.insomnia_healed()
  if not conf.aillusion then
    defs.lost_insomnia()
  elseif affs.blackout or paragraph_length > 1 then
    defs.lost_insomnia()
  else
    ignore_illusion("The heal line doesn't seem to be on it's own as it should be.")
  end
end

function defs.got_block(dir)
  checkaction(dict.block.physical)
  if actions.block_physical then
    lifevision.add(actions.block_physical.p, nil, dir)
  end
end

function valid.smoke_stillgot_inquisition()
  checkaction(dict.hellsight.smoke)
  if actions.hellsight_smoke then
    lifevision.add(actions.hellsight_smoke.p, "inquisition")
  end
end

function valid.smoke_stillhave_madness()
  checkaction(dict.madness.smoke)
  if actions.madness_smoke then
    lifevision.add(actions.madness_smoke.p, "hecate")
  end
end

function valid.smoke_have_rebounding()
  checkaction(dict.rebounding.smoke)
  if actions.rebounding_smoke then
    smoke_cure = true
    lifevision.add(actions.rebounding_smoke.p, "alreadygot")
  end
end

#if skills.chivalry or skills.shindo or skills.kaido or skills.metamorphosis then
function defs.got_fitness()
  checkaction(dict.fitness.physical)
  if actions.fitness_physical then
    lifevision.add(actions.fitness_physical.p)
  end
end

function valid.fitness_cured_asthma()
  checkaction(dict.fitness.physical)
  if actions.fitness_physical then
    lifevision.add(actions.fitness_physical.p, "curedasthma")
  end
end

function valid.fitness_weakness()
  checkaction(dict.fitness.physical)
  if actions.fitness_physical then
    lifevision.add(actions.fitness_physical.p, "weakness")
  end
end

function valid.fitness_allgood()
  checkaction(dict.fitness.physical)
  if actions.fitness_physical then
    lifevision.add(actions.fitness_physical.p, "allgood")
  end
end

function valid.usedfitnessbalance()
  checkaction(dict.stolebalance.happened, true)
  lifevision.add(actions.stolebalance_happened.p, nil, "fitness")
end

function valid.gotfitnessbalance()
  checkaction(dict.gotbalance.happened, true)
  dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "fitness" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
#else
function defs.got_fitness() end
function valid.fitness_cured_asthma() end
function valid.fitness_weariness() end
function valid.fitness_allgood() end
#end

#if skills.chivalry then
function valid.gotragebalance()
  checkaction(dict.gotbalance.happened, true)
  dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "rage" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
#end

function valid.dragonform_riding()
  if actions.riding_physical then
    lifevision.add(actions.riding_physical.p, "dragonform")
  end
end

function defs.started_dragonform()
  if actions.dragonform_physical then
    lifevision.add(actions.dragonform_physical.p)
  end
end

-- set the Elder dragon colour - but only when we are mid-dragonforming, so as not to get tricked by illusions
function valid.dragonformingcolour(colour)
  if not conf.aillusion or actions.waitingfordragonform_waitingfor then
    colour = colour:lower()

    local t = {
       ["red"] = 'dragonfire',
       ["black"] = 'acid',
       ["silver"] = 'lightning',
       -- it is 'golden' and not 'gold' for this message
       ["golden"] = 'psi',
       ["blue"] = 'ice',
       ["green"] = 'venom'
    }

    conf.dragonbreath = t[colour]
    raiseEvent("svo config changed", "dragonbreath")
  end
end

function defs.got_dragonform()
  checkaction(dict.waitingfordragonform.waitingfor)
  if actions.waitingfordragonform_waitingfor then
    lifevision.add(actions.waitingfordragonform_waitingfor.p)
  end
end

function defs.cancelled_dragonform()
  if actions.waitingfordragonform_waitingfor then
    lifevision.add(actions.waitingfordragonform_waitingfor.p, "cancelled")
  end
end

#if skills.groves then
function valid.started_rejuvenate()
  if actions.rejuvenate_physical then
    lifevision.add(actions.rejuvenate_physical.p)
  end
end

function valid.completed_rejuvenate()
  checkaction(dict.waitingforrejuvenate.waitingfor)
  if actions.waitingforrejuvenate_waitingfor then
    lifevision.add(actions.waitingforrejuvenate_waitingfor.p)
  end
end

function valid.cancelled_rejuvenate()
  if actions.waitingforrejuvenate_waitingfor then
    lifevision.add(actions.waitingforrejuvenate_waitingfor.p, "cancelled")
  end
end
#end

#if skills.spirituality then
function defs.started_mace()
  if actions.mace_physical then
    lifevision.add(actions.mace_physical.p)
  end
end

function defs.have_mace()
  if actions.mace_physical then
    lifevision.add(actions.mace_physical.p, "alreadyhave")
  end
end

function defs.got_mace()
  checkaction(dict.waitingformace.waitingfor)
  if actions.waitingformace_waitingfor then
    lifevision.add(actions.waitingformace_waitingfor.p)
  end
end

function defs.cancelled_mace()
  if actions.waitingformace_waitingfor then
    lifevision.add(actions.waitingformace_waitingfor.p, "cancelled")
  end
end

function valid.sacrificed_angel()
  if not conf.aillusion or actions.sacrifice_physical then
    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()

    reset.affs()
    reset.general()
  else
    ignore_illusion("Didn't send the 'angel sacrifice' command recently.")
  end
end
#end

#if skills.shindo then
function valid.shin_phoenix()
  if not conf.aillusion or actions.phoenix_physical then
    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()

    reset.affs()
  else
    ignore_illusion("Didn't send the 'shin phoenix' command recently.")
  end
end
#end

#if skills.propagation then
function defs.notonland_viridian()
  if actions.viridian_physical then
    lifevision.add(actions.viridian_physical.p, "notonland")
  end
end
function defs.viridian_inside()
  if actions.viridian_physical then
    lifevision.add(actions.viridian_physical.p, "indoors")
  end
end
function defs.viridian_cancelled()
  if actions.waitingforviridian_waitingfor then
    lifevision.add(actions.waitingforviridian_waitingfor.p, "cancelled")
  end
end
function defs.got_viridian()
  if actions.waitingforviridian_waitingfor then
    lifevision.add(actions.waitingforviridian_waitingfor.p)
  end
end
function defs.started_viridian()
  if actions.viridian_physical then
    lifevision.add(actions.viridian_physical.p)
  end
end
function defs.alreadyhave_viridian()
  if actions.viridian_physical then
    lifevision.add(actions.viridian_physical.p, "alreadyhave")
  end
end
#end

function valid.alreadyhave_dragonbreath()
  if actions.dragonbreath_physical then
    lifevision.add(actions.dragonbreath_physical.p, "alreadygot")
  end
end

function defs.alreadyhave_dragonform()
  if actions.dragonform_physical then
    lifevision.add(actions.dragonform_physical.p, "alreadyhave")
  end
end

function defs.started_dragonbreath()
  if actions.dragonbreath_physical then
    lifevision.add(actions.dragonbreath_physical.p)
  end
end

function defs.got_dragonbreath()
  checkaction(dict.waitingfordragonbreath.waitingfor)
  if actions.waitingfordragonbreath_waitingfor then
    lifevision.add(actions.waitingfordragonbreath_waitingfor.p)
  end
end
-- hallucinations symptoms
function valid.swandive()
  local have_pflag = pflags.p
  sk.onprompt_beforeaction_add("swandive", function ()
    if not have_pflag and pflags.p then
      valid.simpleprone()
      valid.simplehallucinations()
    end
  end)
end

-- detect conf/dizzy, or amnesia/amnesia at worst
function sk.check_evileye()
  if find_until_last_paragraph("Your curseward has been breached!", "exact") then
    sk.tempevileye.count = sk.tempevileye.count - 1
  end

  -- fails when they give the same aff twice
  --[[local affcount = 0
  for action in lifevision.l:iter() do
    if string.ends(action, "_aff") or string.find(action, "check") then affcount = affcount + 1 end
  end

  local diff = sk.tempevileye.count - affcount]]

  local diff = sk.tempevileye.hiddencount

  if diff == 1 then
    valid.simpleunknownmental()
    echof("assuming focusable aff.")
  elseif diff == 2 then
    valid.simpleconfusion()
    valid.simpleunknownmental()
    echof("assuming confusion and focusable aff.")
  end
  -- diff of 0 is OK

  sk.tempevileye = nil
  signals.before_prompt_processing:disconnect(sk.check_evileye)
end

function valid.hidden_evileye()
  if line:find("stares at you, giving you the evil eye", 1, true) or isPrompt() then
    sk.tempevileye.hiddencount = (sk.tempevileye.hiddencount or 0) + 1
  end
end

function valid.evileye()
  -- check next line to see if it's
  if sk.tempevileye then sk.tempevileye.count = sk.tempevileye.count + 1 return end -- don't set it if the first line already did
  sk.tempevileye = {startline = getLastLineNumber("main"), count = 1}
  signals.before_prompt_processing:connect(sk.check_evileye)
end

function sk.check_trip()
  if not find_until_last_paragraph("You parry the attack with a deft manoeuvre.", "exact") and not find_until_last_paragraph("You step into the attack,", "substring") then
    valid.simpleprone()
  end

  signals.before_prompt_processing:disconnect(sk.check_trip)
end

function valid.trip_prone()
  signals.before_prompt_processing:connect(sk.check_trip)
end

function valid.spiders_all_overme()
  valid.simplefear()
  valid.simplehallucinations()
end

function valid.symp_impale()
  if affs.blackout then
    valid.proper_impale()
  elseif not conf.aillusion then
    valid.simpleimpale()
  else
    sk.impale_symptom()
  end
end

function valid.symp_stupidity()
  sk.stupidity_symptom()
end

function valid.symp_transfixed()
  sk.transfixed_symptom()
end


function valid.symp_paralysis()
  if actions.fillskullcap_physical then
    killaction(dict.fillskullcap.physical)
    if not affs.paralysis then
      valid.simpleparalysis()
      decho(getDefaultColor().." (paralysis confirmed)")
    end
    return
  elseif actions.fillelm_physical then
    killaction(dict.fillelm.physical)
    if not affs.paralysis then
      valid.simpleparalysis()
      decho(getDefaultColor().." (paralysis confirmed)")
    end
    return
  elseif actions.fillvalerian_physical then
    killaction(dict.fillvalerian.physical)
    if not affs.paralysis then
      valid.simpleparalysis()
      decho(getDefaultColor().." (paralysis confirmed)")
    end
    return
  end

  if actions.checkparalysis_misc then
    lifevision.add(actions.checkparalysis_misc.p, "paralysed")
    decho(getDefaultColor().." (paralysis confirmed)")
  elseif not conf.aillusion then
    valid.simpleparalysis()
  elseif not affs.paralysis then
    checkaction(dict.checkparalysis.aff, true)
    lifevision.add(actions.checkparalysis_aff.p)
  end

  if actions.prone_misc then
    killaction(dict.prone.misc)
    if not affs.paralysis then
      valid.simpleparalysis()
      decho(getDefaultColor().." (paralysis confirmed)")
    end
  end

  -- in slowcuring only (for AI safety for now), count all balanceful actions for paralysis
  if sys.sync and usingbal"physical" then
    valid.simpleparalysis()
  end
end

function valid.symp_stun()
  if not conf.aillusion then
    valid.simplestun()
  elseif actions.checkstun_misc then
    lifevision.add(actions.checkstun_misc.p)
  else
    sk.stun_symptom()
  end

  -- reset non-wait things we were doing, because they got cancelled by the stun
  if affs.stun or actions.stun_aff then
    for k,v in actions:iter() do
      if v.p.balance ~= "waitingfor" and v.p.balance ~= "aff" then
        killaction(dict[v.p.action_name][v.p.balance])
      end
    end
  end
end

function valid.symp_illness_constitution()
  sk.illness_constitution_symptom()
end

function valid.saidnothing()
  if actions.checkslows_misc then
    deleteLineP()
    lifevision.add(actions.checkslows_misc.p, "onclear")
  elseif affs.aeon or affs.retardation or affs.stun then
    deleteLineP()
  end
end
valid.silence_vibe = valid.saidnothing

function valid.jump()
  if actions.checkparalysis_misc then
    lifevision.add(actions.checkparalysis_misc.p, "onclear")
    deleteLineP()
  end
end

function valid.nobalance()
  if actions.checkparalysis_misc then
    lifevision.add(actions.checkparalysis_misc.p, "paralysed")
    deleteLineP()
  end

  if actions.checkasthma_misc then
    lifevision.add(actions.checkasthma_misc.p, "weakbreath", nil, 1)
  end

  -- cancel standing if we can't due to no balance
  if actions.prone_misc then
    killaction(dict.prone.misc)
    if bals.balance then
      bals.balance = false -- unset balance, in case of blackout, where we don't see prompt
      raiseEvent("svo lost balance", "balance")
    end
  end

  -- this might not be necessary for this case of getting hit off balance
  -- elseif actions.breath_physical and not affs.asthma and affsp.asthma then
  --   checkaction(dict.checkasthma.misc, true)
  --   lifevision.add(actions.checkasthma_misc.p, "weakbreath", nil, 1)
  -- end
end

function valid.nothingtowield()
  if actions.checkparalysis_misc then
    deleteLineP()
    lifevision.add(actions.checkparalysis_misc.p, "onclear")
  end
end

function valid.nosymptom()
  if actions.checkwrithes_misc then
    tempLineTrigger(0,3,[[deleteLine()]])
    lifevision.add(actions.checkwrithes_misc.p, "onclear")
  end
end

function valid.nothingtoeat()
  if actions.checkanorexia_misc then
    deleteLineP()
    lifevision.add(actions.checkanorexia_misc.p, "onclear")
  elseif actions.checkstun_misc then
    deleteLineP()
    lifevision.add(actions.checkstun_misc.p, "onclear")
  elseif affs.anorexia or affs.stun then
    deleteLineP()
  end
end

function valid.lungsokay()
  if actions.checkasthma_misc then
    deleteLineP()
    lifevision.add(actions.checkasthma_misc.p, "onclear")
  end
end

-- given a sluggish symptom, either confirms sluggish if we're checking for it already
-- or goes out and tests it
function valid.webeslow()
  sk.sawsluggish = getLastLineNumber("main") -- for retardation going away auto-detection
  if sk.sluggishtimer then killTimer(sk.sluggishtimer); sk.sluggishtimer = nil end

  -- if triggered by curing, don't consider it retardation
  if sk.sawcuring() then return end

  -- if we suspect aeon, and aren't checking it yet, add the action in
  if affsp.aeon and not actions.checkslows_misc then
    checkaction(dict.checkslows.misc, true)
  end

  -- confirm that we're sluggish if we were checking for slows
  if actions.checkslows_misc then
    lifevision.add(actions.checkslows_misc.p, "sluggish")
    return
  end

  -- if we have aeon or retardation already, do nothing then
  if affs.aeon or affs.retardation then return end

  if affs.blackout and not affs.retardation then
    valid.simpleaeon()
  elseif not affs.retardation then
    -- confirm aeon out of the blue, treat it as retardation over aeon
    checkaction(dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, "retardation")
    -- sk.retardation_symptom()
  end
end

function valid.webbily()
  if actions.checkwrithes_misc then
    lifevision.add(actions.checkwrithes_misc.p, "webbily")
  end
end

function valid.symp_webbed()
  if not conf.aillusion then
    valid.simplewebbed()
  else
    sk.webbed_symptom()
  end
end

function valid.symp_impaled()
  if not conf.aillusion then
    valid.simpleimpale()
  else
    sk.impaled_symptom()
  end
end

function valid.transfixily()
  if actions.checkwrithes_misc then
    lifevision.add(actions.checkwrithes_misc.p, "transfixily")
  end

  -- special workaround for waking up not showing up in blackout: clear sleep if we saw this msg
  -- it's an issue otherwise to miss the sleep msg from a totem while in blackout and think you're still asleep
  if affs.asleep then removeaff("asleep") end
end

function valid.symp_roped()
  if not conf.aillusion then
    valid.simpleroped()
  else
    sk.roped_symptom()
  end
end

function valid.symp_transfixed()
  if not conf.aillusion then
    valid.simpletransfixed()
  else
    sk.transfixed_symptom()
  end
end

function valid.weakbreath()
  if actions.checkasthma_misc then
    lifevision.add(actions.checkasthma_misc.p, "weakbreath", nil, 1)
  elseif actions.breath_physical and not affs.asthma then
    checkaction(dict.checkasthma.misc, true)
    lifevision.add(actions.checkasthma_misc.p, "weakbreath", nil, 1)
  elseif conf.aillusion and (not actions.breath_physical and not affs.asthma) then
    ignore_illusion("Ignored this illusion because we aren't trying to hold breath right now (or we were forced).")
  else
    checkaction(dict.checkasthma.aff, true)
    lifevision.add(actions.checkasthma_aff.p)
  end
end

function valid.impaly()
  if actions.checkwrithes_misc then
    lifevision.add(actions.checkwrithes_misc.p, "impaly")
  end
end

function valid.chimera_stun()
  if conf.aillusion and (not defc.deaf or not affs.deafaff or not actions.deafaff_aff) then return end

  valid.simplestun(2)
end

function valid.restore()
  checkaction(dict.restore.physical)
  if actions.restore_physical then
    -- prevent against a well-timed restore use, which when empty, forces us to clear all afflictions
    if conf.aillusion then
      local time, lat = getStopWatchTime(actions.restore_physical.p.actionwatch), getping()

      if time < (lat/2) then
        ignore_illusion("This looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    valid.passive_cure()
    lifevision.add(actions.restore_physical.p, nil, getLineNumber())

    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()
  end
end

function valid.dragonheal()
  checkaction(dict.dragonheal.physical)
  if actions.dragonheal_physical then
    valid.passive_cure()
    lifevision.add(actions.dragonheal_physical.p, nil, getLineNumber())

    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()
  end
end

function valid.nodragonheal()
  checkaction(dict.dragonheal.physical)
  if actions.dragonheal_physical then
    lifevision.add(actions.dragonheal_physical.p, "nobalance")
  end
end

function valid.knighthood_disembowel()
  local result = checkany(dict.curingimpale.waitingfor)

  -- we won't get curing* if we didn't even start to writhe, so fake it for these purposes
  if not result and affs.impale then
    checkaction(dict.curingimpale.waitingfor, true)
    result = { name = "curingimpale_waitingfor" }
  end

  if result and actions[result.name] then
    lifevision.add(actions[result.name].p, "withdrew")
  end
end

valid.impale_withdrew = valid.knighthood_disembowel

function valid.fell_sleep()
  checkaction(dict.sleep.aff, true)
  checkaction(dict.prone.aff, true)

  lifevision.add(actions.sleep_aff.p)
  lifevision.add(actions.prone_aff.p)
end

function valid.proper_sleep()
  if defc.insomnia then
    defs.lost_insomnia()
  else
    checkaction(dict.sleep.aff, true)
    checkaction(dict.prone.aff, true)

    lifevision.add(actions.sleep_aff.p)
    lifevision.add(actions.prone_aff.p)
  end
end

function valid.disruptingshiver()
  if conf.aillusion and bals.equilibrium then
    sk.onprompt_beforeaction_add("disruptingshiver", function ()
      if not bals.equilibrium  then
        checkaction(dict.shivering.aff, true)
        checkaction(dict.disrupt.aff, true)
        lifevision.add(actions.shivering_aff.p)
        lifevision.add(actions.disrupt_aff.p)
        defs.lost_caloric()
      end
    end)
  else
    checkaction(dict.shivering.aff, true)
    checkaction(dict.disrupt.aff, true)
    lifevision.add(actions.shivering_aff.p)
    lifevision.add(actions.disrupt_aff.p)
    defs.lost_caloric()
  end
end

function svo.valid.check_dragonform()
  -- show xp? ignore!
  if lastpromptnumber+1 == getLastLineNumber("main") or not find_until_last_paragraph(me.name, "substring") then return end

  if defc.dragonform and not find_until_last_paragraph("Dragon)", "substring") then
    echo"\n" echof("Apparently we aren't in Dragon.")
    svo.defs.lost_dragonform()
    svo.defs.lost_dragonarmour()
    svo.defs.lost_dragonbreath()
  elseif not defc.dragonform and find_until_last_paragraph("Dragon)", "substring") then
    echo"\n" echof("Apparently we're in Dragon.")
    svo.defs.got_dragonform()
  end
end

svo.defs.got_dragonform = dict.waitingfordragonform.waitingfor.oncompleted

function valid.proper_impale()
  if not conf.aillusion then
    valid.simpleimpale()
  else
    checkaction(dict.checkwrithes.aff, true)
    lifevision.add(actions.checkwrithes_aff.p, "impale", stats.currenthealth)
  end
end

function valid.swachbuckling_pesante()
  if (not find_until_last_paragraph("The attack rebounds back onto", "substring")) and (find_until_last_paragraph("jabs", "substring")) and (find_until_last_paragraph("you", "substring")) then
    if (not conf.aillusion) or (defc.deaf or affs.deafaff) then
      valid.simplestun(.5)
    end
  end
end

--[[
  Martellato can get tricked by the following, avoid it:

  Lightning-quick, Bob jabs you with a Soulpiercer.
  A prickly, stinging sensation spreads through your body.
  The songblessing upon the rapier sings out with a piercing high note.
  Mary viciously jabs an elegant Mhaldorian rapier into Bob.
  The songblessing upon the rapier swells with a rich, vibrant hum.

]]
function valid.swachbuckling_martellato()
  if not find_until_last_paragraph("The attack rebounds back onto", "substring") and
     find_until_last_paragraph("jabs", "substring") and
     find_until_last_paragraph("you", "substring") and
     not find_until_last_paragraph("^%w+ viciously jabs", "pattern") then
    valid.simpleprone()
  end
end

local last_jabber = ""
function valid.swashbuckling_jab(name)
  if sk.swashbuckling_jab then killTimer(sk.swashbuckling_jab) end
  sk.swashbuckling_jab = tempTimer(.5, function() sk.swashbuckling_jab = nil end)
  last_jabber = name
end

function valid.voicecraft_tremolo(name, side)
  local known_class = (ndb and ndb.getclass(name))
  if not conf.aillusion or ((affs["crippled"..side.."leg"] or sk["delayvenom_"..side.."leg"] or sk["delayacciaccatura_"..side.."leg"]) and ((sk.swashbuckling_jab and last_jabber == name) or known_class == "bard")) then

    -- when we've accepted that the Tremolo is legitimate, record the side - to be checked later in the mangle trigger for verification
    sk.tremoloside = sk.tremoloside or {}
    sk.tremoloside[side] = true
    prompttrigger("clear tremolo", function()
      -- the prompttrigger happens after the mangle should have been processed:
      -- so if we still have tremoloside setup, it means no mangle happened as the
      -- mangle would have cleared it. Hence, make the venom timer go off at the
      -- earlist possible time.
      if sk.tremoloside and sk.tremoloside[side] and sk["delayvenom_"..side.."leg"] then
        killTimer(sk["delayvenom_"..side.."leg"])
        sk["delayvenom_"..side.."leg"] = nil
        -- we can't use valid here, but we can use addaff
        addaff(dict["crippled"..side.."leg"])

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        signals.canoutr:emit()
      end

      sk.tremoloside = nil
    end)
  end
end

function valid.voicecraft_vibrato(name, side)
  if not conf.aillusion or ((affs["crippled"..side.."arm"] or sk["delayvenom_"..side.."arm"] or sk["delayacciaccatura_"..side.."arm"]) and ((sk.swashbuckling_jab and last_jabber == name) or known_class == "bard")) then
    valid["simplemangled"..side.."arm"]()
  end
end

-- for a Bard tremolo/vibrato hit, avoid curing the crippled limb right away
-- because that will use up our salve balance and delay the mangled break, which
-- follows soon after. Hence this, upon detecting a jab form a Bard with
-- epteth/epseth, delays adding the crippled affliction until after the tremolo
-- or vibrato
function valid.swashbuckling_poison()
  if not conf.aillusion or (paragraph_length == 2 and not conf.batch) then
    for _, limb in ipairs{"rightleg", "rightarm", "leftarm", "leftleg"} do
      if actions["crippled"..limb.."_aff"] then
        killaction(dict["crippled"..limb].aff)

        sk["delayvenom_"..limb] = tempTimer(.25, function()
          if not affs["mangled"..limb] then
            addaff(dict["crippled"..limb])

            signals.after_lifevision_processing:unblock(cnrl.checkwarning)
            signals.canoutr:emit()
            make_gnomes_work()
          end

          sk["delayvenom_"..limb] = nil
        end)
        break
      end
    end
  end
end

function svo.valid.swashbuckling_acciaccatura(side, limb)
  local aff = side..limb

  sk["delayacciaccatura_"..aff] = tempTimer(.25, function()
    if not affs["mangled"..aff] then
      addaff(dict["crippled"..aff])

      signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      signals.canoutr:emit()
      make_gnomes_work()
    end

    sk["delayacciaccatura_"..aff] = nil
  end)
end

-- handle cancelling of delayvenom in case of this being a DSL:
-- apply the cripples right away, so the cure of a potential mangled limb in the
-- dsl, the venoms and the limb break get computed for cure at once on the prompt
signals.limbhit:connect(function(which, attacktype)
  if attacktype ~= "weapon" then return end

  sk.weapon_hits = (sk.weapon_hits or 0) + 1
  sk.onprompt_beforeaction_add("track a dsl", function()
    -- if we got a DSL, apply the delayvenoms right now
    if sk.weapon_hits == 2 then
      for _, aff in ipairs{"rightleg", "rightarm", "leftarm", "leftleg"} do
        if sk["delayvenom_"..aff] then
          if not affs["mangled"..aff] then
            addaff(dict["crippled"..aff])
            signals.after_lifevision_processing:unblock(cnrl.checkwarning)
            signals.canoutr:emit()
          end

          killTimer(sk["delayvenom_"..aff])
          sk["delayvenom_"..aff] = nil
        end
      end
    end

    sk.weapon_hits = nil
  end)
end)

function svo.valid.bloodleech()
  sk.bloodleech_hit = true
  sk.onprompt_beforeaction_add("unset bloodleech", function()
    sk.bloodleech_hit = nil
  end)
end

function svo.valid.defstrip(which)
  assert(which, "svo.valid.defstrip: which defence was stripped?")

  local t = {
    ["anti-weapon field"]      = 'rebounding',
    ["caloric salve"]          = 'caloric',
    ["cold resistance"]        = 'coldresist',
    ["density"]                = 'mass',
    ["electricity resistance"] = 'electricresist',
    ["fire resistance"]        = 'fireresist',
    ["gripping"]               = 'grip',
    ["held breath"]            = 'breath',
    ["insulation"]             = 'caloric',
    ["levitating"]             = 'levitation',
    ["magic resistance"]       = 'magicresist',
    ["scholasticism"]          = 'myrrh',
    ["soft focus"]             = 'softfocus',
    ["soft focusing"]          = 'softfocus',
    ["speed defence"]          = 'speed', -- typo in game was showing 'speed defence defence'
    ["temperance"]             = 'frost',
    ["third eye"]              = 'thirdeye',

#if skills.apostasy then
    ["demon armour"]           = 'demonarmour',
#end
#if skills.necromancy then
    ["death aura"]             = 'deathaura',
#end
#if skills.healing then
    ["earth spiritshield"]     = 'earthblessing',
    ["endurance spiritshield"] = 'enduranceblessing',
    ["frost spiritshield"]     = 'frostblessing',
    ["thermal spiritshield"]   = 'thermalblessing',
    ["willpower spiritshield"] = 'willpowerblessing',
#end
#if skills.pranks or skills.swashbuckling then
    ["arrow catching"]         = 'arrowcatch',
#end
#if skills.metamorphosis then
    ["spirit bonding"]         = 'bonding',
#end
#if skills.groves then
    ["wild growth"]            = 'wildgrowth',

#end
  }

  if t[which] then which = t[which] end

  if defs["lost_"..which] then
    defs["lost_"..which]()
  end
end

function valid.truename()
  if not conf.aillusion then
    valid.simpleaeon()
    defs.lost_lyre()
  elseif (paragraph_length == 1 or (find_until_last_paragraph("is unable to resist the force of your faith", "substring") or find_until_last_paragraph("aura of weapons rebounding disappears", "substring"))) then
    checkaction(dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, "truename")
    defs.lost_lyre()
  else
    ignore_illusion("not first")
  end
end

function valid.just_aeon()
  checkaction(dict.checkslows.aff, true)
  lifevision.add(actions.checkslows_aff.p, nil, "aeon")
end

function valid.proper_aeon()
  if defc.speed then
    defs.lost_speed()
  elseif not conf.aillusion then
    valid.simpleaeon()
  else
    checkaction(dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, "aeon")
  end
end
valid.bashing_aeon = valid.proper_aeon

function valid.proper_retardation()
  if conf.aillusion then
    checkaction(dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, "retardation")
  else
    valid.simpleretardation()
  end
end

function valid.proper_stun(num)
  if not conf.aillusion then
    valid.simplestun(num)
  else
    checkaction(dict.checkstun.aff, true)
    lifevision.add(actions.checkstun_aff.p, nil, num)
  end
end

function valid.proper_paralysis()
  -- if not conf.aillusion or (not (bals.balance and bals.equilibrium and bals.leftarm and bals.rightarm) or ignore.checkparalysis) then
  if not conf.aillusion or ignore.checkparalysis then
    valid.simpleparalysis()
  elseif not affs.paralysis then
    checkaction(dict.checkparalysis.aff, true)
    lifevision.add(actions.checkparalysis_aff.p)
  end

  if conf.paused and conf.hinderpausecolour then
    selectCurrentLine()
    fg(conf.hinderpausecolour)
    resetFormat()
    deselect()
  end
end

function valid.proper_hypersomnia()
  if not conf.aillusion or ignore.checkhypersomnia then
    valid.simplehypersomnia()
  elseif not affs.hypersomnia then
    checkaction(dict.checkhypersomnia.aff, true)
    lifevision.add(actions.checkhypersomnia_aff.p)
  end
end

function valid.proper_asthma()
  if not conf.aillusion or ignore.checkasthma then
    valid.simpleasthma()
    affsp.asthma = nil
  elseif not affs.asthma then
    checkaction(dict.checkasthma.aff, true)
    lifevision.add(actions.checkasthma_aff.p, nil, stats.currenthealth)
  end
end

function valid.proper_asthma_smoking()
  if conf.aillusion and paragraph_length <= 1 and not conf.batch then return end

  if not conf.aillusion or ignore.checkasthma then
    valid.simpleasthma()
    affsp.asthma = nil
  else
    checkaction(dict.checkasthma.aff, true)
    lifevision.add(actions.checkasthma_aff.p, nil, stats.currenthealth)
  end
end

function valid.darkshade_paralysis()
  if not conf.aillusion then
    valid.simpleparalysis()
    valid.simpledarkshade()
  else
    checkaction(dict.checkparalysis.aff, true)
    lifevision.add(actions.checkparalysis_aff.p, nil, "darkshade")
  end
end

function valid.darkshade_sun()
  checkaction(dict.darkshade.aff, true)
  if actions.darkshade_aff then
    lifevision.add(actions.darkshade_aff.p, nil, stats.currenthealth)
  end
end

function valid.maybe_impatience()
  checkaction(dict.checkimpatience.aff, true)
  lifevision.add(actions.checkimpatience_aff.p, nil, "quiet")
end

function valid.proper_impatience()
  if not conf.aillusion or ignore.checkimpatience then
    valid.simpleimpatience()
  else
     -- limerick because songbirds will make lg 2
     -- maggots isn't a full line, because on sw80 it will wrap
    local previousline = (find_until_last_paragraph("glares at you and your brain suddenly feels slower", "substring") or find_until_last_paragraph("evil eye", "substring") or find_until_last_paragraph("wracks", "substring") or find_until_last_paragraph("You recoil in horror as countless maggots squirm over your flesh", "substring") or line:find("jaunty limerick", 1, true) or find_until_last_paragraph("points an imperious finger at you", "substring") or find_until_last_paragraph("glowers at you with a look of repressed disgust before making a slight gesture toward you.", "substring") or find_until_last_paragraph("hand at you, a wash of cold causing your blood to evolve into something new.", "substring") or find_until_last_paragraph("Horror overcomes you as you realise that the curse of impatience", "substring")) and true or false
    if paragraph_length == 1 or previousline then
      checkaction(dict.checkimpatience.aff, true)
      if previousline then
        lifevision.add(actions.checkimpatience_aff.p)
      else
        lifevision.add(actions.checkimpatience_aff.p, nil, nil, 1)
      end
    else
      ignore_illusion("not first")
    end
  end
end

function valid.curse_dispel()
  if defc.ghost then defs.lost_ghost() return end
  if defc.shroud then defs.lost_shroud() return end
end

function valid.subterfuge_hallucinations()
  if getLineNumber("main") ~= lastpromptnumber+2 then return end
  valid.simplehallucinations()
end

function valid.subterfuge_confusion()
  if getLineNumber("main") ~= lastpromptnumber+2 then return end
  valid.simpleconfusion()
end

function valid.subterfuge_bite()
  -- should use affs.from field to track what did you get the venom from, then if it's confirmed, strip sileris
end

function valid.subterfuge_camus()
  checkaction(dict.sileris.gone, true)
  lifevision.add(actions.sileris_gone.p, "camusbite", stats.currenthealth)
end

function valid.subterfuge_sumac()
  checkaction(dict.sileris.gone, true)
  lifevision.add(actions.sileris_gone.p, "sumacbite", stats.currenthealth)
end

function valid.proper_relapsing()
  if not conf.aillusion then
    valid.simplerelapsing()
  else
    checkaction(dict.relapsing.aff, true)
    lifevision.add(actions.relapsing_aff.p)
  end
end

function valid.relapsing_camus()
  checkaction(dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, "camus", stats.currenthealth)
end

function valid.relapsing_sumac()
  checkaction(dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, "sumac", stats.currenthealth)
end

function valid.relapsing_vitality()
  dict.relapsing.aff.hitvitality = true
end

function valid.relapsing_oleander()
  checkaction(dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, "oleander", (defc.blind or affs.blindaff))
end

function valid.relapsing_colocasia()
  checkaction(dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, "colocasia", (defc.blind or affs.blindaff or defc.deaf or affs.deafaff))
end

function valid.relapsing_oculus()
  checkaction(dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, "oculus", (defc.blind or affs.blindaff or defc.deaf or affs.deafaff))
end

function valid.relapsing_oculus()
  checkaction(dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, "oculus", (defc.blind or affs.blindaff))
end

function valid.relapsing_prefarar()
  checkaction(dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, "prefarar", (defc.deaf or affs.deafaff))
end

function valid.relapsing_asthma()
  checkaction(dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, "asthma")
end

function valid.subterfuge_bind()
  if not conf.aillusion or affs.sleep then
    valid.simplebound()
  end
end

function valid.kaido_choke()
  if conf.breath and conf.keepup and not defkeepup[defs.mode].breath then
    defs.keepup("breath", true)
    echo("\n")
    if math.random(1, 10) == 1 then
      echof("Run away! Run away! ('br' to turn off breath)")
    elseif math.random(1, 10) == 1 then
      echof("We'll get through this. *determined* ('br' to turn off breath)")
    else
      echof("Eep... holding our breath ('br' to turn off).")
    end
  end
end
valid.noose_trap = valid.kaido_choke
valid.vodun_throttle = valid.kaido

function valid.proper_sensitivity()
  checkaction(dict.sensitivity.aff, true)
  lifevision.add(actions.sensitivity_aff.p, "checkdeaf")
end

function valid.webbed_buckawns()
  if conf.buckawns then return
  else
    if not conf.aillusion then
      valid.simplewebbed()
    else
      checkaction(dict.checkwrithes.aff, true)
      lifevision.add(actions.checkwrithes_aff.p, nil, "webbed", 1)
    end
  end
end

function valid.proper_webbed()
  if not conf.aillusion then
    valid.simplewebbed()
  else
    checkaction(dict.checkwrithes.aff, true)
    lifevision.add(actions.checkwrithes_aff.p, nil, "webbed")
  end
end

function valid.proper_chill()
  local aff

  if defc.caloric then defs.lost_caloric() return end

  if not affs.shivering then aff = "shivering" else aff = "frozen" end

  checkaction(dict[aff].aff, true)
  if actions[aff .. "_aff"] then
    lifevision.add(actions[aff .. "_aff"].p)
  end
end

function valid.magi_deepfreeze()
  if defc.caloric then
    defs.lost_caloric()
    valid.simpleshivering()
  else
    valid.simpleshivering()
    valid.simplefrozen()
  end
end

-- logic is done inside receivers
function valid.proper_transfix()
  if not conf.aillusion or paragraph_length > 2 then
    valid.simpletransfixed()
  else
    checkaction(dict.checkwrithes.aff, true)
    lifevision.add(actions.checkwrithes_aff.p, nil, "transfixed")
  end
end

valid.proper_transfixed = valid.proper_transfix

function valid.failed_transfix()
  defs.lost_blind()

  if actions.transfixed_aff then
    killaction(dict.transfixed.aff)
  end
  if actions.checkwrithes_aff and lifevision.l.checkwrithes_aff and lifevision.l.checkwrithes_aff.arg == "transfixed" then
    killaction(dict.checkwrithes.aff)
  end
end

function valid.parry_limb(limb)
  if not sp_limbs[limb] then return end

  if find_until_last_paragraph("You feel your will manipulated by the soulmaster entity.", "exact") or find_until_last_paragraph("You cannot help but obey.", "exact") then
    checkaction(dict.doparry.physical, true)
  else
    checkaction(dict.doparry.physical)
  end

  if actions.doparry_physical then
    lifevision.add(actions.doparry_physical.p, nil, limb)
  end
end

function valid.parry_none()
  checkaction(dict.doparry.physical)
  if actions.doparry_physical then
    lifevision.add(actions.doparry_physical.p, "none")
  end
end

function valid.cant_parry()
  valid.parry_none()

  if not conf.aillusion then
    sk.cant_parry()
  else
    sk.unparryable_symptom()
  end
end

function valid.bad_legs()
  if affs.crippledrightleg or affs.crippledleftleg or affs.mangledleftleg or affs.mangledrightleg or affs.mutilatedrightleg or affs.mutilatedleftleg then return end

  valid.simpleunknownany()
end


for _, aff in ipairs({"hamstring", "galed", "voided", "inquisition", "burning", "icing", "phlogistication", "vitrification", "corrupted", "mucous", "rixil", "palpatar", "cadmus", "hecate", "ninkharsag", "swellskin", "pinshot", "dehydrated", "timeflux", "lullaby", "numbedleftarm", "numbedrightarm", "unconsciousness",
#if skills.metamorphosis then
"cantmorph",
#end
}) do
  valid[aff.."_woreoff"] = function()
    checkaction(dict[aff].waitingfor, true)
    if actions[aff.."_waitingfor"] then
      lifevision.add(actions[aff.."_waitingfor"].p)
    end
  end
end

function valid.stun_woreoff()
  -- not only stun, but checkstun maybe was waiting, didn't get to check -> needs to restore lifevision
  checkaction(dict.stun.waitingfor)
  if actions.stun_waitingfor then
    lifevision.add(actions.stun_waitingfor.p)
  elseif actions.checkstun_misc then
    lifevision.add(actions.checkstun_misc.p, nil, "fromstun")
  end
end

#for _, aff in ipairs({"heartseed", "hypothermia"}) do
function valid.$(aff)_cured()
  checkaction(dict.curing$(aff).waitingfor)
  if actions.curing$(aff)_waitingfor then
    lifevision.add(actions.curing$(aff)_waitingfor.p)
  end
end
#end

function valid.aeon_woreoff()
  local result = checkany(dict.aeon.smoke)

  if not result then
    if conf.aillusion and not passive_cure_paragraph and not find_until_last_paragraph("You touch the tree of life tattoo.", "exact") then
      checkaction(dict.aeon.gone, true)
      lifevision.add(actions.aeon_gone.p, nil, nil, 1)
    else
      -- clear the lineguard if we previously set it via aeon_gone
      if table.contains(lifevision.l:keys(), "aeon_gone") and lifevision.getlineguard() then
        lifevision.clearlineguard()
      end
      checkaction(dict.aeon.gone, true)
      lifevision.add(actions.aeon_gone.p)
    end
  else
    -- if it was a smoke cure, can't lineguard 1 then, it'll be 2
    smoke_cure = true
    lifevision.add(actions[result.name].p)
  end
end

function valid.destroy_retardation()
  checkaction(dict.retardation.gone, true)
  lifevision.add(actions.retardation_gone.p)

  valid.simpleaeon()
end

function valid.ablaze_woreoff()
  checkaction(dict.ablaze.gone, true)
  lifevision.add(actions.ablaze_gone.p)
end

function valid.wake_start()
  checkaction(dict.sleep.misc)
  if actions.sleep_misc then
    lifevision.add(actions.sleep_misc.p)
  end
end

function valid.wake_done()
  checkaction(dict.curingsleep.waitingfor, true)
  lifevision.add(actions.curingsleep_waitingfor.p)
end

function valid.symp_dizziness_fell()
  -- if not conf.aillusion then
    valid.simpledizziness()
    valid.simpleprone()
  -- elseif affs.dizziness then
  --   valid.simpleprone()
  -- end
end

function valid.cured_fear()
  checkaction(dict.fear.misc)
  if actions.fear_misc then
    lifevision.add(actions.fear_misc.p)
  end
end

function valid.tootired_focus()
  local r = findbybal("focus")
  if not r then return end

  focus_cure = true

  -- in case of double-applies, don't overwrite the first successful application
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "offbalance")
  end
end

function valid.mickey()
  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then ignore_illusion("not first") return end

  local r = findbybal("herb")
  if not r then return end

  lifevision.add(actions[r.name].p, "mickey")
end

function valid.focus_choleric()
  local r = findbybal("focus")
  if not r then ignore_illusion("Ignored the illusion because we aren't actually focusing right now (or we were forced).") return end

  checkaction(dict.stolebalance.happened, true)
  lifevision.add(actions.stolebalance_happened.p, nil, "focus")

  focus_cure = true
  killaction(dict[r.action_name].focus)
end

function valid.nomana_focus()
  local r = findbybal("focus")
  if not r then return end

  lifevision.add(actions[r.name].p, "nomana")
end

function valid.nomana_clot()
  checkaction(dict.bleeding.misc)
  if actions.bleeding_misc then
    lifevision.add(actions.bleeding_misc.p, "nomana")
  end
end

function valid.stoodup()
  checkaction(dict.prone.misc)
  if actions.prone_misc then
    lifevision.add(actions.prone_misc.p)
  end
end

function valid.sippedhealth()
  checkaction(dict.healhealth.sip)
  if actions.healhealth_sip then
    sip_cure = true
    lifevision.add(actions.healhealth_sip.p)
  end
end
function valid.sippedmana()
  checkaction(dict.healmana.sip)
  if actions.healmana_sip then
    sip_cure = true
    lifevision.add(actions.healmana_sip.p)
  end
end

function valid.gotherb()
  if not conf.aillusion or not sk.blockherbbal then
    checkaction(dict.gotbalance.happened, true)
    dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "herb" -- hack to allow multiple balances at once
    lifevision.add(actions.gotbalance_happened.p)
    selectCurrentLine()
    setFgColor(0, 170, 0)
    deselect()
  else
    ignore_illusion("Couldnt've possibly recovered herb balance so soon - "..(watch.herb_block and getStopWatchTime(watch.herb_block) or '?').."s after eating.")
  end
end

#for _, balance in ipairs{"moss", "focus", "sip", "purgative", "dragonheal", "smoke", "tree"} do
function valid.got$(balance)()
  checkaction(dict.gotbalance.happened, true)
    dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "$(balance)" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
#end

function valid.gotsalve()
  if conf.aillusion and paragraph_length ~= 1 then
    local lastline = getLines(getLineNumber()-1, getLineNumber())[1]

    local lines = {
      ["Your left leg feels stronger and healthier."] = {affs = {"curingmutilatedrightleg", "curingmutilatedleftleg", "curingmangledrightleg", "curingmangledleftleg", "curingparestolegs"}, location = "legs"},
      ["Your right leg feels stronger and healthier."] = {affs = {"curingmutilatedrightleg", "curingmutilatedleftleg", "curingmangledrightleg", "curingmangledleftleg", "curingparestolegs"}, location = "legs"},
      ["Your left arm feels stronger and healthier."] = {affs = {"curingmutilatedrightarm", "curingmutilatedleftarm", "curingmangledrightarm", "curingmangledleftarm", "curingparestoarms"}, location = "arms"},
      ["Your right arm feels stronger and healthier."] = {affs = {"curingmutilatedrightarm", "curingmutilatedleftarm", "curingmangledrightarm", "curingmangledleftarm", "curingparestoarms"}, location = "arms"},
    }

    if lines[lastline] then
      local had
      for _, aff in ipairs(lines[lastline].affs) do
        if actions[aff.."_waitingfor"] then
          local afftime = getStopWatchTime(actions[aff.."_waitingfor"].p.actionwatch)
          if afftime >= conf.ai_minrestorecure then
            had = true; break
          else
            ignore_illusion(string.format("%s cure couldnt've possibly finished so soon, in %ss - minimum allowed is %ss. This seems like an illusion to trick you.", aff, afftime, conf.ai_minrestorecure))
            return
          end
        end
      end

      if not had then
        ignore_illusion("We aren't applying restoration to "..lines[lastline].location.." right now")
      end
    end
  end
  checkaction(dict.gotbalance.happened, true)
    dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "salve" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function valid.gotpurgative()
  checkaction(dict.gotbalance.happened, true)
    dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "purgative" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function valid.forcesalve()
  checkaction(dict.gotbalance.happened, true)
    dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "salve" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function valid.forcefocus()
  checkaction(dict.gotbalance.happened, true)
    dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "focus" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function valid.forceherb()
  checkaction(dict.gotbalance.happened, true)
    dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "herb" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function valid.got_rebounding()
  checkaction(dict.waitingonrebounding.waitingfor)
  if actions.waitingonrebounding_waitingfor then
    lifevision.add(actions.waitingonrebounding_waitingfor.p)
  end
end

function valid.rebounding_deathtarot()
  checkaction(dict.waitingonrebounding.waitingfor, false)
  if actions.waitingonrebounding_waitingfor then
    lifevision.add(actions.waitingonrebounding_waitingfor.p, "deathtarot")
  end
end

-- palpatar line will be before this if you've had it
function defs.got_speed()
  checkaction(dict.curingspeed.waitingfor)
  if actions.curingspeed_waitingfor then
    lifevision.add(actions.curingspeed_waitingfor.p)
  end
end

function valid.bled(howmuch)
  local amount = tonumber(howmuch)

  checkaction(dict.bleeding.aff, true)
  if actions.bleeding_aff then
    lifevision.add(actions.bleeding_aff.p, nil, amount)
  end

  if affs.unknownany and stats.hp == 100 and stats.mana == 100 then
    valid.simplerecklessness()
  end
end

function valid.clot1()
  checkaction(dict.bleeding.misc)
  if actions.bleeding_misc then
    lifevision.add(actions.bleeding_misc.p)
  end

  if conf.gagclot and not sys.sync then deleteLineP() end
end

function valid.clot2()
  checkaction(dict.bleeding.misc)
  if actions.bleeding_misc then
    lifevision.add(actions.bleeding_misc.p, "oncured")
  end

  if conf.gagclot and not sys.sync then deleteLineP() end
end

function valid.symp_haemophilia()
  if not conf.aillusion and actions.bleeding_misc then
    valid.remove_unknownany("haemophilia")
    valid.simplehaemophilia()
  else
    checkaction(dict.bleeding.misc, false)
    if actions.bleeding_misc then
      valid.remove_unknownany("haemophilia")
      lifevision.add(actions.bleeding_misc.p, "haemophilia", nil, 1)
    elseif not affs.haemophilia then
      ignore_illusion("Ignored this illusion because we aren't trying to clot right now (or we were forced).")
    end
  end
end

function valid.proper_haemophilia()
  if not conf.aillusion then
    valid.simplehaemophilia()
  elseif find_until_last_paragraph("wracks", "substring") and paragraph_length >= 3 then
    valid.simplehaemophilia()
  elseif find_until_last_paragraph("glowers at you with a look of repressed disgust", "substring") or find_until_last_paragraph("stares menacingly at you, its eyes flashing brightly.", "substring") then
    valid.simplehaemophilia()
  elseif find_until_last_paragraph("points an imperious finger at you.", "substring") then
    -- shamanism
    valid.simplehaemophilia()
  elseif find_until_last_paragraph("makes a quick, sharp gesture toward you.", "substring") then
    -- occultism instill
    valid.simplehaemophilia()
  elseif line:starts("A bloodleech leaps at you, clamping with teeth onto exposed flesh and secreting some foul toxin into your bloodstream. You stumble as you are afflicted") then
    -- domination bloodleech
    valid.simplehaemophilia()
  else
    ignore_illusion("Doesn't seem to be an Alchemist wrack or Occultism instill - going to see if it's real off symptoms.")
  end
end

function valid.humour_wrack()
  checkaction(dict.unknownany.aff, true)
  lifevision.add(actions["unknownany_aff"].p, "wrack", nil)

  -- to check if we got reckless!
  if stats.currenthealth ~= stats.maxhealth then
    dict.unknownany.reckhp = true end
  if stats.currentmana ~= stats.maxmana then
    dict.unknownany.reckmana = true end
end

-- detect how many wracks (of the 2 available in a truewrack) were hidden (that is - humour-based wrack, which is hidden)
-- vs affliction-based wrack, which is visible
function valid.humour_truewrack()
  local sawaffs = 0
  for _, action in pairs(lifevision.l:keys()) do
    if action:find("_aff", 1, true) then
      sawaffs = sawaffs + 1
    end
  end

  -- limit to 2 in case we saw more - we don't want to add more than 2 unknowns
  if sawaffs > 2 then sawaffs = 2 end

  -- add the appropriate amount of missing unknowns, up to 2. If we saw an affliction, don't add an unknown for it.
  for i = 1, 2-sawaffs do
    valid.simpleunknownany()
  end
end

function valid.got_humour(which)
  assert(dict[which.."humour"], "svo.valid.got_humour: which humour to add?")

  local function countaffs(humour)
    local affs_in_a_humour = 3

    local t = {
      choleric    = {"illness", "sensitivity", "slickness"},
      melancholic = {"anorexia", "impatience", "stupidity"},
      phlegmatic  = {"asthma", "clumsiness", "disloyalty"},
      sanguine    = {"haemophilia", "recklessness",  "paralysis"}
    }

    -- add the amount of focusables in a humour as the 4th argument, to check for as well
    for humour, data in pairs(t) do
      local focusables_in_humour = 0
      for i = 1, affs_in_a_humour do
        if dict[data[i]].focus then focusables_in_humour = focusables_in_humour + 1 end
      end
      data[affs_in_a_humour+1] = focusables_in_humour
    end

    -- update temper count according to known humour-related affs we've got
    local count = 0
    for i = 1, affs_in_a_humour do
      if affs[t[humour][i]] then count = count + 1 end
    end

    -- update temper count according to unknown focusable affs we've got, limited by the max
    -- amount of focusable affs we can have
    if affs.unknownmental then
      local max_focusable_affs_in_humour = t[humour][affs_in_a_humour+1]
      count = count + (dict.unknownmental.count > max_focusable_affs_in_humour and max_focusable_affs_in_humour or dict.unknownmental.count)
    end

    -- and lastly, unknown affs
    if affs.unknownany then
      count = count + dict.unknownany.count
    end

    return count
  end

  -- humours give up to 3 levels in one go, depending on which relevant afflictions have you got. account for unknown afflictions as well!
  -- 1 for the temper, + any more affs
  local humourlevels = 1 + countaffs(which)
  -- trim the max we counted down to 3, which is the most possible right now
  if humourlevels > 3 then humourlevels = 3 end

  checkaction(dict[which.."humour"].aff, true)
  lifevision.add(actions[which.."humour_aff"].p, nil, humourlevels)
end

function valid.sanguine_inundate()
  checkaction(dict.sanguinehumour.herb, true)
  if actions.sanguinehumour_herb then
    lifevision.add(actions.sanguinehumour_herb.p, "inundated")
  end
end

function valid.choleric_inundate()
  checkaction(dict.cholerichumour.herb, true)
  if actions.cholerichumour_herb then
    lifevision.add(actions.cholerichumour_herb.p, "inundated")
  end
end

function valid.melancholic_inundate()
  checkaction(dict.melancholichumour.herb, true)
  if actions.melancholichumour_herb then
    lifevision.add(actions.melancholichumour_herb.p, "inundated")
  end
end

function valid.phlegmatic_inundate()
  checkaction(dict.phlegmatichumour.herb, true)
  if actions.phlegmatichumour_herb then
    lifevision.add(actions.phlegmatichumour_herb.p, "inundated")
  end
end

#for _, aff in ipairs({"skullfractures", "crackedribs", "wristfractures", "torntendons"}) do
function valid.$(aff)_apply()
  applyelixir_cure = true

  checkaction(dict.$(aff).sip, true)
  lifevision.add(actions.$(aff)_sip.p)
end

function valid.$(aff)_cured()
  applyelixir_cure = true

  checkaction(dict.$(aff).sip, true)
  lifevision.add(actions.$(aff)_sip.p, "cured")
end
#end

function valid.tarot_aeon()
  -- speed -can- be stripped in blackout
  -- if conf.aillusion and defc.speed and not actions.speed_gone and paragraph_length <= 2 then return end

  if not conf.aillusion or paragraph_length > 2 then
    valid.simpleaeon()
  else
    checkaction(dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, "aeon")
  end
end

function valid.refilled(what)
  local shortname = es_shortnamesr[what]
  if not shortname or es_categories[what] == "venom" then return end

  if es_potions[es_categories[what]][what].sips == 0 then
    es_potions[es_categories[what]][what].sips = es_potions[es_categories[what]][what].sips + 50
    es_potions[es_categories[what]][what].vials = es_potions[es_categories[what]][what].vials + 1
    echo"\n" echof("We refilled %s - will use it for cures now.", what)
  end
end

function valid.missing_herb()
  if actions.checkstun_misc then
    deleteLineP()
    lifevision.add(actions.checkstun_misc.p, "onclear")
  end

  -- don't echo anything for serverside failing to eat a herb
  if conf.serverside then return end

  local eating = findbybals ({"herb", "moss"})
  if not eating then return end
  local action = select(2, next(eating))
  eating = next(eating)

  if sys.last_used[eating] then
    rift.invcontents[sys.last_used[eating]] = 0

    -- echo only if temporarily ran out and have more in rift
    if rift.riftcontents[sys.last_used[eating]] ~= 0 and sys.canoutr then
      echo"\n" echof("(don't have %s in inventory for %s as I thought)", sys.last_used[eating], action.action_name)
    end
    -- SHOULD cancel action, but that can also cause us to get into an infinite loop of eating nothing
    -- needs to be fixed after better herb tracking
  end
end

function valid.symp_anorexia()
  if not conf.aillusion then -- ai is off? go-ahead then
    valid.simpleanorexia()
    return
  end

  local eating = findbybal ("herb")
  if eating then
    valid.simpleanorexia()
    killaction(dict[eating.action_name].herb)
  elseif findbybals({"sip", "purgative", "herb", "moss"}) then
    valid.simpleanorexia()
  elseif actions.checkanorexia_misc then
    lifevision.add(actions.checkanorexia_misc.p, "blehfood")
  end
end

function valid.salve_fizzled(limb)
  local r = checkany(dict.crippledleftarm.salve, dict.crippledleftleg.salve, dict.crippledrightarm.salve, dict.crippledrightleg.salve, dict.unknowncrippledlimb.salve, dict.unknowncrippledarm.salve, dict.unknowncrippledleg.salve)
  if not r then return end

  apply_cure = true

  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "fizzled", limb)
  end
end

function valid.health_fizzled()
  local r = checkany(dict.skullfractures.sip, dict.crackedribs.sip, dict.wristfractures.sip, dict.torntendons.sip)
  if not r then return end

  applyelixir_cure = true

  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "fizzled")
  end
end

function valid.health_noeffect()
  local r = checkany(dict.skullfractures.sip, dict.crackedribs.sip, dict.wristfractures.sip, dict.torntendons.sip)
  if not r then return end

  applyelixir_cure = true
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "noeffect")
  end
end

-- this can happen on a restore or a mending application
-- handle upgrading of the limb
function valid.update_break(limb)
  local r = checkany(dict.crippledleftarm.salve, dict.crippledleftleg.salve, dict.crippledrightarm.salve, dict.crippledrightleg.salve, dict.unknowncrippledlimb.salve, dict.unknowncrippledarm.salve, dict.unknowncrippledleg.salve)
  if not r and not actions.restore_physical then return end

  if actions.restore_physical then
    if not affs["mangled"..limb] then
      valid.simple["mangled"..limb]()
    end
  else
    apply_cure = true
    if not lifevision.l[r.name] then
      lifevision.add(actions[r.name].p, "fizzled", limb)
    end
  end
end

function valid.salve_offbalance()
  local r = findbybal("salve")
  if not r then return end

  apply_cure = true

  -- in case of double-applies, don't overwrite the first successful application
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "offbalance")
  end
end

function valid.force_aeon()
  vaff("aeon")
end

function valid.herb_cured_insomnia()
  local r = checkany(dict.dissonance.herb, dict.impatience.herb, dict.stupidity.herb, dict.dizziness.herb, dict.epilepsy.herb, dict.shyness.herb)
  if conf.aillusion and not (r or find_until_last_paragraph("You feel irresistibly compelled", "substring") or find_until_last_paragraph("You cannot help but obey.", "exact")) then ignore_illusion("We aren't eating goldenseal at the moment.") return end

  if r then
    killaction(dict[r.action_name].herb)
  end

  defs.lost_insomnia()
  lostbal_herb()

  if r then
    checkaction(dict[r.action_name].gone, true)
    lifevision.add(actions[r.action_name.."_gone"].p)
  end

  checkaction(dict.checkimpatience.misc, true)
  lifevision.add(actions.checkimpatience_misc.p, "onclear")
end

function valid.fillskullcap()
  checkaction(dict.fillskullcap.physical)
  if actions.fillskullcap_physical then
    lifevision.add(actions.fillskullcap_physical.p)
  end
end

function valid.fillelm()
  checkaction(dict.fillelm.physical)
  if actions.fillelm_physical then
    lifevision.add(actions.fillelm_physical.p)
  end
end

function valid.fillvalerian()
  checkaction(dict.fillvalerian.physical)
  if actions.fillvalerian_physical then
    lifevision.add(actions.fillvalerian_physical.p)
  end
end

function valid.alreadyfull()
  local result = checkany(dict.fillskullcap.physical, dict.fillelm.physical, dict.fillvalerian.physical)

  if not result then return end

  lifevision.add(actions[result.name].p)
end

function valid.litpipe(gag2)
  if not sys.sync then
    if conf.gagrelight then deleteLineP() end
    if conf.gagrelight and gag2 then deleteLine() end
  end

  local result = checkany(
    dict.lightelm.physical, dict.lightvalerian.physical, dict.lightskullcap.physical)

  if not result then return end
  lifevision.add(actions[result.name].p)
end

function valid.litallpipes()
  if not sys.sync and conf.gagrelight then deleteLineP() end

  checkaction(dict.lightpipes.physical)
  if actions.lightpipes_physical then
    lifevision.add(actions.lightpipes_physical.p)
  end
end

herb_cure = false
 -- reset the flag tracking whenever we got a cure for what we ate (herb_cure) at the start
function valid.ate1()
  if paragraph_length == 1 then
    herb_cure = false
  end

  -- see if we need to enable arena mode for some reason
  local t = sk.arena_areas
  local area = atcp.RoomArea or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.area)
  if area and t[area] and not conf.arena then
    conf.arena = true
    raiseEvent("svo config changed", "arena")
    prompttrigger("arena echo", function()
      echo'\n'echof("Looks like you're actually in the arena - enabled arena mode.\n") showprompt()
    end)
  end

  -- check anti-illusion with GMCP's herb removal
  if conf.aillusion and not conf.arena and not affs.dementia and sys.enabledgmcp and not sk.removed_something and not find_until_last_paragraph("You feel irresistibly compelled", "substring") and not find_until_last_paragraph("You cannot help but obey.", "exact") then
    -- let nicer tooltips come first before this one
    aiprompt("nothing removed, but ate", function() ignore_illusion("We didn't eat that!", true) end)
  end

  -- check if we need to add or remove addiction - but not if we are ginseng/ferrum as that doesn't go off on addiction
  if (not conf.aillusion or findbybal("herb")) and not find_until_last_paragraph("ginseng root", "substring") and not find_until_last_paragraph("ferrum flake", "substring") then
    sk.onprompt_beforelifevision_add("add/remove addiction", function()
      if not affs.addiction and find_until_last_paragraph("Your addiction can never be sated.", "exact") then
        valid.simpleaddiction()
      elseif affs.addiction and not find_until_last_paragraph("Your addiction can never be sated.", "exact") then
        checkaction(dict.addiction.gone, true)
        lifevision.add(actions.addiction_gone.p)
      end
    end)
  end
end

-- see if the herb we ate actually cured us: if no, register the herb eating action as 'empty'
function valid.ate2()
  -- cadmus comes on the next line after
  tempLineTrigger(1,1,[[
    if line == "The vile curse of Cadmus leaves you." then
      svo.valid.cadmus_woreoff()
    end
  ]])

  -- if it's addition or swellskin stretching the eating - don't go off now, but on the next one
  if line == "Your addiction can never be sated." or line == "Eating is suddenly less difficult again." then return end

  if not herb_cure then
    local eating = findbybal("herb")
    if not eating then return end

    -- check timers here! should not be less than half of getping(). Check *action*, not affliction timer as well
    if conf.aillusion and not conf.serverside then
      local time, lat = getStopWatchTime(actions[eating.name].p.actionwatch), getping()

      if time < (lat/2) then
        ignore_illusion("This looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    -- addiction needs to stretch the lineguard to 2, since it is You eat/Your addiction/prompt.
    -- [Curing] does not show up for find_until_last_paragraph when it is gagged, so track it otherwise
    if conf.aillusion then
      lifevision.add(actions[eating.name].p, "empty", nil, ((find_until_last_paragraph("Your addiction can never be sated.", "exact") or find_until_last_paragraph("Eating is suddenly less difficult again.", "exact") or sk.sawcuringcommand) and 2 or 1))
    else
      lifevision.add(actions[eating.name].p, "empty")
    end
  end

  herb_cure = false
end

local sip_cure = false

function valid.sip1()
  sip_cure = false
end

function valid.sip2()
  if not sip_cure then
  local sipping = findbybal("purgative")

  if not sipping then
    -- special case for speed, which is a sip but balanceless
    if doingaction"speed" then
      lifevision.add(actions.speed_purgative.p)
    end
  return end

    lifevision.add(actions[sipping.name].p, "empty")
  end

  sip_cure = false
end

local tree_cure = false

function valid.tree1()
  tree_cure = false
end

function valid.tree2()
  if not tree_cure then
    if conf.aillusion and not actions.touchtree_misc then
      ignore_illusion("We aren't actually touching tree right now (or we were forced).", true)
      return
    end

    -- prevent against a well-timed tree illusion, which when empty, forces us to clear all afflictions
    if conf.aillusion then
      local time, lat = getStopWatchTime(actions.touchtree_misc.p.actionwatch), getping()

      if time < (lat/2) then
        ignore_illusion("This looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    checkaction(dict.touchtree.misc, true)

    -- add it anyway, as the illusion could get cancelled later on
    lifevision.add(actions.touchtree_misc.p, "empty")
  end

  tree_cure = false
end

apply_cure = false

function valid.apply1()
  apply_cure = false
end

function valid.apply2()
  if not apply_cure then
  local r = findbybal("salve")
  if not r then return end

    lifevision.add(actions[r.name].p, "empty")
  end

  apply_cure = false
end

smoke_cure = false

function valid.smoke1()
  smoke_cure = false
end

function valid.smoke2()
  if not smoke_cure then
    local r = findbybal("smoke")
    if r then
      lifevision.add(actions[r.name].p, "empty")
    elseif actions.checkasthma_smoke then
      lifevision.add(actions.checkasthma_smoke.p, "onclear")
    end
  end

  smoke_cure = false
end

applyelixir_cure = false

function valid.applyelixir1()
  applyelixir_cure = false
end

function valid.applyelixir2()
  if not applyelixir_cure then
    local r = findbybal("sip")
    if not r then return end

      lifevision.add(actions[r.name].p, "empty")
  end

  applyelixir_cure = false
end

focus_cure = false

-- note: rixil fading will be inbetween here
function valid.focus1()
  focus_cure = false
end

-- this should go off on the line where a focus cure would have otherwise seen
function valid.focus2()
  -- ignore spirit disrupt tick and affliction lines, as they will trigger an 'empty'
  local spiritdisrupt = {
    "The elemental energy about you fluctuates.",
    "Your throat grows suddenly dry.",
    "Your skin begins to grow uncomfortably hot.",
    "A sudden feeling of nausea overtakes you.",
    "Your lungs suddenly constrict and dizziness overtakes you."
  }

  if table.contains(spiritdisrupt, line) then return end

  if actions.checkimpatience_misc then
    lifevision.add(actions.checkimpatience_misc.p, "onclear")
  end

  if not focus_cure then
    focus_cure = false

    local r = findbybal("focus")

    if not r then return end

    -- check timers here! should not be less than half of getping(). Check *action*, not affliction timer as well
    if conf.aillusion and not conf.serverside then
      local time, lat = getStopWatchTime(actions[r.name].p.actionwatch), getping()

      if time < (lat/2) then
        ignore_illusion("This 'cure' looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    lifevision.add(actions[r.name].p, "empty")
  end
end

function valid.salve_had_no_effect()
  local r = findbybal("salve")
  if not r then return end

  apply_cure = true
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "noeffect")
  end
end

function valid.plant_had_no_effect()
  local r = findbybal("herb")
  if not r then return end

  herb_cure = true

  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "noeffect")
  end
end

function valid.salve_slickness()
  local r = findbybal("salve")
  if not r then return end

  apply_cure = true
  valid.simpleslickness()
  killaction(dict[r.action_name].salve)
end

function valid.potion_slickness()
  local r = findbybal("salve")
  if not r then return end

  apply_cure = true
  valid.simpleslickness()
  killaction(dict[r.action_name].salve)
end

function valid.sip_had_no_effect()
  local function kill(r)
    sip_cure = true
    if not lifevision.l[r.name] then
      lifevision.add(actions[r.name].p, "noeffect")
    end
  end

  local r = findbybal("sip")
  if r then kill(r) else
    r = findbybal("purgative")
    if not r then return end

    kill(r)
  end
end

function valid.removed_from_rift()
  -- we're only interested in this while in sync mode
  if not sys.sync then return end

  local eating = findbybal("herb")
  if eating then killaction(eating) return end

  local outring = findbybal("physical")
  if outring then killaction(outring) end
end
signals.removed_from_rift:connect(valid.removed_from_rift)

function valid.no_refill_herb()
  for _, herb in ipairs{"elm", "valerian", "skullcap"} do
    if actions["fill"..herb.."_physical"] then
      rift.invcontents[pipes[herb].filledwith] = 0
      killaction(dict["fill"..herb].physical)
    end
  end
end

function valid.no_outr_herb(what)
  assert(what, "svo.valid.no_outr_herb: requires a single argument")
  if actions.doprecache_misc and rift.precache[what] ~= 0 and rift.riftcontents[what] ~= 0 and (rift.invcontents[what] < rift.precache[what]) then
    rift.riftcontents[what] = 0
    echo"\n" echof("Apparently we're out of %s! Can't precache it.", what)
  else
    local eating = findbybals ({"herb", "moss", "misc"})
    if not eating then
      -- check pipes instead
      local r = checkany(dict.fillskullcap.physical, dict.fillelm.physical, dict.fillvalerian.physical)

      if not r then return end

      rift.riftcontents[sys.last_used[r.name]] = 0
      return
    end

    local action = select(2, next(eating))
    eating = next(eating)

    -- check against what we actually ate as well in case of overlaps (ie sileris/irid)
    if sys.last_used[eating] and what:find(sys.last_used[eating]) then
      local eaten = sys.last_used[eating]
      rift.riftcontents[eaten] = 0

      local alternative
      if action.eatcure[1] == eaten then alternative = action.eatcure[2]
      else alternative = action.eatcure[1] end

      echo'\n' echof("Don't have %s, will try %s next time.", eaten, alternative)

      if rift.riftcontents[alternative] <= 0 then
        rift.riftcontents[alternative] = 1
      end
    end
  end
end

function valid.cureddisrupt()
  checkaction(dict.disrupt.misc)
  if actions.disrupt_misc then
    lifevision.add(actions.disrupt_misc.p)
  end
end


function valid.failed_focus_impatience()
  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then ignore_illusion("not first") return end
  local r = findbybal("focus")
  if r or not conf.aillusion or actions.checkimpatience_misc then
    if r then killaction(dict[r.action_name].focus) end

    if actions.checkimpatience_misc then
      lifevision.add(actions.checkimpatience_misc.p, "impatient", nil, 1)
    else
      valid.simpleimpatience()
    end
  -- don't show a false (i) when we already know we've got impatience
  elseif conf.aillusion and not affs.impatience then
    ignore_illusion("Not actually trying to focus right now (or we were forced).")
  end
end

function valid.smoke_failed_asthma()
  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then ignore_illusion("not first") return end

  if actions.checkasthma_smoke then
    lifevision.add(actions.checkasthma_smoke.p, "badlungs", nil, 1)
  end

  local r = findbybal("smoke")
  if r or not conf.aillusion then

    if not affs.asthma then
      checkaction(dict.asthma.aff, true)
      lifevision.add(actions["asthma_aff"].p, nil, nil, 1)
      affsp.asthma = nil
    end
  elseif conf.aillusion and not affs.asthma then -- don't show (i) on delays + already have valid asthma
    ignore_illusion("Not actually trying to smoke anything right now (or we were forced).")
  end
end

function valid.got_mucous()
  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then ignore_illusion("not first") return end

  if actions.checkasthma_smoke then
    lifevision.add(actions.checkasthma_smoke.p, "mucous", nil, 1)
  end

  local r = findbybal("smoke")
  if r or not conf.aillusion then

    if not affs.mucous then
      checkaction(dict.mucous.aff, true)
      lifevision.add(actions["mucous_aff"].p, nil, nil, 1)
    end
  elseif conf.aillusion then
    ignore_illusion("Not actually trying to smoke anything right now (or we were forced).")
  end
end

function valid.have_mucous()
  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then ignore_illusion("not first") return end

  local r = findbybal("smoke")
  if r or not conf.aillusion then

    if not affs.mucous then
      checkaction(dict.mucous.aff, true)
      lifevision.add(actions["mucous_aff"].p, nil, nil, 1)
    end
  elseif conf.aillusion then
    ignore_illusion("Not actually trying to smoke anything right now (or we were forced).")
  end
end

function valid.unlit_pipe()
  local r = findbybal("smoke")
  if not r then return end

  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then
    ignore_illusion("not first")
    return
  end

  if type(dict[r.action_name].smoke.smokecure) == "string" then
    pipes[dict[r.action_name].smoke.smokecure].lit = false
    show_info("unlit "..dict[r.action_name].smoke.smokecure, "Apparently the "..dict[r.action_name].smoke.smokecure.." pipe was out")
    killaction(dict[r.action_name].smoke)
  elseif type(dict[r.action_name].smoke.smokecure) == "table" then
    for _, herb in pairs(dict[r.action_name].smoke.smokecure) do
      if pipes[herb] and pipes[herb].lit then
        pipes[herb].lit = false
        show_info("unlit "..herb, "Apparently the "..herb.." pipe was out")
        if pipes[herb].arty then
          pipes[herb].arty = false
          show_info("not an artefact", "It's not an artefact pipe, either. I've made it be a normal one for you")
        end
        killaction(dict[r.action_name].smoke)
      end
    end
  end
end

function valid.necromancy_shrivel()
  valid["simplecrippled"..matches[2]..matches[3]]()
end

function valid.got_aeon()
  if conf.aillusion and not defc.speed then
    valid.simpleaeon()
  elseif not conf.aillusion then
    if not conf.aillusion then
      valid.simpleaeon()
    else
      checkaction(dict.checkslows.aff, true)
      lifevision.add(actions.checkslows_aff.p, nil, "aeon")
    end

    defs.lost_speed()
  end
end

function valid.empty_pipe()
  local r = findbybal("smoke")
  if not r then
    if conf.aillusion and not (actions.fillskullcap_physical or actions.fillelm_physical or actions.fillvalerian_physical)
      then ignore_illusion("Not actually trying to smoke anything right now (or we were forced).") end
    return
  end

  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then
    ignore_illusion("not first")
    return
  end

-- TODO: turn this into a dict. action validated by lifevision w/ a lifeguard
  if type(dict[r.action_name].smoke.smokecure) == "string" then
    pipes[dict[r.action_name].smoke.smokecure].puffs = 0
  elseif type(dict[r.action_name].smoke.smokecure) == "table" then
    for _, herb in pairs(dict[r.action_name].smoke.smokecure) do
      if pipes[herb] and pipes[herb].puffs then
        pipes[herb].puffs = 0
      end
    end
  end

  killaction(dict[r.action_name].smoke)

  if dict[r.action_name].smoke.smokecure[1] == "valerian" and not (bals.balance and bals.equilibrium) then
    sk.warn("emptyvalerianpipe")
  end
end

function valid.pipe_emptied()
  local r = checkany(dict.fillskullcap.physical, dict.fillelm.physical, dict.fillvalerian.physical)

  if not r then return end

  if dict[r.action_name].fillingid == pipes[dict[r.action_name].physical.herb].id then
    pipes[dict[r.action_name].physical.herb].puffs = 0
  else
    pipes[dict[r.action_name].physical.herb].puffs2 = 0
  end

  if sys.sync then
    killaction(dict[r.action_name].physical)
  end
end

function valid.empty_light()
  local r = checkany(dict.lightskullcap.physical, dict.lightelm.physical, dict.lightvalerian.physical)

  if not r then return end

  if dict[r.action_name].fillingid == pipes[dict[r.action_name].physical.herb].id then
    pipes[dict[r.action_name].physical.herb].puffs = 0
  else
    pipes[dict[r.action_name].physical.herb].puffs2 = 0
  end
  killaction(dict[r.action_name].physical)
end

-- bindings
#for _,aff in ipairs({"bound", "webbed", "roped", "transfixed", "impale", "hoisted"}) do
function valid.writhed$(aff)()
  if not affs.$(aff) then return end

  local result = checkany(dict.curingbound.waitingfor, dict.curingwebbed.waitingfor, dict.curingroped.waitingfor, dict.curingtransfixed.waitingfor, dict.curingimpale.waitingfor, dict.curinghoisted.waitingfor)

  if not result then return end

  -- if we were writhing what we expected from to writhe, continue
  if actions.curing$(aff)_waitingfor then
    lifevision.add(dict.curing$(aff).waitingfor)
  -- otherwise if we writhed from something we were not - kill if we were doing anything else and add the new
  else
    killaction(dict[result.action_name].waitingfor)
    checkaction(dict.curing$(aff).waitingfor, true)
    lifevision.add(dict.curing$(aff).waitingfor)
  end
end
#end

function valid.writhe()
  local result = checkany(dict.bound.misc, dict.webbed.misc, dict.roped.misc, dict.transfixed.misc, dict.hoisted.misc, dict.impale.misc)

  if not result then return end
  if actions[result.name] then
    lifevision.add(actions[result.name].p)
  end
end


function valid.writheimpale()
  local result = checkany(dict.impale.misc, dict.transfixed.misc, dict.webbed.misc, dict.roped.misc, dict.hoisted.misc, dict.bound.misc)

  if not result then return end

  if result.name == "impale_misc" then
    lifevision.add(actions[result.name].p)
  else
    lifevision.add(actions[result.name].p, "impale")
  end
end

function valid.writhe_helpless()
  local result = checkany(dict.bound.misc, dict.webbed.misc, dict.roped.misc, dict.impale.misc, dict.transfixed.misc, dict.hoisted.misc)

  if not result then ignore_illusion("We aren't actually writhing from anything right now (or we were forced).") return end
  if actions[result.name] then
    lifevision.add(actions[result.name].p, "helpless")
  end
end

-- restoration cures
#for _, restoration in pairs({
#  restorationlegs = {"mutilatedrightleg", "mutilatedleftleg", "mangledrightleg", "mangledleftleg", "parestolegs"},
#  restorationarms = {"mutilatedrightarm", "mutilatedleftarm", "mangledrightarm", "mangledleftarm", "parestoarms"},
#  restorationother = {"mildtrauma", "serioustrauma", "mildconcussion", "seriousconcussion", "laceratedthroat", "heartseed"}
#}) do
#  local checkany_string = ""
#  local temp = {}

#  for _, aff in pairs(restoration) do
#    temp[#temp+1] = encodew("curing"..aff)
#  end
#  checkany_string = table.concat(temp, ", ")

#  for _, aff in pairs(restoration) do
function valid.curing$(aff)()
  local result = checkany(dict.curing$(aff).waitingfor, $(checkany_string))

  if not result then return end

  if result.name == "curing$(aff)_waitingfor" then
    lifevision.add(actions["curing$(aff)_waitingfor"].p)
#if aff:find("leg")  then
  elseif (not conf.aillusion or affs.$(aff) or affs.parestolegs) then
#else
  elseif (not conf.aillusion or affs.$(aff) or affs.parestoarms) then
#end
    checkaction(dict["curing$(aff)"].waitingfor, true)
    lifevision.add(dict["curing$(aff)"].waitingfor)
  else
    ignore_illusion("We don't have a $(aff) right now.")
  end
end
#  end
#end

-- salve cures - instantaneous only
#for _, regeneration in pairs({
#caloric   = {"frozen", "shivering", "caloric"},
#epidermal = {"anorexia", "itching", "stuttering", "slashedthroat", "blindaff", "deafaff", "scalded"},
#mending   = {"selarnia", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "ablaze", "unknowncrippledarm", "unknowncrippledleg", "unknowncrippledlimb"},
#}) do
#local checkany_string = ""
#local temp = {}

#for _, aff in pairs(regeneration) do
#temp[#temp+1] = encodes(aff)
#end
#checkany_string = table.concat(temp, ", ")

#for _, aff in pairs(regeneration) do
function valid.salve_cured_$(aff)()
  local result = checkany(dict.$(aff).salve, $(checkany_string))

  if not result then return end

  apply_cure = true
  if result.name == "$(aff)_salve" then
    lifevision.add(actions.$(aff)_salve.p)
  else
    killaction(dict[result.action_name].salve)
    checkaction(dict.$(aff).salve, true)
    lifevision.add(dict.$(aff).salve)
  end
end
#end
#end


-- focus
#do
#local afflist = {"claustrophobia", "weakness", "masochism", "dizziness", "confusion", "stupidity", "generosity", "loneliness", "agoraphobia", "recklessness", "epilepsy", "pacifism", "anorexia", "shyness", "vertigo", "fear", "airdisrupt", "firedisrupt", "waterdisrupt"}
#local checkany_string = ""
#local temp = {}

#for _, aff in pairs(afflist) do
#temp[#temp+1] = encodef(aff)
#end
#checkany_string = table.concat(temp, ", ")

#for _, aff in pairs(afflist) do
function valid.focus_cured_$(aff)()
  local result = checkany(dict.$(aff).focus, $(checkany_string))
  if not result then return end

  focus_cure = true

  if result.name == "$(aff)_focus" then
    lifevision.add(actions.$(aff)_focus.p)

    -- check timers here! should not be less than half of getping(). Check *action*, not affliction timer as well
    if conf.aillusion and not conf.serverside then
      local time, lat = getStopWatchTime(actions.$(aff)_focus.p.actionwatch), getping()

      if time < (lat/2) then
        ignore_illusion("This 'cure' looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end
  else
    killaction(dict[result.action_name].focus)
    checkaction(dict.$(aff).focus, true)
    lifevision.add(dict.$(aff).focus)
  end
end

#end
#end


-- normal smokes
#for _, smoke in pairs({
#valerian = {"disloyalty", "slickness", "manaleech"},
#elm = {"deadening", "hellsight", "madness", "aeon"}}) do
#local checkany_string = ""
#local temp = {}

#for _, aff in pairs(smoke) do
#temp[#temp+1] = encodesm(aff)
#end
#checkany_string = table.concat(temp, ", ")

#for _, aff in pairs(smoke) do
function valid.smoke_cured_$(aff)()
  local result = checkany(dict.$(aff).smoke, $(checkany_string))
# -- $aff twice, first so most cases it gets returned first when it's the only aff

  if not result then return end

  smoke_cure = true
  if result.name == "$(aff)_smoke" then
    lifevision.add(actions.$(aff)_smoke.p)
  else
    killaction(dict[result.action_name].smoke)
    checkaction(dict.$(aff).smoke, true)
    lifevision.add(dict.$(aff).smoke)
  end
end

#end
#end

-- normal herbs
#for _, herb in pairs({
#ash        = {"hallucinations", "hypersomnia", "confusion", "paranoia", "dementia"},
#bellwort   = {"generosity", "pacifism", "justice", "inlove", "peace"},
#bloodroot  = {"paralysis", "slickness"},
#ginger     = {"melancholichumour", "cholerichumour", "phlegmatichumour", "sanguinehumour"},
#ginseng    = {"haemophilia", "darkshade", "relapsing", "addiction", "illness", "lethargy"},
#goldenseal = {"dissonance", "impatience", "stupidity", "dizziness", "epilepsy", "shyness"},
#kelp       = {"asthma", "hypochondria", "healthleech", "sensitivity", "clumsiness", "weakness"},
#lobelia    = {"claustrophobia", "recklessness", "agoraphobia", "loneliness", "masochism", "vertigo", "spiritdisrupt", "airdisrupt", "waterdisrupt", "earthdisrupt", "firedisrupt"},
#}) do
#local checkany_string = ""
#local temp = {}

#for _, aff in pairs(herb) do
#temp[#temp+1] = encode(aff)
#end
#checkany_string = table.concat(temp, ", ")

#for _, aff in pairs(herb) do
function valid.herb_cured_$(aff)()
  local result = checkany(dict.$(aff).herb, $(checkany_string))

  if not result then return end

  herb_cure = true
  if result.name == "$(aff)_herb" then
    -- check timers here! should not be less than half of getping(). Check *action*, not affliction timer as well
    if conf.aillusion and not conf.serverside then
      local time, lat = getStopWatchTime(actions.$(aff)_herb.p.actionwatch), getping()

      if time < (lat/2) then
        ignore_illusion("This 'cure' looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    lifevision.add(actions.$(aff)_herb.p)
  -- with AI on, don't accept cures for affs that we don't have (although do consider check*s)
  elseif (not conf.aillusion or (conf.aillusion and (affs.$(aff) or affs.unknownany or affs.unknownmental or affsp.$(aff)))) then
    killaction(dict[result.action_name].herb)
    checkaction(dict.$(aff).herb, true)
    lifevision.add(dict.$(aff).herb)
  elseif not sk.sawcuringcommand then
    moveCursor(0, getLineNumber()-1)
    moveCursor(#getCurrentLine(), getLineNumber())
    insertLink(" (i)", '', "Ignored the $(aff) herb cure, because I don't think we have this affliction atm, and we don't have any unknown affs either - so seems it's an illusion.")
    moveCursorEnd()
  end
end

#end
#end

-- tree touches
#for _, tree in pairs({
#tree = {"ablaze", "addiction", "aeon", "agoraphobia", "anorexia", "asthma", "blackout", "bleeding", "bound", "burning", "claustrophobia", "clumsiness", "mildconcussion", "confusion", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "darkshade", "deadening", "dementia", "disloyalty", "dissonance", "dizziness", "epilepsy", "fear", "galed", "generosity", "haemophilia", "hallucinations", "healthleech", "hellsight", "hypersomnia", "hypochondria", "icing", "illness", "impatience", "inlove", "itching", "justice", "laceratedthroat", "lethargy", "loneliness", "madness", "masochism","pacifism", "paranoia", "peace", "prone", "recklessness", "relapsing", "selarnia", "sensitivity", "shyness", "slashedthroat", "slickness", "stupidity", "stuttering",  "vertigo", "voided", "voyria", "weakness", "hamstring", "shivering", "frozen", "spiritdisrupt", "airdisrupt", "firedisrupt", "earthdisrupt", "waterdisrupt"}}) do

#for _, aff in pairs(tree) do
function valid.tree_cured_$(aff)()
  checkaction(dict.touchtree.misc)
  if actions.touchtree_misc then
    lifevision.add(actions.touchtree_misc.p, nil, "$(aff)")
    tree_cure = true
  end
end
#end
#end

-- humour cures
#for _, herb in pairs({
#ginger     = {"melancholichumour", "cholerichumour", "phlegmatichumour", "sanguinehumour"},
#}) do
#local checkany_string = ""
#local temp = {}

#for _, aff in pairs(herb) do
#temp[#temp+1] = encode(aff)
#end
#checkany_string = table.concat(temp, ", ")

#for _, aff in pairs(herb) do
function valid.herb_helped_$(aff)()
  local result = checkany(dict.$(aff).herb, $(checkany_string))

  if not result then return end

  herb_cure = true
  if result.name == "$(aff)_herb" then
    -- check timers here! should not be less than half of getping(). Check *action*, not affliction timer as well
    if conf.aillusion and not conf.serverside then
      local time, lat = getStopWatchTime(actions.$(aff)_herb.p.actionwatch), getping()

      if time < (lat/2) then
        ignore_illusion("This 'cure' looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    lifevision.add(actions.$(aff)_herb.p, "cured")
  elseif (not conf.aillusion or (conf.aillusion and (affs.$(aff) or (affs.unknownany or affs.unknownmental)))) then -- with AI on, don't accept cures for affs that we don't have
    killaction(dict[result.action_name].herb)
    checkaction(dict.$(aff).herb, true)
    lifevision.add(dict.$(aff).herb, "cured")
  else
    moveCursor(0, getLineNumber()-1)
    moveCursor(#getCurrentLine(), getLineNumber())
    insertLink(" (i)", '', "Ignored the $(aff) herb cure, because I don't think we have this affliction atm, and we don't have any unknown affs either - so seems it's an illusion.")
    moveCursorEnd()
  end
end

#end
#end

-- common ninkharsag code across tree and passive cures
function sk.ninkharsag()
  checkaction(dict.ninkharsag.gone, true)

  if lifevision.l.ninkharsag_gone then
    lifevision.add(actions.ninkharsag_gone.p, "hiddencures", 1 + (lifevision.l.ninkharsag_gone.arg or 1))
  else
    lifevision.add(actions.ninkharsag_gone.p, "hiddencures", 1)
  end
end

-- ninkharsag doesn't show us what we cured - so atm, we'll assume it cured nothing (and not clear all our affs either)
function valid.tree_ninkharsag()
  if conf.aillusion and not actions.touchtree_misc then return end

  tree_cure = true
  sk.ninkharsag()
end

function valid.ninkharsag()
  -- ignore if we don't actually have ninkharsag or we aren't getting a passive cure
  if conf.aillusion and not (affs.ninkharsag and passive_cure_paragraph) then return end

  sk.ninkharsag()
end


function valid.touched_treeoffbal()
  checkaction(dict.touchtree.misc)
  if actions.touchtree_misc then
    lifevision.add(actions.touchtree_misc.p, "offbal")
  end
end

-- special defences
function defs.got_deaf()
  checkaction(dict.waitingondeaf.waitingfor)
  if actions.waitingondeaf_waitingfor then
    lifevision.add(actions.waitingondeaf_waitingfor.p)
  end
end

#if skills.shindo then
function defs.shindo_blind_start()
  checkaction(dict.blind.misc)
  if actions.blind_misc then
    lifevision.add(actions.blind_misc.p)
  end
end
function defs.shindo_blind_got()
  checkaction(dict.waitingonblind.waitingfor)
  if actions.waitingonblind_waitingfor then
    lifevision.add(actions.waitingonblind_waitingfor.p)
  end
end

function defs.shindo_deaf_start()
  checkaction(dict.deaf.misc)
  if actions.deaf_misc then
    lifevision.add(actions.deaf_misc.p)
  end
end
#end
#if skills.kaido then
function defs.kaido_blind_start()
  checkaction(dict.blind.misc)
  if actions.blind_misc then
    lifevision.add(actions.blind_misc.p)
  end
end
function defs.kaido_blind_got()
  checkaction(dict.waitingonblind.waitingfor)
  if actions.waitingonblind_waitingfor then
    lifevision.add(actions.waitingonblind_waitingfor.p)
  end
end

function defs.kaido_deaf_start()
  checkaction(dict.deaf.misc)
  if actions.deaf_misc then
    lifevision.add(actions.deaf_misc.p)
  end
end
#end

function defs.got_blind()
  local r = checkany(dict.blind.herb)

  if not r then return end

  herb_cure = true
  lifevision.add(actions[r.name].p)
end

function defs.already_blind()
  local r = checkany(dict.blind.herb)

  if not r then return end

  herb_cure = true
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "noeffect")
  end
end

-- a function to properly assign and ignore missing enchants - works with svo's "do all enchants at once" feature.
function missing_enchant()
  -- find out which actions are we doing, sort them - and see which one is missing (the top one)
  local t = {}
  if actions.magicresist_physical then t[#t+1] = "magicresist" end
  if actions.fireresist_physical then t[#t+1] = "fireresist" end
  if actions.coldresist_physical then t[#t+1] = "coldresist" end
  if actions.electricresist_physical then t[#t+1] = "electricresist" end

  if #t == 0 then return end

  t = prio.sortlist(t, "physical")

  local result = t[1]

  if not ignore[result] then
    setignore(result, { because = "you were missing the enchantment" })

    echo'\n' echofn("Looks like you don't have %s anymore - I'll put it on ignore then, take it off later with '", result)

    setFgColor(unpack(getDefaultColorNums))
    setUnderline(true)

    echoLink("vignore "..result, 'svo.ignore.'..result..' = nil svo.echof("Removed '..result..' from the ignore list (will be doing it now).")', 'Click here take '..result..' off the ignore list', true)
    setUnderline(false)
    echo"'.\n"

    killaction(dict[result].physical)
  end
end

-- a function to stop any light* actions and put all current non-artefact pipes on ignore
function missing_tinderbox()
  -- find which pipes were we lighting and kill those actions. We we were lighting at least one, figure out which pipes are non-arty, get a list, put them on ignore and say which ones we've added to ignore now

  local gotaction
  if actions.lightvalerian_physical then
    killaction(dict.lightvalerian.physical); gotaction = true
  end
  if actions.lightelm_physical then
    killaction(dict.lightelm.physical); gotaction = true
  end
  if actions.lightskullcap_physical then
    killaction(dict.lightskullcap.physical); gotaction = true
  end

  -- if we weren't lighting - then... this might not be real!
  if not gotaction then return end

  -- find out which pipes are not artefact & ignore
  local realthing, assumedname = {}, {}
  for id = 1, #pipes.pnames do
    local herb, pipe = pipes.pnames[id], pipes[pipes.pnames[id]]
    if not pipe.arty and not ignore["light"..herb] then
      realthing[#realthing+1] = "light"..herb
      assumedname[#assumedname+1] = pipe.filledwith
      setignore("light"..herb, { because = "you were missing a tinderbox" })
    end
  end

  if realthing[1] then
    echo"\n" echof("Looks like you don't have a tinderbox! I've put non-artefact pipes - %s on the ignore list (under the names of %s). To unignore them, check vshow ignore.", concatand(assumedname), concatand(realthing))
  end
end

function valid.restoration_noeffect()
  local r = checkany(
  dict.curingheartseed.waitingfor, dict.curingmangledleftleg.waitingfor, dict.curingmangledrightleg.waitingfor, dict.curingmangledrightarm.waitingfor, dict.curingmangledleftarm.waitingfor, dict.curingmutilatedrightarm.waitingfor, dict.curingmutilatedleftarm.waitingfor, dict.curingparestolegs.waitingfor, dict.curingmildtrauma.waitingfor, dict.curingserioustrauma.waitingfor, dict.curingmutilatedrightleg.waitingfor, dict.curingmutilatedleftleg.waitingfor, dict.curingseriousconcussion.waitingfor, dict.curingmildconcussion.waitingfor, dict.curinglaceratedthroat.waitingfor)

  if not r then return end

  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "noeffect")
  end
end

function valid.ate_moss()
  local result = checkany(dict.healhealth.moss, dict.healmana.moss)

  if not result then return end

  herb_cure = true
  lifevision.add(actions[result.name].p)
end
valid.generic_ate_moss = valid.ate_moss

function valid.noeffect_moss()
  local r = checkany(dict.healhealth.moss, dict.healmana.moss)
  if not r then return end

  herb_cure = true
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, "noeffect")
  end
end

function valid.got_waterbubble()
  checkaction(dict.waterbubble.herb)

  herb_cure = true
  if actions.waterbubble_herb then
    lifevision.add(actions.waterbubble_herb.p)
  end
end

function defs.gotherb_myrrh()
  checkaction(dict.myrrh.herb)

  herb_cure = true
  if actions.myrrh_herb then
    lifevision.add(actions.myrrh_herb.p)
  end
end

function defs.gotherb_kola()
  checkaction(dict.kola.herb)

  herb_cure = true
  if actions.kola_herb then
    lifevision.add(actions.kola_herb.p)
  end
end

function defs.gotherb_deathsight()
  checkaction(dict.deathsight.herb)

  herb_cure = true
  if actions.deathsight_herb then
    lifevision.add(actions.deathsight_herb.p)
  end
end

function defs.gotskill_deathsight()
  checkaction(dict.deathsight.physical)
  if actions.deathsight_physical then
    lifevision.add(actions.deathsight_physical.p)
  end
end

function defs.gotherb_thirdeye()
  checkaction(dict.thirdeye.herb)

  herb_cure = true
  if actions.thirdeye_herb then
    lifevision.add(actions.thirdeye_herb.p)
  end
end

function defs.gotskill_thirdeye()
  checkaction(dict.thirdeye.misc)
  if actions.thirdeye_misc then
    lifevision.add(actions.thirdeye_misc.p)
  end
end

function defs.gotherb_insomnia()
  checkaction(dict.insomnia.herb)

  herb_cure = true
  if actions.insomnia_herb then
    lifevision.add(actions.insomnia_herb.p)
  end
end

function defs.gotskill_insomnia()
  if actions.checkhypersomnia_misc then
    lifevision.add(actions.checkhypersomnia_misc.p, "onclear")
  end


  checkaction(dict.insomnia.misc)
  if actions.insomnia_misc then
    lifevision.add(actions.insomnia_misc.p)
  end
end

function valid.generic_insomnia()
  local r = checkany(dict.insomnia.herb, dict.insomnia.misc)

  if not r then return end

  herb_cure = true
  lifevision.add(actions[r.name].p)
end

function valid.insomnia_hypersomnia()
  local r = checkany(dict.insomnia.herb, dict.insomnia.misc)

  if r then
    herb_cure = true
    lifevision.add(actions[r.name].p, "hypersomnia")
  elseif actions.checkhypersomnia_misc then
    lifevision.add(actions.checkhypersomnia_misc.p, "hypersomnia")
    decho(getDefaultColor().." (hypersomnia confirmed)")
  elseif not conf.aillusion then
    valid.simplehypersomnia()
  elseif not affs.hypersomnia then
    checkaction(dict.checkhypersomnia.aff, true)
    lifevision.add(actions.checkhypersomnia_aff.p)
  end
end

function defs.salve_got_caloric()
  local r = checkany(dict.frozen.salve, dict.shivering.salve, dict.caloric.salve)

  if not r then return end

  apply_cure = true
  local hypothermia = find_until_last_paragraph("You are far too frozen to relieve your shivers.", "exact")
  lifevision.add(actions[r.name].p, "gotcaloricdef", hypothermia)
end

function defs.salve_got_mass()
  checkaction(dict.mass.salve)
  apply_cure = true
  if actions.mass_salve then
    lifevision.add(actions.mass_salve.p)
  end
end


local generic_cures_data = {
  "ablaze", "addiction", "aeon", "agoraphobia", "anorexia", "asthma", "blackout", "bleeding", "bound", "burning", "claustrophobia", "clumsiness", "mildconcussion", "confusion", "crippledleftarm", "crippledleftleg", "crippledrightarm", "crippledrightleg", "darkshade", "deadening", "dementia", "disloyalty", "disrupt", "dissonance", "dizziness", "epilepsy", "fear", "galed", "generosity", "haemophilia", "hallucinations", "healthleech", "heartseed", "hellsight", "hypersomnia", "hypochondria", "icing", "illness", "impale", "impatience", "inlove", "inquisition", "itching", "justice", "laceratedthroat", "lethargy", "loneliness", "lovers", "madness", "mangledleftarm", "mangledleftleg", "mangledrightarm", "mangledrightleg", "masochism", "mildtrauma", "mutilatedleftarm", "mutilatedleftleg", "mutilatedrightarm", "mutilatedrightleg", "pacifism", "paralysis", "paranoia", "peace", "prone", "recklessness", "relapsing", "roped", "selarnia", "sensitivity", "seriousconcussion", "serioustrauma", "shyness", "slashedthroat", "slickness", "stun", "stupidity", "stuttering", "transfixed", "unknownany", "unknowncrippledarm", "unknowncrippledleg", "unknownmental", "vertigo", "voided", "voyria", "weakness", "webbed", "healhealth", "healmana", "hamstring", "shivering", "frozen", "hallucinations", "stain", "rixil", "palpatar", "cadmus", "hecate", "spiritdisrupt", "airdisrupt", "firedisrupt", "earthdisrupt", "waterdisrupt",
}

for i = 1, #generic_cures_data do
  local aff = generic_cures_data[i]

  valid["generic_"..aff] = function ()

    -- passive curing...
    if passive_cure_paragraph and dict[aff].gone then
      checkaction(dict[aff].gone, true)
      if actions[aff .. "_gone"] then
        lifevision.add(actions[aff .. "_gone"].p)
      end
      return
    end

    -- ... or something we caused.
    if actions_performed[aff] then
      lifevision.add(actions[actions_performed[aff].name].p)

    -- if it's not something we were directly doing, try to link by balances
    else
      local result

      for j,k in actions:iter() do
#if DEBUG then
        if not k then
          debugf("[svo error]: no k here, j is %s. Actions list:", tostring(j))
          for m,n in actions:iter() do
            debugf("%s - %s", tostring(m), tostring(n))
          end
        end
#end
        if k and k.p.balance ~= "waitingfor" and k.p.balance ~= "aff" and dict[aff][k.p.balance] then result = k.p break end
      end

      if not result then -- maybe tree?
        if actions.touchtree_misc then
          lifevision.add(actions.touchtree_misc.p, nil, aff)
          tree_cure = true
        elseif actions.restore_physical then
          lifevision.add(actions.restore_physical.p)
          valid.passive_cure()
        end
        return
      end

#if DEBUG then
      debugf("Result is %s", tostring(result.action_name))
#end
      killaction(dict[result.action_name][result.balance])

      checkaction(dict[aff][result.balance], true)
      lifevision.add(dict[aff][result.balance])
    end
  end
end

disable_generic_trigs = function ()
  disableTrigger("General cures")
  enableTrigger("Ate")
  enableTrigger("Sip")
  enableTrigger("Applied")
  enableTrigger("Smoke")
  enableTrigger("Focus mind")
end

enable_generic_trigs = function ()
  enableTrigger("General cures")
  disableTrigger("Ate")
  disableTrigger("Sip")
  disableTrigger("Applied")
  disableTrigger("Smoke")
  disableTrigger("Focus mind")
end

check_generics = function ()
  if affs.blackout and not generics_enabled then
    generics_enabled = true
    generics_enabled_for_blackout = true
    enable_generic_trigs()
    echo("\n")
    echof("Enabled blackout curing.")
  elseif generics_enabled and generics_enabled_for_blackout and not affs.blackout and not actions.blackout_aff then
    generics_enabled_for_blackout, generics_enabled = false, false
    disable_generic_trigs()
    echo("\n")
    echof("Out of blackout, disabled blackout curing.")
  elseif passive_cure_paragraph and not generics_enabled and not generics_enabled_for_passive then
    generics_enabled_for_passive, generics_enabled = true, true
    enable_generic_trigs ()
  elseif not passive_cure_paragraph and generics_enabled and generics_enabled_for_passive then
    generics_enabled_for_passive, generics_enabled = false, false
    disable_generic_trigs ()
  end
end
disable_generic_trigs()
check_generics()

signals.systemstart:connect(function ()
  disableTrigger("General cures")
  if conf.aillusion then enableTrigger("Pre-parse anti-illusion")
  else disableTrigger("Pre-parse anti-illusion") end
end)

-- passive cures
function valid.passive_cure()
  local affn = table.size(affs)
  passive_cure_paragraph = true
  check_generics()
  sk.onprompt_beforeaction_add("check for unknowns", function ()
    -- if the counts are the same, then we cured something we didn't know about
    -- this does not need lifevision validation, being done post-fact
    if affn == table.size(affs) then
      if affs.unknownmental then
        dict.unknownmental.count = dict.unknownmental.count - 1
        if dict.unknownmental.count <= 0 then removeaff("unknownmental"); dict.unknownmental.count = 0
        else updateaffcount(dict.unknownmental) end
      elseif affs.unknownany then
        dict.unknownany.count = dict.unknownany.count - 1
        if dict.unknownany.count <= 0 then removeaff("unknownany"); dict.unknownany.count = 0 else
          updateaffcount(dict.unknownany)
        end
      end
    end
  end)
  sk.onprompt_beforeaction_add("check generics", function () passive_cure_paragraph = false; check_generics() end)
  signals.after_lifevision_processing:unblock(cnrl.checkwarning)
end

function valid.underwater_nopear()
  if not conf.aillusion then eat(dict.waterbubble.herb) else
    local oldhealth = stats.currenthealth
    sk.onprompt_beforeaction_add("check for pear damage", function ()
      if stats.currenthealth < oldhealth then
        eat(dict.waterbubble.herb)
      end
    end)
  end
end

-- the voided timer at the moment account for multiple pommelstrikes occuring
function valid.pommelstrike()
end

function valid.dragonflex()
  checkaction (dict.dragonflex.misc)
  if actions.dragonflex_misc then
    lifevision.add(actions.dragonflex_misc.p)
  end
end

function valid.dwinnu()
  checkaction (dict.dwinnu.misc)
  if actions.dwinnu_misc then
    lifevision.add(actions.dwinnu_misc.p)
  end
end

function valid.got_blind()
  sk.onprompt_beforeaction_add("hypochondria_blind", function ()
    if not affs.blindaff and not defs.blind then
      valid.simplehypochondria()
    end
  end)
end

function valid.venom_crippledrightleg()
  if paragraph_length ~= 1 then
    valid.simplecrippledrightleg()
  else
    sk.hypochondria_symptom()
  end
end
function valid.venom_crippledleftleg()
  if paragraph_length ~= 1 then
    valid.simplecrippledleftleg()
  else
    sk.hypochondria_symptom()
  end
end
-- might not be hypochondria, but plague vibe
function valid.proper_clumsiness()
    valid.simpleclumsiness()
end
function valid.proper_weakness()
  if paragraph_length ~= 1 then
    valid.simpleweakness()
  else
    sk.hypochondria_symptom()
  end
end
function valid.proper_disloyalty()
  if paragraph_length ~= 1 then
    valid.simpledisloyalty()
  else
    sk.hypochondria_symptom()
  end
end
function valid.proper_illness()
  if paragraph_length ~= 1 then
    valid.simpleillness()
  else
    sk.hypochondria_symptom()
  end
end
function valid.proper_lethargy()
  if paragraph_length ~= 1 or affs.torntendons or find_until_last_paragraph("You stumble as you are afflicted with", "substring") then
    valid.simplelethargy()
  else
    sk.hypochondria_symptom()
  end
end
-- skullfractures makes the affliction come back on its own
function valid.proper_addiction()
  if paragraph_length ~= 1 or affs.skullfractures then
    valid.simpleaddiction()
  else
    sk.hypochondria_symptom()
  end
end
function valid.proper_anorexia()
  if not conf.aillusion then
    if paragraph_length ~= 1 or find_until_last_paragraph("With a characteristic Jaziran trill", "substring") then
      valid.simpleanorexia()
    else
      sk.hypochondria_symptom()
    end
  else
    checkaction(dict.checkanorexia.aff, true)
    lifevision.add(actions.checkanorexia_aff.p)
  end
end

-- traps can give this
function valid.proper_slickness()
  if paragraph_length ~= 1 then
    valid.simpleslickness()
  else
    sk.hypochondria_symptom()
  end
end
function valid.proper_recklessness(attacktype)
  if not conf.aillusion then
    valid.simplerecklessness()
  else
    checkaction(dict.recklessness.aff, true)
    if actions.recklessness_aff then
      lifevision.add(actions.recklessness_aff.p, nil, {oldhp = stats.currenthealth, oldmana = stats.currentmana, attacktype = attacktype, atline = getLastLineNumber("main")})
    end
  end
end
function valid.proper_recklessness2()
  if not conf.aillusion then
    valid.simplerecklessness()
  else
    checkaction(dict.recklessness.aff, true)
    if actions.recklessness_aff then
      if find_until_last_paragraph("wracks", "substring") or find_until_last_paragraph("points an imperious finger at you", "substring") or find_until_last_paragraph("A heavy burden descends upon your soul as", "substring") or find_until_last_paragraph("stares at you, giving you the evil eye", "substring") or find_until_last_paragraph("glowers at you with a look of repressed disgust before making a slight gesture toward you.", "substring") or find_until_last_paragraph("smashing your temple with a backhanded blow", "substring") then
        lifevision.add(actions.recklessness_aff.p, nil, {oldhp = stats.currenthealth, attacktype = attacktype, atline = getLastLineNumber("main")})
      else
        lifevision.add(actions.recklessness_aff.p, nil, {oldhp = stats.currenthealth, attacktype = attacktype, atline = getLastLineNumber("main")}, 1)
      end
    end
  end
end
function valid.venom_crippledleftarm()
  if paragraph_length ~= 1 then
    valid.simplecrippledleftarm()
  else
    sk.hypochondria_symptom()
  end
end
function valid.venom_crippledrightarm()
  if paragraph_length ~= 1 then
    valid.simplecrippledrightarm()
  else
    sk.hypochondria_symptom()
  end
end

function valid.lost_arena()
  echo"\n"
  echof("I'm sorry =(")

  reset.affs()
  reset.general()
  reset.defs()
end

function valid.lost_ffa()
  local oldroom = (atcp.RoomNum or gmcp.Room.Info.num)
  sk.onprompt_beforeaction_add("arena_death",
    function ()
      if oldroom ~= (atcp.RoomNum or gmcp.Room.Info.num) then
        reset.affs()
        reset.general()
        reset.defs()
      end
    end)
end

function valid.won_arena()
  echo"\n"
  if math.random(10) == 1 then echof("Winnar!")
  else echof("You won!") end

  -- rebounding coming up gets killed
  if actions.waitingonrebounding_waitingfor then
    killaction(dict.waitingonrebounding.waitingfor)
  end

  reset.affs()

  -- blind/insomnia/deaf get reset too
  defences.lost("blind") defences.lost("deaf") defences.lost("insomnia")
end

#if skills.necromancy then
function valid.soulcaged()
  reset.affs()
  reset.general()
  reset.defs()
  if type(conf.burstmode) == "string" then
    echo"\n"echof("Auto-switching to %s defences mode.", conf.burstmode)
    defs.switch(conf.burstmode, false)
  end
end
#elseif skills.occultism then
function valid.transmogged()
  reset.affs()
  reset.general()
  reset.defs()
  if type(conf.burstmode) == "string" then
    echo"\n"echof("Auto-switching to %s defences mode.", conf.burstmode)
    defs.switch(conf.burstmode, false)
  end
end
#else
function valid.soulcaged() end
function valid.transmogged() end
#end

function valid.died()
  if line == "Your starburst tattoo flares as the world is momentarily tinted red." then
    sk.onprompt_beforeaction_add("death",
      function ()
        if affs.recklessness or (stats.currenthealth == stats.maxhealth and stats.currentmana == stats.maxmana) then
          reset.affs()
          reset.general()
          reset.defs()
          rift.resetinvcontents()
          echo "\n" echof("We hit starburst!")
          signals.before_prompt_processing:unblock(valid.check_life)
          if type(conf.burstmode) == "string" then
            echof("Auto-switching to %s defences mode.", conf.burstmode)
            defs.switch(conf.burstmode, false)
          end

          -- rebounding coming up gets cancelled
          if actions.waitingonrebounding_waitingfor then killaction(dict.waitingonrebounding.waitingfor) end

          raiseEvent("svo died", "starburst")
        end
      end)
  elseif not conf.paused then
    sk.onprompt_beforeaction_add("death",
      function ()
        if affs.recklessness or stats.currenthealth == 0 then
          reset.affs()
          reset.general()
          reset.defs()
          rift.resetinvcontents()

          -- rebounding coming up gets cancelled
          if actions.waitingonrebounding_waitingfor then killaction(dict.waitingonrebounding.waitingfor) end

          echo "\n"
          if math.random(1,10) == 1 then
            echo[[



                   __, _ __,   _, _ __,
                   |_) | |_)   |\/| |_
                   | \ | |     |  | |
                   ~ ~ ~ ~     ~  ~ ~~~


 ]]
          elseif math.random(1, 25) == 1 then
            echo[[


             _     _      _     _      _     _      _     _
            (c).-.(c)    (c).-.(c)    (c).-.(c)    (c).-.(c)
             / x_x \      / x_x \      / x_x \      / x_x \
           __\( Y )/__  __\( Y )/__  __\( Y )/__  __\( Y )/__
          (_.-/'-'\-._)(_.-/'-'\-._)(_.-/'-'\-._)(_.-/'-'\-._)
             || D ||      || E ||      || A ||      || D ||
           _.' `-' '._  _.' `-' '._  _.' `-' '._  _.' `-' '._
          (.-./`-'\.-.)(.-./`-'\.-.)(.-./`-'\.-.)(.-./`-'\.-.)
           `-'     `-'  `-'     `-'  `-'     `-'  `-'     `-'


            ]]
          else
            echo"\n"echof("We died.") end
          conf.paused = true
          signals.before_prompt_processing:unblock(valid.check_life)
          raiseEvent("svo died")
          raiseEvent("svo config changed", "paused")
        elseif stats.currenthealth == stats.maxhealth and stats.currentmana == stats.maxmana and find_until_last_paragraph("Your starburst tattoo flares as the world is momentarily tinted red.", "exact") then -- in case something else came between "you died" and starburst
          reset.affs()
          reset.general()
          reset.defs()
          rift.resetinvcontents()

          -- rebounding coming up gets cancelled
          if actions.waitingonrebounding_waitingfor then killaction(dict.waitingonrebounding.waitingfor) end

          echo "\n" echof("We hit starburst!")
          signals.before_prompt_processing:unblock(valid.check_life)
          if type(conf.burstmode) == "string" then
            echof("Auto-switching to %s defences mode.", conf.burstmode)
            defs.switch(conf.burstmode, false)
          end
          raiseEvent("svo died", "starburst")
        end
      end)
  end
end

function valid.check_life()
  if stats.currenthealth ~= 0 then
    echo"\n" echof("Welcome back to life! System unpaused.")
    conf.paused = false
    raiseEvent("svo config changed", "paused")
    signals.before_prompt_processing:block(valid.check_life)
  end
end
signals.before_prompt_processing:connect(valid.check_life)
signals.before_prompt_processing:block(valid.check_life)


function valid.check_recklessness()
  local vitals = gmcp.Char.Vitals

  -- check against GMCP, as Svof modifies them
  if affs.recklessness and (vitals.mp < vitals.maxmp or vitals.hp < vitals.maxhp) then
    removeaff("recklessness")
  end
end
signals.before_prompt_processing:connect(valid.check_recklessness)
-- toggled inside svo.dict
signals.before_prompt_processing:block(valid.check_recklessness)


function valid.limb_hit(which, attacktype)
  if not sp_limbs[which] then return end

  me.lasthitlimb = which

  if selectString(which, 1) ~= -1 then
    fg(conf.highlightparryfg)
    bg(conf.highlightparrybg)
    deselect()
    resetFormat()
  else -- things like BM slashes don't say the limb, but say the plural name of it - legs, arms.
    local plural = which:sub(-3).."s"

    if selectString(plural, 1) ~= -1 then
      fg(conf.highlightparryfg)
      bg(conf.highlightparrybg)
      deselect()
      resetFormat()
    end
  end

  signals.after_lifevision_processing:unblock(sp_checksp)
  signals.limbhit:emit(which, attacktype)
  raiseEvent("svo limb hit", which, attacktype)
end

local function saw_tekura_in_paragraph()
  return
    -- punches
    find_until_last_paragraph("balls up one fist and hammerfists you", "substring") or
    find_until_last_paragraph("forms a spear hand and stabs out at you", "substring") or
    find_until_last_paragraph("launches a powerful uppercut at you", "substring") or
    find_until_last_paragraph("unleashes a powerful hook towards you", "substring") or

    -- kicks
    find_until_last_paragraph("lets fly at you with a snap kick", "substring") or
    find_until_last_paragraph("towards you with a lightning-fast moon kick", "substring") or
    find_until_last_paragraph("leg high and scythes downwards at you", "substring") or
    find_until_last_paragraph("pumps out at you with a powerful side kick", "substring") or
    find_until_last_paragraph("spins into the air and throws a whirlwind kick towards you", "substring") or
    find_until_last_paragraph("The blow sends a shock of pain through you, your muscles reflexively locking in response.", "exact")
end

-- count up how much tekura stuff have we seen in the paragraph so far. If more than two things, then count this as a combo.
local function all_in_one_tekura()
  local c =
    -- punches
    count_until_last_paragraph("balls up one fist and hammerfists you", "substring") +
    count_until_last_paragraph("forms a spear hand and stabs out at you", "substring") +
    count_until_last_paragraph("launches a powerful uppercut at you", "substring") +
    count_until_last_paragraph("unleashes a powerful hook towards you", "substring") +

    -- kicks
    count_until_last_paragraph("lets fly at you with a snap kick", "substring") +
    count_until_last_paragraph("drops to the floor and sweeps his legs round at you.", "substring") +
    count_until_last_paragraph("drops to the floor and sweeps her legs round at you.", "substring") +
    count_until_last_paragraph("knocks your legs out from under you and sends you sprawling to the floor.", "substring") +
    count_until_last_paragraph("towards you with a lightning-fast moon kick", "substring") +
    count_until_last_paragraph("leg high and scythes downwards at you", "substring") +
    count_until_last_paragraph("pumps out at you with a powerful side kick", "substring") +
    count_until_last_paragraph("spins into the air and throws a whirlwind kick towards you", "substring") +
    count_until_last_paragraph("The blow sends a shock of pain through you, your muscles reflexively locking in response.", "exact")

    return (c >= 2) and true or false
end


for _,name in ipairs({"rightarm", "leftarm", "leftleg", "rightleg"}) do
  for _, status in ipairs({"mangled", "mutilated"}) do
    valid["proper_"..status..name] = function ()
      -- idea: see if any previous lines contain the limb name; it would have to be included in the msg
      if conf.aillusion then
        local limb = string.format("%s %s", string.match(name, "(%w+)(%w%w%w)"))
        local plural = name:sub(-3).."s"

        -- last line doesn't work with stuff like bm breaks, where it is limb\anothermsg\actualbreak. So go until the prompt.
        local previouslinenumber, currentlinenumber = lastpromptnumber+1, getLastLineNumber("main")

        -- workaround for deleteLine() making lastpromptnumber's tracking get invalidated
        if currentlinenumber <= previouslinenumber then
          previouslinenumber = currentlinenumber - 1
        end

        -- this, with short enough wrapping, might not get the line that the rend starts on. So if this line doesn't start with a capital, pull in one more line
        local combined = table.concat(getLines(previouslinenumber, currentlinenumber))

        if not combined:sub(1,1):match("%u") then
          combined = table.concat(getLines(previouslinenumber-1, currentlinenumber))
        end

        -- remember blackout, don't check this in it
        if not affs.blackout and (combined:find(limb, 1, true) or combined:find(plural, 1, true)) then
          -- special exception for blademaster breaks, which do so little damage, you can regen it:
          --[[Spinning to the right as he draws 11 11 from its sheath, 11 delivers a precise slash across your arms.
              Your left arm is greatly damaged from the beating. (+65h, 0.8%, +75m, 1.1%) ]]
          if find_until_last_paragraph("^Spinning to the right as s?he draws %w+ %w+ from its sheath, %w+ delivers a precise slash across your arms%.$", "pattern") then
            valid["simple"..status..name]()
          elseif saw_tekura_in_paragraph() then
            checkaction(dict[status..name].aff, true)
            lifevision.add(actions[status..name.."_aff"].p, "tekura", stats.currenthealth)
          else
            checkaction(dict[status..name].aff, true)
            lifevision.add(actions[status..name.."_aff"].p, nil, stats.currenthealth)
          end

          tempLineTrigger(1,1, [[
            if line == "Your shield completely absorbs the damage." then
              svo.valid.simple]]..status..name..[[() end]]
          )
        else
          debugf("Didn't find limb (%s) or plural (%s) in combined (%s)", limb, plural, combined)
        end
      else -- anti-illusion off
        -- when we see a tekura combo, try to add all the mangles at the end of it, so the priorities take effect - instead of being dictated by first-hit
        if saw_tekura_in_paragraph() then

          -- if this is an all-in-one combo, don't queue up the hits
          if all_in_one_tekura() then
            checkaction(dict[status..name].aff, true)
            lifevision.add(actions[status..name.."_aff"].p, nil, stats.currenthealth)

            -- clear a delayed break if there was one
            if sk.delaying_break then
              killTimer(sk.delaying_break); sk.delaying_break = nil
              for _, aff in ipairs(sk.tekura_mangles) do
                addaff(dict[aff])
              end
              sk.tekura_mangles = nil
            end
          else
            -- not an all-in-one combo, or the first hit of it
            if not sk.delaying_break then
              sk.delaying_break = tempTimer(getNetworkLatency() + conf.tekura_delay, function() -- from the first hit, it's approximately getNetworkLatency() time until the second - add the conf.tekura_delay to allow for variation in ping
                sk.delaying_break = nil

                for _, aff in ipairs(sk.tekura_mangles) do
                  addaff(dict[aff])
                end
                sk.tekura_mangles = nil
                signals.after_lifevision_processing:unblock(cnrl.checkwarning)
                signals.canoutr:emit()
                make_gnomes_work()
              end)
            end

            sk.tekura_mangles = sk.tekura_mangles or {}
            sk.tekura_mangles[#sk.tekura_mangles+1] = status..name
          end
        else
          checkaction(dict[status..name].aff, true)
          lifevision.add(actions[status..name.."_aff"].p, nil, stats.currenthealth)
        end
      end
    end
  end
end

for _, name in ipairs({"serioustrauma", "mildtrauma", "mildconcussion", "seriousconcussion"}) do
  valid["proper_"..name] = function ()
    checkaction(dict[name].aff, true)
    lifevision.add(actions[name.."_aff"].p, nil, stats.currenthealth)
    tempLineTrigger(1,1, [[
      if line == "Your shield completely absorbs the damage." then
        svo.valid.simple]]..name..[[()
      end
    ]])
  end
end

valid.generic_burn = function (number)
  assert(not number or tonumber(number), "svo.valid.simpleburn: how many removals do you want to do? Must be a number")

  checkaction(dict.ablaze.gone, true)

  if lifevision.l.ablaze_gone then
    lifevision.add(actions.ablaze_gone.p, "generic_reducelevel", (number or 1) +(lifevision.l.ablaze_gone.arg or 1))
  else
    lifevision.add(actions.ablaze_gone.p, "generic_reducelevel", (number or 1))
  end
end

valid.low_willpower = sk.checkwillpower

#if skills.healing then
sk.check_emptyhealingheal = function ()
  if sk.currenthealinghealcount+1 == getLineCount() then
    lifevision.add(actions.usehealing_misc.p, "empty")
  else
    lifevision.add(actions.usehealing_misc.p)
  end

  signals.before_prompt_processing:disconnect(sk.check_emptyhealingheal)
end

valid.healercure = function ()
  checkaction(dict.usehealing.misc)
  if actions.usehealing_misc then
    sk.currenthealinghealcount = getLineCount()
    signals.before_prompt_processing:connect(sk.check_emptyhealingheal)
    valid.passive_cure()
  end
end


valid.emptyheal = function ()
  if actions.usehealing_misc then
    lifevision.add(actions.usehealing_misc.p, "empty")
  end
end

valid.healing_cured_insomnia = function ()
  checkaction(dict.usehealing.misc)
  if actions.usehealing_misc then
    defs.lost_insomnia()
    lifevision.add(actions.usehealing_misc.p, "empty")
  end
end

-- valid.healercure = function ()
--   checkaction(dict.usehealing.misc)
--   if actions.usehealing_misc then
--     valid.passive_cure()
--     lifevision.add(actions.usehealing_misc.p)
--   end
-- end

valid.nohealbalance = function ()
  checkaction(dict.usehealing.misc)
  if actions.usehealing_misc then
    lifevision.add(actions.usehealing_misc.p, "nobalance")
  end
end

valid.bedevilheal = function ()
  checkaction(dict.usehealing.misc)
  if actions.usehealing_misc then
    lifevision.add(actions.usehealing_misc.p, "bedevilheal")
  end
end
#else
valid.healercure = function () end
valid.healing_cured_insomnia = valid.healercure
valid.nohealbalance = valid.healercure
valid.bedevilheal = valid.healercure
#end

#if skills.chivalry then
sk.check_emptyrage = function ()
  if sk.currentragecount+1 == getLineCount() then
    lifevision.add(actions.rage_misc.p, "empty")
  else
    lifevision.add(actions.rage_misc.p)
  end

  signals.before_prompt_processing:disconnect(sk.check_emptyrage)
end

valid.ragecure = function ()
  checkaction(dict.rage.misc)
  if actions.rage_misc then
    sk.currentragecount = getLineCount()
    signals.before_prompt_processing:connect(sk.check_emptyrage)
    valid.passive_cure()
  end
end
#else
valid.ragecure = function() end
#end

#if skills.kaido then
valid.transmuted = function ()
  -- always check transmute so we can count how many we did (to cancel timer if we can)
  checkaction(dict.transmute.physical, true)
  lifevision.add(actions.transmute_physical.p)
end
#else
valid.transmuted = function() end
#end

-- possibly suspectible to sylvans double-doing it, or a sylvan doing & illusioning it?
function valid.sylvan_heartseed()
  if not conf.aillusion or affs.mildtrauma then
    valid.simpleheartseed()
  else
    tempTimer(5, function () sk.heartseed2window = true end)
    tempTimer(10, function () sk.heartseed2window = false end)
  end
end

function valid.sylvan_heartseed2()
  if not affs.heartseed and (not conf.aillusion or sk.heartseed2window) then
    valid.simpleheartseed()
  end
end

function valid.sylvan_eclipse()
  sk.sylvan_eclipse = true
  tempTimer(10, function () sk.sylvan_eclipse = nil end)
end

function valid.sylvan_lacerate1()
  checkaction(dict.slashedthroat.aff, true)
  lifevision.add(actions.slashedthroat_aff.p, "sylvanhit", stats.currenthealth)
end

function valid.sylvan_lacerate2()
  checkaction(dict.laceratedthroat.aff, true)
  lifevision.add(actions.laceratedthroat_aff.p, "sylvanhit", stats.currenthealth)
end

function svo.connected()
  signals.connected:emit()
end

function valid.stripped_caloric()
  checkaction(dict.caloric.gone, true)
  if actions.unknownany_aff then
    lifevision.add(actions.caloric_gone.p, nil, "unknownany")
  elseif actions.unknownmental_aff then
    lifevision.add(actions.caloric_gone.p, nil, "unknownmental")
  else
    lifevision.add(actions.caloric_gone.p)
  end
end

function valid.stripped_insomnia()
  checkaction(dict.insomnia.gone, true)
  if actions.unknownany_aff then
    lifevision.add(actions.insomnia_gone.p, nil, "unknownany")
  elseif actions.unknownmental_aff then
    lifevision.add(actions.insomnia_gone.p, nil, "unknownmental")
  else
    lifevision.add(actions.insomnia_gone.p)
  end
end

#if skills.elementalism or skills.healing then
function valid.lacking_channels()
  if usingbal("physical") then
    defs.lost_simultaneity()
  end
end
#else
valid.lacking_channels = function() end
#end

function valid.bubbleout()
  if not conf.aillusion then eat(dict.waterbubble.herb) end
end

-- check if we're the ones who got hit with it
function valid.aeon_card()
  if not affs.blackout then return end

  -- if sk.aeon_thrown then killTimer(sk.aeon_thrown) end
  -- sk.aeon_thrown = tempTimer(4, function() sk.aeon_thrown = nil end)

  -- account for lag between shuffle and throw, try and check for aeon
  tempTimer(0.2, function()
    checkaction(dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, "aeon")
  end)

  tempTimer(0.7, function()
    checkaction(dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, "aeon")
  end)
end

function valid.lust_card()
  if not affs.blackout then return end

  -- if sk.aeon_thrown then killTimer(sk.aeon_thrown) end
  -- sk.aeon_thrown = tempTimer(4, function() sk.aeon_thrown = nil end)

  -- account for lag between shuffle and throw, try and check for aeon
  tempTimer(0.2+getNetworkLatency(), function()
    if not sys.sync then echof("Checking allies for potential lust...") send("allies", conf.commandecho) end
  end)

  dict.blackout.check_lust = true
end

function defs.cant_empower()
  if actions.empower_physical then
    local off = {}

    if defkeepup[defs.mode].empower then
      svo.defs.keepup("empower", false)
      off[#off+1] = "keepup"
    end

    if defdefup[defs.mode].empower then
      svo.defs.defup("empower", false)
      off[#off+1] = "defup"
    end

    echo"\n" echof("Seems that you can't empower yet - so I took it off %s for you.", table.concat(off, ", "))
  end
end

function ignore_snake_bite()
  if not find_until_last_paragraph("You scream out in agony as a vicious venom tears through your body.", "exact")
    and not find_until_last_paragraph("You gasp as a terrible aching strikes all your limbs.", "exact")
   then ignore_illusion("Ignored the single-aff bite (vconfig ignoresinglebites is on)", true) return end
end

function valid.stop_wielding()
  checkaction(dict.rewield.physical)
  if actions.rewield_physical then
    lifevision.add(actions.rewield_physical.p, "clear")
  end
end

function valid.reflection_cancelled()
  if conf.aillusion and paragraph_length == 1 and not conf.batch then return end

  for _, action in pairs(lifevision.l:keys()) do
    if action:find("_aff", 1, true) then
      killaction(dict[action:match("(%w+)_")].aff)

      -- typically, you'd only have one aff per prompt - so no need to complicate by optimizing
      selectCurrentLine()
      fg("MediumSlateBlue")
      deselect()
      resetFormat()
    end
  end
end

function valid.homunculus_throat()
  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then ignore_illusion("This needs to be on it's own line.") return end

  lostbal_focus()
end

function valid.retardation_gone()
  checkaction(dict.retardation.gone, true)
  lifevision.add(actions["retardation_gone"].p)

  -- re-check to make sure it's true
  if conf.aillusion then
    checkaction(dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, "retardation")
  end
end

function valid.soa()
  if not conf.aillusion then return end

  if paragraph_length == 2 and (find_until_last_paragraph("greatly damaged from the beating", "substring") or find_until_last_paragraph("has been mutilated beyond repair by ordinary means", "substring")) then
    ignore_illusion("This looks pretty fake - can't get a limb-break and an SoA hit without anyone poking it", true)
  end
end

function valid.enmesh_start()
  if conf.aillusion and paragraph_length ~= 1 and not conf.batch then ignore_illusion("Enmesh can't be chained with other things at once") return end

  -- kill previous timers and set them for future. An enmesh hits at 5s after it was started
  if sys.enmesh1timer then killTimer(sys.enmesh1timer) end
  if sys.enmesh2timer then killTimer(sys.enmesh2timer) end

  sys.enmesh1timer = tempTimer(3, function() sys.enmesh1timer = nil end)

  sys.enmesh2timer = tempTimer(7+getNetworkLatency(), function() sys.enmesh2timer = nil end)
end

function valid.enmesh_hit()
  if not conf.aillusion or (sys.enmesh2timer and not sys.enmesh1timer) then
    valid.simpleroped()
  else
    ignore_illusion("We weren't getting enmeshed, this looks fake.")
  end
end

function valid.chaosrays()
  if not conf.aillusion then return end

  -- first and easiest case: you got hit by it directly, nobody died and bugged the game out
  if find_until_last_paragraph("Seven rays of different coloured light spring out from", "substring") then return end

  -- second, more difficult case - somebody died, go back until the previous prompt, see if anyone else died too
  if paragraph_length == 1 then
    local checking, getLines = getLineNumber()-1, getLines -- start checking lines 2 back, as 1 back will be prompt

    local line = getLines(checking-1, checking)[1]
    if line:find("Unable to withstand the rays of chaos", 1, true) or line:find("falls from", 1, true) then return end
  end

  ignore_illusion("This looks fake!")
end

function valid.proper_stain()
  if not conf.aillusion then
    valid.simplestain()
  else
    checkaction(dict.stain.aff, true)
    lifevision.add(actions.stain_aff.p, nil, stats.maxhealth)
  end
end

function valid.gothit(class, name)
  checkaction(dict.gothit.happened, true)
  dict.gothit.happened.tempmap[name or "?"] = class
  lifevision.add(actions.gothit_happened.p)
end

function valid.dcurse_start(whom)
  if not conf.aillusion or sk.dcurse_start then return end

  sk.dcurse_start = {tempTimer(10.5+getNetworkLatency(), function() sk.dcurse_start = nil end), whom}
end

function valid.dcurse_hit(aff)
  if conf.aillusion and not sk.dcurse_start then return end

  (valid["proper_"..aff] or valid["simple"..aff])()
end

function svo.valid.broken_legs()
  if not affs.crippledrightleg and not affs.mangledrightleg and not affs.mutilatedrightleg
    and not affs.crippledleftleg and not affs.mangledleftleg and not affs.mutilatedleftleg and not affs.unknowncrippledlimb and not affs.unknowncrippledleg and not affs.hamstring then
    valid.simpleunknowncrippledleg()

    -- cancel potential stand
    if actions.prone_misc then
      killaction(dict.prone.misc)
    end
  end
end

-- remove unknown level if the affliction from a symptom was not present before
valid.remove_unknownmental = function (affliction)
  if affs[affliction] then return end

  checkaction(dict.unknownmental.gone, true)
  lifevision.add(actions.unknownmental_gone.p, "lost_level")
end
valid.remove_unknownany = function (affliction)
  if affs[affliction] then return end

  checkaction(dict.unknownany.gone, true)
  lifevision.add(actions.unknownany_gone.p, "lost_level")
end

function valid.loki()
  valid.simpleunknownany()
end

--[[

|exp|91%H|93%M|cdb|[sleep st maso pr par hecate rop cl mad con ra1]
Your blood regains its ability to clot. -> claustrop
Thank Maya, the Great Mother! Your clumsiness has been cured. -> shyness
As a firelord glares at you, sudden agonising heat ignites in your veins. It is gone as swiftly as
it came, but you feel suddenly lightheaded. (i)

]]

-- Clumsiness to Shyness - Lethargy to Recklessness - Haemophilia to Claustrophobia - Health Leech to Agoraphobia - Sensitivity to Paranoia - Darkshade to Confusion
function valid.pyradius()
  local affmap = {
    ["clumsiness"]  = "shyness",
    ["darkshade"]   = "confusion",
    ["haemophilia"] = "claustrophobia",
    ["healthleech"] = "agoraphobia",
    ["lethargy"]    = "recklessness",
    ["sensitivity"] = "paranoia",
  }

  local cures = sk.getuntilprompt()
  local startline = getLineNumber()

  -- no affs cured?
  if #cures == 0 then return end

  for i = 1, #cures do
    moveCursor(0, startline-i)
    deleteLine()
  end
  moveCursorEnd()

  svo.valid.passive_cure() feedTriggers(table.concat(cures, "\n").."\n")

  sk.onprompt_beforelifevision_add("update pyradius", function()
    for _, action in pairs(lifevision.l:keys()) do
      local aff = action:match("^(%w+)")
      if affmap[aff] then
        (valid["proper_"..affmap[aff]] or valid["simple"..affmap[aff]])()
      end
    end
  end)

  -- have to force lifevision and all, since feedTriggers happens after the prompt
  send("\n")
end

#if skills.healing then
function valid.usedhealingbalance()
  checkaction(dict.stolebalance.happened, true)
  lifevision.add(actions.stolebalance_happened.p, nil, "healing")
end

function valid.gothealingbalance()
  checkaction(dict.gotbalance.happened, true)
  dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "healing" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
#end

#if skills.venom then
function valid.shrugging()
  checkaction(dict.shrugging.physical)
  if actions.shrugging_physical then
    valid.passive_cure()
    lifevision.add(actions.shrugging_physical.p, nil, getLineNumber())

    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()
  end
end

function valid.noshruggingbalance()
  checkaction(dict.shrugging.physical)
  if actions.shrugging_physical then
    lifevision.add(actions.shrugging_physical.p, "offbal")
  end
end

function valid.gotshruggingbalance()
  checkaction(dict.gotbalance.happened, true)
  dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "shrugging" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
#end

#if skills.voicecraft then
function valid.usedvoicebalance()
  checkaction(dict.stolebalance.happened, true)
  lifevision.add(actions.stolebalance_happened.p, nil, "voice")
end

function valid.gotvoicebalance()
  checkaction(dict.gotbalance.happened, true)
  dict.gotbalance.happened.tempmap[#dict.gotbalance.happened.tempmap+1] = "voice" -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
#end

function valid.proper_hamstring()
  checkaction(dict.hamstring.aff, true)
  lifevision.add(actions["hamstring_aff"].p, "renew")
end

function valid.alreadyprone()
  valid.simpleprone()

  if actions.lyre_physical then killaction(dict.lyre.physical) end
end

function valid.negation_gem()
  if not conf.aillusion then
    me.manualdefcheck = true
    defences.lost("shield")
  else
    prompttrigger("check negation gem", function()
      -- in cases where classes have +con/health adjusting buffs, test the line for a max health drop
      -- pending investigation on what happens to current health
    end)
  end
end

function valid.meta_glare()
  prompttrigger("check for stupidity or impatience", function()
    if find_until_last_paragraph("You shuffle your feet noisily, suddenly bored.", "exact") then
      addaff(dict.impatience)
    else
      addaff(dict.stupidity)
    end
  end)
end

function valid.bind_totem()
  if conf.aillusion and paragraph_length <= 1 and not conf.batch then ignore_illusion("This can't appear on its own, should only happen when you enter a room") end

  defs.lost_kola()
  valid.simplesleep()
  valid.simpletransfixed()
end

function valid.pummel()
  local oldhp = stats.hp
  aiprompt("check pummel damage", function()
    -- if the damage taken is more than 30%, then we are frozen
    if (oldhp - stats.hp) >= 25 then
      valid.simpleshivering()
      valid.simplefrozen()
    end
  end)
end

function valid.skirmish_drag()
  local result = checkany(dict.impale.misc, dict.curingimpale.waitingfor)

  if not result then return end
  lifevision.add(actions[result.name].p, "dragged")
end

function valid.cured_burn_health()
  local result = checkany(dict.ablaze.salve, dict.severeburn.salve, dict.extremeburn.salve, dict.charredburn.salve, dict.meltingburn.salve)

  if not result then return end

  apply_cure = true
  if actions[result.name] then
    lifevision.add(actions[result.name].p)
  end
end

function valid.cured_burns_health()
  local result = checkany(dict.ablaze.salve, dict.severeburn.salve, dict.extremeburn.salve, dict.charredburn.salve, dict.meltingburn.salve)

  if not result then return end

  apply_cure = true
  if actions[result.name] then
    lifevision.add(actions[result.name].p, "all")
  end
end

function valid.tree_cured_burn()
  checkaction(dict.touchtree.misc)
  if actions.touchtree_misc then
    lifevision.add(actions.touchtree_misc.p, nil, "burn")
    tree_cure = true
  end
end

function valid.tree_cured_burns()
  checkaction(dict.touchtree.misc)
  if actions.touchtree_misc then
    lifevision.add(actions.touchtree_misc.p, nil, "all burns")
    tree_cure = true
  end
end

#for _, aff in ipairs({"skullfractures", "crackedribs", "wristfractures", "torntendons"}) do
function valid.tree_cure_$(aff)()
  checkaction(dict.touchtree.misc)
  if actions.touchtree_misc then
    tree_cure = true
    lifevision.add(actions.touchtree_misc.p, nil, "$(aff)")
  end
end

function valid.tree_cured_$(aff)()
  checkaction(dict.touchtree.misc)
  if actions.touchtree_misc then
    lifevision.add(actions.touchtree_misc.p, nil, "$(aff) cured")
    tree_cure = true
  end
end

function valid.generic_cure_$(aff)()
  checkaction(dict.$(aff).gone, true)
  if lifevision.l.$(aff)_gone then
    lifevision.add(actions.$(aff)_gone.p, "general_cure", (number or 1) + (lifevision.l.$(aff)_gone.arg or 1))
  else
    lifevision.add(actions.$(aff)_gone.p, "general_cure", (number or 1))
  end
end

function valid.generic_cured_$(aff)()
  checkaction(dict.$(aff).gone, true)
  lifevision.add(actions.$(aff)_gone.p, "general_cured")
end
#end

function valid.expend_torso()
  checkaction(dict.waitingonrebounding.waitingfor)
  if actions.waitingonrebounding_waitingfor then
    lifevision.add(actions.waitingonrebounding_waitingfor.p, "expend")
  end
end

-- happens on wrist fracture levels 1-3
function valid.devastate_arms_cripple()
  checkaction(dict.wristfractures.gone, true)
  lifevision.add(actions.wristfractures_gone.p)

  valid.simplecrippledrightarm()
  valid.simplecrippledleftarm()
end

-- happens on wrist fracture levels 4,5
-- edit: This ability can also mutilate a mangled limb.
function valid.devastate_arms_mangle()
  checkaction(dict.wristfractures.gone, true)
  lifevision.add(actions.wristfractures_gone.p)

  if affs.mangledrightarm
  then
    removeaff("mangledrightarm")
	valid.simplemutilatedrightarm()
  else valid.simplemangledrightarm()
  end
  if affs.mangledleftarm
  then
    removeadd("mangledleftarm")
	valid.simplemutilatedleftarm()
  else valid.simplemangledleftarm()
  end
end

-- happens on wrist fracture levels 6,7
function valid.devastate_arms_mutilate()
  checkaction(dict.wristfractures.gone, true)
  lifevision.add(actions.wristfractures_gone.p)

  valid.simplemutilatedrightarm()
  valid.simplemutilatedleftarm()
end

-- happens on torn tendon levels 1-3
function valid.devastate_legs_cripple()
  checkaction(dict.torntendons.gone, true)
  lifevision.add(actions.torntendons_gone.p)

  valid.simplecrippledrightleg()
  valid.simplecrippledleftleg()
end

-- happens on torn tendon levels 4,5
-- edit: This ability can also mutilate a mangled limb.
function valid.devastate_legs_mangle()
  checkaction(dict.torntendons.gone, true)
  lifevision.add(actions.torntendons_gone.p)


  if affs.mangledrightleg
  then
    removeaff("mangledrightleg")
	valid.simplemutilatedrightleg()
  else valid.simplemangledrightleg()
  end
  if affs.mangledleftleg
  then
    removeaff("mangledleftleg")
	valid.simplemutilatedleftleg()
  else valid.simplemangledleftleg()
  end
end

-- happens on torn tendon levels 6,7
function valid.devastate_legs_mutilate()
  checkaction(dict.torntendons.gone, true)
  lifevision.add(actions.torntendons_gone.p)

  valid.simplemutilatedrightleg()
  valid.simplemutilatedleftleg()
end

function valid.smash_high()
  lostbal_focus()
end

function valid.proper_ablaze()
  if not affs.severeburn and not affs.extremeburn and not affs.charredburn and not affs.meltingburn then
    valid.simpleablaze()
  end
end

function valid.riding_alreadyon()
  checkaction(dict.riding.physical, true)
  lifevision.add(actions.riding_physical.p, "alreadyon")
end

function valid.recoverable_attack()
  checkaction(dict.footingattack.happened, true)
  lifevision.add(actions.footingattack_happened.p)
end

valid.recovered_footing = valid.stoodup

function knight_focused(who)
  me.focusedknights[who] = true
end
function valid.doublehander_hit(who)
  if me.focusedknights[who] then
    sk.doubleknightaff = true
    me.focusedknights[who] = nil
    prompttrigger("clear double knight affs", function() sk.doubleknightaff = false end)
  end
end

function valid.skirmish_lacerate()
  prompttrigger("check lacerate rebounding", function()
    if not find_until_last_paragraph("The attack rebounds back onto", "substring") then
      valid.simplehaemophilia()
    end
  end)
end

function valid.skirmish_gouge()
  prompttrigger("check gouge deafness", function()
    if not find_until_last_paragraph("Your hearing is suddenly restored.", "exact") then
      valid.simplesensitivity()
    end
  end)
end
