ndb.valid = ndb.valid or {}

ndb.valid.cities = {
  "Ashtan", "Cyrene", "Hashan", "Eleusis", "Mhaldor", "Targossas", "Undead"
}
ndb.valid.classes = {
  "alchemist", "apostate", "bard", "blademaster", "depthswalker", "druid", "infernal", "jester", "magi", "monk", "occultist", "paladin", "pariah", "priest", "psion", "runewarden", "sentinel", "serpent", "shaman", "sylvan", "unnamable"
}
ndb.valid.houses = {
  "Scions", "Merchants", "Heartwood", "Cij", "Somatikos", "Shield", "Krymenian", "Virtuosi", "Outriders", "Dawnblade", "Harbingers", "Legates", "Insidium", "Consortium", "Savants", "Vanguard"
}
ndb.valid.races = {
  "tsol'aa", "dwarf", "fayad", "human", "troll", "atavian", "rajamala", "horkval", "grook", "xoran", "siren", "satyr", "mhun", "tash'la", "undead", "elemental lord", "elemental lady"
}
ndb.valid.infamous = {
  ["is rapidly approaching the ranks of the Infamous"] = 1,
  ["is one of the Infamous"]                        = 2,
  ["is one of the solidly Infamous"]                = 3,
  ["is one of the staggeringly Infamous"]           = 4,
  ["is one of the entrenched Infamous"]             = 5,
  ["is one of the near-permanent Infamous"]         = 6,
  ["is one of the inveterately Infamous"]           = 7,
}
ndb.valid.shortinfamous = {
  "nearly",
  "Infamous",
  "solidly Infamous",
  "staggeringly Infamous",
  "entrenched Infamous",
  "near-permanent Infamous",
  "inveterately Infamous"
}

ndb.valid.cityranks = {
  Mhaldor = {
    Slave = 1,
    Troni = 2,
    Dynamis = 3,
    Dominion = 4,
    Archai = 5,
    Exsusiai = 6,
  },

  Cyrene = {
    Citizen = 1,
    Peer = 2,
    Noble = 3,
    Marquis = 4,
    Marquise = 4,
    Duke = 5,
    Duchess = 5,
    Lord = 6,
    Lady = 6,
  },

  Ashtan = {
    Plebeian = 1,
    Equite = 2,
    Centurion = 3,
    Patrician = 4,
    Matrician = 4,
    Consul = 5,
    Praetor = 6,
  },

  Eleusis = {
    Freeman = 1,
    Freewoman = 1,
    Ranger = 2,
    Tender = 3,
    Warden = 4,
    Watcher = 5,
    Elder = 6,
  },

  Hashan = {
    Peasant = 1,
    Commoner = 2,
    Burgher = 3,
    Esquire = 4,
    Peer = 5,
    Peeress = 5,
    Lord = 6,
    Lady = 6,
  },

  -- dead city, but some people in your namedb could be listed as Shallam still
  Shallam = {
    Villager = 1,
    Citizen = 2,
    Chieftain = 3,
    Satrap = 4,
    Ataman = 5,
    Emir = 6
  },

  Targossas = {
    Settler = 1,
    Sentry = 2,
    Devout = 3,
    Vigilant = 4,
    Paragon = 5,
    Vanguard = 6,
  },
}

-- make a reverse map as well, rank = name
for city, citydata in pairs(ndb.valid.cityranks) do
  for rank, rankn in pairs(citydata) do
    citydata[rankn] = rank
  end
end

ndb.valid.months = {
  "Sarapin",
  "Daedalan",
  "Aeguary",
  "Miraman",
  "Scarlatan",
  "Ero",
  "Valnuary",
  "Lupar",
  "Phaestian",
  "Chronos",
  "Glacian",
  "Mayan",
  Sarapin = 1,
  Daedalan = 2,
  Aeguary = 3,
  Miraman = 4,
  Scarlatan = 5,
  Ero = 6,
  Valnuary = 7,
  Lupar = 8,
  Phaestian = 9,
  Chronos = 10,
  Glacian = 11,
  Mayan = 12,
}

function ndb.isvalidcity(which)
  which = which:title()
  return table.contains(ndb.valid.cities, which) and true or false
end

function ndb.isvalidhouse(which)
  which = which:title()
  return table.contains(ndb.valid.houses, which) and true or false
end

function ndb.isvalidclass(which)
  which = which:lower()
  return table.contains(ndb.valid.classes, which) and true or false
end

function ndb.isvalidrace(which)
  which = which:lower()
  return table.contains(ndb.valid.races, which) and true or false
end