-- if you'd like to add your own strat: add it in another script outside Svo, so it stays upon an update.
-- make sure the script is either after the Svof one or it loads itself on the 'svo system loaded' event.
-- then just copy one of these strats and edit it! When you save it, it'll appear in the vconfig2 strat list.

-- to count how many affs you have in total, you can use: local affcount = table.size(svo.affl)

svo.fitness = svo.fitness or {}

svo.fitness.anylock = {
  desc = "Use fitness if we've got any locks we can use fitness to cure out of",

  function ()
    return (svo.me.locks.soft and not svo.doing"focus") or svo.me.locks.venom or svo.me.locks.hard or
            svo.me.locks.rift or svo.me.locks["rift 2"] or svo.me.locks.slow or svo.me.locks["true"]
  end
}

svo.fitness.asthmainaeon = {
  desc = "Use fitness if we've got asthma in aeon",

  function ()
    return svo.affl.asthma and svo.affl.aeon
  end
}

svo.fitness.hellsightconc = {
  desc = "Use fitness if we've got hellsight and a concussion",

  function ()
    return svo.affl.hellsight and (svo.affl.mildconcussion or svo.affl.seriousconcussion)
  end
}