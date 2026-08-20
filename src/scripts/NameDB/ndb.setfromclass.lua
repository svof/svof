ndb.classhits = ndb.classhits or {}

function ndb.setfromclass(_, class, name)
  -- a name isn't always given if it is not available
  if not name then return end

  class = class:lower()

  if class == "knight" then return end

  ndb.classhits[name] = ndb.classhits[name] or {hits = 0, class = class}

  if ndb.classhits[name].class ~= class then
    ndb.classhits[name].hits = 0 -- reset on a hit from the same person on another class
  else
    ndb.classhits[name].hits = ndb.classhits[name].hits + 1

    if ndb.classhits[name].hits >= svo.conf.autoclassset then
      if class == "dragon" then
        if not ndb.isdragon(name) then
          ndb.setdragon(name, true)
          svo.echof("Auto-set %s as a Dragon.", name)
        end
      else
        local oldclass = ndb.getclass(name)
        if not oldclass then return end -- if the name isn't known, don't add it - could be fake names from illusions

        if class ~= oldclass then
          ndb.setclass(name, class)
          svo.echof("Auto-set %s's class to %s.", name, class:title())
        end
      end

      ndb.classhits[name].hits = 0 -- reset, so we aren't querying the db on every hit
    end
  end
end