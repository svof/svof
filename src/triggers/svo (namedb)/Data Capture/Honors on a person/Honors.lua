if ndb.honorsid then killTimer(ndb.honorsid) end

local pronoun = line:match("^(%w+)")

local function getGender()
  if pronoun == "He" or pronoun == "His" then return "male"
  elseif pronoun == "She" or pronoun == "Her" then return "female"
  elseif pronoun == "Fae" or pronoun == "Faes" then return "non-binary"
  end
end
ndb.getinfo(ndb.honorsname)

temp_name_list = {}
temp_name_list[1] = {name = ndb.honorsname, city = "", city_rank = 0, dragon = 0,
  guild = "", gender = getGender(), mark = "",
}

moveCursorEnd() -- make sure the cursor is at the current line

local foundname
local startline = getLineNumber()
for i = 1, 10 do -- word wrapping can mess it up, go so back a fair bit in case of small screen

  -- work backwards until the line with the name is located
  if string.find(getCurrentLine(), "%f[%a]"..ndb.honorsname.."%f[%A]") then
    -- pick up the race as it is listed
    local race = getCurrentLine():match("%(male (.-)%)") or getCurrentLine():match("%(female (.-)%)") or 
    getCurrentLine():match("%(non-binary (.-)%)") or ""

    local occultist = race:match("Chaos .- resembling a (%a+)")
    if occultist then
      race = occultist
      temp_name_list[1].class = "occultist"
    end
    local sylvan = race:match("Viridian (%a+)")
    if sylvan then
      race = sylvan
      temp_name_list[1].class = "sylvan"
    end

    if ndb.isvalidrace(race) then
      temp_name_list[1].race = race:lower()
    elseif race:find("Dragon") then
      temp_name_list[1].dragon = 1
    end

    foundname = true
    break
  end
  if ndb.gaghonours then deleteLine() end
  moveCursor(0, startline-i)
end

-- failsafe for ndb update all messing up - in case we didn't find the name, don't capture any data
if not foundname then
  setTriggerStayOpen("Honors", 0)
  disableTrigger("Honors")
  local gaghonours = ndb.gaghonours
  ndb.honorsid, ndb.gaghonours = nil, nil

  raiseEvent("NameDB finished honors", temp_name_list[1].name, (gaghonours and "quiet" or "manual"))

  temp_name_list = nil
end

moveCursorEnd()