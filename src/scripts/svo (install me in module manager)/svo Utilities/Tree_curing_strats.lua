-- if you'd like to add your own strat: add it in another script outside Svo, so it stays upon an update.
-- make sure the script is either after the Svof one or it loads itself on the 'svo system loaded' event.
-- then just copy one of these strats and edit it! When you save it, it'll appear in the vconfig2 strat list.

-- to count how many affs you have in total, you can use: local affcount = table.size(svo.affl)

svo.tree = svo.tree or {}

svo.tree.blackout = {
  desc = "Use tree to cure blackout",

  function () return svo.affl.blackout and not svo.ignore.blackout end
}

svo.tree.aeon = {
  desc = "Use tree to cure aeon when we have asthma or mucous",

  function () return svo.affl.aeon and (svo.affl.asthma or svo.affl.mucous) end
}

svo.tree.hardlock = {
  desc = "Use tree to cure hard locks (asthma, anorexia, slickness, and can't focus)",

  function ()

    return svo.me.locks.hard
  end
}

-- touch tree if we have 3+ limbs damaged and at least one of them is curable with tree
svo.tree.maybevivi = {
  desc = "Use tree in a situation when you might get vivisected",

  function ()
    local affs = svo.affl

    if not (affs.crippledleftarm or affs.crippledrightarm or affs.crippledleftleg or affs.crippledrightleg)
      then return end

    return svo.countbrokenlimbs() >= 3
  end
}

svo.tree.crippledandprone = {
  desc = "Use tree if prone and both legs are crippled",

  function ()
    local affs = svo.affl

    return (affs.crippledleftleg and not (affs.mangledleftleg or affs.mutilatedleftleg))
      and (affs.crippledrightleg and not (affs.mangledrightleg or affs.mutilatedrightleg)) and (affs.prone or not svo.bals.salve)
  end
}

svo.tree.getupfaster = {
  desc = "Use tree if prone, off salve balance, and a leg is crippled",

  function ()
    local affs = svo.affl

    return ((affs.crippledleftleg and not (affs.mangledleftleg or affs.mutilatedleftleg))
      or (affs.crippledrightleg and not (affs.mangledrightleg or affs.mutilatedrightleg))) and affs.prone and not svo.bals.salve
  end
}

svo.tree.curearmsfaster = {
  desc = "Use tree if both arms are crippled and you're off salve balance",

  function ()
    local affs = svo.affl

    return ((affs.crippledleftarm and not (affs.mangledleftarm or affs.mutilatedleftarm)) or (affs.crippledrightarm and not (affs.mangledrightarm or affs.mutilatedrightarm))) and not svo.bals.salve
  end
}

svo.tree.novoyriacure = {
  desc = "Use tree when you have voyria and no immunity/antigen for it",

  function ()
    return (svo.affl.voyria and ((svo.es_potions.elixir and svo.es_potions.elixir["an elixir of immunity"] and svo.es_potions.elixir["an elixir of immunity"].sips <= 1)
      and (svo.es_potions.tonic and svo.es_potions.tonic["a tonic of antigen"] and svo.es_potions.tonic["a tonic of antigen"].sips <= 1))
    )
  end
}

svo.tree.any2affs = {
  desc = "Use tree when we've got at least two tree-curable afflictions",

  function ()
    return #svo.gettreeableaffs() >= 2
  end
}

svo.tree.any3affs = {
  desc = "Use tree when we've got at least three tree-curable afflictions",

  function ()
    return #svo.gettreeableaffs() >= 3
  end
}

svo.tree.fractures = {
  desc = "Use tree you're got a fracture and are off sip balance",

  function ()
    return not svo.bals.sip and svo.havefractures()
  end
}