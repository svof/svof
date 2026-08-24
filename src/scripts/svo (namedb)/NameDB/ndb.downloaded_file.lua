-- credit to Veldrin for the original function

function ndb.downloaded_file(_, filename)
  -- is the file that downloaded ours?
  if not string.find(filename, "namedb.json") then return end
  local f = io.open(filename)
  local s = f:read("*all")
  if f then f:close() end
  os.remove(filename)
  s = s:gsub("\"", "")
  local name = filename:match("(%w+)-namedb")
  local fullname = s:match([[fullname:(.+),city]])
  local level = s:match([[level:(%d+),class]])
  local city = s:match([[city:(.+),house]])
  local house = s:match([[house:(.+),level]])
  local class = s:match([[class:(.+),mob_kills]])
  local xp_rank = s:match([[xp_rank:(%d+),explorer_rank]])
  local dragon
  local temp_name_list

  -- sometimes players, unless you're logged in, aren't visible
  if s:find("I do not recognize that player.") then
    temp_name_list = {{
      name = name,
      xp_rank = -2,
    }}

  elseif level == nil then
    temp_name_list = {{
      name = name,
      immortal = 1
    }}
 
  else
    
    if tonumber(level) > 98 then dragon = 1 else dragon = 0 end
    if tonumber(xp_rank) == 0 then xp_rank = -2 end -- unranked shows up as 0

    temp_name_list = {{
      name = name,
      class = class,
      dragon = dragon,
      title = fullname,
      level = level,
      immortal = 0,
      xp_rank = xp_rank and xp_rank or -1,
    }}
    if city ~= "(hidden)" then
        temp_name_list[1].city = (city ~= "(none)" and string.title(city) or "rogue")
    end
    -- API returns 'underworld' for the Undead.
    if city == 'underworld' then
        temp_name_list[1].city = 'Undead'
    end										
    -- house info isn't shown if you're logged in to the website for some people
    if not(house == "(hidden)" or house == "(none)") then
      temp_name_list[1].guild = string.title(house)
    end
  end

  db:merge_unique(ndb.db.people, temp_name_list)

  raiseEvent("NameDB finished honors")
end

function ndb.getinfo(person)
  downloadFile(getMudletHomeDir().."/"..person.."-namedb.json", "http://api.achaea.com/characters/"..person..".json")
end