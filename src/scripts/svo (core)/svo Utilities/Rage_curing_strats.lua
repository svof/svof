-- if you'd like to add your own strat: add it in another script outside Svo, so it stays upon an update.
-- make sure the script is either after the Svof one or it loads itself on the 'svo system loaded' event.
-- then just copy one of these strats and edit it! When you save it, it'll appear in the vconfig2 strat list.

-- to count how many affs you have in total, you can use: local affcount = table.size(svo.affl)

svo.rage = svo.rage or {}

svo.rage.any2affs = {
  desc = "Use rage when we've got at least two afflictions and one of them is rage-curable",

  function ()
    return table.size(svo.affl) >= 2
  end
}

svo.rage.any3affs = {
  desc = "Use rage when we've got at least three afflictions and one of them is rage-curable",

  function ()
    return table.size(svo.affl) >= 3
  end
}