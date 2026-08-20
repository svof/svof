function ndb.loadsettings()
  ndb.conf = ndb.conf or {}
  ndb.conf.citypolitics = ndb.conf.citypolitics or {}

  local conf_path = getMudletHomeDir() .. "/svo/namedb/citypolitics"

  if lfs.attributes(conf_path) then
    table.load(conf_path, ndb.conf.citypolitics)
  end

  -- setup defaults
  if next(ndb.conf.citypolitics) then return end

  -- include own city in table in case of org switch
  if svo.conf.org == "Shallam" then svo.config.set("org", "Targossas") end
  ndb.conf.citypolitics = {
    Mhaldor = "neutral", Ashtan = "neutral", Cyrene = "neutral", Hashan = "neutral", Targossas = "neutral", Eleusis = "neutral", Undead = "neutral"
  }
end