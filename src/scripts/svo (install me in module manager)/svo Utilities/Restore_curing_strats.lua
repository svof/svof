-- if you'd like to add your own strat: add it in another script outside Svo, so it stays upon an update.
-- make sure the script is either after the Svof one or it loads itself on the 'svo system loaded' event.
-- then just copy one of these strats and edit it! When you save it, it'll appear in the vconfig2 strat list.

-- to count how many affs you have in total, you can use: local affcount = table.size(svo.affl)

--[[svo.restore.anylimb = {
  desc = "Use restore if any limb is crippled (useful for bashing without mending, for example)",
  function () return svo.affl.crippledleftleg or svo.affl.crippledrightleg
    or svo.affl.crippledrightarm or svo.affl.crippledleftarm
  end
}]]

svo.restore = svo.restore or {}

svo.restore.anyoneortwolimbs = {
  desc = "Use restore if one or two limbs are crippled (and no more), and you're off salve/tree balance",

  function ()
    local mangledormultilated = 0
    if svo.affl.mangledleftleg or svo.affl.mutilatedleftleg then mangledormultilated = mangledormultilated + 1 end
    if svo.affl.mangledrightleg or svo.affl.mutilatedrightleg then mangledormultilated = mangledormultilated + 1 end
    if svo.affl.mangledrightarm or svo.affl.mutilatedrightarm then mangledormultilated = mangledormultilated + 1 end
    if svo.affl.mangledleftarm or svo.affl.mutilatedleftarm then mangledormultilated = mangledormultilated + 1 end

    local crippled = svo.countonlybrokenlimbs()

    -- add mangled/mutilated limbs to count, so we don't exceed it
    -- don't go off on mangled/mutilated limbs only as well
    local total = mangledormultilated + crippled

    if crippled > 0 and (total == 1 or total == 2) then return true end
  end
}


svo.restore.anyoneortwolimbsprone = {
  desc = "Use restore if one or two limbs are crippled (and no more), prone, and you're off salve/tree balance",

  function ()
    if not svo.affl.prone then return false end

    local mangledormultilated = 0
    if svo.affl.mangledleftleg or svo.affl.mutilatedleftleg then mangledormultilated = mangledormultilated + 1 end
    if svo.affl.mangledrightleg or svo.affl.mutilatedrightleg then mangledormultilated = mangledormultilated + 1 end
    if svo.affl.mangledrightarm or svo.affl.mutilatedrightarm then mangledormultilated = mangledormultilated + 1 end
    if svo.affl.mangledleftarm or svo.affl.mutilatedleftarm then mangledormultilated = mangledormultilated + 1 end

    local crippled = svo.countonlybrokenlimbs()

    -- add mangled/mutilated limbs to count, so we don't exceed it
    -- don't go off on mangled/mutilated limbs only as well
    local total = mangledormultilated + crippled

    if crippled > 0 and (total == 1 or total == 2) then return true end
  end
}

svo.restore.riftlock = {
  desc = "Use restore on riftlocks",

  function()
    local affs = svo.affl
    return (affs.asthma and (affs.slickness or svo.me.pipes.valerian.puffs <= 0)
      and ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm))
      and not ((affs.mangledleftarm or affs.mutilatedleftarm) and (affs.mangledrightarm or affs.mutilatedrightarm))
    )
  end
}

-- restore if we have 3+ limbs damaged and at least one of them is curable with restore
svo.restore.maybevivi = {
  desc = "Use restore if you have 3+ limbs damaged and at least one of them is curable with restore",

  function ()
    local affs = svo.affl

    if not (affs.crippledleftarm or affs.crippledrightarm or affs.crippledleftleg or affs.crippledrightleg)
      then return end

    return svo.countbrokenlimbs() >= 3
  end
}
