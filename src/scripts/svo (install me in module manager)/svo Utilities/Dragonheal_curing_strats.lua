-- if you'd like to add your own strat: add it in another script outside Svo, so it stays upon an update.
-- make sure the script is either after the Svof one or it loads itself on the 'svo system loaded' event.
-- then just copy one of these strats and edit it! When you save it, it'll appear in the vconfig2 strat list.

-- to count how many affs you have in total, you can use: local affcount = table.size(svo.affl)

svo.dragonheal = svo.dragonheal or {}

svo.dragonheal.riftlock = {
  desc = "Use dragonheal on riftlocks",

  function()
    local affs = svo.affl
    return (affs.asthma and (affs.slickness or svo.me.pipes.valerian.puffs <= 0)
      and ((affs.crippledleftarm or affs.mangledleftarm or affs.mutilatedleftarm) and (affs.crippledrightarm or affs.mangledrightarm or affs.mutilatedrightarm))
      and not ((affs.mangledleftarm or affs.mutilatedleftarm) and (affs.mangledrightarm or affs.mutilatedrightarm))
    )
  end
}

svo.dragonheal.aeon = {
  desc = "Use dragonheal to cure aeon when we have asthma or mucous",

  function () return svo.affl.aeon and (svo.affl.asthma or svo.affl.mucous) end
}

svo.dragonheal.hardlock = {
  desc = "Use dragonheal to cure hard locks (asthma, anorexia, slickness, and can't focus)",

  function ()

    return svo.me.locks.hard
  end
}

-- dragonheal if we have 3+ limbs damaged and at least one of them is curable with dragonheal
svo.dragonheal.maybevivi = {
  desc = "Use dragonheal in a situation when you might get vivisected - if we have 3+ limbs damaged and at least one of them is curable with dragonheal",

  function ()
    local affs = svo.affl

    if not (affs.crippledleftarm or affs.crippledrightarm or affs.crippledleftleg or affs.crippledrightleg)
      then return end

    return svo.countbrokenlimbs() >= 3
  end
}