ndb.schema = {
  people = {
    name          = "",
    title         = "",
    gender        = "",
    class         = "",
    city          = "",
    city_rank     = 0,
    city_soldier  = -1, -- -1 default, 0 no, -2 yes
    guild         = "",
    might         = -1, -- 0 is a possible might, -1 unknown
    importance    = 0,
    xp_rank       = -1, -- -1 default, -2 unranked
    level         = -1, -- -1 default (unknown)
    immortal      = 0,
    iff           = -1, -- -1 autodetected, 1 enemy, 2 ally
    cityenemy     = 0, -- 0 is not enemy, 1 is enemy
    orderenemy    = 0, -- 0 is not enemy, 1 is enemy
    houseenemy    = 0, -- 0 is not enemy, 1 is enemy
    order         = "",
    notes         = "",
    dragon        = 0,
    mark          = "", -- contributed by Veldrin
    race          = "",
    combat_rank   = -1, -- -1 default, 0 no rank, > 0 yes
    combat_rating = -1, -- -1 default, 0 no rating, > 0 yes
    birth_day     = 0, -- 0 default, > 0 yes
    birth_month   = 0, -- 0 default, > 0 yes
    birth_year    = 0, -- 0 default, > 0 yes
    birth_hidden  = -1, -- -1 default, 0 not hidden, 1 hidden
    arms          = "",
    divorces      = 0, -- 0 default,
    motto         = "",
    warcry        = "",
    infamous      = -1, -- -1 default, 0 not infamous, 1 nearly, 2-7 infamous 

    _unique     = {"name"},
    _violations = "REPLACE"
  },
}

function ndb.init()
  ndb.db = db:create("NameDB", ndb.schema)
  -- necessary on Windows, because its IO tends to... slow down with time.
  -- http://www.sqlite.org/pragma.html#pragma_synchronous
  db.__conn["namedb"]:execute("pragma synchronous = OFF")

  -- automigration by db: doesn't work anymore because LuaSQL bugs out on the pragma statement
  -- so if there was any data at all in the db, see if any of it needs to be added

  local test = db:fetch(ndb.db.people)
  if next(test) then
    local _,someperson = next(test)
    
    if someperson.order == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "order" TEXT NULL DEFAULT ""]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons order.\n")
    end

    if someperson.race == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "race" TEXT NULL DEFAULT ""]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons race.\n")
    end

    if someperson.dragon == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "dragon" REAL NULL DEFAULT 0]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field to see if a person is a dragon.\n")
    end

    if someperson.mark == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "mark" TEXT NULL DEFAULT ""]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field to see if a person is a mark.\n")
    end

    if someperson.combat_rank == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "combat_rank" REAL NULL DEFAULT -1]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the person combat rank.\n")
    end

    if someperson.combat_rating == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "combat_rating" REAL NULL DEFAULT -1]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons combat rating.\n")
    end

    if someperson.city_soldier == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "city_soldier" REAL NULL DEFAULT -1]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field to see if a person is a city soldier.\n")
    end

    if someperson.birth_day == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "birth_day" REAL NULL DEFAULT 0]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons birth day.\n")
    end

    if someperson.birth_month == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "birth_month" REAL NULL DEFAULT 0]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons birth month.\n")
    end

    if someperson.birth_year == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "birth_year" REAL NULL DEFAULT 0]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons birth year.\n")
    end

    if someperson.birth_hidden == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "birth_hidden" REAL NULL DEFAULT -1]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field to see if a person has a hidden birthdate.\n")
    end

    if someperson.arms == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "arms" TEXT NULL DEFAULT ""]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons arms.\n")
    end

    if someperson.divorces == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "divorces" REAL NULL DEFAULT 0]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field to see how many divorces a person has had.\n")
    end

    if someperson.infamous == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "infamous" REAL NULL DEFAULT 0]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field to track Infamous people.\n")
    end

    if someperson.motto == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "motto" TEXT NULL DEFAULT ""]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons motto.\n")
    end

    if someperson.warcry == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "warcry" TEXT NULL DEFAULT ""]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field for the persons warcry.\n")
    end

    if someperson.level == nil then
      local conn = db.__conn.namedb
      local sql_add = [[ALTER TABLE people ADD COLUMN "level" REAL NULL DEFAULT 0]]
      conn:execute(sql_add)
      conn:commit()
      cecho("(namedb): upgraded your database to have a field to track a persons level.\n")
    end
  end

  -- shuffle Shallamese into Targossas
  local c = #(db:fetch(ndb.db.people, db:eq(ndb.db.people.city, "Shallam")))
  if c ~= 0 then
    -- wait for ndb.fixed_set to be loaded
    tempTimer(0, [[ndb.fixed_set(ndb.db.people.city, "Targossas", db:eq(ndb.db.people.city, "Shallam")); svo.echof("Migrated ]]..c..[[ Shallamese to be called Targossians now.")]])
  end

   tempTimer(0, function()
     -- fix up knowns to go into rogue
     ndb.fixed_set(ndb.db.people.city, "rogue", db:eq(ndb.db.people.city, "(none)"))
     ndb.fixed_set(ndb.db.people.city, "rogue", db:eq(ndb.db.people.city, "none"))
     ndb.fixed_set(ndb.db.people.city, "rogue", db:eq(ndb.db.people.city, ""))
   end)
end

ndb.init()