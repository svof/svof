-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

local sys, affs, defdefup, defkeepup, signals = svo.sys, svo.affs, svo.defdefup, svo.defkeepup, svo.signals
local conf, sk, me, defs, defc = svo.conf, svo.sk, svo.me, svo.defs, svo.defc
local defences, stats, cnrl, rift = svo.defences, svo.stats, svo.cnrl, svo.rift
local bals, pipes, valid, actions = svo.bals, svo.pipes, svo.valid, svo.actions
local lifevision = svo.lifevision

function svo.valid.caught_illusion()
  sys.flawedillusion = true
  me.haveillusion = true
end

function svo.not_illusion(reason)
  sys.not_illusion = reason or true
end

function svo.ignore_illusion(reason, moveback)
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

  moveCursorEnd('main')
  svo.debugf("svo.ignore_illusion()")
end

function svo.show_info(shortmsg, message, moveback)
  if moveback then moveCursor(0, getLineNumber()-1) end
  moveCursor(#getCurrentLine(), getLineNumber())
  insertText(" ") moveCursor(#getCurrentLine(), getLineNumber())
  deselect()
  fg('green')
  insertLink("("..shortmsg..")", '', message or '') -- can't format, https://bugs.launchpad.net/mudlet/+bug/1027732
  resetFormat()
end

-- +2 if we do stuff on the prompt
function svo.vm.last_line_was_prompt()
  return (svo.paragraph_length == 1) and true or false
end

function svo.valid.symp_asleep()
  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then
    svo.ignore_illusion("not first")
    return
  end

  if not affs.sleep and not actions.sleep_aff then
    svo.checkaction(svo.dict.sleep.aff, true)
    lifevision.add(actions['sleep_aff'].p, 'symptom', nil, 1)
  end

  -- svo.reset non-wait things we were doing, because they got cancelled by the sleep
  if affs.asleep or actions.asleep_aff then
    for _,v in actions:iter() do
      if v.p.balance ~= 'waitingfor' and v.p.balance ~= 'aff' then
        svo.killaction(svo.dict[v.p.action_name][v.p.balance])
      end
    end
  end
end

function svo.valid.cured_lovers()
  svo.checkaction(svo.dict.lovers.physical)
  if actions.lovers_physical then
    lifevision.add(actions.lovers_physical.p, nil, multimatches[2][2])
  end
end

function svo.valid.cured_lovers_nobody()
  svo.checkaction(svo.dict.lovers.physical)
  if actions.lovers_physical then
    lifevision.add(actions.lovers_physical.p, 'nobody')
  end
end


function svo.valid.bloodsworn_gone()
if svo.haveskillset('devotion') then
  svo.checkaction(svo.dict.bloodsworntoggle.misc)
  if actions.bloodsworntoggle_misc then
    lifevision.add(actions.bloodsworntoggle_misc.p)
  end
end
end

function svo.defs.sileris_start()
  svo.checkaction(svo.dict.sileris.misc)
  if actions.sileris_misc then
    lifevision.add(actions.sileris_misc.p)
  end
end

function svo.defs.sileris_finished()
  svo.checkaction(svo.dict.waitingforsileris.waitingfor)
  if actions.waitingforsileris_waitingfor then
    lifevision.add(actions.waitingforsileris_waitingfor.p)
  end
end

function svo.defs.sileris_slickness()
  svo.checkaction(svo.dict.sileris.misc)
  if actions.sileris_misc then
    if svo.dict.sileris.applying == 'quicksilver' and not line:find('quicksilver', 1, true) then
      svo.ignore_illusion("Ignored this illusion because we're applying quicksilver, not sileris right now (or we were forced).")
    elseif svo.dict.sileris.applying == 'sileris' and not line:find('berry', 1, true) then
      svo.ignore_illusion("Ignored this illusion because we're applying sileris, not quicksilver right now (or we were forced).")
    else
      lifevision.add(actions.sileris_misc.p, 'slick', nil, 1)
    end
  end
end

function svo.valid.sileris_flayed()
  if not conf.aillusion then
    defs.lost_sileris()
  elseif svo.paragraph_length == 1 then
    svo.checkaction(svo.dict.sileris.gone, true)
    lifevision.add(actions.sileris_gone.p, nil, getLastLineNumber('main'), 1)
  else
    svo.ignore_illusion("not first")
  end
end

function svo.valid.insomnia_relaxed()
  if not conf.aillusion then
    defs.lost_insomnia()
  else
    svo.checkaction(svo.dict.insomnia.gone, true)
    lifevision.add(actions.insomnia_gone.p, 'relaxed', getLastLineNumber('main'))
  end
end

function svo.valid.insomnia_healed()
  if not conf.aillusion then
    defs.lost_insomnia()
  elseif affs.blackout or svo.paragraph_length > 1 then
    defs.lost_insomnia()
  else
    svo.ignore_illusion("The heal line doesn't seem to be on it's own as it should be.")
  end
end

function svo.defs.got_block(dir)
  svo.checkaction(svo.dict.block.physical)
  if actions.block_physical then
    lifevision.add(actions.block_physical.p, nil, dir)
  end
end

function svo.valid.smoke_stillgot_inquisition()
  svo.checkaction(svo.dict.hellsight.smoke)
  if actions.hellsight_smoke then
    lifevision.add(actions.hellsight_smoke.p, 'inquisition')
  end
end

function svo.valid.smoke_stillhave_madness()
  svo.checkaction(svo.dict.madness.smoke)
  if actions.madness_smoke then
    lifevision.add(actions.madness_smoke.p, 'hecate')
  end
end

function svo.valid.smoke_have_rebounding()
  svo.checkaction(svo.dict.rebounding.smoke)
  if actions.rebounding_smoke then
    svo.smoke_cure = true
    lifevision.add(actions.rebounding_smoke.p, 'alreadygot')
  end
end

if svo.haveskillset('chivalry') or svo.haveskillset('shindo') or svo.haveskillset('kaido') or svo.haveskillset('metamorphosis') then
  function svo.defs.got_fitness()
    svo.checkaction(svo.dict.fitness.physical)
    if actions.fitness_physical then
      lifevision.add(actions.fitness_physical.p)
    end
  end

  function svo.valid.fitness_cured_asthma()
    svo.checkaction(svo.dict.fitness.physical)
    if actions.fitness_physical then
      lifevision.add(actions.fitness_physical.p, 'curedasthma')
    end
  end

  function svo.valid.fitness_weakness()
    svo.checkaction(svo.dict.fitness.physical)
    if actions.fitness_physical then
      lifevision.add(actions.fitness_physical.p, 'weakness')
    end
  end

  function svo.valid.fitness_allgood()
    svo.checkaction(svo.dict.fitness.physical)
    if actions.fitness_physical then
      lifevision.add(actions.fitness_physical.p, 'allgood')
    end
  end

  function svo.valid.usedfitnessbalance()
    svo.checkaction(svo.dict.stolebalance.happened, true)
    lifevision.add(actions.stolebalance_happened.p, nil, 'fitness')
  end

  function svo.valid.gotfitnessbalance()
    svo.checkaction(svo.dict.gotbalance.happened, true)
    svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'fitness' -- hack to allow multiple balances at once
    lifevision.add(actions.gotbalance_happened.p)
  end
else
  function svo.defs.got_fitness() end
  function svo.valid.fitness_cured_asthma() end
  function svo.valid.fitness_weariness() end
  function svo.valid.fitness_allgood() end
end

if svo.haveskillset('chivalry') then
function svo.valid.gotragebalance()
  svo.checkaction(svo.dict.gotbalance.happened, true)
  svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'rage' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
end

function svo.valid.dragonform_riding()
  if actions.riding_physical then
    lifevision.add(actions.riding_physical.p, 'dragonform')
  end
end

function svo.defs.started_dragonform()
  if actions.dragonform_physical then
    lifevision.add(actions.dragonform_physical.p)
  end
end

-- set the Elder dragon colour - but only when we are mid-dragonforming, so as not to get tricked by illusions
function svo.valid.dragonformingcolour(colour)
  if not conf.aillusion or actions.waitingfordragonform_waitingfor then
    colour = colour:lower()

    local t = {
       ['red'] = 'dragonfire',
       ['black'] = 'acid',
       ['silver'] = 'lightning',
       -- it is 'golden' and not 'gold' for this message
       ['golden'] = 'psi',
       ['blue'] = 'ice',
       ['green'] = 'venom'
    }

    conf.dragonbreath = t[colour]
    raiseEvent("svo config changed", 'dragonbreath')
  end
end

function svo.defs.got_dragonform()
  svo.checkaction(svo.dict.waitingfordragonform.waitingfor)
  if actions.waitingfordragonform_waitingfor then
    lifevision.add(actions.waitingfordragonform_waitingfor.p)
  end
end

function svo.defs.cancelled_dragonform()
  if actions.waitingfordragonform_waitingfor then
    lifevision.add(actions.waitingfordragonform_waitingfor.p, 'cancelled')
  end
end

if svo.haveskillset('groves') then
function svo.valid.started_rejuvenate()
  if actions.rejuvenate_physical then
    lifevision.add(actions.rejuvenate_physical.p)
  end
end

function svo.valid.completed_rejuvenate()
  svo.checkaction(svo.dict.waitingforrejuvenate.waitingfor)
  if actions.waitingforrejuvenate_waitingfor then
    lifevision.add(actions.waitingforrejuvenate_waitingfor.p)
  end
end

function svo.valid.cancelled_rejuvenate()
  if actions.waitingforrejuvenate_waitingfor then
    lifevision.add(actions.waitingforrejuvenate_waitingfor.p, 'cancelled')
  end
end
end

if svo.haveskillset('spirituality') then
function svo.defs.started_mace()
  if actions.mace_physical then
    lifevision.add(actions.mace_physical.p)
  end
end

function svo.defs.have_mace()
  if actions.mace_physical then
    lifevision.add(actions.mace_physical.p, 'alreadyhave')
  end
end

function svo.defs.got_mace()
  svo.checkaction(svo.dict.waitingformace.waitingfor)
  if actions.waitingformace_waitingfor then
    lifevision.add(actions.waitingformace_waitingfor.p)
  end
end

function svo.defs.cancelled_mace()
  if actions.waitingformace_waitingfor then
    lifevision.add(actions.waitingformace_waitingfor.p, 'cancelled')
  end
end

function svo.valid.sacrificed_angel()
  if not conf.aillusion or actions.sacrifice_physical then
    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()

    svo.reset.affs()
    svo.reset.general()
  else
    svo.ignore_illusion("Didn't send the 'angel sacrifice' command recently.")
  end
end
end

if svo.haveskillset('shindo') then
function svo.valid.shin_phoenix()
  if not conf.aillusion or actions.phoenix_physical then
    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()

    svo.reset.affs()
  else
    svo.ignore_illusion("Didn't send the 'shin phoenix' command recently.")
  end
end
end

if svo.haveskillset('propagation') then
function svo.defs.notonland_viridian()
  if actions.viridian_physical then
    lifevision.add(actions.viridian_physical.p, 'notonland')
  end
end
function svo.defs.viridian_inside()
  if actions.viridian_physical then
    lifevision.add(actions.viridian_physical.p, 'indoors')
  end
end
function svo.defs.viridian_cancelled()
  if actions.waitingforviridian_waitingfor then
    lifevision.add(actions.waitingforviridian_waitingfor.p, 'cancelled')
  end
end
function svo.defs.got_viridian()
  if actions.waitingforviridian_waitingfor then
    lifevision.add(actions.waitingforviridian_waitingfor.p)
  end
end
function svo.defs.started_viridian()
  if actions.viridian_physical then
    lifevision.add(actions.viridian_physical.p)
  end
end
function svo.defs.alreadyhave_viridian()
  if actions.viridian_physical then
    lifevision.add(actions.viridian_physical.p, 'alreadyhave')
  end
end
end

function svo.valid.alreadyhave_dragonbreath()
  if actions.dragonbreath_physical then
    lifevision.add(actions.dragonbreath_physical.p, 'alreadygot')
  end
end

function svo.defs.alreadyhave_dragonform()
  if actions.dragonform_physical then
    lifevision.add(actions.dragonform_physical.p, 'alreadyhave')
  end
end

function svo.defs.started_dragonbreath()
  if actions.dragonbreath_physical then
    lifevision.add(actions.dragonbreath_physical.p)
  end
end

function svo.defs.got_dragonbreath()
  svo.checkaction(svo.dict.waitingfordragonbreath.waitingfor)
  if actions.waitingfordragonbreath_waitingfor then
    lifevision.add(actions.waitingfordragonbreath_waitingfor.p)
  end
end
-- hallucinations symptoms
function svo.valid.swandive()
  local have_pflag = svo.pflags.p
  sk.onprompt_beforeaction_add('swandive', function ()
    if not have_pflag and svo.pflags.p then
      valid.simpleprone()
      valid.simplehallucinations()
    end
  end)
end

-- detect conf/dizzy, or amnesia/amnesia at worst
function sk.check_evileye()
  if svo.find_until_last_paragraph("Your curseward has been breached!", 'exact') then
    sk.tempevileye.count = sk.tempevileye.count - 1
  end

  -- fails when they give the same aff twice
  --[[local affcount = 0
  for action in lifevision.l:iter() do
    if string.ends(action, '_aff') or string.find(action, 'check') then affcount = affcount + 1 end
  end

  local diff = sk.tempevileye.count - affcount]]

  local diff = sk.tempevileye.hiddencount

  if diff == 1 then
    valid.simpleunknownmental()
    svo.echof("assuming focusable aff.")
  elseif diff == 2 then
    valid.simpleconfusion()
    valid.simpleunknownmental()
    svo.echof("assuming confusion and focusable aff.")
  end
  -- diff of 0 is OK

  sk.tempevileye = nil
  signals.before_prompt_processing:disconnect(sk.check_evileye)
end

function svo.valid.hidden_evileye()
  if line:find("stares at you, giving you the evil eye", 1, true) or isPrompt() then
    sk.tempevileye.hiddencount = (sk.tempevileye.hiddencount or 0) + 1
  end
end

function svo.valid.evileye()
  -- check next line to see if it's
  if sk.tempevileye then sk.tempevileye.count = sk.tempevileye.count + 1 return end -- don't set it if the first line already did
  sk.tempevileye = {startline = getLastLineNumber('main'), count = 1}
  signals.before_prompt_processing:connect(sk.check_evileye)
end

function sk.check_trip()
  if not svo.find_until_last_paragraph("You parry the attack with a deft manoeuvre.", 'exact') and not svo.find_until_last_paragraph("You step into the attack,", 'substring') then
    valid.simpleprone()
  end

  signals.before_prompt_processing:disconnect(sk.check_trip)
end

function svo.valid.trip_prone()
  signals.before_prompt_processing:connect(sk.check_trip)
end

function svo.valid.spiders_all_overme()
  valid.simplefear()
  valid.simplehallucinations()
end

function svo.valid.symp_impale()
  if affs.blackout then
    valid.proper_impale()
  elseif not conf.aillusion then
    valid.simpleimpale()
  else
    sk.impale_symptom()
  end
end

function svo.valid.symp_stupidity()
  sk.stupidity_symptom()
end

function svo.valid.symp_transfixed()
  sk.transfixed_symptom()
end


function svo.valid.symp_paralysis()
  if actions.fillskullcap_physical then
    svo.killaction(svo.dict.fillskullcap.physical)
    if not affs.paralysis then
      valid.simpleparalysis()
      decho(svo.getDefaultColor().." (paralysis confirmed)")
    end
    return
  elseif actions.fillelm_physical then
    svo.killaction(svo.dict.fillelm.physical)
    if not affs.paralysis then
      valid.simpleparalysis()
      decho(svo.getDefaultColor().." (paralysis confirmed)")
    end
    return
  elseif actions.fillvalerian_physical then
    svo.killaction(svo.dict.fillvalerian.physical)
    if not affs.paralysis then
      valid.simpleparalysis()
      decho(svo.getDefaultColor().." (paralysis confirmed)")
    end
    return
  end

  if actions.checkparalysis_misc then
    lifevision.add(actions.checkparalysis_misc.p, 'paralysed')
    decho(svo.getDefaultColor().." (paralysis confirmed)")
  elseif not conf.aillusion then
    valid.simpleparalysis()
  elseif not affs.paralysis then
    svo.checkaction(svo.dict.checkparalysis.aff, true)
    lifevision.add(actions.checkparalysis_aff.p)
  end

  if actions.prone_misc then
    svo.killaction(svo.dict.prone.misc)
    if not affs.paralysis then
      valid.simpleparalysis()
      decho(svo.getDefaultColor().." (paralysis confirmed)")
    end
  end

  -- in slowcuring only (for AI safety for now), count all balanceful actions for paralysis
  if sys.sync and svo.usingbal'physical' then
    valid.simpleparalysis()
  end
end

function svo.valid.symp_stun()
  if not conf.aillusion then
    valid.simplestun()
  elseif actions.checkstun_misc then
    lifevision.add(actions.checkstun_misc.p)
  else
    sk.stun_symptom()
  end

  -- svo.reset non-wait things we were doing, because they got cancelled by the stun
  if affs.stun or actions.stun_aff then
    for _,v in actions:iter() do
      if v.p.balance ~= 'waitingfor' and v.p.balance ~= 'aff' then
        svo.killaction(svo.dict[v.p.action_name][v.p.balance])
      end
    end
  end
end

function svo.valid.symp_illness_constitution()
  sk.illness_constitution_symptom()
end

function svo.valid.saidnothing()
  if actions.checkslows_misc then
    svo.deleteLineP()
    lifevision.add(actions.checkslows_misc.p, 'onclear')
  elseif affs.aeon or affs.retardation or affs.stun then
    svo.deleteLineP()
  end
end
valid.silence_vibe = valid.saidnothing

function svo.valid.jump()
  if actions.checkparalysis_misc then
    lifevision.add(actions.checkparalysis_misc.p, 'onclear')
    svo.deleteLineP()
  end
end

function svo.valid.nobalance()
  if actions.checkparalysis_misc then
    lifevision.add(actions.checkparalysis_misc.p, 'paralysed')
    svo.deleteLineP()
  end

  if actions.checkasthma_misc then
    lifevision.add(actions.checkasthma_misc.p, 'weakbreath', nil, 1)
  end

  -- cancel standing if we can't due to no balance
  if actions.prone_misc then
    svo.killaction(svo.dict.prone.misc)
    if bals.balance then
      bals.balance = false -- unset balance, in case of blackout, where we don't see prompt
      raiseEvent("svo lost balance", 'balance')
    end
  end

  -- this might not be necessary for this case of getting hit off balance
  -- elseif actions.breath_physical and not affs.asthma and svo.affsp.asthma then
  --   svo.checkaction(svo.dict.checkasthma.misc, true)
  --   lifevision.add(actions.checkasthma_misc.p, 'weakbreath', nil, 1)
  -- end
end

function svo.valid.nothingtowield()
  if actions.checkparalysis_misc then
    svo.deleteLineP()
    lifevision.add(actions.checkparalysis_misc.p, 'onclear')
  end
end

function svo.valid.nosymptom()
  if actions.checkwrithes_misc then
    tempLineTrigger(0,3,[[deleteLine()]])
    lifevision.add(actions.checkwrithes_misc.p, 'onclear')
  end
end

function svo.valid.nothingtoeat()
  if actions.checkanorexia_misc then
    svo.deleteLineP()
    lifevision.add(actions.checkanorexia_misc.p, 'onclear')
  elseif actions.checkstun_misc then
    svo.deleteLineP()
    lifevision.add(actions.checkstun_misc.p, 'onclear')
  elseif affs.anorexia or affs.stun then
    svo.deleteLineP()
  end
end

function svo.valid.lungsokay()
  if actions.checkasthma_misc then
    svo.deleteLineP()
    lifevision.add(actions.checkasthma_misc.p, 'onclear')
  end
end

-- given a sluggish symptom, either confirms sluggish if we're checking for it already
-- or goes out and tests it
function svo.valid.webeslow()
  sk.sawsluggish = getLastLineNumber('main') -- for retardation going away auto-detection
  if sk.sluggishtimer then killTimer(sk.sluggishtimer); sk.sluggishtimer = nil end

  -- if triggered by curing, don't consider it retardation
  if sk.sawcuring() then return end

  -- if we suspect aeon, and aren't checking it yet, add the action in
  if svo.affsp.aeon and not actions.checkslows_misc then
    svo.checkaction(svo.dict.checkslows.misc, true)
  end

  -- confirm that we're sluggish if we were checking for slows
  if actions.checkslows_misc then
    lifevision.add(actions.checkslows_misc.p, 'sluggish')
    return
  end

  -- if we have aeon or retardation already, do nothing then
  if affs.aeon or affs.retardation then return end

  if affs.blackout and not affs.retardation then
    valid.simpleaeon()
  elseif not affs.retardation then
    -- confirm aeon out of the blue, treat it as retardation over aeon
    svo.checkaction(svo.dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, 'retardation')
    -- sk.retardation_symptom()
  end
end

function svo.valid.webbily()
  if actions.checkwrithes_misc then
    lifevision.add(actions.checkwrithes_misc.p, 'webbily')
  end
end

function svo.valid.symp_webbed()
  if not conf.aillusion then
    valid.simplewebbed()
  else
    sk.webbed_symptom()
  end
end

function svo.valid.symp_impaled()
  if not conf.aillusion then
    valid.simpleimpale()
  else
    sk.impaled_symptom()
  end
end

function svo.valid.transfixily()
  if actions.checkwrithes_misc then
    lifevision.add(actions.checkwrithes_misc.p, 'transfixily')
  end

  -- special workaround for waking up not showing up in blackout: clear sleep if we saw this msg
  -- it's an issue otherwise to miss the sleep msg from a totem while in blackout and think you're still asleep
  if affs.asleep then svo.rmaff('asleep') end
end

function svo.valid.symp_roped()
  if not conf.aillusion then
    valid.simpleroped()
  else
    sk.roped_symptom()
  end
end

function svo.valid.symp_transfixed()
  if not conf.aillusion then
    valid.simpletransfixed()
  else
    sk.transfixed_symptom()
  end
end

function svo.valid.weakbreath()
  if actions.checkasthma_misc then
    lifevision.add(actions.checkasthma_misc.p, 'weakbreath', nil, 1)
  elseif actions.breath_physical and not affs.asthma then
    svo.checkaction(svo.dict.checkasthma.misc, true)
    lifevision.add(actions.checkasthma_misc.p, 'weakbreath', nil, 1)
  elseif conf.aillusion and (not actions.breath_physical and not affs.asthma) then
    svo.ignore_illusion("Ignored this illusion because we aren't trying to hold breath right now (or we were forced).")
  else
    svo.checkaction(svo.dict.checkasthma.aff, true)
    lifevision.add(actions.checkasthma_aff.p)
  end
end

function svo.valid.impaly()
  if actions.checkwrithes_misc then
    lifevision.add(actions.checkwrithes_misc.p, 'impaly')
  end
end

function svo.valid.chimera_stun()
  if conf.aillusion and (not defc.deaf or not affs.deafaff or not actions.deafaff_aff) then return end

  valid.simplestun(2)
end

function svo.valid.restore()
  svo.checkaction(svo.dict.restore.physical)
  if actions.restore_physical then
    -- prevent against a well-timed restore use, which when empty, forces us to clear all afflictions
    if conf.aillusion then
      local time, lat = getStopWatchTime(actions.restore_physical.p.actionwatch), svo.getping()

      if time < (lat/2) then
        svo.ignore_illusion("This looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
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

function svo.valid.dragonheal()
  svo.checkaction(svo.dict.dragonheal.physical)
  if actions.dragonheal_physical then
    valid.passive_cure()
    lifevision.add(actions.dragonheal_physical.p, nil, getLineNumber())

    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()
  end
end

function svo.valid.nodragonheal()
  svo.checkaction(svo.dict.dragonheal.physical)
  if actions.dragonheal_physical then
    lifevision.add(actions.dragonheal_physical.p, 'nobalance')
  end
end

function svo.valid.knighthood_disembowel()
  local result = svo.checkany(svo.dict.curingimpale.waitingfor)

  -- we won't get curing* if we didn't even start to writhe, so fake it for these purposes
  if not result and affs.impale then
    svo.checkaction(svo.dict.curingimpale.waitingfor, true)
    result = { name = 'curingimpale_waitingfor' }
  end

  if result and actions[result.name] then
    lifevision.add(actions[result.name].p, 'withdrew')
  end
end

valid.impale_withdrew = valid.knighthood_disembowel

function svo.valid.fell_sleep()
  svo.checkaction(svo.dict.sleep.aff, true)
  svo.checkaction(svo.dict.prone.aff, true)

  lifevision.add(actions.sleep_aff.p)
  lifevision.add(actions.prone_aff.p)
end

function svo.valid.proper_sleep()
  if defc.insomnia then
    defs.lost_insomnia()
  else
    svo.checkaction(svo.dict.sleep.aff, true)
    svo.checkaction(svo.dict.prone.aff, true)

    lifevision.add(actions.sleep_aff.p)
    lifevision.add(actions.prone_aff.p)
  end
end

function svo.valid.disruptingshiver()
  if conf.aillusion and bals.equilibrium then
    sk.onprompt_beforeaction_add('disruptingshiver', function ()
      if not bals.equilibrium  then
        svo.checkaction(svo.dict.shivering.aff, true)
        svo.checkaction(svo.dict.disrupt.aff, true)
        lifevision.add(actions.shivering_aff.p)
        lifevision.add(actions.disrupt_aff.p)
        defs.lost_caloric()
      end
    end)
  else
    svo.checkaction(svo.dict.shivering.aff, true)
    svo.checkaction(svo.dict.disrupt.aff, true)
    lifevision.add(actions.shivering_aff.p)
    lifevision.add(actions.disrupt_aff.p)
    defs.lost_caloric()
  end
end

function svo.valid.check_dragonform()
  -- show xp? ignore!
  if svo.lastpromptnumber+1 == getLastLineNumber('main') or not svo.find_until_last_paragraph(me.name, 'substring') then return end

  if defc.dragonform and not svo.find_until_last_paragraph("Dragon)", 'substring') then
    echo"\n" svo.echof("Apparently we aren't in Dragon.")
    svo.defs.lost_dragonform()
    svo.defs.lost_dragonarmour()
    svo.defs.lost_dragonbreath()
  elseif not defc.dragonform and svo.find_until_last_paragraph("Dragon)", 'substring') then
    echo"\n" svo.echof("Apparently we're in Dragon.")
    svo.defs.got_dragonform()
  end
end

svo.defs.got_dragonform = svo.dict.waitingfordragonform.waitingfor.oncompleted

function svo.valid.proper_impale()
  if not conf.aillusion then
    valid.simpleimpale()
  else
    svo.checkaction(svo.dict.checkwrithes.aff, true)
    lifevision.add(actions.checkwrithes_aff.p, 'impale', stats.currenthealth)
  end
end

function svo.valid.swachbuckling_pesante()
  if (not svo.find_until_last_paragraph("The attack rebounds back onto", 'substring')) and (svo.find_until_last_paragraph('jabs', 'substring')) and (svo.find_until_last_paragraph('you', 'substring')) then
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
function svo.valid.swachbuckling_martellato()
  if not svo.find_until_last_paragraph("The attack rebounds back onto", 'substring') and
     svo.find_until_last_paragraph('jabs', 'substring') and
     svo.find_until_last_paragraph('you', 'substring') and
     not svo.find_until_last_paragraph("^%w+ viciously jabs", 'pattern') then
    valid.simpleprone()
  end
end

local last_jabber = ""
function svo.valid.swashbuckling_jab(name)
  if sk.swashbuckling_jab then killTimer(sk.swashbuckling_jab) end
  sk.swashbuckling_jab = tempTimer(.5, function() sk.swashbuckling_jab = nil end)
  last_jabber = name
end

function svo.valid.voicecraft_tremolo(name, side)
  local known_class = (ndb and ndb.getclass(name))
  if not conf.aillusion or ((affs['crippled'..side..'leg'] or sk['delayvenom_'..side..'leg'] or sk['delayacciaccatura_'..side..'leg']) and ((sk.swashbuckling_jab and last_jabber == name) or known_class == 'bard')) then

    -- when we've accepted that the Tremolo is legitimate, record the side - to be checked later in the mangle trigger for verification
    sk.tremoloside = sk.tremoloside or {}
    sk.tremoloside[side] = true
    svo.prompttrigger("clear tremolo", function()
      -- the svo.prompttrigger happens after the mangle should have been processed:
      -- so if we still have tremoloside setup, it means no mangle happened as the
      -- mangle would have cleared it. Hence, make the venom timer go off at the
      -- earlist possible time.
      if sk.tremoloside and sk.tremoloside[side] and sk['delayvenom_'..side..'leg'] then
        killTimer(sk['delayvenom_'..side..'leg'])
        sk['delayvenom_'..side..'leg'] = nil
        -- we can't use valid here, but we can use addaff
        svo.addaffdict(svo.dict['crippled'..side..'leg'])

        signals.after_lifevision_processing:unblock(cnrl.checkwarning)
        signals.canoutr:emit()
      end

      sk.tremoloside = nil
    end)
  end
end

function svo.valid.voicecraft_vibrato(name, side)
  local known_class = (ndb and ndb.getclass(name))
  if not conf.aillusion or ((affs['crippled'..side..'arm'] or sk['delayvenom_'..side..'arm'] or sk['delayacciaccatura_'..side..'arm']) and ((sk.swashbuckling_jab and last_jabber == name) or known_class == 'bard')) then
    valid['simplemangled'..side..'arm']()
  end
end

-- for a Bard tremolo/vibrato hit, avoid curing the crippled limb right away
-- because that will use up our salve balance and delay the mangled break, which
-- follows soon after. Hence this, upon detecting a jab form a Bard with
-- epteth/epseth, delays adding the crippled affliction until after the tremolo
-- or vibrato
function svo.valid.swashbuckling_poison()
  if not conf.aillusion or (svo.paragraph_length == 2 and not conf.batch) then
    for _, limb in ipairs{'rightleg', 'rightarm', 'leftarm', 'leftleg'} do
      if actions['crippled'..limb..'_aff'] then
        svo.killaction(svo.dict['crippled'..limb].aff)

        sk['delayvenom_'..limb] = tempTimer(.25, function()
          if not affs['mangled'..limb] then
            svo.addaffdict(svo.dict['crippled'..limb])

            signals.after_lifevision_processing:unblock(cnrl.checkwarning)
            signals.canoutr:emit()
            svo.make_gnomes_work()
          end

          sk['delayvenom_'..limb] = nil
        end)
        break
      end
    end
  end
end

function svo.valid.swashbuckling_acciaccatura(side, limb)
  local aff = side..limb

  sk['delayacciaccatura_'..aff] = tempTimer(.25, function()
    if not affs['mangled'..aff] then
      svo.addaffdict(svo.dict['crippled'..aff])

      signals.after_lifevision_processing:unblock(cnrl.checkwarning)
      signals.canoutr:emit()
      svo.make_gnomes_work()
    end

    sk['delayacciaccatura_'..aff] = nil
  end)
end

-- handle cancelling of delayvenom in case of this being a DSL:
-- apply the cripples right away, so the cure of a potential mangled limb in the
-- dsl, the venoms and the limb break get computed for cure at once on the prompt
signals.limbhit:connect(function(attacktype)
  if attacktype ~= 'weapon' then return end

  sk.weapon_hits = (sk.weapon_hits or 0) + 1
  sk.onprompt_beforeaction_add("track a dsl", function()
    -- if we got a DSL, apply the delayvenoms right now
    if sk.weapon_hits == 2 then
      for _, aff in ipairs{'rightleg', 'rightarm', 'leftarm', 'leftleg'} do
        if sk['delayvenom_'..aff] then
          if not affs['mangled'..aff] then
            svo.addaffdict(svo.dict['crippled'..aff])
            signals.after_lifevision_processing:unblock(cnrl.checkwarning)
            signals.canoutr:emit()
          end

          killTimer(sk['delayvenom_'..aff])
          sk['delayvenom_'..aff] = nil
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
  svo.assert(which, "svo.valid.defstrip: which defence was stripped?")

  local t = {
    ["anti-weapon field"]      = 'rebounding',
    ["caloric salve"]          = 'caloric',
    ["cold resistance"]        = 'coldresist',
    ['density']                = 'mass',
    ["electricity resistance"] = 'electricresist',
    ["fire resistance"]        = 'fireresist',
    ['gripping']               = 'grip',
    ["held breath"]            = 'breath',
    ['insulation']             = 'caloric',
    ['levitating']             = 'levitation',
    ["magic resistance"]       = 'magicresist',
    ['scholasticism']          = 'myrrh',
    ["soft focus"]             = 'softfocus',
    ["soft focusing"]          = 'softfocus',
    ["speed defence"]          = 'speed', -- typo in game was showing 'speed defence defence'
    ['temperance']             = 'frost',
    ["third eye"]              = 'thirdeye'
  }

  if svo.haveskillset('apostasy') then
    t["demon armour"]           = 'demonarmour'
  end
  if svo.haveskillset('necromancy') then
    t["death aura"]             = 'deathaura'
  end
  if svo.haveskillset('healing') then
    t["earth spiritshield"]     = 'earthblessing'
    t["endurance spiritshield"] = 'enduranceblessing'
    t["frost spiritshield"]     = 'frostblessing'
    t["thermal spiritshield"]   = 'thermalblessing'
    t["willpower spiritshield"] = 'willpowerblessing'
  end
  if svo.haveskillset('pranks') or svo.haveskillset('swashbuckling') then
    t["arrow catching"]         = 'arrowcatch'
  end
  if svo.haveskillset('metamorphosis') then
    t["spirit bonding"]         = 'bonding'
  end
  if svo.haveskillset('groves') then
    t["wild growth"]            = 'wildgrowth'
  end

  if t[which] then which = t[which] end

  if defs['lost_'..which] then
    defs['lost_'..which]()
  end
end

function svo.valid.truename()
  if not conf.aillusion then
    valid.simpleaeon()
    defs.lost_lyre()
  elseif (svo.paragraph_length == 1 or (svo.find_until_last_paragraph("is unable to resist the force of your faith", 'substring') or svo.find_until_last_paragraph("aura of weapons rebounding disappears", 'substring'))) then
    svo.checkaction(svo.dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, 'truename')
    defs.lost_lyre()
  else
    svo.ignore_illusion("not first")
  end
end

function svo.valid.just_aeon()
  svo.checkaction(svo.dict.checkslows.aff, true)
  lifevision.add(actions.checkslows_aff.p, nil, 'aeon')
end

function svo.valid.proper_aeon()
  if defc.speed then
    defs.lost_speed()
  elseif not conf.aillusion then
    valid.simpleaeon()
  else
    svo.checkaction(svo.dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, 'aeon')
  end
end
valid.bashing_aeon = valid.proper_aeon

function svo.valid.proper_retardation()
  if conf.aillusion then
    svo.checkaction(svo.dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, 'retardation')
  else
    valid.simpleretardation()
  end
end

function svo.valid.proper_stun(num)
  if not conf.aillusion then
    valid.simplestun(num)
  else
    svo.checkaction(svo.dict.checkstun.aff, true)
    lifevision.add(actions.checkstun_aff.p, nil, num)
  end
end

function svo.valid.proper_paralysis()
  -- if not conf.aillusion or (not (bals.balance and bals.equilibrium and bals.leftarm and bals.rightarm) or ignore.checkparalysis) then
  if not conf.aillusion or svo.ignore.checkparalysis then
    valid.simpleparalysis()
  elseif not affs.paralysis then
    svo.checkaction(svo.dict.checkparalysis.aff, true)
    lifevision.add(actions.checkparalysis_aff.p)
  end

  if conf.paused and conf.hinderpausecolour then
    selectCurrentLine()
    fg(conf.hinderpausecolour)
    resetFormat()
    deselect()
  end
end

function svo.valid.proper_hypersomnia()
  if not conf.aillusion or svo.ignore.checkhypersomnia then
    valid.simplehypersomnia()
  elseif not affs.hypersomnia then
    svo.checkaction(svo.dict.checkhypersomnia.aff, true)
    lifevision.add(actions.checkhypersomnia_aff.p)
  end
end

function svo.valid.proper_asthma()
  if not conf.aillusion or svo.ignore.checkasthma then
    valid.simpleasthma()
    svo.affsp.asthma = nil
  elseif not affs.asthma then
    svo.checkaction(svo.dict.checkasthma.aff, true)
    lifevision.add(actions.checkasthma_aff.p, nil, stats.currenthealth)
  end
end

function svo.valid.proper_asthma_smoking()
  if conf.aillusion and svo.paragraph_length <= 1 and not conf.batch then return end

  if not conf.aillusion or svo.ignore.checkasthma then
    valid.simpleasthma()
    svo.affsp.asthma = nil
  else
    svo.checkaction(svo.dict.checkasthma.aff, true)
    lifevision.add(actions.checkasthma_aff.p, nil, stats.currenthealth)
  end
end

function svo.valid.darkshade_paralysis()
  if not conf.aillusion then
    valid.simpleparalysis()
    valid.simpledarkshade()
  else
    svo.checkaction(svo.dict.checkparalysis.aff, true)
    lifevision.add(actions.checkparalysis_aff.p, nil, 'darkshade')
  end
end

function svo.valid.darkshade_sun()
  svo.checkaction(svo.dict.darkshade.aff, true)
  if actions.darkshade_aff then
    lifevision.add(actions.darkshade_aff.p, nil, stats.currenthealth)
  end
end

function svo.valid.maybe_impatience()
  svo.checkaction(svo.dict.checkimpatience.aff, true)
  lifevision.add(actions.checkimpatience_aff.p, nil, 'quiet')
end

function svo.valid.proper_impatience()
  if not conf.aillusion or svo.ignore.checkimpatience then
    valid.simpleimpatience()
  else
     -- limerick because songbirds will make lg 2
     -- maggots isn't a full line, because on sw80 it will wrap
    local previousline = (svo.find_until_last_paragraph("glares at you and your brain suddenly feels slower", 'substring') or svo.find_until_last_paragraph("evil eye", 'substring') or svo.find_until_last_paragraph('wracks', 'substring') or svo.find_until_last_paragraph("You recoil in horror as countless maggots squirm over your flesh", 'substring') or line:find("jaunty limerick", 1, true) or svo.find_until_last_paragraph("points an imperious finger at you", 'substring') or svo.find_until_last_paragraph("glowers at you with a look of repressed disgust before making a slight gesture toward you.", 'substring') or svo.find_until_last_paragraph("hand at you, a wash of cold causing your blood to evolve into something new.", 'substring') or svo.find_until_last_paragraph("Horror overcomes you as you realise that the curse of impatience", 'substring') or svo.find_until_last_paragraph("palm towards your face.", 'substring')) and true or false
    if svo.paragraph_length == 1 or previousline then
      svo.checkaction(svo.dict.checkimpatience.aff, true)
      if previousline then
        lifevision.add(actions.checkimpatience_aff.p)
      else
        lifevision.add(actions.checkimpatience_aff.p, nil, nil, 1)
      end
    else
      svo.ignore_illusion("not first")
    end
  end
end

function svo.valid.curse_dispel()
  if defc.ghost then defs.lost_ghost() return end
  if defc.shroud then defs.lost_shroud() return end
end

function svo.valid.subterfuge_hallucinations()
  if getLineNumber('main') ~= svo.lastpromptnumber+2 then return end
  valid.simplehallucinations()
end

function svo.valid.subterfuge_confusion()
  if getLineNumber('main') ~= svo.lastpromptnumber+2 then return end
  valid.simpleconfusion()
end

function svo.valid.subterfuge_bite()
  -- should use affs.from field to track what did you get the venom from, then if it's confirmed, strip sileris
end

function svo.valid.subterfuge_camus()
  svo.checkaction(svo.dict.sileris.gone, true)
  lifevision.add(actions.sileris_gone.p, 'camusbite', stats.currenthealth)
end

function svo.valid.subterfuge_sumac()
  svo.checkaction(svo.dict.sileris.gone, true)
  lifevision.add(actions.sileris_gone.p, 'sumacbite', stats.currenthealth)
end

function svo.valid.proper_relapsing()
  if not conf.aillusion then
    valid.simplerelapsing()
  else
    svo.checkaction(svo.dict.relapsing.aff, true)
    lifevision.add(actions.relapsing_aff.p)
  end
end

function svo.valid.relapsing_camus()
  svo.checkaction(svo.dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, 'camus', stats.currenthealth)
end

function svo.valid.relapsing_sumac()
  svo.checkaction(svo.dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, 'sumac', stats.currenthealth)
end

function svo.valid.relapsing_vitality()
  svo.dict.relapsing.aff.hitvitality = true
end

function svo.valid.relapsing_oleander()
  svo.checkaction(svo.dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, 'oleander', (defc.blind or affs.blindaff))
end

function svo.valid.relapsing_colocasia()
  svo.checkaction(svo.dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, 'colocasia', (defc.blind or affs.blindaff or defc.deaf or affs.deafaff))
end

function svo.valid.relapsing_oculus()
  svo.checkaction(svo.dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, 'oculus', (defc.blind or affs.blindaff or defc.deaf or affs.deafaff))
end

function svo.valid.relapsing_oculus()
  svo.checkaction(svo.dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, 'oculus', (defc.blind or affs.blindaff))
end

function svo.valid.relapsing_prefarar()
  svo.checkaction(svo.dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, 'prefarar', (defc.deaf or affs.deafaff))
end

function svo.valid.relapsing_asthma()
  svo.checkaction(svo.dict.relapsing.aff, true)
  lifevision.add(actions.relapsing_aff.p, 'asthma')
end

function svo.valid.subterfuge_bind()
  if not conf.aillusion or affs.sleep then
    valid.simplebound()
  end
end

function svo.valid.kaido_choke()
  if conf.breath and conf.keepup and not defkeepup[defs.mode].breath then
    defs.keepup('breath', true)
    echo("\n")
    if math.random(1, 10) == 1 then
      svo.echof("Run away! Run away! ('br' to turn off breath)")
    elseif math.random(1, 10) == 1 then
      svo.echof("We'll get through this. *determined* ('br' to turn off breath)")
    else
      svo.echof("Eep... holding our breath ('br' to turn off).")
    end
  end
end
valid.noose_trap = valid.kaido_choke
valid.vodun_throttle = valid.kaido

function svo.valid.proper_sensitivity()
  svo.checkaction(svo.dict.sensitivity.aff, true)
  lifevision.add(actions.sensitivity_aff.p, 'checkdeaf')
end

function svo.valid.webbed_buckawns()
  if conf.buckawns then return
  else
    if not conf.aillusion then
      valid.simplewebbed()
    else
      svo.checkaction(svo.dict.checkwrithes.aff, true)
      lifevision.add(actions.checkwrithes_aff.p, nil, 'webbed', 1)
    end
  end
end

function svo.valid.proper_webbed()
  if not conf.aillusion then
    valid.simplewebbed()
  else
    svo.checkaction(svo.dict.checkwrithes.aff, true)
    lifevision.add(actions.checkwrithes_aff.p, nil, 'webbed')
  end
end

function svo.valid.proper_chill()
  local aff

  if defc.caloric then defs.lost_caloric() return end

  if not affs.shivering then aff = 'shivering' else aff = 'frozen' end

  svo.checkaction(svo.dict[aff].aff, true)
  if actions[aff .. '_aff'] then
    lifevision.add(actions[aff .. '_aff'].p)
  end
end

function svo.valid.magi_deepfreeze()
  if defc.caloric then
    defs.lost_caloric()
    valid.simpleshivering()
  else
    valid.simpleshivering()
    valid.simplefrozen()
  end
end

-- logic is done inside receivers
function svo.valid.proper_transfix()
  if not conf.aillusion or svo.paragraph_length > 2 then
    valid.simpletransfixed()
  else
    svo.checkaction(svo.dict.checkwrithes.aff, true)
    lifevision.add(actions.checkwrithes_aff.p, nil, 'transfixed')
  end
end

valid.proper_transfixed = valid.proper_transfix

function svo.valid.failed_transfix()
  defs.lost_blind()

  if actions.transfixed_aff then
    svo.killaction(svo.dict.transfixed.aff)
  end
  if actions.checkwrithes_aff and lifevision.l.checkwrithes_aff and lifevision.l.checkwrithes_aff.arg == 'transfixed' then
    svo.killaction(svo.dict.checkwrithes.aff)
  end
end

function svo.valid.parry_limb(limb)
  if not svo.sp_limbs[limb] then return end

  if svo.find_until_last_paragraph("You feel your will manipulated by the soulmaster entity.", 'exact') or svo.find_until_last_paragraph("You cannot help but obey.", 'exact') then
    svo.checkaction(svo.dict.doparry.physical, true)
  else
    svo.checkaction(svo.dict.doparry.physical)
  end

  if actions.doparry_physical then
    lifevision.add(actions.doparry_physical.p, nil, limb)
  end
end

function svo.valid.parry_none()
  svo.checkaction(svo.dict.doparry.physical)
  if actions.doparry_physical then
    lifevision.add(actions.doparry_physical.p, 'none')
  end
end

function svo.valid.cant_parry()
  valid.parry_none()

  if not conf.aillusion then
    sk.cant_parry()
  else
    sk.unparryable_symptom()
  end
end

function svo.valid.bad_legs()
  if affs.crippledrightleg or affs.crippledleftleg or affs.mangledleftleg or affs.mangledrightleg or affs.mutilatedrightleg or affs.mutilatedleftleg then return end

  valid.simpleunknownany()
end


do
  local afflist = {'hamstring', 'galed', 'voided', 'inquisition', 'burning', 'icing', 'phlogistication', 'vitrification', 'corrupted', 'mucous', 'rixil', 'palpatar', 'cadmus', 'hecate', 'ninkharsag', 'swellskin', 'pinshot', 'dehydrated', 'timeflux', 'lullaby', 'numbedleftarm', 'numbedrightarm', 'unconsciousness', 'degenerate', 'deteriorate', 'hatred'}
  if svo.haveskillset('metamorphosis') then
    afflist[#afflist+1] = 'cantmorph'
  end

  for _, aff in ipairs(afflist) do
    valid[aff..'_woreoff'] = function()
      svo.checkaction(svo.dict[aff].waitingfor, true)
      if actions[aff..'_waitingfor'] then
        lifevision.add(actions[aff..'_waitingfor'].p)
      end
    end
  end
end

function svo.valid.stun_woreoff()
  -- not only stun, but checkstun maybe was waiting, didn't get to check -> needs to restore lifevision
  svo.checkaction(svo.dict.stun.waitingfor)
  if actions.stun_waitingfor then
    lifevision.add(actions.stun_waitingfor.p)
  elseif actions.checkstun_misc then
    lifevision.add(actions.checkstun_misc.p, nil, 'fromstun')
  end
end

for _, aff in ipairs({'heartseed', 'hypothermia'}) do
valid[aff..'_cured'] = function()
  svo.checkaction(svo.dict['curing'..aff].waitingfor)
  if actions['curing'..aff..'_waitingfor'] then
    lifevision.add(actions['curing'..aff..'_waitingfor'].p)
  end
end
end

function svo.valid.aeon_woreoff()
  local result = svo.checkany(svo.dict.aeon.smoke)

  if not result then
    if conf.aillusion and not svo.passive_cure_paragraph and not svo.find_until_last_paragraph("You touch the tree of life tattoo.", 'exact') then
      svo.checkaction(svo.dict.aeon.gone, true)
      lifevision.add(actions.aeon_gone.p, nil, nil, 1)
    else
      -- clear the lineguard if we previously set it via aeon_gone
      if table.contains(lifevision.l:keys(), 'aeon_gone') and lifevision.getlineguard() then
        lifevision.clearlineguard()
      end
      svo.checkaction(svo.dict.aeon.gone, true)
      lifevision.add(actions.aeon_gone.p)
    end
  else
    -- if it was a smoke cure, can't lineguard 1 then, it'll be 2
    svo.smoke_cure = true
    lifevision.add(actions[result.name].p)
  end
end

function svo.valid.destroy_retardation()
  svo.checkaction(svo.dict.retardation.gone, true)
  lifevision.add(actions.retardation_gone.p)

  valid.simpleaeon()
end

function svo.valid.ablaze_woreoff()
  svo.checkaction(svo.dict.ablaze.gone, true)
  lifevision.add(actions.ablaze_gone.p)
end

function svo.valid.wake_start()
  svo.checkaction(svo.dict.sleep.misc)
  if actions.sleep_misc then
    lifevision.add(actions.sleep_misc.p)
  end
end

function svo.valid.wake_done()
  svo.checkaction(svo.dict.curingsleep.waitingfor, true)
  lifevision.add(actions.curingsleep_waitingfor.p)
end

function svo.valid.symp_dizziness_fell()
  -- if not conf.aillusion then
    valid.simpledizziness()
    valid.simpleprone()
  -- elseif affs.dizziness then
  --   valid.simpleprone()
  -- end
end

function svo.valid.cured_fear()
  svo.checkaction(svo.dict.fear.misc)
  if actions.fear_misc then
    lifevision.add(actions.fear_misc.p)
  end
end

function svo.valid.tootired_focus()
  local r = svo.findbybal('focus')
  if not r then return end

  svo.focus_cure = true

  -- in case of double-applies, don't overwrite the first successful application
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'offbalance')
  end
end

function svo.valid.mickey()
  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then svo.ignore_illusion("not first") return end

  local r = svo.findbybal('herb')
  if not r then return end

  lifevision.add(actions[r.name].p, 'mickey')
end

function svo.valid.focus_choleric()
  local r = svo.findbybal('focus')
  if not r then svo.ignore_illusion("Ignored the illusion because we aren't actually focusing right now (or we were forced).") return end

  svo.checkaction(svo.dict.stolebalance.happened, true)
  lifevision.add(actions.stolebalance_happened.p, nil, 'focus')

  svo.focus_cure = true
  svo.killaction(svo.dict[r.action_name].focus)
end

function svo.valid.nomana_focus()
  local r = svo.findbybal('focus')
  if not r then return end

  lifevision.add(actions[r.name].p, 'nomana')
end

function svo.valid.nomana_clot()
  svo.checkaction(svo.dict.bleeding.misc)
  if actions.bleeding_misc then
    lifevision.add(actions.bleeding_misc.p, 'nomana')
  end
end

function svo.valid.stoodup()
  svo.checkaction(svo.dict.prone.misc)
  if actions.prone_misc then
    lifevision.add(actions.prone_misc.p)
  end
end

function svo.valid.sippedhealth()
  svo.checkaction(svo.dict.healhealth.sip)
  if actions.healhealth_sip then
    svo.sip_cure = true
    lifevision.add(actions.healhealth_sip.p)
  end
end
function svo.valid.sippedmana()
  svo.checkaction(svo.dict.healmana.sip)
  if actions.healmana_sip then
    svo.sip_cure = true
    lifevision.add(actions.healmana_sip.p)
  end
end

function svo.valid.gotherb()
  if not conf.aillusion or not sk.blockherbbal then
    svo.checkaction(svo.dict.gotbalance.happened, true)
    svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'herb' -- hack to allow multiple balances at once
    lifevision.add(actions.gotbalance_happened.p)
    selectCurrentLine()
    setFgColor(0, 170, 0)
    deselect()
  else
    svo.ignore_illusion("Couldnt've possibly recovered herb balance so soon - "..(svo.watch.herb_block and getStopWatchTime(svo.watch.herb_block) or '?').."s after eating.")
  end
end

for _, balance in ipairs{'moss', 'focus', 'sip', 'purgative', 'dragonheal', 'smoke', 'tree'} do
valid['got'..balance] = function()
  svo.checkaction(svo.dict.gotbalance.happened, true)
    svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = balance -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
end

function svo.valid.gotsalve()
  if conf.aillusion and svo.paragraph_length ~= 1 then
    local lastline = getLines(getLineNumber()-1, getLineNumber())[1]

    local lines = {
      ["Your left leg feels stronger and healthier."] = {affs = {'curingmutilatedrightleg', 'curingmutilatedleftleg', 'curingmangledrightleg', 'curingmangledleftleg', 'curingparestolegs'}, location = 'legs'},
      ["Your right leg feels stronger and healthier."] = {affs = {'curingmutilatedrightleg', 'curingmutilatedleftleg', 'curingmangledrightleg', 'curingmangledleftleg', 'curingparestolegs'}, location = 'legs'},
      ["Your left arm feels stronger and healthier."] = {affs = {'curingmutilatedrightarm', 'curingmutilatedleftarm', 'curingmangledrightarm', 'curingmangledleftarm', 'curingparestoarms'}, location = 'arms'},
      ["Your right arm feels stronger and healthier."] = {affs = {'curingmutilatedrightarm', 'curingmutilatedleftarm', 'curingmangledrightarm', 'curingmangledleftarm', 'curingparestoarms'}, location = 'arms'},
    }

    if lines[lastline] then
      local had
      for _, aff in ipairs(lines[lastline].affs) do
        if actions[aff..'_waitingfor'] then
          local afftime = getStopWatchTime(actions[aff..'_waitingfor'].p.actionwatch)
          if afftime >= conf.ai_minrestorecure then
            had = true; break
          else
            svo.ignore_illusion(string.format("%s cure couldnt've possibly finished so soon, in %ss - minimum allowed is %ss. This seems like an illusion to trick you.", aff, afftime, conf.ai_minrestorecure))
            return
          end
        end
      end

      if not had then
        svo.ignore_illusion("We aren't applying restoration to "..lines[lastline].location.." right now")
      end
    end
  end
  svo.checkaction(svo.dict.gotbalance.happened, true)
    svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'salve' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function svo.valid.gotpurgative()
  svo.checkaction(svo.dict.gotbalance.happened, true)
    svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'purgative' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function svo.valid.forcesalve()
  svo.checkaction(svo.dict.gotbalance.happened, true)
    svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'salve' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function svo.valid.forcefocus()
  svo.checkaction(svo.dict.gotbalance.happened, true)
    svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'focus' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function svo.valid.forceherb()
  svo.checkaction(svo.dict.gotbalance.happened, true)
    svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'herb' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end

function svo.valid.got_rebounding()
  svo.checkaction(svo.dict.waitingonrebounding.waitingfor)
  if actions.waitingonrebounding_waitingfor then
    lifevision.add(actions.waitingonrebounding_waitingfor.p)
  end
end

function svo.valid.rebounding_deathtarot()
  svo.checkaction(svo.dict.waitingonrebounding.waitingfor, false)
  if actions.waitingonrebounding_waitingfor then
    lifevision.add(actions.waitingonrebounding_waitingfor.p, 'deathtarot')
  end
end

-- palpatar line will be before this if you've had it
function svo.defs.got_speed()
  svo.checkaction(svo.dict.curingspeed.waitingfor)
  if actions.curingspeed_waitingfor then
    lifevision.add(actions.curingspeed_waitingfor.p)
  end
end

function svo.valid.bled()
  -- we don't actually care about the bleeding here, but we want the reckless crosscheck
  if affs.unknownany and stats.hp == 100 and stats.mana == 100 then
    valid.simplerecklessness()
  end
end

function svo.valid.clot1()
  svo.checkaction(svo.dict.bleeding.misc)
  if actions.bleeding_misc then
    lifevision.add(actions.bleeding_misc.p)
  end

  if conf.gagclot and not sys.sync then svo.deleteLineP() end
end

function svo.valid.clot2()
  svo.checkaction(svo.dict.bleeding.misc)
  if actions.bleeding_misc then
    lifevision.add(actions.bleeding_misc.p, 'oncured')
  end

  if conf.gagclot and not sys.sync then svo.deleteLineP() end
end

function svo.valid.symp_haemophilia()
  if not conf.aillusion and actions.bleeding_misc then
    valid.remove_unknownany('haemophilia')
    valid.simplehaemophilia()
  else
    svo.checkaction(svo.dict.bleeding.misc, false)
    if actions.bleeding_misc then
      valid.remove_unknownany('haemophilia')
      lifevision.add(actions.bleeding_misc.p, 'haemophilia', nil, 1)
    elseif not affs.haemophilia then
      svo.ignore_illusion("Ignored this illusion because we aren't trying to clot right now (or we were forced).")
    end
  end
end

function svo.valid.proper_haemophilia()
  if not conf.aillusion then
    valid.simplehaemophilia()
  elseif svo.find_until_last_paragraph('wracks', 'substring') and svo.paragraph_length >= 3 then
    valid.simplehaemophilia()
  elseif svo.find_until_last_paragraph("glowers at you with a look of repressed disgust", 'substring') or svo.find_until_last_paragraph("stares menacingly at you, its eyes flashing brightly.", 'substring') then
    valid.simplehaemophilia()
  elseif svo.find_until_last_paragraph("points an imperious finger at you.", 'substring') then
    -- shamanism
    valid.simplehaemophilia()
  elseif svo.find_until_last_paragraph("makes a quick, sharp gesture toward you.", 'substring') then
    -- occultism instill
    valid.simplehaemophilia()
  elseif line:starts("A bloodleech leaps at you, clamping with teeth onto exposed flesh and secreting some foul toxin into your bloodstream. You stumble as you are afflicted") then
    -- domination bloodleech
    valid.simplehaemophilia()
  else
    svo.ignore_illusion("Doesn't seem to be an Alchemist wrack or Occultism instill - going to see if it's real off symptoms.")
  end
end

function svo.valid.humour_wrack()
  svo.checkaction(svo.dict.unknownany.aff, true)
  lifevision.add(actions['unknownany_aff'].p, 'wrack', nil)

  -- to check if we got reckless!
  if stats.currenthealth ~= stats.maxhealth then
    svo.dict.unknownany.reckhp = true end
  if stats.currentmana ~= stats.maxmana then
    svo.dict.unknownany.reckmana = true end
end

-- detect how many wracks (of the 2 available in a truewrack) were hidden (that is - humour-based wrack, which is hidden)
-- vs affliction-based wrack, which is visible
function svo.valid.humour_truewrack()
  local sawaffs = 0
  for _, action in pairs(lifevision.l:keys()) do
    if action:find('_aff', 1, true) then
      sawaffs = sawaffs + 1
    end
  end

  -- limit to 2 in case we saw more - we don't want to add more than 2 unknowns
  if sawaffs > 2 then sawaffs = 2 end

  -- add the appropriate amount of missing unknowns, up to 2. If we saw an affliction, don't add an unknown for it.
  for _ = 1, 2-sawaffs do
    valid.simpleunknownany()
  end
end

function svo.valid.got_humour(which)
  svo.assert(svo.dict[which..'humour'], "svo.valid.got_humour: which humour to add?")

  local function countaffs(humour)
    local affs_in_a_humour = 3

    local t = {
      choleric    = {'illness', 'sensitivity', 'slickness'},
      melancholic = {'anorexia', 'impatience', 'stupidity'},
      phlegmatic  = {'asthma', 'clumsiness', 'disloyalty'},
      sanguine    = {'haemophilia', 'recklessness',  'paralysis'}
    }

    -- add the amount of focusables in a humour as the 4th argument, to check for as well
    for humour, data in pairs(t) do
      local focusables_in_humour = 0
      for i = 1, affs_in_a_humour do
        if svo.dict[data[i]].focus then focusables_in_humour = focusables_in_humour + 1 end
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
      count = count + (svo.dict.unknownmental.count > max_focusable_affs_in_humour and max_focusable_affs_in_humour or svo.dict.unknownmental.count)
    end

    -- and lastly, unknown affs
    if affs.unknownany then
      count = count + svo.dict.unknownany.count
    end

    return count
  end

  -- humours give up to 3 levels in one go, depending on which relevant afflictions have you got. account for unknown afflictions as well!
  -- 1 for the temper, + any more affs
  local humourlevels = 1 + countaffs(which)
  -- trim the max we counted down to 3, which is the most possible right now
  if humourlevels > 3 then humourlevels = 3 end

  svo.checkaction(svo.dict[which..'humour'].aff, true)
  lifevision.add(actions[which..'humour_aff'].p, nil, humourlevels)
end

function svo.valid.sanguine_inundate()
  svo.checkaction(svo.dict.sanguinehumour.herb, true)
  if actions.sanguinehumour_herb then
    lifevision.add(actions.sanguinehumour_herb.p, 'inundated')
  end
end

function svo.valid.choleric_inundate()
  svo.checkaction(svo.dict.cholerichumour.herb, true)
  if actions.cholerichumour_herb then
    lifevision.add(actions.cholerichumour_herb.p, 'inundated')
  end
end

function svo.valid.melancholic_inundate()
  svo.checkaction(svo.dict.melancholichumour.herb, true)
  if actions.melancholichumour_herb then
    lifevision.add(actions.melancholichumour_herb.p, 'inundated')
  end
end

function svo.valid.phlegmatic_inundate()
  svo.checkaction(svo.dict.phlegmatichumour.herb, true)
  if actions.phlegmatichumour_herb then
    lifevision.add(actions.phlegmatichumour_herb.p, 'inundated')
  end
end

for _, aff in ipairs({'skullfractures', 'crackedribs', 'wristfractures', 'torntendons'}) do
valid[aff..'_apply'] = function()
  svo.applyelixir_cure = true

  svo.checkaction(svo.dict[aff].sip, true)
  lifevision.add(actions[aff..'_sip'].p)
end

valid[aff..'_cured'] = function()
  svo.applyelixir_cure = true

  svo.checkaction(svo.dict[aff].sip, true)
  lifevision.add(actions[aff..'_sip'].p, 'cured')
end
end

function svo.valid.tarot_aeon()
  -- speed -can- be stripped in blackout
  -- if conf.aillusion and defc.speed and not actions.speed_gone and svo.paragraph_length <= 2 then return end

  if not conf.aillusion or svo.paragraph_length > 2 then
    valid.simpleaeon()
  else
    svo.checkaction(svo.dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, 'aeon')
  end
end

function svo.valid.refilled(what)
  local shortname = svo.es_shortnamesr[what]
  if not shortname or svo.es_categories[what] == 'venom' then return end

  if svo.es_potions[svo.es_categories[what]][what].sips == 0 then
    svo.es_potions[svo.es_categories[what]][what].sips = svo.es_potions[svo.es_categories[what]][what].sips + 50
    svo.es_potions[svo.es_categories[what]][what].vials = svo.es_potions[svo.es_categories[what]][what].vials + 1
    echo"\n" svo.echof("We refilled %s - will use it for cures now.", what)
  end
end

function svo.valid.missing_herb()
  if actions.checkstun_misc then
    svo.deleteLineP()
    lifevision.add(actions.checkstun_misc.p, 'onclear')
  end

  -- don't echo anything for serverside failing to svo.eat a herb
  if conf.serverside then return end

  local eating = svo.findbybals ({'herb', 'moss'})
  if not eating then return end
  local action = select(2, next(eating))
  eating = next(eating)

  if sys.last_used[eating] then
    rift.invcontents[sys.last_used[eating]] = 0

    -- echo only if temporarily ran out and have more in rift
    if rift.riftcontents[sys.last_used[eating]] ~= 0 and sys.canoutr then
      echo"\n" svo.echof("(don't have %s in inventory for %s as I thought)", sys.last_used[eating], action.action_name)
    end
    -- SHOULD cancel action, but that can also cause us to get into an infinite loop of eating nothing
    -- needs to be fixed after better herb tracking
  end
end

function svo.valid.symp_anorexia()
  if not conf.aillusion then -- ai is off? go-ahead then
    valid.simpleanorexia()
    return
  end

  local eating = svo.findbybal ('herb')
  if eating then
    valid.simpleanorexia()
    svo.killaction(svo.dict[eating.action_name].herb)
  elseif svo.findbybals({'sip', 'purgative', 'herb', 'moss'}) then
    valid.simpleanorexia()
  elseif actions.checkanorexia_misc then
    lifevision.add(actions.checkanorexia_misc.p, 'blehfood')
  end
end

function svo.valid.salve_fizzled(limb)
  local r = svo.checkany(svo.dict.crippledleftarm.salve, svo.dict.crippledleftleg.salve, svo.dict.crippledrightarm.salve, svo.dict.crippledrightleg.salve, svo.dict.unknowncrippledlimb.salve, svo.dict.unknowncrippledarm.salve, svo.dict.unknowncrippledleg.salve)
  if not r then return end

  svo.apply_cure = true

  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'fizzled', limb)
  end
end

function svo.valid.health_fizzled()
  local r = svo.checkany(svo.dict.skullfractures.sip, svo.dict.crackedribs.sip, svo.dict.wristfractures.sip, svo.dict.torntendons.sip)
  if not r then return end

  svo.applyelixir_cure = true

  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'fizzled')
  end
end

function svo.valid.health_noeffect()
  local r = svo.checkany(svo.dict.skullfractures.sip, svo.dict.crackedribs.sip, svo.dict.wristfractures.sip, svo.dict.torntendons.sip)
  if not r then return end

  svo.applyelixir_cure = true
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'noeffect')
  end
end

-- this can happen on a restore or a mending application
-- handle upgrading of the limb
function svo.valid.update_break(limb)
  local r = svo.checkany(svo.dict.crippledleftarm.salve, svo.dict.crippledleftleg.salve, svo.dict.crippledrightarm.salve, svo.dict.crippledrightleg.salve, svo.dict.unknowncrippledlimb.salve, svo.dict.unknowncrippledarm.salve, svo.dict.unknowncrippledleg.salve)
  if not r and not actions.restore_physical then return end

  if actions.restore_physical then
    if not affs['mangled'..limb] then
      valid.simple['mangled'..limb]()
    end
  else
    svo.apply_cure = true
    if not lifevision.l[r.name] then
      lifevision.add(actions[r.name].p, 'fizzled', limb)
    end
  end
end

function svo.valid.salve_offbalance()
  local r = svo.findbybal('salve')
  if not r then return end

  svo.apply_cure = true

  -- in case of double-applies, don't overwrite the first successful application
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'offbalance')
  end
end

function svo.valid.force_aeon()
  svo.vaff('aeon')
end

function svo.valid.herb_cured_insomnia()
  local r = svo.checkany(svo.dict.dissonance.herb, svo.dict.impatience.herb, svo.dict.stupidity.herb, svo.dict.dizziness.herb, svo.dict.epilepsy.herb, svo.dict.shyness.herb)
  if conf.aillusion and not (r or svo.find_until_last_paragraph("You feel irresistibly compelled", 'substring') or svo.find_until_last_paragraph("You cannot help but obey.", 'exact')) then svo.ignore_illusion("We aren't eating goldenseal at the moment.") return end

  if r then
    svo.killaction(svo.dict[r.action_name].herb)
  end

  defs.lost_insomnia()
  svo.lostbal_herb()

  if r then
    svo.checkaction(svo.dict[r.action_name].gone, true)
    lifevision.add(actions[r.action_name..'_gone'].p)
  end

  svo.checkaction(svo.dict.checkimpatience.misc, true)
  lifevision.add(actions.checkimpatience_misc.p, 'onclear')
end

function svo.valid.fillskullcap()
  svo.checkaction(svo.dict.fillskullcap.physical)
  if actions.fillskullcap_physical then
    lifevision.add(actions.fillskullcap_physical.p)
  end
end

function svo.valid.fillelm()
  svo.checkaction(svo.dict.fillelm.physical)
  if actions.fillelm_physical then
    lifevision.add(actions.fillelm_physical.p)
  end
end

function svo.valid.fillvalerian()
  svo.checkaction(svo.dict.fillvalerian.physical)
  if actions.fillvalerian_physical then
    lifevision.add(actions.fillvalerian_physical.p)
  end
end

function svo.valid.alreadyfull()
  local result = svo.checkany(svo.dict.fillskullcap.physical, svo.dict.fillelm.physical, svo.dict.fillvalerian.physical)

  if not result then return end

  lifevision.add(actions[result.name].p)
end

function svo.valid.litpipe(gag2)
  if not sys.sync then
    if conf.gagrelight then svo.deleteLineP() end
    if conf.gagrelight and gag2 then deleteLine() end
  end

  local result = svo.checkany(
    svo.dict.lightelm.physical, svo.dict.lightvalerian.physical, svo.dict.lightskullcap.physical)

  if not result then return end
  lifevision.add(actions[result.name].p)
end

function svo.valid.litallpipes()
  if not sys.sync and conf.gagrelight then svo.deleteLineP() end

  svo.checkaction(svo.dict.lightpipes.physical)
  if actions.lightpipes_physical then
    lifevision.add(actions.lightpipes_physical.p)
  end
end

function svo.valid.paradox_aff(herb)
  svo.checkaction(svo.dict.paradox.aff, true)
  lifevision.add(actions.paradox_aff.p, nil, herb)
end

function svo.valid.paradox_boosted()
  svo.checkaction(svo.dict.paradox.boosted, true)
  lifevision.add(actions.paradox_boosted.p)
end

function svo.valid.paradox_weakened()
  if svo.find_until_last_paragraph(svo.dict.paradox.blocked_herb, 'substring') or svo.find_until_last_paragraph(rift.herb_conversions[svo.dict.paradox.blocked_herb], 'substring') then return end
  svo.checkaction(svo.dict.paradox.weakened, true)
  lifevision.add(actions.paradox_weakened.p)
end

function svo.valid.paradox_faded()
  svo.checkaction(svo.dict.paradox.gone, true)
  lifevision.add(actions.paradox_gone.p)
end

svo.herb_cure = false
 -- svo.reset the flag tracking whenever we got a cure for what we ate (svo.herb_cure) at the start
function svo.valid.ate1()
  if svo.paragraph_length == 1 then
    svo.herb_cure = false
  end

  -- see if we need to enable arena mode for some reason
  local t = sk.arena_areas
  local area = atcp.RoomArea or (gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.area)
  if area and t[area] and not conf.arena then
    conf.arena = true
    raiseEvent("svo config changed", 'arena')
    svo.prompttrigger("arena echo", function()
      echo'\n'svo.echof("Looks like you're actually in the arena - enabled arena mode.\n") svo.showprompt()
    end)
  end

  -- check anti-illusion with GMCP's herb removal
  if conf.aillusion and not conf.arena and not affs.dementia and sys.enabledgmcp and not sk.removed_something and not svo.find_until_last_paragraph("You feel irresistibly compelled", 'substring') and not svo.find_until_last_paragraph("You cannot help but obey.", 'exact') then
    -- let nicer tooltips come first before this one
    svo.aiprompt("nothing removed, but ate", function() svo.ignore_illusion("We didn't svo.eat that!", true) end)
  end

  -- check if we need to add or remove addiction - but not if we are ginseng/ferrum as that doesn't go off on addiction
  if (not conf.aillusion or svo.findbybal('herb')) and not svo.find_until_last_paragraph("ginseng root", 'substring') and not svo.find_until_last_paragraph("ferrum flake", 'substring') then
    sk.onprompt_beforelifevision_add("add/remove addiction", function()
      if not affs.addiction and svo.find_until_last_paragraph("Your addiction can never be sated.", 'exact') then
        valid.simpleaddiction()
      elseif affs.addiction and not svo.find_until_last_paragraph("Your addiction can never be sated.", 'exact') then
        svo.checkaction(svo.dict.addiction.gone, true)
        lifevision.add(actions.addiction_gone.p)
      end
    end)
  end
end

-- see if the herb we ate actually cured us: if no, register the herb eating action as 'empty'
function svo.valid.ate2()
  -- cadmus comes on the next line after
  tempLineTrigger(1,1,[[
    if line == "The vile curse of Cadmus leaves you." then
      svo.valid.cadmus_woreoff()
    elseif line == "The paradox affecting you weakens." then
      svo.valid.paradox_weakened()
    elseif line == "The paradox fades." then
      svo.valid.paradox_faded()
    end
  ]])

  -- if it's addition or swellskin stretching the eating - don't go off now, but on the next one
  if line == "Your addiction can never be sated." or line == "Eating is suddenly less difficult again." then return end

  if not svo.herb_cure then
    local eating = svo.findbybal('herb')
    if not eating then return end

    -- check timers here! should not be less than half of svo.getping(). Check *action*, not affliction timer as well
    if conf.aillusion and not conf.serverside then
      local time, lat = getStopWatchTime(actions[eating.name].p.actionwatch), svo.getping()

      if time < (lat/2) then
        svo.ignore_illusion("This looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    -- addiction needs to stretch the lineguard to 2, since it is You svo.eat/Your addiction/prompt.
    -- [Curing] does not show up for svo.find_until_last_paragraph when it is gagged, so track it otherwise
    if conf.aillusion then
      lifevision.add(actions[eating.name].p, 'empty', nil, ((svo.find_until_last_paragraph("Your addiction can never be sated.", 'exact') or svo.find_until_last_paragraph("Eating is suddenly less difficult again.", 'exact') or sk.sawcuringcommand) and 2 or 1))
    else
      lifevision.add(actions[eating.name].p, 'empty')
    end
  end

  svo.herb_cure = false
end

svo.sip_cure = false

function svo.valid.sip1()
  svo.sip_cure = false
end

function svo.valid.sip2()
  if not svo.sip_cure then
  local sipping = svo.findbybal('purgative')

  if not sipping then
    -- special case for speed, which is a sip but balanceless
    if svo.doingaction'speed' then
      lifevision.add(actions.speed_purgative.p)
    end
  return end

    lifevision.add(actions[sipping.name].p, 'empty')
  end

  svo.sip_cure = false
end

local tree_cure = false

function svo.valid.tree1()
  tree_cure = false
end

function svo.valid.tree2()
  if not tree_cure then
    if conf.aillusion and not actions.touchtree_misc then
      svo.ignore_illusion("We aren't actually touching tree right now (or we were forced).", true)
      return
    end

    -- prevent against a well-timed tree illusion, which when empty, forces us to clear all afflictions
    if conf.aillusion then
      local time, lat = getStopWatchTime(actions.touchtree_misc.p.actionwatch), svo.getping()

      if time < (lat/2) then
        svo.ignore_illusion("This looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    svo.checkaction(svo.dict.touchtree.misc, true)

    -- add it anyway, as the illusion could get cancelled later on
    lifevision.add(actions.touchtree_misc.p, 'empty')
  end

  tree_cure = false
end

svo.apply_cure = false

function svo.valid.apply1()
  svo.apply_cure = false
end

function svo.valid.apply2()
  if not svo.apply_cure then
  local r = svo.findbybal('salve')
  if not r then return end

    lifevision.add(actions[r.name].p, 'empty')
  end

  svo.apply_cure = false
end

svo.smoke_cure = false

function svo.valid.smoke1()
  svo.smoke_cure = false
end

function svo.valid.smoke2()
  if not svo.smoke_cure then
    local r = svo.findbybal('smoke')
    if r then
      lifevision.add(actions[r.name].p, 'empty')
    elseif actions.checkasthma_smoke then
      lifevision.add(actions.checkasthma_smoke.p, 'onclear')
    end
  end

  svo.smoke_cure = false
end

svo.applyelixir_cure = false

function svo.valid.applyelixir1()
  svo.applyelixir_cure = false
end

function svo.valid.applyelixir2()
  if not svo.applyelixir_cure then
    local r = svo.findbybal('sip')
    if not r then return end

      lifevision.add(actions[r.name].p, 'empty')
  end

  svo.applyelixir_cure = false
end

svo.focus_cure = false

-- note: rixil fading will be inbetween here
function svo.valid.focus1()
  svo.focus_cure = false
end

-- this should go off on the line where a focus cure would have otherwise seen
function svo.valid.focus2()
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
    lifevision.add(actions.checkimpatience_misc.p, 'onclear')
  end

  if not svo.focus_cure then
    svo.focus_cure = false

    local r = svo.findbybal('focus')

    if not r then return end

    -- check timers here! should not be less than half of svo.getping(). Check *action*, not affliction timer as well
    if conf.aillusion and not conf.serverside then
      local time, lat = getStopWatchTime(actions[r.name].p.actionwatch), svo.getping()

      if time < (lat/2) then
        svo.ignore_illusion("This 'cure' looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
        return
      end
    end

    lifevision.add(actions[r.name].p, 'empty')
  end
end

function svo.valid.salve_had_no_effect()
  local r = svo.findbybal('salve')
  if not r then return end

  svo.apply_cure = true
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'noeffect')
  end
end

function svo.valid.plant_had_no_effect()
  local r = svo.findbybal('herb')
  if not r then return end

  svo.herb_cure = true

  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'noeffect')
  end
end

function svo.valid.salve_slickness()
  local r = svo.findbybal('salve')
  if not r then return end

  svo.apply_cure = true
  valid.simpleslickness()
  svo.killaction(svo.dict[r.action_name].salve)
end

function svo.valid.potion_slickness()
  local r = svo.findbybal('salve')
  if not r then return end

  svo.apply_cure = true
  valid.simpleslickness()
  svo.killaction(svo.dict[r.action_name].salve)
end

function svo.valid.sip_had_no_effect()
  local function kill(r)
    svo.sip_cure = true
    if not lifevision.l[r.name] then
      lifevision.add(actions[r.name].p, 'noeffect')
    end
  end

  local r = svo.findbybal('sip')
  if r then kill(r) else
    r = svo.findbybal('purgative')
    if not r then return end

    kill(r)
  end
end

function svo.valid.removed_from_rift()
  -- we're only interested in this while in sync mode
  if not sys.sync then return end

  local eating = svo.findbybal('herb')
  if eating then svo.killaction(eating) return end

  local outring = svo.findbybal('physical')
  if outring then svo.killaction(outring) end
end
signals.removed_from_rift:connect(valid.removed_from_rift)

function svo.valid.no_refill_herb()
  for _, herb in ipairs{'elm', 'valerian', 'skullcap'} do
    if actions['fill'..herb..'_physical'] then
      rift.invcontents[pipes[herb].filledwith] = 0
      svo.killaction(svo.dict['fill'..herb].physical)
    end
  end
end

function svo.valid.no_outr_herb(what)
  svo.assert(what, "svo.valid.no_outr_herb: requires a single argument")
  if actions.doprecache_misc and rift.precache[what] ~= 0 and rift.riftcontents[what] ~= 0 and (rift.invcontents[what] < rift.precache[what]) then
    rift.riftcontents[what] = 0
    echo"\n" svo.echof("Apparently we're out of %s! Can't precache it.", what)
  else
    local eating = svo.findbybals ({'herb', 'moss', 'misc'})
    if not eating then
      -- check pipes instead
      local r = svo.checkany(svo.dict.fillskullcap.physical, svo.dict.fillelm.physical, svo.dict.fillvalerian.physical)

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

      echo'\n' svo.echof("Don't have %s, will try %s next time.", eaten, alternative)

      if rift.riftcontents[alternative] <= 0 then
        rift.riftcontents[alternative] = 1
      end
    end
  end
end

function svo.valid.cureddisrupt()
  svo.checkaction(svo.dict.disrupt.misc)
  if actions.disrupt_misc then
    lifevision.add(actions.disrupt_misc.p)
  end
end


function svo.valid.failed_focus_impatience()
  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then svo.ignore_illusion("not first") return end
  local r = svo.findbybal('focus')
  if r or not conf.aillusion or actions.checkimpatience_misc then
    if r then svo.killaction(svo.dict[r.action_name].focus) end

    if actions.checkimpatience_misc then
      lifevision.add(actions.checkimpatience_misc.p, 'impatient', nil, 1)
    else
      valid.simpleimpatience()
    end
  -- don't show a false (i) when we already know we've got impatience
  elseif conf.aillusion and not affs.impatience then
    svo.ignore_illusion("Not actually trying to focus right now (or we were forced).")
  end
end

function svo.valid.smoke_failed_asthma()
  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then svo.ignore_illusion("not first") return end

  if actions.checkasthma_smoke then
    lifevision.add(actions.checkasthma_smoke.p, 'badlungs', nil, 1)
  end

  local r = svo.findbybal('smoke')
  if r or not conf.aillusion then

    if not affs.asthma then
      svo.checkaction(svo.dict.asthma.aff, true)
      lifevision.add(actions['asthma_aff'].p, nil, nil, 1)
      svo.affsp.asthma = nil
    end
  elseif conf.aillusion and not affs.asthma then -- don't show (i) on delays + already have valid asthma
    svo.ignore_illusion("Not actually trying to smoke anything right now (or we were forced).")
  end
end

function svo.valid.got_mucous()
  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then svo.ignore_illusion("not first") return end

  if actions.checkasthma_smoke then
    lifevision.add(actions.checkasthma_smoke.p, 'mucous', nil, 1)
  end

  local r = svo.findbybal('smoke')
  if r or not conf.aillusion then

    if not affs.mucous then
      svo.checkaction(svo.dict.mucous.aff, true)
      lifevision.add(actions['mucous_aff'].p, nil, nil, 1)
    end
  elseif conf.aillusion then
    svo.ignore_illusion("Not actually trying to smoke anything right now (or we were forced).")
  end
end

function svo.valid.have_mucous()
  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then svo.ignore_illusion("not first") return end

  local r = svo.findbybal('smoke')
  if r or not conf.aillusion then

    if not affs.mucous then
      svo.checkaction(svo.dict.mucous.aff, true)
      lifevision.add(actions['mucous_aff'].p, nil, nil, 1)
    end
  elseif conf.aillusion then
    svo.ignore_illusion("Not actually trying to smoke anything right now (or we were forced).")
  end
end

function svo.valid.unlit_pipe()
  local r = svo.findbybal('smoke')
  if not r then return end

  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then
    svo.ignore_illusion("not first")
    return
  end

  if type(svo.dict[r.action_name].smoke.smokecure) == 'string' then
    pipes[svo.dict[r.action_name].smoke.smokecure].lit = false
    svo.show_info("unlit "..svo.dict[r.action_name].smoke.smokecure, "Apparently the "..svo.dict[r.action_name].smoke.smokecure.." pipe was out")
    svo.killaction(svo.dict[r.action_name].smoke)
  elseif type(svo.dict[r.action_name].smoke.smokecure) == 'table' then
    for _, herb in pairs(svo.dict[r.action_name].smoke.smokecure) do
      if pipes[herb] and pipes[herb].lit then
        pipes[herb].lit = false
        svo.show_info("unlit "..herb, "Apparently the "..herb.." pipe was out")
        if pipes[herb].arty then
          pipes[herb].arty = false
          svo.show_info("not an artefact", "It's not an artefact pipe, either. I've made it be a normal one for you")
        end
        svo.killaction(svo.dict[r.action_name].smoke)
      end
    end
  end
end

function svo.valid.necromancy_shrivel()
  valid['simplecrippled'..matches[2]..matches[3]]()
end

function svo.valid.got_aeon()
  if conf.aillusion and not defc.speed then
    valid.simpleaeon()
  elseif not conf.aillusion then
    if not conf.aillusion then
      valid.simpleaeon()
    else
      svo.checkaction(svo.dict.checkslows.aff, true)
      lifevision.add(actions.checkslows_aff.p, nil, 'aeon')
    end

    defs.lost_speed()
  end
end

function svo.valid.empty_pipe()
  local r = svo.findbybal('smoke')
  if not r then
    if conf.aillusion and not (actions.fillskullcap_physical or actions.fillelm_physical or actions.fillvalerian_physical)
      then svo.ignore_illusion("Not actually trying to smoke anything right now (or we were forced).") end
    return
  end

  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then
    svo.ignore_illusion("not first")
    return
  end

-- TODO: turn this into a svo.dict. action validated by lifevision w/ a lifeguard
  if type(svo.dict[r.action_name].smoke.smokecure) == 'string' then
    pipes[svo.dict[r.action_name].smoke.smokecure].puffs = 0
  elseif type(svo.dict[r.action_name].smoke.smokecure) == 'table' then
    for _, herb in pairs(svo.dict[r.action_name].smoke.smokecure) do
      if pipes[herb] and pipes[herb].puffs then
        pipes[herb].puffs = 0
      end
    end
  end

  svo.killaction(svo.dict[r.action_name].smoke)

  if svo.dict[r.action_name].smoke.smokecure[1] == 'valerian' and not (bals.balance and bals.equilibrium) then
    sk.warn('emptyvalerianpipe')
  end
end

function svo.valid.pipe_emptied()
  local r = svo.checkany(svo.dict.fillskullcap.physical, svo.dict.fillelm.physical, svo.dict.fillvalerian.physical)

  if not r then return end

  if svo.dict[r.action_name].fillingid == pipes[svo.dict[r.action_name].physical.herb].id then
    pipes[svo.dict[r.action_name].physical.herb].puffs = 0
  else
    pipes[svo.dict[r.action_name].physical.herb].puffs2 = 0
  end

  if sys.sync then
    svo.killaction(svo.dict[r.action_name].physical)
  end
end

function svo.valid.empty_light()
  local r = svo.checkany(svo.dict.lightskullcap.physical, svo.dict.lightelm.physical, svo.dict.lightvalerian.physical)

  if not r then return end

  if svo.dict[r.action_name].fillingid == pipes[svo.dict[r.action_name].physical.herb].id then
    pipes[svo.dict[r.action_name].physical.herb].puffs = 0
  else
    pipes[svo.dict[r.action_name].physical.herb].puffs2 = 0
  end
  svo.killaction(svo.dict[r.action_name].physical)
end

-- bindings
for _,aff in ipairs({'bound', 'webbed', 'roped', 'transfixed', 'impale', 'hoisted'}) do
valid['writhed'..aff] = function()
  if not affs[aff] then return end

  local result = svo.checkany(svo.dict.curingbound.waitingfor, svo.dict.curingwebbed.waitingfor, svo.dict.curingroped.waitingfor, svo.dict.curingtransfixed.waitingfor, svo.dict.curingimpale.waitingfor, svo.dict.curinghoisted.waitingfor)

  if not result then return end

  -- if we were writhing what we expected from to writhe, continue
  if actions['curing'..aff..'_waitingfor'] then
    lifevision.add(svo.dict['curing'..aff].waitingfor)
  -- otherwise if we writhed from something we were not - kill if we were doing anything else and add the new
  else
    svo.killaction(svo.dict[result.action_name].waitingfor)
    svo.checkaction(svo.dict['curing'..aff].waitingfor, true)
    lifevision.add(svo.dict['curing'..aff].waitingfor)
  end
end
end

function svo.valid.writhe()
  local result = svo.checkany(svo.dict.bound.misc, svo.dict.webbed.misc, svo.dict.roped.misc, svo.dict.transfixed.misc, svo.dict.hoisted.misc, svo.dict.impale.misc)

  if not result then return end
  if actions[result.name] then
    lifevision.add(actions[result.name].p)
  end
end


function svo.valid.writheimpale()
  local result = svo.checkany(svo.dict.impale.misc, svo.dict.transfixed.misc, svo.dict.webbed.misc, svo.dict.roped.misc, svo.dict.hoisted.misc, svo.dict.bound.misc)

  if not result then return end

  if result.name == 'impale_misc' then
    lifevision.add(actions[result.name].p)
  else
    lifevision.add(actions[result.name].p, 'impale')
  end
end

function svo.valid.writhe_helpless()
  local result = svo.checkany(svo.dict.bound.misc, svo.dict.webbed.misc, svo.dict.roped.misc, svo.dict.impale.misc, svo.dict.transfixed.misc, svo.dict.hoisted.misc)

  if not result then svo.ignore_illusion("We aren't actually writhing from anything right now (or we were forced).") return end
  if actions[result.name] then
    lifevision.add(actions[result.name].p, 'helpless')
  end
end

-- restoration cures
for _, restoration in pairs({
  restorationlegs = {'mutilatedrightleg', 'mutilatedleftleg', 'mangledrightleg', 'mangledleftleg', 'parestolegs'},
  restorationarms = {'mutilatedrightarm', 'mutilatedleftarm', 'mangledrightarm', 'mangledleftarm', 'parestoarms'},
  restorationother = {'mildtrauma', 'serioustrauma', 'mildconcussion', 'seriousconcussion', 'laceratedthroat', 'heartseed'}}) do
  local other_restoration_affs = {}

  -- compile a list of other things we can cure but aren't intending to with this action
  for _, aff in pairs(restoration) do
    other_restoration_affs[#other_restoration_affs+1] = svo.dict['curing'..aff].waitingfor
  end

  for _, aff in pairs(restoration) do
    valid['curing'..aff] = function()
      local result = svo.checkany(svo.dict['curing'..aff].waitingfor, unpack(other_restoration_affs))

      if not result then return end

      if result.name == 'curing'..aff..'_waitingfor' then
        lifevision.add(actions['curing'..aff..'_waitingfor'].p)
      elseif (aff:find('leg') and (not conf.aillusion or affs[aff] or affs.parestolegs)) or
        (aff:find('arm') and (not conf.aillusion or affs[aff] or affs.parestoarms)) then
        svo.checkaction(svo.dict['curing'..aff].waitingfor, true)
        lifevision.add(svo.dict['curing'..aff].waitingfor)
      else
        svo.ignore_illusion("We don't have a "..aff.." right now.")
      end
    end
  end
end

-- salve cures - instantaneous only
for _, regeneration in pairs({
  caloric   = {'frozen', 'shivering', 'caloric'},
  epidermal = {'anorexia', 'itching', 'stuttering', 'slashedthroat', 'blindaff', 'deafaff', 'scalded'},
  mending   = {'selarnia', 'crippledleftarm', 'crippledleftleg', 'crippledrightarm', 'crippledrightleg', 'ablaze', 'unknowncrippledarm', 'unknowncrippledleg', 'unknowncrippledlimb'}}) do
  local other_regeneration_affs = {}

  for _, aff in pairs(regeneration) do
    other_regeneration_affs[#other_regeneration_affs+1] = svo.dict[aff].salve
  end

  for _, aff in pairs(regeneration) do
    valid['salve_cured_'..aff] = function()
      local result = svo.checkany(svo.dict[aff].salve, unpack(other_regeneration_affs))

      if not result then return end

      svo.apply_cure = true
      if result.name == aff..'_salve' then
        lifevision.add(actions[aff..'_salve'].p)
      else
        svo.killaction(svo.dict[result.action_name].salve)
        svo.checkaction(svo.dict[aff].salve, true)
        lifevision.add(svo.dict[aff].salve)
      end
    end
  end
end


-- focus
do
  local afflist = {'claustrophobia', 'masochism', 'dizziness', 'confusion', 'stupidity', 'generosity', 'loneliness', 'agoraphobia', 'recklessness', 'epilepsy', 'pacifism', 'anorexia', 'shyness', 'vertigo', 'fear', 'airdisrupt', 'firedisrupt', 'waterdisrupt', 'dementia', 'paranoia', 'hallucinations'}
  local other_focus_affs = {}

  for _, aff in pairs(afflist) do
    other_focus_affs[#other_focus_affs+1] = svo.dict[aff].focus
  end

  for _, aff in pairs(afflist) do
    valid['focus_cured_'..aff] = function()
      local result = svo.checkany(svo.dict[aff].focus, unpack(other_focus_affs))
      if not result then return end

      svo.focus_cure = true

      if result.name == aff..'_focus' then
        lifevision.add(actions[aff..'_focus'].p)

        -- check timers here! should not be less than half of svo.getping(). Check *action*, not affliction timer as well
        if conf.aillusion and not conf.serverside then
          local time, lat = getStopWatchTime(actions[aff..'_focus'].p.actionwatch), svo.getping()

          if time < (lat/2) then
            svo.ignore_illusion("This 'cure' looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
            return
          end
        end
      else
        svo.killaction(svo.dict[result.action_name].focus)
        svo.checkaction(svo.dict[aff].focus, true)
        lifevision.add(svo.dict[aff].focus)
      end
    end

  end
end


-- normal smokes
for _, smoke in pairs({
  valerian = {'disloyalty', 'slickness', 'manaleech'},
  elm = {'deadening', 'hellsight', 'madness', 'aeon'}}) do
  local other_smoke_cures = {}

  for _, aff in pairs(smoke) do
    other_smoke_cures[#other_smoke_cures+1] = svo.dict[aff].smoke
  end

  for _, aff in pairs(smoke) do
    valid['smoke_cured_'..aff] = function()
      local result = svo.checkany(svo.dict[aff].smoke, unpack(other_smoke_cures))
     -- aff twice in the svo.checkany list, first so most cases it gets returned first when it's the only aff

      if not result then return end

      svo.smoke_cure = true
      if result.name == aff".._smoke" then
        lifevision.add(actions[aff..'_smoke'].p)
      else
        svo.killaction(svo.dict[result.action_name].smoke)
        svo.checkaction(svo.dict[aff].smoke, true)
        lifevision.add(svo.dict[aff].smoke)
      end
    end

  end
end

-- normal herbs
for _, herb in pairs({
  ash        = {'hallucinations', 'hypersomnia', 'confusion', 'paranoia', 'dementia'},
  bellwort   = {'generosity', 'pacifism', 'justice', 'inlove', 'peace', 'retribution', 'timeloop'},
  bloodroot  = {'paralysis', 'slickness'},
  ginger     = {'melancholichumour', 'cholerichumour', 'phlegmatichumour', 'sanguinehumour'},
  ginseng    = {'haemophilia', 'darkshade', 'relapsing', 'addiction', 'illness', 'lethargy'},
  goldenseal = {'dissonance', 'impatience', 'stupidity', 'dizziness', 'epilepsy', 'shyness', 'depression', 'shadowmadness'},
  kelp       = {'asthma', 'hypochondria', 'healthleech', 'sensitivity', 'clumsiness', 'weakness', 'parasite'},
  lobelia    = {'claustrophobia', 'recklessness', 'agoraphobia', 'loneliness', 'masochism', 'vertigo', 'spiritdisrupt', 'airdisrupt', 'waterdisrupt', 'earthdisrupt', 'firedisrupt'}}) do
  local other_herb_cures = {}

  for _, aff in pairs(herb) do
    other_herb_cures[#other_herb_cures+1] = svo.dict[aff].herb
  end

  for _, aff in pairs(herb) do
    valid['herb_cured_'..aff] = function()
      local result = svo.checkany(svo.dict[aff].herb, unpack(other_herb_cures))

      if not result then return end

      svo.herb_cure = true
      if result.name == aff..'_herb' then
        -- check timers here! should not be less than half of svo.getping(). Check *action*, not affliction timer as well
        if conf.aillusion and not conf.serverside then
          local time, lat = getStopWatchTime(actions[aff..'_herb'].p.actionwatch), svo.getping()

          if time < (lat/2) then
            svo.ignore_illusion("This 'cure' looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
            return
          end
        end

        lifevision.add(actions[aff..'_herb'].p)
      -- with AI on, don't accept cures for affs that we don't have (although do consider check*s)
      elseif (not conf.aillusion or (conf.aillusion and (affs[aff] or affs.unknownany or affs.unknownmental or svo.affsp[aff]))) then
        svo.killaction(svo.dict[result.action_name].herb)
        svo.checkaction(svo.dict[aff].herb, true)
        lifevision.add(svo.dict[aff].herb)
      elseif not sk.sawcuringcommand then
        moveCursor(0, getLineNumber()-1)
        moveCursor(#getCurrentLine(), getLineNumber())
        insertLink(" (i)", '', "Ignored the "..aff.." herb cure, because I don't think we have this affliction atm, and we don't have any unknown affs either - so seems it's an illusion.")
        moveCursorEnd()
      end
    end

  end
end

-- tree touches
for _, tree in pairs({
  tree = {'ablaze', 'addiction', 'aeon', 'agoraphobia', 'anorexia', 'asthma', 'blackout', 'bleeding', 'bound', 'burning', 'claustrophobia', 'clumsiness', 'mildconcussion', 'confusion', 'crippledleftarm', 'crippledleftleg', 'crippledrightarm', 'crippledrightleg', 'darkshade', 'deadening', 'dementia', 'disloyalty', 'dissonance', 'dizziness', 'epilepsy', 'fear', 'galed', 'generosity', 'haemophilia', 'hallucinations', 'healthleech', 'hellsight', 'hypersomnia', 'hypochondria', 'icing', 'illness', 'impatience', 'inlove', 'itching', 'justice', 'laceratedthroat', 'lethargy', 'loneliness', 'madness', 'masochism','pacifism', 'paranoia', 'peace', 'prone', 'recklessness', 'relapsing', 'selarnia', 'sensitivity', 'shyness', 'slashedthroat', 'slickness', 'stupidity', 'stuttering',  'vertigo', 'voided', 'voyria', 'weakness', 'hamstring', 'shivering', 'frozen', 'spiritdisrupt', 'airdisrupt', 'firedisrupt', 'earthdisrupt', 'waterdisrupt', 'depression', 'parasite', 'retribution', 'shadowmadness', 'timeloop', 'degenerate', 'deteriorate'}}) do

  for _, aff in pairs(tree) do
    valid['tree_cured_'..aff] = function()
      svo.checkaction(svo.dict.touchtree.misc)
      if actions.touchtree_misc then
        lifevision.add(actions.touchtree_misc.p, nil, aff)
        tree_cure = true
      end
    end
  end
end

-- humour cures
for _, herb in pairs({
  ginger     = {'melancholichumour', 'cholerichumour', 'phlegmatichumour', 'sanguinehumour'}}) do
  local other_humour_cures = {}
  for _, aff in pairs(herb) do
    other_humour_cures[#other_humour_cures+1] = svo.dict[aff].herb
  end

  for _, aff in pairs(herb) do
    valid['herb_helped_'..aff] = function()
      local result = svo.checkany(svo.dict[aff].herb, unpack(other_humour_cures))

      if not result then return end

      svo.herb_cure = true
      if result.name == aff..'_herb' then
        -- check timers here! should not be less than half of svo.getping(). Check *action*, not affliction timer as well
        if conf.aillusion and not conf.serverside then
          local time, lat = getStopWatchTime(actions[aff..'_herb'].p.actionwatch), svo.getping()

          if time < (lat/2) then
            svo.ignore_illusion("This 'cure' looks fake - finished way too quickly, in "..time.."s, while our ping is "..lat)
            return
          end
        end

        lifevision.add(actions[aff..'_herb'].p, 'cured')
      elseif (not conf.aillusion or (conf.aillusion and (affs[aff] or (affs.unknownany or affs.unknownmental)))) then -- with AI on, don't accept cures for affs that we don't have
        svo.killaction(svo.dict[result.action_name].herb)
        svo.checkaction(svo.dict[aff].herb, true)
        lifevision.add(svo.dict[aff].herb, 'cured')
      else
        moveCursor(0, getLineNumber()-1)
        moveCursor(#getCurrentLine(), getLineNumber())
        insertLink(" (i)", '', "Ignored the "..aff.." herb cure, because I don't think we have this affliction atm, and we don't have any unknown affs either - so seems it's an illusion.")
        moveCursorEnd()
      end
    end

  end
end

-- common ninkharsag code across tree and passive cures
function sk.ninkharsag()
  svo.checkaction(svo.dict.ninkharsag.gone, true)

  if lifevision.l.ninkharsag_gone then
    lifevision.add(actions.ninkharsag_gone.p, 'hiddencures', 1 + (lifevision.l.ninkharsag_gone.arg or 1))
  else
    lifevision.add(actions.ninkharsag_gone.p, 'hiddencures', 1)
  end
end

-- ninkharsag doesn't show us what we cured - so atm, we'll assume it cured nothing (and not clear all our affs either)
function svo.valid.tree_ninkharsag()
  if conf.aillusion and not actions.touchtree_misc then return end

  tree_cure = true
  sk.ninkharsag()
end

function svo.valid.ninkharsag()
  -- ignore if we don't actually have ninkharsag or we aren't getting a passive cure
  if conf.aillusion and not (affs.ninkharsag and svo.passive_cure_paragraph) then return end

  sk.ninkharsag()
end


function svo.valid.touched_treeoffbal()
  svo.checkaction(svo.dict.touchtree.misc)
  if actions.touchtree_misc then
    lifevision.add(actions.touchtree_misc.p, 'offbal')
  end
end

-- special defences
function svo.defs.got_deaf()
  svo.checkaction(svo.dict.waitingondeaf.waitingfor)
  if actions.waitingondeaf_waitingfor then
    lifevision.add(actions.waitingondeaf_waitingfor.p)
  end
end

if svo.haveskillset('shindo') then
function svo.defs.shindo_blind_start()
  svo.checkaction(svo.dict.blind.misc)
  if actions.blind_misc then
    lifevision.add(actions.blind_misc.p)
  end
end
function svo.defs.shindo_blind_got()
  svo.checkaction(svo.dict.waitingonblind.waitingfor)
  if actions.waitingonblind_waitingfor then
    lifevision.add(actions.waitingonblind_waitingfor.p)
  end
end

function svo.defs.shindo_deaf_start()
  svo.checkaction(svo.dict.deaf.misc)
  if actions.deaf_misc then
    lifevision.add(actions.deaf_misc.p)
  end
end
end
if svo.haveskillset('kaido') then
function svo.defs.kaido_blind_start()
  svo.checkaction(svo.dict.blind.misc)
  if actions.blind_misc then
    lifevision.add(actions.blind_misc.p)
  end
end
function svo.defs.kaido_blind_got()
  svo.checkaction(svo.dict.waitingonblind.waitingfor)
  if actions.waitingonblind_waitingfor then
    lifevision.add(actions.waitingonblind_waitingfor.p)
  end
end

function svo.defs.kaido_deaf_start()
  svo.checkaction(svo.dict.deaf.misc)
  if actions.deaf_misc then
    lifevision.add(actions.deaf_misc.p)
  end
end
end

function svo.defs.got_blind()
  local r = svo.checkany(svo.dict.blind.herb)

  if not r then return end

  svo.herb_cure = true
  lifevision.add(actions[r.name].p)
end

function svo.defs.already_blind()
  local r = svo.checkany(svo.dict.blind.herb)

  if not r then return end

  svo.herb_cure = true
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'noeffect')
  end
end

-- a function to properly assign and ignore missing enchants - works with svo's "do all enchants at once" feature.
function svo.missing_enchant()
  -- find out which actions are we doing, sort them - and see which one is missing (the top one)
  local t = {}
  if actions.magicresist_physical then t[#t+1] = 'magicresist' end
  if actions.fireresist_physical then t[#t+1] = 'fireresist' end
  if actions.coldresist_physical then t[#t+1] = 'coldresist' end
  if actions.electricresist_physical then t[#t+1] = 'electricresist' end

  if #t == 0 then return end

  t = svo.prio.sortlist(t, 'physical')

  local result = t[1]

  if not svo.ignore[result] then
    svo.setignore(result, { because = "you were missing the enchantment" })

    echo'\n' svo.echofn("Looks like you don't have %s anymore - I'll put it on ignore then, take it off later with '", result)

    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true)

    echoLink("vignore "..result, 'svo.ignore.'..result..' = nil svo.echof("Removed '..result..' from the ignore list (will be doing it now).")', 'Click here take '..result..' off the ignore list', true)
    setUnderline(false)
    echo"'.\n"

    svo.killaction(svo.dict[result].physical)
  end
end

-- a function to stop any light* actions and put all current non-artefact pipes on ignore
function svo.missing_tinderbox()
  -- find which pipes were we lighting and kill those actions. We we were lighting at least one, figure out which pipes are non-arty, get a list, put them on ignore and say which ones we've added to ignore now

  local gotaction
  if actions.lightvalerian_physical then
    svo.killaction(svo.dict.lightvalerian.physical); gotaction = true
  end
  if actions.lightelm_physical then
    svo.killaction(svo.dict.lightelm.physical); gotaction = true
  end
  if actions.lightskullcap_physical then
    svo.killaction(svo.dict.lightskullcap.physical); gotaction = true
  end

  -- if we weren't lighting - then... this might not be real!
  if not gotaction then return end

  -- find out which pipes are not artefact & ignore
  local realthing, assumedname = {}, {}
  for id = 1, #pipes.pnames do
    local herb, pipe = pipes.pnames[id], pipes[pipes.pnames[id]]
    if not pipe.arty and not svo.ignore['light'..herb] then
      realthing[#realthing+1] = 'light'..herb
      assumedname[#assumedname+1] = pipe.filledwith
      svo.setignore('light'..herb, { because = "you were missing a tinderbox" })
    end
  end

  if realthing[1] then
    echo"\n" svo.echof("Looks like you don't have a tinderbox! I've put non-artefact pipes - %s on the ignore list (under the names of %s). To unignore them, check vshow ignore.", svo.concatand(assumedname), svo.concatand(realthing))
  end
end

function svo.valid.restoration_noeffect()
  local r = svo.checkany(
  svo.dict.curingheartseed.waitingfor, svo.dict.curingmangledleftleg.waitingfor, svo.dict.curingmangledrightleg.waitingfor, svo.dict.curingmangledrightarm.waitingfor, svo.dict.curingmangledleftarm.waitingfor, svo.dict.curingmutilatedrightarm.waitingfor, svo.dict.curingmutilatedleftarm.waitingfor, svo.dict.curingparestolegs.waitingfor, svo.dict.curingmildtrauma.waitingfor, svo.dict.curingserioustrauma.waitingfor, svo.dict.curingmutilatedrightleg.waitingfor, svo.dict.curingmutilatedleftleg.waitingfor, svo.dict.curingseriousconcussion.waitingfor, svo.dict.curingmildconcussion.waitingfor, svo.dict.curinglaceratedthroat.waitingfor)

  if not r then return end

  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'noeffect')
  end
end

function svo.valid.ate_moss()
  local result = svo.checkany(svo.dict.healhealth.moss, svo.dict.healmana.moss)

  if not result then return end

  svo.herb_cure = true
  lifevision.add(actions[result.name].p)
end
valid.generic_ate_moss = valid.ate_moss

function svo.valid.noeffect_moss()
  local r = svo.checkany(svo.dict.healhealth.moss, svo.dict.healmana.moss)
  if not r then return end

  svo.herb_cure = true
  if not lifevision.l[r.name] then
    lifevision.add(actions[r.name].p, 'noeffect')
  end
end

function svo.valid.got_waterbubble()
  svo.checkaction(svo.dict.waterbubble.herb)

  svo.herb_cure = true
  if actions.waterbubble_herb then
    lifevision.add(actions.waterbubble_herb.p)
  end
end

function svo.defs.gotherb_myrrh()
  svo.checkaction(svo.dict.myrrh.herb)

  svo.herb_cure = true
  if actions.myrrh_herb then
    lifevision.add(actions.myrrh_herb.p)
  end
end

function svo.defs.gotherb_kola()
  svo.checkaction(svo.dict.kola.herb)

  svo.herb_cure = true
  if actions.kola_herb then
    lifevision.add(actions.kola_herb.p)
  end
end

function svo.defs.gotherb_deathsight()
  svo.checkaction(svo.dict.deathsight.herb)

  svo.herb_cure = true
  if actions.deathsight_herb then
    lifevision.add(actions.deathsight_herb.p)
  end
end

function svo.defs.gotskill_deathsight()
  svo.checkaction(svo.dict.deathsight.physical)
  if actions.deathsight_physical then
    lifevision.add(actions.deathsight_physical.p)
  end
end

function svo.defs.gotherb_thirdeye()
  svo.checkaction(svo.dict.thirdeye.herb)

  svo.herb_cure = true
  if actions.thirdeye_herb then
    lifevision.add(actions.thirdeye_herb.p)
  end
end

function svo.defs.gotskill_thirdeye()
  svo.checkaction(svo.dict.thirdeye.misc)
  if actions.thirdeye_misc then
    lifevision.add(actions.thirdeye_misc.p)
  end
end

function svo.defs.gotherb_insomnia()
  svo.checkaction(svo.dict.insomnia.herb)

  svo.herb_cure = true
  if actions.insomnia_herb then
    lifevision.add(actions.insomnia_herb.p)
  end
end

function svo.defs.gotskill_insomnia()
  if actions.checkhypersomnia_misc then
    lifevision.add(actions.checkhypersomnia_misc.p, 'onclear')
  end


  svo.checkaction(svo.dict.insomnia.misc)
  if actions.insomnia_misc then
    lifevision.add(actions.insomnia_misc.p)
  end
end

function svo.valid.generic_insomnia()
  local r = svo.checkany(svo.dict.insomnia.herb, svo.dict.insomnia.misc)

  if not r then return end

  svo.herb_cure = true
  lifevision.add(actions[r.name].p)
end

function svo.valid.insomnia_hypersomnia()
  local r = svo.checkany(svo.dict.insomnia.herb, svo.dict.insomnia.misc)

  if r then
    svo.herb_cure = true
    lifevision.add(actions[r.name].p, 'hypersomnia')
  elseif actions.checkhypersomnia_misc then
    lifevision.add(actions.checkhypersomnia_misc.p, 'hypersomnia')
    decho(svo.getDefaultColor().." (hypersomnia confirmed)")
  elseif not conf.aillusion then
    valid.simplehypersomnia()
  elseif not affs.hypersomnia then
    svo.checkaction(svo.dict.checkhypersomnia.aff, true)
    lifevision.add(actions.checkhypersomnia_aff.p)
  end
end

function svo.defs.salve_got_caloric()
  local r = svo.checkany(svo.dict.frozen.salve, svo.dict.shivering.salve, svo.dict.caloric.salve)

  if not r then return end

  svo.apply_cure = true
  local hypothermia = svo.find_until_last_paragraph("You are far too frozen to relieve your shivers.", 'exact')
  lifevision.add(actions[r.name].p, 'gotcaloricdef', hypothermia)
end

function svo.defs.salve_got_mass()
  svo.checkaction(svo.dict.mass.salve)
  svo.apply_cure = true
  if actions.mass_salve then
    lifevision.add(actions.mass_salve.p)
  end
end


local generic_cures_data = {
  'ablaze', 'addiction', 'aeon', 'agoraphobia', 'anorexia', 'asthma', 'blackout', 'bleeding', 'bound', 'burning', 'claustrophobia', 'clumsiness', 'mildconcussion', 'confusion', 'crippledleftarm', 'crippledleftleg', 'crippledrightarm', 'crippledrightleg', 'darkshade', 'deadening', 'dementia', 'disloyalty', 'disrupt', 'dissonance', 'dizziness', 'epilepsy', 'fear', 'galed', 'generosity', 'haemophilia', 'hallucinations', 'healthleech', 'heartseed', 'hellsight', 'hypersomnia', 'hypochondria', 'icing', 'illness', 'impale', 'impatience', 'inlove', 'inquisition', 'itching', 'justice', 'laceratedthroat', 'lethargy', 'loneliness', 'lovers', 'madness', 'mangledleftarm', 'mangledleftleg', 'mangledrightarm', 'mangledrightleg', 'masochism', 'mildtrauma', 'mutilatedleftarm', 'mutilatedleftleg', 'mutilatedrightarm', 'mutilatedrightleg', 'pacifism', 'paralysis', 'paranoia', 'peace', 'prone', 'recklessness', 'relapsing', 'roped', 'selarnia', 'sensitivity', 'seriousconcussion', 'serioustrauma', 'shyness', 'slashedthroat', 'slickness', 'stun', 'stupidity', 'stuttering', 'transfixed', 'unknownany', 'unknowncrippledarm', 'unknowncrippledleg', 'unknownmental', 'vertigo', 'voided', 'voyria', 'weakness', 'webbed', 'healhealth', 'healmana', 'hamstring', 'shivering', 'frozen', 'hallucinations', 'stain', 'rixil', 'palpatar', 'cadmus', 'hecate', 'spiritdisrupt', 'airdisrupt', 'firedisrupt', 'earthdisrupt', 'waterdisrupt', 'depression', 'parasite', 'retribution', 'shadowmadness', 'timeloop', 'degenerate', 'deteriorate', 'hatred'
}

for i = 1, #generic_cures_data do
  local aff = generic_cures_data[i]

  valid['generic_'..aff] = function ()

    -- passive curing...
    if svo.passive_cure_paragraph and svo.dict[aff].gone then
      svo.checkaction(svo.dict[aff].gone, true)
      if actions[aff .. '_gone'] then
        lifevision.add(actions[aff .. '_gone'].p)
      end
      return
    end

    -- ... or something we caused.
    if svo.actions_performed[aff] then
      lifevision.add(actions[svo.actions_performed[aff].name].p)

    -- if it's not something we were directly doing, try to link by balances
    else
      local result

      for j,k in actions:iter() do
        if not k then
          svo.debugf("[svo error]: no k here, j is %s. Actions list:", tostring(j))
          for m,n in actions:iter() do
            svo.debugf("%s - %s", tostring(m), tostring(n))
          end
        end
        if k and k.p.balance ~= 'waitingfor' and k.p.balance ~= 'aff' and svo.dict[aff][k.p.balance] then result = k.p break end
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

      svo.debugf("Result is %s", tostring(result.action_name))
      svo.killaction(svo.dict[result.action_name][result.balance])

      svo.checkaction(svo.dict[aff][result.balance], true)
      lifevision.add(svo.dict[aff][result.balance])
    end
  end
end

svo.disable_generic_trigs = function ()
  disableTrigger("General cures")
  enableTrigger('Ate')
  enableTrigger('Sip')
  enableTrigger('Applied')
  enableTrigger('Smoke')
  enableTrigger("Focus mind")
end

svo.enable_generic_trigs = function ()
  enableTrigger("General cures")
  disableTrigger('Ate')
  disableTrigger('Sip')
  disableTrigger('Applied')
  disableTrigger('Smoke')
  disableTrigger("Focus mind")
end

svo.check_generics = function ()
  if affs.blackout and not svo.generics_enabled then
    svo.generics_enabled = true
    svo.generics_enabled_for_blackout = true
    svo.enable_generic_trigs()
    echo("\n")
    svo.echof("Enabled blackout curing.")
  elseif svo.generics_enabled and svo.generics_enabled_for_blackout and not affs.blackout and not actions.blackout_aff then
    svo.generics_enabled_for_blackout, svo.generics_enabled = false, false
    svo.disable_generic_trigs()
    echo("\n")
    svo.echof("Out of blackout, disabled blackout curing.")
  elseif svo.passive_cure_paragraph and not svo.generics_enabled and not svo.generics_enabled_for_passive then
    svo.generics_enabled_for_passive, svo.generics_enabled = true, true
    svo.enable_generic_trigs ()
  elseif not svo.passive_cure_paragraph and svo.generics_enabled and svo.generics_enabled_for_passive then
    svo.generics_enabled_for_passive, svo.generics_enabled = false, false
    svo.disable_generic_trigs ()
  end
end
svo.disable_generic_trigs()
svo.check_generics()

signals.systemstart:connect(function ()
  disableTrigger("General cures")
  if conf.aillusion then enableTrigger("Pre-parse anti-illusion")
  else disableTrigger("Pre-parse anti-illusion") end
end)

-- passive cures
function svo.valid.passive_cure()
  local affn = table.size(affs)
  svo.passive_cure_paragraph = true
  svo.check_generics()
  sk.onprompt_beforeaction_add("check for unknowns", function ()
    -- if the counts are the same, then we cured something we didn't know about
    -- this does not need lifevision validation, being done post-fact
    if affn == table.size(affs) then
      if affs.unknownmental then
        svo.dict.unknownmental.count = svo.dict.unknownmental.count - 1
        if svo.dict.unknownmental.count <= 0 then svo.rmaff('unknownmental'); svo.dict.unknownmental.count = 0
        else svo.updateaffcount(svo.dict.unknownmental) end
      elseif affs.unknownany then
        svo.dict.unknownany.count = svo.dict.unknownany.count - 1
        if svo.dict.unknownany.count <= 0 then svo.rmaff('unknownany'); svo.dict.unknownany.count = 0 else
          svo.updateaffcount(svo.dict.unknownany)
        end
      end
    end
  end)
  sk.onprompt_beforeaction_add("check generics", function () svo.passive_cure_paragraph = false; svo.check_generics() end)
  signals.after_lifevision_processing:unblock(cnrl.checkwarning)
end

function svo.valid.underwater_nopear()
  if not conf.aillusion then svo.eat(svo.dict.waterbubble.herb) else
    local oldhealth = stats.currenthealth
    sk.onprompt_beforeaction_add("check for pear damage", function ()
      if stats.currenthealth < oldhealth then
        svo.eat(svo.dict.waterbubble.herb)
      end
    end)
  end
end

-- the voided timer at the moment account for multiple pommelstrikes occuring
function svo.valid.pommelstrike()
end

function svo.valid.dragonflex()
  svo.checkaction (svo.dict.dragonflex.misc)
  if actions.dragonflex_misc then
    lifevision.add(actions.dragonflex_misc.p)
  end
end

function svo.valid.dwinnu()
  svo.checkaction (svo.dict.dwinnu.misc)
  if actions.dwinnu_misc then
    lifevision.add(actions.dwinnu_misc.p)
  end
end

function svo.valid.got_blind()
  sk.onprompt_beforeaction_add('hypochondria_blind', function ()
    if not affs.blindaff and not defs.blind then
      valid.simplehypochondria()
    end
  end)
end

function svo.valid.venom_crippledrightleg()
  if svo.paragraph_length ~= 1 then
    valid.simplecrippledrightleg()
  else
    sk.hypochondria_symptom()
  end
end
function svo.valid.venom_crippledleftleg()
  if svo.paragraph_length ~= 1 then
    valid.simplecrippledleftleg()
  else
    sk.hypochondria_symptom()
  end
end
-- might not be hypochondria, but plague vibe
function svo.valid.proper_clumsiness()
    valid.simpleclumsiness()
end
function svo.valid.proper_weakness()
  if svo.paragraph_length ~= 1 then
    valid.simpleweakness()
  else
    sk.hypochondria_symptom()
  end
end
function svo.valid.proper_disloyalty()
  if svo.paragraph_length ~= 1 then
    valid.simpledisloyalty()
  else
    sk.hypochondria_symptom()
  end
end
function svo.valid.proper_illness()
  if svo.paragraph_length ~= 1 then
    valid.simpleillness()
  else
    sk.hypochondria_symptom()
  end
end
function svo.valid.proper_lethargy()
  if svo.paragraph_length ~= 1 or affs.torntendons or svo.find_until_last_paragraph("You stumble as you are afflicted with", 'substring') then
    valid.simplelethargy()
  else
    sk.hypochondria_symptom()
  end
end
-- skullfractures makes the affliction come back on its own
function svo.valid.proper_addiction()
  if svo.paragraph_length ~= 1 or affs.skullfractures then
    valid.simpleaddiction()
  else
    sk.hypochondria_symptom()
  end
end
function svo.valid.proper_anorexia()
  if not conf.aillusion then
    if svo.paragraph_length ~= 1 or svo.find_until_last_paragraph("With a characteristic Jaziran trill", 'substring') then
      valid.simpleanorexia()
    else
      sk.hypochondria_symptom()
    end
  else
    svo.checkaction(svo.dict.checkanorexia.aff, true)
    lifevision.add(actions.checkanorexia_aff.p)
  end
end

-- traps can give this
function svo.valid.proper_slickness()
  if svo.paragraph_length ~= 1 then
    valid.simpleslickness()
  else
    sk.hypochondria_symptom()
  end
end
function svo.valid.proper_recklessness(attacktype)
  if not conf.aillusion then
    valid.simplerecklessness()
  else
    svo.checkaction(svo.dict.recklessness.aff, true)
    if actions.recklessness_aff then
      lifevision.add(actions.recklessness_aff.p, nil, {oldhp = stats.currenthealth, oldmana = stats.currentmana, attacktype = attacktype, atline = getLastLineNumber('main')})
    end
  end
end
function svo.valid.proper_recklessness2(attacktype)
  if not conf.aillusion then
    valid.simplerecklessness()
  else
    svo.checkaction(svo.dict.recklessness.aff, true)
    if actions.recklessness_aff then
      if svo.find_until_last_paragraph('wracks', 'substring') or svo.find_until_last_paragraph("points an imperious finger at you", 'substring') or svo.find_until_last_paragraph("A heavy burden descends upon your soul as", 'substring') or svo.find_until_last_paragraph("stares at you, giving you the evil eye", 'substring') or svo.find_until_last_paragraph("glowers at you with a look of repressed disgust before making a slight gesture toward you.", 'substring') or svo.find_until_last_paragraph("smashing your temple with a backhanded blow", 'substring') then
        lifevision.add(actions.recklessness_aff.p, nil, {oldhp = stats.currenthealth, attacktype = attacktype, atline = getLastLineNumber('main')})
      else
        lifevision.add(actions.recklessness_aff.p, nil, {oldhp = stats.currenthealth, attacktype = attacktype, atline = getLastLineNumber('main')}, 1)
      end
    end
  end
end
function svo.valid.venom_crippledleftarm()
  if svo.paragraph_length ~= 1 then
    valid.simplecrippledleftarm()
  else
    sk.hypochondria_symptom()
  end
end
function svo.valid.venom_crippledrightarm()
  if svo.paragraph_length ~= 1 then
    valid.simplecrippledrightarm()
  else
    sk.hypochondria_symptom()
  end
end

function svo.valid.lost_arena()
  echo"\n"
  svo.echof("I'm sorry =(")

  svo.reset.affs()
  svo.reset.general()
  svo.reset.defs()
end

function svo.valid.lost_ffa()
  local oldroom = (atcp.RoomNum or gmcp.Room.Info.num)
  sk.onprompt_beforeaction_add('arena_death',
    function ()
      if oldroom ~= (atcp.RoomNum or gmcp.Room.Info.num) then
        svo.reset.affs()
        svo.reset.general()
        svo.reset.defs()
      end
    end)
end

function svo.valid.won_arena()
  echo"\n"
  if math.random(10) == 1 then svo.echof("Winnar!")
  else svo.echof("You won!") end

  -- rebounding coming up gets killed
  if actions.waitingonrebounding_waitingfor then
    svo.killaction(svo.dict.waitingonrebounding.waitingfor)
  end

  svo.reset.affs()

  -- blind/insomnia/deaf get svo.reset too
  defences.lost('blind') defences.lost('deaf') defences.lost('insomnia')
end

if svo.haveskillset('necromancy') then
  function svo.valid.soulcaged()
    svo.reset.affs()
    svo.reset.general()
    svo.reset.defs()
    if type(conf.burstmode) == 'string' then
      echo"\n"svo.echof("Auto-switching to %s defences mode.", conf.burstmode)
      defs.switch(conf.burstmode, false)
    end
  end
elseif svo.haveskillset('occultism') then
  function svo.valid.transmogged()
    svo.reset.affs()
    svo.reset.general()
    svo.reset.defs()
    if type(conf.burstmode) == 'string' then
      echo"\n"svo.echof("Auto-switching to %s defences mode.", conf.burstmode)
      defs.switch(conf.burstmode, false)
    end
  end
else
  function svo.valid.soulcaged() end
  function svo.valid.transmogged() end
end

function svo.valid.died()
  if line == "Your starburst tattoo flares as the world is momentarily tinted red." then
    sk.onprompt_beforeaction_add('death',
      function ()
        if affs.recklessness or (stats.currenthealth == stats.maxhealth and stats.currentmana == stats.maxmana) then
          svo.reset.affs()
          svo.reset.general()
          svo.reset.defs()
          rift.resetinvcontents()
          echo "\n" svo.echof("We hit starburst!")
          signals.before_prompt_processing:unblock(valid.check_life)
          if type(conf.burstmode) == 'string' then
            svo.echof("Auto-switching to %s defences mode.", conf.burstmode)
            defs.switch(conf.burstmode, false)
          end

          -- rebounding coming up gets cancelled
          if actions.waitingonrebounding_waitingfor then svo.killaction(svo.dict.waitingonrebounding.waitingfor) end

          raiseEvent("svo died", 'starburst')
        end
      end)
  elseif not conf.paused then
    sk.onprompt_beforeaction_add('death',
      function ()
        if affs.recklessness or stats.currenthealth == 0 then
          svo.reset.affs()
          svo.reset.general()
          svo.reset.defs()
          rift.resetinvcontents()

          -- rebounding coming up gets cancelled
          if actions.waitingonrebounding_waitingfor then svo.killaction(svo.dict.waitingonrebounding.waitingfor) end

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
            echo"\n"svo.echof("We died.") end
          conf.paused = true
          signals.before_prompt_processing:unblock(valid.check_life)
          raiseEvent("svo died")
          raiseEvent("svo config changed", 'paused')
        elseif stats.currenthealth == stats.maxhealth and stats.currentmana == stats.maxmana and svo.find_until_last_paragraph("Your starburst tattoo flares as the world is momentarily tinted red.", 'exact') then -- in case something else came between "you died" and starburst
          svo.reset.affs()
          svo.reset.general()
          svo.reset.defs()
          rift.resetinvcontents()

          -- rebounding coming up gets cancelled
          if actions.waitingonrebounding_waitingfor then svo.killaction(svo.dict.waitingonrebounding.waitingfor) end

          echo "\n" svo.echof("We hit starburst!")
          signals.before_prompt_processing:unblock(valid.check_life)
          if type(conf.burstmode) == 'string' then
            svo.echof("Auto-switching to %s defences mode.", conf.burstmode)
            defs.switch(conf.burstmode, false)
          end
          raiseEvent("svo died", 'starburst')
        end
      end)
  end
end

function svo.valid.check_life()
  if stats.currenthealth ~= 0 then
    echo"\n" svo.echof("Welcome back to life! System unpaused.")
    conf.paused = false
    raiseEvent("svo config changed", 'paused')
    signals.before_prompt_processing:block(valid.check_life)
  end
end
signals.before_prompt_processing:connect(valid.check_life)
signals.before_prompt_processing:block(valid.check_life)


function svo.valid.check_recklessness()
  local vitals = gmcp.Char.Vitals

  -- check against GMCP, as Svof modifies them
  if affs.recklessness and (vitals.mp < vitals.maxmp or vitals.hp < vitals.maxhp) then
    svo.rmaff('recklessness')
  end
end
signals.before_prompt_processing:connect(valid.check_recklessness)
-- toggled inside svo.dict
signals.before_prompt_processing:block(valid.check_recklessness)


function svo.valid.limb_hit(which, attacktype)
  if not svo.sp_limbs[which] then return end

  me.lasthitlimb = which

  if selectString(which, 1) ~= -1 then
    fg(conf.highlightparryfg)
    bg(conf.highlightparrybg)
    deselect()
    resetFormat()
  else -- things like BM slashes don't say the limb, but say the plural name of it - legs, arms.
    local plural = which:sub(-3)..'s'

    if selectString(plural, 1) ~= -1 then
      fg(conf.highlightparryfg)
      bg(conf.highlightparrybg)
      deselect()
      resetFormat()
    end
  end

  signals.after_lifevision_processing:unblock(svo.sp_checksp)
  signals.limbhit:emit(which, attacktype)
  raiseEvent("svo limb hit", which, attacktype)
end

local function saw_tekura_in_paragraph()
  return
    -- punches
    svo.find_until_last_paragraph("balls up one fist and hammerfists you", 'substring') or
    svo.find_until_last_paragraph("forms a spear hand and stabs out at you", 'substring') or
    svo.find_until_last_paragraph("launches a powerful uppercut at you", 'substring') or
    svo.find_until_last_paragraph("unleashes a powerful hook towards you", 'substring') or

    -- kicks
    svo.find_until_last_paragraph("lets fly at you with a snap kick", 'substring') or
    svo.find_until_last_paragraph("towards you with a lightning-fast moon kick", 'substring') or
    svo.find_until_last_paragraph("leg high and scythes downwards at you", 'substring') or
    svo.find_until_last_paragraph("pumps out at you with a powerful side kick", 'substring') or
    svo.find_until_last_paragraph("spins into the air and throws a whirlwind kick towards you", 'substring') or
    svo.find_until_last_paragraph("The blow sends a shock of pain through you, your muscles reflexively locking in response.", 'exact')
end

-- count up how much tekura stuff have we seen in the paragraph so far. If more than two things, then count this as a combo.
local function all_in_one_tekura()
  local c =
    -- punches
    svo.count_until_last_paragraph("balls up one fist and hammerfists you", 'substring') +
    svo.count_until_last_paragraph("forms a spear hand and stabs out at you", 'substring') +
    svo.count_until_last_paragraph("launches a powerful uppercut at you", 'substring') +
    svo.count_until_last_paragraph("unleashes a powerful hook towards you", 'substring') +

    -- kicks
    svo.count_until_last_paragraph("lets fly at you with a snap kick", 'substring') +
    svo.count_until_last_paragraph("drops to the floor and sweeps his legs round at you.", 'substring') +
    svo.count_until_last_paragraph("drops to the floor and sweeps her legs round at you.", 'substring') +
    svo.count_until_last_paragraph("knocks your legs out from under you and sends you sprawling to the floor.", 'substring') +
    svo.count_until_last_paragraph("towards you with a lightning-fast moon kick", 'substring') +
    svo.count_until_last_paragraph("leg high and scythes downwards at you", 'substring') +
    svo.count_until_last_paragraph("pumps out at you with a powerful side kick", 'substring') +
    svo.count_until_last_paragraph("spins into the air and throws a whirlwind kick towards you", 'substring') +
    svo.count_until_last_paragraph("The blow sends a shock of pain through you, your muscles reflexively locking in response.", 'exact')

    return (c >= 2) and true or false
end


for _,name in ipairs({'rightarm', 'leftarm', 'leftleg', 'rightleg'}) do
  for _, status in ipairs({'mangled', 'mutilated'}) do
    valid['proper_'..status..name] = function ()
      -- idea: see if any previous lines contain the limb name; it would have to be included in the msg
      if conf.aillusion then
        local limb = string.format("%s %s", string.match(name, "(%w+)(%w%w%w)"))
        local plural = name:sub(-3)..'s'

        -- last line doesn't work with stuff like bm breaks, where it is limb\anothermsg\actualbreak. So go until the prompt.
        local previouslinenumber, currentlinenumber = svo.lastpromptnumber+1, getLastLineNumber('main')

        -- workaround for deleteLine() making svo.lastpromptnumber's tracking get invalidated
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
          if svo.find_until_last_paragraph("^Spinning to the right as s?he draws %w+ %w+ from its sheath, %w+ delivers a precise slash across your arms%.$", 'pattern') then
            valid['simple'..status..name]()
          elseif saw_tekura_in_paragraph() then
            svo.checkaction(svo.dict[status..name].aff, true)
            lifevision.add(actions[status..name..'_aff'].p, 'tekura', stats.currenthealth)
          else
            svo.checkaction(svo.dict[status..name].aff, true)
            lifevision.add(actions[status..name..'_aff'].p, nil, stats.currenthealth)
          end

          tempLineTrigger(1,1, [[
            if line == "Your shield completely absorbs the damage." then
              svo.valid.simple]]..status..name..[[() end]]
          )
        else
          svo.debugf("Didn't find limb (%s) or plural (%s) in combined (%s)", limb, plural, combined)
        end
      else -- anti-illusion off
        -- when we see a tekura combo, try to add all the mangles at the end of it, so the priorities take effect - instead of being dictated by first-hit
        if saw_tekura_in_paragraph() then

          -- if this is an all-in-one combo, don't queue up the hits
          if all_in_one_tekura() then
            svo.checkaction(svo.dict[status..name].aff, true)
            lifevision.add(actions[status..name..'_aff'].p, nil, stats.currenthealth)

            -- clear a delayed break if there was one
            if sk.delaying_break then
              killTimer(sk.delaying_break); sk.delaying_break = nil
              for _, aff in ipairs(sk.tekura_mangles) do
                svo.addaffdict(svo.dict[aff])
              end
              sk.tekura_mangles = nil
            end
          else
            -- not an all-in-one combo, or the first hit of it
            if not sk.delaying_break then
              sk.delaying_break = tempTimer(getNetworkLatency() + conf.tekura_delay, function() -- from the first hit, it's approximately getNetworkLatency() time until the second - add the conf.tekura_delay to allow for variation in ping
                sk.delaying_break = nil

                for _, aff in ipairs(sk.tekura_mangles) do
                  svo.addaffdict(svo.dict[aff])
                end
                sk.tekura_mangles = nil
                signals.after_lifevision_processing:unblock(cnrl.checkwarning)
                signals.canoutr:emit()
                svo.make_gnomes_work()
              end)
            end

            sk.tekura_mangles = sk.tekura_mangles or {}
            sk.tekura_mangles[#sk.tekura_mangles+1] = status..name
          end
        else
          svo.checkaction(svo.dict[status..name].aff, true)
          lifevision.add(actions[status..name..'_aff'].p, nil, stats.currenthealth)
        end
      end
    end
  end
end

for _, name in ipairs({'serioustrauma', 'mildtrauma', 'mildconcussion', 'seriousconcussion'}) do
  valid['proper_'..name] = function ()
    svo.checkaction(svo.dict[name].aff, true)
    lifevision.add(actions[name..'_aff'].p, nil, stats.currenthealth)
    tempLineTrigger(1,1, [[
      if line == "Your shield completely absorbs the damage." then
        svo.valid.simple]]..name..[[()
      end
    ]])
  end
end

valid.generic_burn = function (number)
  svo.assert(not number or tonumber(number), "svo.valid.simpleburn: how many removals do you want to do? Must be a number")

  svo.checkaction(svo.dict.ablaze.gone, true)

  if lifevision.l.ablaze_gone then
    lifevision.add(actions.ablaze_gone.p, 'generic_reducelevel', (number or 1) +(lifevision.l.ablaze_gone.arg or 1))
  else
    lifevision.add(actions.ablaze_gone.p, 'generic_reducelevel', (number or 1))
  end
end

valid.low_willpower = sk.checkwillpower

if svo.haveskillset('healing') then
  sk.check_emptyhealingheal = function ()
    if sk.currenthealinghealcount+1 == getLineCount() then
      lifevision.add(actions.usehealing_misc.p, 'empty')
    else
      lifevision.add(actions.usehealing_misc.p)
    end

    signals.before_prompt_processing:disconnect(sk.check_emptyhealingheal)
  end

  valid.healercure = function ()
    svo.checkaction(svo.dict.usehealing.misc)
    if actions.usehealing_misc then
      sk.currenthealinghealcount = getLineCount()
      signals.before_prompt_processing:connect(sk.check_emptyhealingheal)
      valid.passive_cure()
    end
  end


  valid.emptyheal = function ()
    if actions.usehealing_misc then
      lifevision.add(actions.usehealing_misc.p, 'empty')
    end
  end

  valid.healing_cured_insomnia = function ()
    svo.checkaction(svo.dict.usehealing.misc)
    if actions.usehealing_misc then
      defs.lost_insomnia()
      lifevision.add(actions.usehealing_misc.p, 'empty')
    end
  end

  -- valid.healercure = function ()
  --   svo.checkaction(svo.dict.usehealing.misc)
  --   if actions.usehealing_misc then
  --     valid.passive_cure()
  --     lifevision.add(actions.usehealing_misc.p)
  --   end
  -- end

  valid.nohealbalance = function ()
    svo.checkaction(svo.dict.usehealing.misc)
    if actions.usehealing_misc then
      lifevision.add(actions.usehealing_misc.p, 'nobalance')
    end
  end

  valid.bedevilheal = function ()
    svo.checkaction(svo.dict.usehealing.misc)
    if actions.usehealing_misc then
      lifevision.add(actions.usehealing_misc.p, 'bedevilheal')
    end
  end
else
  valid.healercure = function () end
  valid.healing_cured_insomnia = valid.healercure
  valid.nohealbalance = valid.healercure
  valid.bedevilheal = valid.healercure
end

if svo.haveskillset('chivalry') then
  sk.check_emptyrage = function ()
    if sk.currentragecount+1 == getLineCount() then
      lifevision.add(actions.rage_misc.p, 'empty')
    else
      lifevision.add(actions.rage_misc.p)
    end

    signals.before_prompt_processing:disconnect(sk.check_emptyrage)
  end

  valid.ragecure = function ()
    svo.checkaction(svo.dict.rage.misc)
    if actions.rage_misc then
      sk.currentragecount = getLineCount()
      signals.before_prompt_processing:connect(sk.check_emptyrage)
      valid.passive_cure()
    end
  end
else
  valid.ragecure = function() end
end

if svo.haveskillset('kaido') then
  valid.transmuted = function ()
    -- always check transmute so we can count how many we did (to cancel timer if we can)
    svo.checkaction(svo.dict.transmute.physical, true)
    lifevision.add(actions.transmute_physical.p)
  end
else
  valid.transmuted = function() end
end

-- possibly suspectible to sylvans double-doing it, or a sylvan doing & illusioning it?
function svo.valid.sylvan_heartseed()
  if not conf.aillusion or affs.mildtrauma then
    valid.simpleheartseed()
  else
    tempTimer(5, function () sk.heartseed2window = true end)
    tempTimer(10, function () sk.heartseed2window = false end)
  end
end

function svo.valid.sylvan_heartseed2()
  if not affs.heartseed and (not conf.aillusion or sk.heartseed2window) then
    valid.simpleheartseed()
  end
end

function svo.valid.sylvan_eclipse()
  sk.sylvan_eclipse = true
  tempTimer(10, function () sk.sylvan_eclipse = nil end)
end

function svo.valid.sylvan_lacerate1()
  svo.checkaction(svo.dict.slashedthroat.aff, true)
  lifevision.add(actions.slashedthroat_aff.p, 'sylvanhit', stats.currenthealth)
end

function svo.valid.sylvan_lacerate2()
  svo.checkaction(svo.dict.laceratedthroat.aff, true)
  lifevision.add(actions.laceratedthroat_aff.p, 'sylvanhit', stats.currenthealth)
end

function svo.connected()
  signals.connected:emit()
end

function svo.valid.stripped_caloric()
  svo.checkaction(svo.dict.caloric.gone, true)
  if actions.unknownany_aff then
    lifevision.add(actions.caloric_gone.p, nil, 'unknownany')
  elseif actions.unknownmental_aff then
    lifevision.add(actions.caloric_gone.p, nil, 'unknownmental')
  else
    lifevision.add(actions.caloric_gone.p)
  end
end

function svo.valid.stripped_insomnia()
  svo.checkaction(svo.dict.insomnia.gone, true)
  if actions.unknownany_aff then
    lifevision.add(actions.insomnia_gone.p, nil, 'unknownany')
  elseif actions.unknownmental_aff then
    lifevision.add(actions.insomnia_gone.p, nil, 'unknownmental')
  else
    lifevision.add(actions.insomnia_gone.p)
  end
end

if svo.haveskillset('elementalism') or svo.haveskillset('healing') then
  function svo.valid.lacking_channels()
    if svo.usingbal('physical') then
      defs.lost_simultaneity()
    end
  end
else
  valid.lacking_channels = function() end
end

function svo.valid.bubbleout()
  if not conf.aillusion then svo.eat(svo.dict.waterbubble.herb) end
end

-- check if we're the ones who got hit with it
function svo.valid.aeon_card()
  if not affs.blackout then return end

  -- if sk.aeon_thrown then killTimer(sk.aeon_thrown) end
  -- sk.aeon_thrown = tempTimer(4, function() sk.aeon_thrown = nil end)

  -- account for lag between shuffle and throw, try and check for aeon
  tempTimer(0.2, function()
    svo.checkaction(svo.dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, 'aeon')
  end)

  tempTimer(0.7, function()
    svo.checkaction(svo.dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, 'aeon')
  end)
end

function svo.valid.lust_card()
  if not affs.blackout then return end

  -- if sk.aeon_thrown then killTimer(sk.aeon_thrown) end
  -- sk.aeon_thrown = tempTimer(4, function() sk.aeon_thrown = nil end)

  -- account for lag between shuffle and throw, try and check for aeon
  tempTimer(0.2+getNetworkLatency(), function()
    if not sys.sync then svo.echof("Checking allies for potential lust...") send('allies', conf.commandecho) end
  end)

  svo.dict.blackout.check_lust = true
end

function svo.defs.cant_empower()
  if actions.empower_physical then
    local off = {}

    if defkeepup[defs.mode].empower then
      svo.defs.keepup('empower', false)
      off[#off+1] = 'keepup'
    end

    if defdefup[defs.mode].empower then
      svo.defs.defup('empower', false)
      off[#off+1] = 'defup'
    end

    echo"\n" svo.echof("Seems that you can't empower yet - so I took it off %s for you.", table.concat(off, ", "))
  end
end

function svo.ignore_snake_bite()
  if not svo.find_until_last_paragraph("You scream out in agony as a vicious venom tears through your body.", 'exact')
    and not svo.find_until_last_paragraph("You gasp as a terrible aching strikes all your limbs.", 'exact')
   then svo.ignore_illusion("Ignored the single-aff bite (vconfig ignoresinglebites is on)", true) return end
end

function svo.valid.stop_wielding()
  svo.checkaction(svo.dict.rewield.physical)
  if actions.rewield_physical then
    lifevision.add(actions.rewield_physical.p, 'clear')
  end
end

function svo.valid.reflection_cancelled()
  if conf.aillusion and svo.paragraph_length == 1 and not conf.batch then return end

  for _, action in pairs(lifevision.l:keys()) do
    if action:find('_aff', 1, true) then
      svo.killaction(svo.dict[action:match("(%w+)_")].aff)

      -- typically, you'd only have one aff per prompt - so no need to complicate by optimizing
      selectCurrentLine()
      fg('MediumSlateBlue')
      deselect()
      resetFormat()
    end
  end
end

function svo.valid.homunculus_throat()
  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then svo.ignore_illusion("This needs to be on it's own line.") return end

  svo.lostbal_focus()
end

function svo.valid.retardation_gone()
  svo.checkaction(svo.dict.retardation.gone, true)
  lifevision.add(actions['retardation_gone'].p)

  -- re-check to make sure it's true
  if conf.aillusion then
    svo.checkaction(svo.dict.checkslows.aff, true)
    lifevision.add(actions.checkslows_aff.p, nil, 'retardation')
  end
end

function svo.valid.soa()
  if not conf.aillusion then return end

  if svo.paragraph_length == 2 and (svo.find_until_last_paragraph("greatly damaged from the beating", 'substring') or svo.find_until_last_paragraph("has been mutilated beyond repair by ordinary means", 'substring')) then
    svo.ignore_illusion("This looks pretty fake - can't get a limb-break and an SoA hit without anyone poking it", true)
  end
end

function svo.valid.enmesh_start()
  if conf.aillusion and svo.paragraph_length ~= 1 and not conf.batch then svo.ignore_illusion("Enmesh can't be chained with other things at once") return end

  -- kill previous timers and set them for future. An enmesh hits at 5s after it was started
  if sys.enmesh1timer then killTimer(sys.enmesh1timer) end
  if sys.enmesh2timer then killTimer(sys.enmesh2timer) end

  sys.enmesh1timer = tempTimer(3, function() sys.enmesh1timer = nil end)

  sys.enmesh2timer = tempTimer(7+getNetworkLatency(), function() sys.enmesh2timer = nil end)
end

function svo.valid.enmesh_hit()
  if not conf.aillusion or (sys.enmesh2timer and not sys.enmesh1timer) then
    valid.simpleroped()
  else
    svo.ignore_illusion("We weren't getting enmeshed, this looks fake.")
  end
end

function svo.valid.chaosrays()
  if not conf.aillusion then return end

  -- first and easiest case: you got hit by it directly, nobody died and bugged the game out
  if svo.find_until_last_paragraph("Seven rays of different coloured light spring out from", 'substring') then return end

  -- second, more difficult case - somebody died, go back until the previous prompt, see if anyone else died too
  if svo.paragraph_length == 1 then
    local checking, getLines = getLineNumber()-1, getLines -- start checking lines 2 back, as 1 back will be prompt

    local line = getLines(checking-1, checking)[1]
    if line:find("Unable to withstand the rays of chaos", 1, true) or line:find("falls from", 1, true) then return end
  end

  svo.ignore_illusion("This looks fake!")
end

function svo.valid.proper_stain()
  if not conf.aillusion then
    valid.simplestain()
  else
    svo.checkaction(svo.dict.stain.aff, true)
    lifevision.add(actions.stain_aff.p, nil, stats.maxhealth)
  end
end

function svo.valid.gothit(class, name)
  svo.checkaction(svo.dict.gothit.happened, true)
  svo.dict.gothit.happened.tempmap[name or "?"] = class
  lifevision.add(actions.gothit_happened.p)
end

function svo.valid.dcurse_start(whom)
  if not conf.aillusion or sk.dcurse_start then return end

  sk.dcurse_start = {tempTimer(10.5+getNetworkLatency(), function() sk.dcurse_start = nil end), whom}
end

function svo.valid.dcurse_hit(aff)
  if conf.aillusion and not sk.dcurse_start then return end

  (valid['proper_'..aff] or valid['simple'..aff])()
end

function svo.valid.broken_legs()
  if not affs.crippledrightleg and not affs.mangledrightleg and not affs.mutilatedrightleg
    and not affs.crippledleftleg and not affs.mangledleftleg and not affs.mutilatedleftleg and not affs.unknowncrippledlimb and not affs.unknowncrippledleg and not affs.hamstring then
    valid.simpleunknowncrippledleg()

    -- cancel potential stand
    if actions.prone_misc then
      svo.killaction(svo.dict.prone.misc)
    end
  end
end

-- remove unknown level if the affliction from a symptom was not present before
valid.remove_unknownmental = function (affliction)
  if affs[affliction] then return end

  svo.checkaction(svo.dict.unknownmental.gone, true)
  lifevision.add(actions.unknownmental_gone.p, 'lost_level')
end
valid.remove_unknownany = function (affliction)
  if affs[affliction] then return end

  svo.checkaction(svo.dict.unknownany.gone, true)
  lifevision.add(actions.unknownany_gone.p, 'lost_level')
end

function svo.valid.loki()
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
function svo.valid.pyradius()
  local affmap = {
    ['clumsiness']  = 'shyness',
    ['darkshade']   = 'confusion',
    ['haemophilia'] = 'claustrophobia',
    ['healthleech'] = 'agoraphobia',
    ['lethargy']    = 'recklessness',
    ['sensitivity'] = 'paranoia',
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
        (valid['proper_'..affmap[aff]] or valid['simple'..affmap[aff]])()
      end
    end
  end)

  -- have to force lifevision and all, since feedTriggers happens after the prompt
  send("\n")
end

if svo.haveskillset('healing') then
function svo.valid.usedhealingbalance()
  svo.checkaction(svo.dict.stolebalance.happened, true)
  lifevision.add(actions.stolebalance_happened.p, nil, 'healing')
end

function svo.valid.gothealingbalance()
  svo.checkaction(svo.dict.gotbalance.happened, true)
  svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'healing' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
end

if svo.haveskillset('venom') then
function svo.valid.shrugging()
  svo.checkaction(svo.dict.shrugging.physical)
  if actions.shrugging_physical then
    valid.passive_cure()
    lifevision.add(actions.shrugging_physical.p, nil, getLineNumber())

    selectCurrentLine()
    setBgColor(0,0,0)
    setFgColor(0,170,255)
    resetFormat()
  end
end

function svo.valid.noshruggingbalance()
  svo.checkaction(svo.dict.shrugging.physical)
  if actions.shrugging_physical then
    lifevision.add(actions.shrugging_physical.p, 'offbal')
  end
end

function svo.valid.gotshruggingbalance()
  svo.checkaction(svo.dict.gotbalance.happened, true)
  svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'shrugging' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
end

if svo.haveskillset('voicecraft') then
function svo.valid.usedvoicebalance()
  svo.checkaction(svo.dict.stolebalance.happened, true)
  lifevision.add(actions.stolebalance_happened.p, nil, 'voice')
end

function svo.valid.gotvoicebalance()
  svo.checkaction(svo.dict.gotbalance.happened, true)
  svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'voice' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
end

if svo.haveskillset('terminus') then
function svo.valid.usedwordbalance()
  svo.checkaction(svo.dict.stolebalance.happened, true)
  lifevision.add(actions.stolebalance_happened.p, nil, 'word')
end

function svo.valid.gotwordbalance()
  svo.checkaction(svo.dict.gotbalance.happened, true)
  svo.dict.gotbalance.happened.tempmap[#svo.dict.gotbalance.happened.tempmap+1] = 'word' -- hack to allow multiple balances at once
  lifevision.add(actions.gotbalance_happened.p)
end
end

function svo.valid.proper_hamstring()
  svo.checkaction(svo.dict.hamstring.aff, true)
  lifevision.add(actions['hamstring_aff'].p, 'renew')
end

function svo.valid.alreadyprone()
  valid.simpleprone()

  if actions.lyre_physical then svo.killaction(svo.dict.lyre.physical) end
end

function svo.valid.negation_gem()
  if not conf.aillusion then
    me.manualdefcheck = true
    defences.lost('shield')
  else
    svo.prompttrigger("check negation gem", function()
      -- in cases where classes have +con/health adjusting buffs, test the line for a max health drop
      -- pending investigation on what happens to current health
    end)
  end
end

function svo.valid.meta_glare()
  svo.prompttrigger("check for stupidity or impatience", function()
    if svo.find_until_last_paragraph("You shuffle your feet noisily, suddenly bored.", 'exact') then
      svo.addaffdict(svo.dict.impatience)
    else
      svo.addaffdict(svo.dict.stupidity)
    end
  end)
end

function svo.valid.bind_totem()
  if conf.aillusion and svo.paragraph_length <= 1 and not conf.batch then svo.ignore_illusion("This can't appear on its own, should only happen when you enter a room") end

  defs.lost_kola()
  valid.simplesleep()
  valid.simpletransfixed()
end

function svo.valid.pummel()
  local oldhp = stats.hp
  svo.aiprompt("check pummel damage", function()
    -- if the damage taken is more than 30%, then we are frozen
    if (oldhp - stats.hp) >= 25 then
      valid.simpleshivering()
      valid.simplefrozen()
    end
  end)
end

function svo.valid.skirmish_drag()
  local result = svo.checkany(svo.dict.impale.misc, svo.dict.curingimpale.waitingfor)

  if not result then return end
  lifevision.add(actions[result.name].p, 'dragged')
end

function svo.valid.cured_burn_health()
  local result = svo.checkany(svo.dict.ablaze.salve, svo.dict.severeburn.salve, svo.dict.extremeburn.salve, svo.dict.charredburn.salve, svo.dict.meltingburn.salve)

  if not result then return end

  svo.apply_cure = true
  if actions[result.name] then
    lifevision.add(actions[result.name].p)
  end
end

function svo.valid.cured_burns_health()
  local result = svo.checkany(svo.dict.ablaze.salve, svo.dict.severeburn.salve, svo.dict.extremeburn.salve, svo.dict.charredburn.salve, svo.dict.meltingburn.salve)

  if not result then return end

  svo.apply_cure = true
  if actions[result.name] then
    lifevision.add(actions[result.name].p, 'all')
  end
end

function svo.valid.tree_cured_burn()
  svo.checkaction(svo.dict.touchtree.misc)
  if actions.touchtree_misc then
    lifevision.add(actions.touchtree_misc.p, nil, 'burn')
    tree_cure = true
  end
end

function svo.valid.tree_cured_burns()
  svo.checkaction(svo.dict.touchtree.misc)
  if actions.touchtree_misc then
    lifevision.add(actions.touchtree_misc.p, nil, "all burns")
    tree_cure = true
  end
end

for _, aff in ipairs({'skullfractures', 'crackedribs', 'wristfractures', 'torntendons'}) do
  valid['tree_cure_'..aff] = function()
    svo.checkaction(svo.dict.touchtree.misc)
    if actions.touchtree_misc then
      tree_cure = true
      lifevision.add(actions.touchtree_misc.p, nil, aff)
    end
  end

  valid['tree_cured_'..aff] = function()
    svo.checkaction(svo.dict.touchtree.misc)
    if actions.touchtree_misc then
      lifevision.add(actions.touchtree_misc.p, nil, aff.." cured")
      tree_cure = true
    end
  end

  valid['generic_cure_'..aff] = function()
    svo.checkaction(svo.dict[aff].gone, true)
    if lifevision.l[aff..'_gone'] then
      lifevision.add(actions[aff..'_gone'].p, 'general_cure', 1 + (lifevision.l[aff..'_gone'].arg or 1))
    else
      lifevision.add(actions[aff..'_gone'].p, 'general_cure', 1)
    end
  end

  valid['generic_cured_'..aff] = function()
    svo.checkaction(svo.dict[aff].gone, true)
    lifevision.add(actions[aff..'_gone'].p, 'general_cured')
  end
end

function svo.valid.expend_torso()
  svo.checkaction(svo.dict.waitingonrebounding.waitingfor)
  if actions.waitingonrebounding_waitingfor then
    lifevision.add(actions.waitingonrebounding_waitingfor.p, 'expend')
  end
end

-- happens on wrist fracture levels 1-3
function svo.valid.devastate_arms_cripple()
  svo.checkaction(svo.dict.wristfractures.gone, true)
  lifevision.add(actions.wristfractures_gone.p)

  valid.simplecrippledrightarm()
  valid.simplecrippledleftarm()
end

-- happens on wrist fracture levels 4,5
-- edit: This ability can also mutilate a mangled limb.
function svo.valid.devastate_arms_mangle()
  svo.checkaction(svo.dict.wristfractures.gone, true)
  lifevision.add(actions.wristfractures_gone.p)

  if affs.mangledrightarm then
    svo.rmaff('mangledrightarm')
    valid.simplemutilatedrightarm()
  else
    valid.simplemangledrightarm()
  end
  if affs.mangledleftarm then
    svo.rmaff('mangledleftarm')
    valid.simplemutilatedleftarm()
  else
    valid.simplemangledleftarm()
  end
end

-- happens on wrist fracture levels 6,7
function svo.valid.devastate_arms_mutilate()
  svo.checkaction(svo.dict.wristfractures.gone, true)
  lifevision.add(actions.wristfractures_gone.p)

  valid.simplemutilatedrightarm()
  valid.simplemutilatedleftarm()
end

-- happens on torn tendon levels 1-3
function svo.valid.devastate_legs_cripple()
  svo.checkaction(svo.dict.torntendons.gone, true)
  lifevision.add(actions.torntendons_gone.p)

  valid.simplecrippledrightleg()
  valid.simplecrippledleftleg()
end

-- happens on torn tendon levels 4,5
-- edit: This ability can also mutilate a mangled limb.
function svo.valid.devastate_legs_mangle()
  svo.checkaction(svo.dict.torntendons.gone, true)
  lifevision.add(actions.torntendons_gone.p)


  if affs.mangledrightleg then
    svo.rmaff('mangledrightleg')
    valid.simplemutilatedrightleg()
  else
    valid.simplemangledrightleg()
  end
  if affs.mangledleftleg then
    svo.rmaff('mangledleftleg')
    valid.simplemutilatedleftleg()
  else
    valid.simplemangledleftleg()
  end
end

-- happens on torn tendon levels 6,7
function svo.valid.devastate_legs_mutilate()
  svo.checkaction(svo.dict.torntendons.gone, true)
  lifevision.add(actions.torntendons_gone.p)

  valid.simplemutilatedrightleg()
  valid.simplemutilatedleftleg()
end

function svo.valid.smash_high()
  svo.lostbal_focus()
end

function svo.valid.proper_ablaze()
  if not affs.severeburn and not affs.extremeburn and not affs.charredburn and not affs.meltingburn then
    valid.simpleablaze()
  end
end

function svo.valid.riding_alreadyon()
  svo.checkaction(svo.dict.riding.physical, true)
  lifevision.add(actions.riding_physical.p, 'alreadyon')
end

function svo.valid.recoverable_attack()
  svo.checkaction(svo.dict.footingattack.happened, true)
  lifevision.add(actions.footingattack_happened.p)
end

valid.recovered_footing = valid.stoodup

function svo.knight_focused(who)
  me.focusedknights[who] = true
end
function svo.valid.doublehander_hit(who)
  if me.focusedknights[who] then
    sk.doubleknightaff = true
    me.focusedknights[who] = nil
    svo.prompttrigger("clear double knight affs", function() sk.doubleknightaff = false end)
  end
end

function svo.valid.skirmish_lacerate()
  svo.prompttrigger("check lacerate rebounding", function()
    if not svo.find_until_last_paragraph("The attack rebounds back onto", 'substring') then
      valid.simplehaemophilia()
    end
  end)
end

function svo.valid.skirmish_gouge()
  svo.prompttrigger("check gouge deafness", function()
    if not svo.find_until_last_paragraph("Your hearing is suddenly restored.", 'exact') then
      valid.simplesensitivity()
    end
  end)
end
