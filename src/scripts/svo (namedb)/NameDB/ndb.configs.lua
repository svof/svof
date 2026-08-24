function ndb.setuporders()
  local r = db:fetch_sql(ndb.db.people, [[SELECT DISTINCT "order" FROM 'people';]])
  if not r then return end

  table.sort(r, function(a,b) return a.order < b.order end)

  for i = 1, #r do
    if r[i].order ~= "" then
      local order = r[i].order

      svo.config.setoption("highlight"..order:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s highlight %s's Order members.", svo.getDefaultColor(), order) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s highlight %s's Order members.", svo.getDefaultColor(), order) end,
      })
      svo.config.setoption("bold"..order:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s bold %s's Order members.", svo.getDefaultColor(), order) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s bold %s's Order members.", svo.getDefaultColor(), order) end,
      })
      svo.config.setoption("underline"..order:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s underline %s's Order members.", svo.getDefaultColor(), order) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s underline %s's Order members.", svo.getDefaultColor(), order) end,
      })
      svo.config.setoption("italicize"..order:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s italicize %s's Order members.", svo.getDefaultColor(), order) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s italicize %s's Order members.", svo.getDefaultColor(), order) end,
      })

      svo.config.setoption(order:lower().."color", {
        type = "string",
        check = function (what)
          if color_table[what] then return true end
        end,
        onset = function ()
          ndb.loadhighlights()
          local r,g,b = unpack(color_table[svo.conf[order:lower().."color"]])
          svo.echof("Highlighting %s Order members in <%s,%s,%s>%s%s now.", order, r,g,b, svo.conf[order:lower().."color"], svo.getDefaultColor())
        end,
      })
    end
  end
end

function ndb.configs()
  if svo.conf.autocheck == nil then svo.conf.autocheck = true end
  if svo.conf.ndbpause == nil then svo.conf.ndbpause = false end
  if svo.conf.usehonors == nil then svo.conf.usehonors = false end

  svo.config.setoption("usehonors", {
    type = "boolean",
    vconfig2string = true,
    onenabled = function () svo.echof("<0,250,0>Will%s make use of honors when checking new people, which'll allow NameDB to capture more information.", svo.getDefaultColor()) end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s make use of honors when checking new people.", svo.getDefaultColor()) end
  })

  svo.config.setoption("autocheck", {
    type = "boolean",
    vconfig2string = true,
    onenabled = function () svo.echof("<0,250,0>Will%s automatically, and quietly, honors new people we come across.", svo.getDefaultColor()) ndb.updatebyhonors() end,
    ondisabled = function () svo.echof("<250,0,0>Won't%s automatically honors new people. Use 'ndb honorsnew' to clear the new names backlog manually.", svo.getDefaultColor()) ndb.cancelhonors(true) end,
    onshow = function (defaultcolour)
      fg("gold")
      echoLink("NameDB:", "", "svo NameDB", true)
      fg(defaultcolour) echo(" ")
      fg("a_cyan") echoLink(svo.conf.autocheck and "Auto-checking" or "Not auto-checking", "svo.config.set('autocheck', "..(svo.conf.autocheck and "false" or "true")..", true)", "Click to "..(svo.conf.autocheck and "disable" or "enable").." automatic name checks on new people that we see", true)
      fg(defaultcolour)
      echo(" new people, highlighting names is ")
      fg(defaultcolour)
      fg("a_cyan") echoLink(not svo.conf.ndbpaused and "on" or "off", "svo.config.set('ndbpaused', "..(svo.conf.ndbpaused and "false" or "true")..", true)", "Click to "..(svo.conf.ndbpaused and "start" or "stop").." highlighting names", true)
      fg(defaultcolour)
      echo(", ")
      fg("a_cyan") echoLink(svo.conf.usehonors and "will" or "won't", "svo.config.set('usehonors', "..(svo.conf.usehonors and "false" or "true")..", true)", "Click to "..(not svo.conf.usehonors and "enable" or "disable").." using honors to check names", true)
      fg(defaultcolour)
      echo(" use honors.\n")
    end
  })

  svo.config.setoption("ndbpaused", {
    type = "boolean",
    onenabled = function () ndb.loadhighlights() svo.echof("Name highlighting <250,0,0>stopped%s.", svo.getDefaultColor()) end,
    ondisabled = function () ndb.loadhighlights() svo.echof("Name highlighting <0,250,0>resumed%s.", svo.getDefaultColor()) end
  })

  svo.conf.autoclassset = svo.conf.autoclassset or 10
  svo.config.setoption("autoclassset", {
    type = "number",
    vconfig2string = true,
    onshow = function (defaultcolour)
      fg("gold")
      echoLink("NameDB:", "", "svo NameDB", true)
      fg(defaultcolour) echo(" Capture a persons class after ")
      fg("a_cyan") echoLink(tostring(svo.conf.autoclassset), "printCmdLine('vconfig autoclassset ')", "Click to set the amount of consecutive attacks a person must do from a particular class before it's recorded in NameDB. This is for anti-illusion purposes, so illusions can't easily make NameDB mess with their known class", true)
      fg(defaultcolour)
      echo(" consecutive attacks.\n")
    end,
    onset = function ()
      svo.echof("Will record/change a persons class after %d class-specific attacks from them.", svo.conf.autoclassset)
    end,
  })

  svo.config.setoption("politics", {
    type = "custom",
    onmenu = function () ndb.showpolitics(true) end,
  })

  local function setupwatchfor()
    svo.config.setoption("highlightwatchfor", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s highlight names on the watchfor list.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s highlight names on the watchfor list.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("boldwatchfor", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s bold names on the watchfor list.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s bold names on the watchfor list.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("underlinewatchfor", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s underline names on the watchfor list.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s underline names on the watchfor list.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("italicizewatchfor", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s italicize names on the watchfor list.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s italicize names on the watchfor list.", svo.getDefaultColor()) end,
    })

    svo.config.setoption("watchforcolor", {
      type = "string",
      check = function (what)
        if color_table[what] then return true end
      end,
      onset = function ()
        ndb.loadhighlights()
        local r,g,b = unpack(color_table[svo.conf.watchforcolor])
        svo.echof("Highlighting watchfor names in <%s,%s,%s>%s%s now.", r,g,b, svo.conf.watchforcolor, svo.getDefaultColor())
      end,
    })
  end

  local function setupcities()
    for _, city in ipairs(ndb.valid.cities) do
      svo.config.setoption("highlight"..city:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s highlight citizens of %s.", svo.getDefaultColor(), city) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s highlight citizens of %s.", svo.getDefaultColor(), city) end,
      })
      svo.config.setoption("bold"..city:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s bold the names of %s citizens.", svo.getDefaultColor(), city) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s bold the names of %s citizens.", svo.getDefaultColor(), city) end,
      })
      svo.config.setoption("underline"..city:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s underline the names of %s citizens.", svo.getDefaultColor(), city) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s underline the names of %s citizens.", svo.getDefaultColor(), city) end,
      })
      svo.config.setoption("italicize"..city:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s italicize the names of %s citizens.", svo.getDefaultColor(), city) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s italicize the names of %s citizens.", svo.getDefaultColor(), city) end,
      })

      svo.config.setoption(city:lower().."color", {
        type = "string",
        check = function (what)
          if color_table[what] then return true end
        end,
        onset = function ()
          ndb.loadhighlights()
          local r,g,b = unpack(color_table[svo.conf[city:lower().."color"]])
          svo.echof("Highlighting %s citizens in <%s,%s,%s>%s%s now.", city, r,g,b, svo.conf[city:lower().."color"], svo.getDefaultColor())
        end,
      })
    end
  end

  local function setuprogues()
    svo.config.setoption("highlightrogues", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s highlight rogues.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s highlight rogues.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("boldrogues", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s bold the names of rogues.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s bold the names of rogues.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("underlinerogues", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s underline the names of rogues.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s underline the names of rogues.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("italicizerogues", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s italicize the names of rogues.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s italicize the names of rogues.", svo.getDefaultColor()) end,
    })

    svo.config.setoption("roguescolor", {
      type = "string",
      check = function (what)
        if color_table[what] then return true end
      end,
      onset = function ()
        ndb.loadhighlights()
        local r,g,b = unpack(color_table[svo.conf["roguescolor"]])
        svo.echof("Highlighting rogues in <%s,%s,%s>%s%s now.", r,g,b, svo.conf["roguescolor"], svo.getDefaultColor())
      end,
    })
  end

  local function setupenemies()
    for _, org in ipairs({"city", "house", "order"}) do
      svo.config.setoption("highlight"..org:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s highlight enemies of your of %s.", svo.getDefaultColor(), org) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s highlight enemies of your of %s.", svo.getDefaultColor(), org) end,
      })
      svo.config.setoption("bold"..org:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s bold the names of your %s enemies.", svo.getDefaultColor(), org) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s bold the names of your %s enemies.", svo.getDefaultColor(), org) end,
      })
      svo.config.setoption("underline"..org:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s underline the names of your %s enemies.", svo.getDefaultColor(), org) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s underline the names of your %s enemies.", svo.getDefaultColor(), org) end,
      })
      svo.config.setoption("italicize"..org:lower(), {
        type = "boolean",
        onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s italicize the names of your %s enemies.", svo.getDefaultColor(), org) end,
        ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s italicize the names of your %s enemies.", svo.getDefaultColor(), org) end,
      })

      svo.config.setoption(org:lower().."color", {
        type = "string",
        check = function (what)
          if color_table[what] then return true end
        end,
        onset = function ()
          ndb.loadhighlights()
          local r,g,b = unpack(color_table[svo.conf[org:lower().."color"]])
          svo.echof("Highlighting your %s enemies in <%s,%s,%s>%s%s now.", org, r,g,b, svo.conf[org:lower().."color"], svo.getDefaultColor())
        end,
      })
    end
  end
  
  local function setupdivines()
    svo.config.setoption("highlightdivine", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s highlight Divines.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s highlight Divines.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("bolddivine", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s bold Divines.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s bold Divines.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("underlinedivine", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s underline Divines.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s underline Divines.", svo.getDefaultColor()) end,
    })
    svo.config.setoption("italicizedivine", {
      type = "boolean",
      onenabled = function () ndb.loadhighlights() svo.echof("<0,250,0>Will%s italicize Divines.", svo.getDefaultColor()) end,
      ondisabled = function () ndb.loadhighlights() svo.echof("<250,0,0>Won't%s italicize Divines.", svo.getDefaultColor()) end,
    })

    svo.config.setoption("divinecolor", {
      type = "string",
      check = function (what)
        if color_table[what] then return true end
      end,
      onset = function ()
        ndb.loadhighlights()
        local r,g,b = unpack(color_table[svo.conf.divinecolor])
        svo.echof("Highlighting Divines in <%s,%s,%s>%s%s now.", r,g,b, svo.conf.divinecolor, svo.getDefaultColor())
      end,
    })
  end

  local function addhighlightignore()
    svo.me.highlightignore = svo.me.highlightignore or {}

    svo.config.setoption("highlightignore", {
      type = "string",
      check = function(what)
        if what:find("^%w+$") then return true end
      end,
      onset = function ()
        local name = string.title(svo.conf.highlightignore)
        -- we want nil, not false so 'or' doesn't help
        if svo.me.highlightignore[name] then svo.me.highlightignore[name] = nil else svo.me.highlightignore[name] = true end

        if svo.me.highlightignore[name] then
          svo.echof("Added <0,255,0>%s%s to the highlightignore list - so we won't highlight them.", name, svo.getDefaultColor())
        else
          svo.echof("Removed %s from the highlightignore list.", name)
        end
        raiseEvent("NameDB highlightignore name changed", name)
      end
    })
  end

  setupcities()
  setuprogues()
  setupwatchfor()
  setupenemies()
  setupdivines()
  ndb.setuporders()
  addhighlightignore()
end

-- improve: add background colors
--   rogues as a section
function ndb.showpolitics(noprompt)
  local echo, setFgColor, setUnderline, setFgColor, echoLink = echo, setFgColor, setUnderline, setFgColor, echoLink
  svo.echof("Adjust city stances and setup highlights (currently highlighting %s names):", table.size(ndb.highlightIDs))
  svo.echofn("(click on underlined to change, ")
    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true) echoLink("view color list", "showColors()", "Click here to view the list of possible colors you can choose", true) setUnderline(false)
    echo("):\n\n")

  local function showcities()
    svo.echof("City politics:")

    -- cities
    for _, city in ipairs(ndb.valid.cities) do
      local status = ndb.conf.citypolitics[city]
      local extraspaces = 0
      setFgColor(unpack(svo.getDefaultColorNums))
      echo("  ")
      echo(string.format("%-9s is ", city))

      local nextstatus
      if status == "ally" then fg("a_green"); nextstatus = "enemy"; status = "an ally"; extraspaces = 7
      elseif status == "enemy" then fg("a_red"); nextstatus = "neutral"; status = "an enemy"; extraspaces = 8
      else fg("a_darkwhite"); nextstatus = "ally"; extraspaces = 7 end

      if svo.conf.org ~= city then
        setUnderline(true) echoLink(tostring(status), "ndb.conf.citypolitics."..city.." = '"..nextstatus.."'; ndb.showpolitics()", 'Click to set '..city.."s status to "..nextstatus, true) setUnderline(false)
      else
        setFgColor(unpack(svo.getDefaultColorNums)) echo("your home"); extraspaces = 9
      end

      setFgColor(unpack(svo.getDefaultColorNums))
      echo(",")
      echo((" "):rep(10-extraspaces))

      setUnderline(true)
      echoLink(svo.conf["highlight"..city:lower()] and "highlighting" or "not highlighting", 
        'svo.config.set("highlight'..city:lower()..'", '..(svo.conf["highlight"..city:lower()] and "false" or "true")..', true); ndb.showpolitics()', 
        'Click to '..(svo.conf["highlight"..city:lower()] and "stop" or "start").. ' highlighting citizens of '..city, 
      true)
      setUnderline(false)

      if not svo.conf["highlight"..city:lower()] then
        echo("  its citizens in any color,")
        echo((" "):rep(2))
      else
        echo((" "):rep(5))
        echo(" its citizens in ")
        setUnderline(true)
        setFgColor(unpack(color_table[svo.conf[city:lower().."color"] or "a_darkwhite"]))
        echoLink(svo.conf[city:lower().."color"] or "a_darkwhite", 
          "printCmdLine'vconfig "..city:lower().."color '", 
          'Click to set the color of '..ndb.getpluralcity(city, 2)..' citizens', 
        true)
        setUnderline(false)
        setFgColor(unpack(svo.getDefaultColorNums))
        echo(", ")
        echo((" "):rep(10-#(svo.conf[city:lower().."color"] or "a_darkwhite")))
      end

      echo("(")

      setUnderline(true)
      echoLink(svo.conf["bold"..city:lower()] and "bold" or "no bld", 
        'svo.config.set("bold'..city:lower()..'", '..(svo.conf["bold"..city:lower()] and "false" or "true")..', true); ndb.showpolitics()', 
        'Click to '..(svo.conf["bold"..city:lower()] and "stop" or "start").. ' bolding citizens of '..city, 
      true)
      setUnderline(false)
      echo(", ")

      setUnderline(true)
      echoLink(svo.conf["underline"..city:lower()] and "undl" or "no undl", 
        'svo.config.set("underline'..city:lower()..'", '..(svo.conf["underline"..city:lower()] and "false" or "true")..', true); ndb.showpolitics()', 
        'Click to '..(svo.conf["underline"..city:lower()] and "stop" or "start").. ' underlining citizens of '..city, 
      true)
      setUnderline(false)
      echo(", ")

      setUnderline(true)
      echoLink(svo.conf["italicize"..city:lower()] and "ital" or "no ital", 
        'svo.config.set("italicize'..city:lower()..'", '..(svo.conf["italicize"..city:lower()] and "false" or "true")..', true); ndb.showpolitics()', 
        'Click to '..(svo.conf["italicize"..city:lower()] and "stop" or "start").. ' italicizing citizens of '..city, 
      true)
      setUnderline(false)

      echo(")")

      echo('\n')
    end

    -- rogues
    setFgColor(unpack(svo.getDefaultColorNums))
    echo("  Rogues are neutral,     ")

    setUnderline(true)
    echoLink(svo.conf["highlightrogues"] and "highlighting" or "not highlighting", 
      'svo.config.set("highlightrogues", '..(svo.conf["highlightrogues"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["highlightrogues"] and "stop" or "start").. ' highlighting rogues', 
    true)
    setUnderline(false)

    if not svo.conf["highlightrogues"] then
      echo("  them in any color,")
      echo((" "):rep(10))
    else
      echo((" "):rep(5))
      echo(" them in ")
      setUnderline(true)
      setFgColor(unpack(color_table[svo.conf["roguescolor"] or "a_darkwhite"]))
      echoLink(svo.conf["roguescolor"] or "a_darkwhite", 
        "printCmdLine'vconfig rogues".."color '", 
        'Click to set the color of rogues', 
      true)
      setUnderline(false)
      setFgColor(unpack(svo.getDefaultColorNums))
      echo(", ")
      echo((" "):rep(18-#(svo.conf["roguescolor"] or "a_darkwhite")))
    end

    echo("(")

    setUnderline(true)
    echoLink(svo.conf["boldrogues"] and "bold" or "no bld", 
      'svo.config.set("boldrogues", '..(svo.conf["boldrogues"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["boldrogues"] and "stop" or "start").. ' bolding rogues', 
    true)
    setUnderline(false)
    echo(", ")

    setUnderline(true)
    echoLink(svo.conf["underlinerogues"] and "undl" or "no undl", 
      'svo.config.set("underlinerogues", '..(svo.conf["underlinerogues"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["underlinerogues"] and "stop" or "start").. ' underlining rogues', 
    true)
    setUnderline(false)
    echo(", ")

    setUnderline(true)
    echoLink(svo.conf["italicizerogues"] and "ital" or "no ital", 
      'svo.config.set("italicizerogues", '..(svo.conf["italicizerogues"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["italicizerogues"] and "stop" or "start").. ' italicizing rogues', 
    true)
    setUnderline(false)

    echo(")")

    echo('\n')
  end

  local function showwatchfor()
    svo.echof("Watchfor list:")
    setFgColor(unpack(svo.getDefaultColorNums))
    echo("  ")
    setUnderline(true)
    echoLink(svo.conf["highlightwatchfor"] and "Highlighting" or "Not highlighting", 
      'svo.config.set("highlightwatchfor", '..(svo.conf["highlightwatchfor"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["highlightwatchfor"] and "stop" or "start").. ' highlighting names on the watchfor list',
    true)
    setUnderline(false)

    if not svo.conf["highlightwatchfor"] then
      echo(" names on the watchfor list. ")
      echo((" "):rep(25))
    else
      echo(" names on the watchfor list in ")
      setUnderline(true)
      setFgColor(unpack(color_table[svo.conf["watchforcolor"] or "a_darkwhite"]))
      echoLink(svo.conf["watchforcolor"] or "a_darkwhite", 
        "printCmdLine'vconfig watchfor".."color '", 
        'Click to set the color of names on the watchfor list', 
      true)
      setUnderline(false)
      setFgColor(unpack(svo.getDefaultColorNums))
      echo(", ")
      echo((" "):rep(25-#(svo.conf["watchforcolor"] or "a_darkwhite")))
    end

    echo("(")

    setUnderline(true)
    echoLink(svo.conf["boldwatchfor"] and "bold" or "no bld", 
      'svo.config.set("boldwatchfor", '..(svo.conf["boldwatchfor"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["boldwatchfor"] and "stop" or "start").. ' bolding names on watchfor list', 
    true)
    setUnderline(false)
    echo(", ")

    setUnderline(true)
    echoLink(svo.conf["underlinewatchfor"] and "undl" or "no undl", 
      'svo.config.set("underlinewatchfor", '..(svo.conf["underlinewatchfor"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["underlinewatchfor"] and "stop" or "start").. ' underlining names on watchfor list', 
    true)
    setUnderline(false)
    echo(", ")

    setUnderline(true)
    echoLink(svo.conf["italicizewatchfor"] and "ital" or "no ital", 
      'svo.config.set("italicizewatchfor", '..(svo.conf["italicizewatchfor"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["italicizewatchfor"] and "stop" or "start").. ' italicizing names on watchfor list', 
    true)
    setUnderline(false)

    echo(")")
    echo("\n")
  end

  local function showdivines()
    svo.echof("Divine list:")
    setFgColor(unpack(svo.getDefaultColorNums))
    echo("  ")
    setUnderline(true)
    echoLink(svo.conf["highlightdivine"] and "Highlighting" or "Not highlighting", 
      'svo.config.set("highlightdivine", '..(svo.conf["highlightdivine"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["highlightdivine"] and "stop" or "start").. ' highlighting Divines',
    true)
    setUnderline(false)

    if not svo.conf["highlightdivine"] then
      echo(" Divines. ")
      echo((" "):rep(44))
    else
      echo(" Divines in ")
      setUnderline(true)
      setFgColor(unpack(color_table[svo.conf["divinecolor"] or "a_darkwhite"]))
      echoLink(svo.conf["divinecolor"] or "a_darkwhite", 
        "printCmdLine'vconfig divine".."color '", 
        'Click to set the color of Divine names', 
      true)
      setUnderline(false)
      setFgColor(unpack(svo.getDefaultColorNums))
      echo(", ")
      echo((" "):rep(44-#(svo.conf["divinecolor"] or "a_darkwhite")))
    end

    echo("(")

    setUnderline(true)
    echoLink(svo.conf["bolddivine"] and "bold" or "no bld", 
      'svo.config.set("bolddivine", '..(svo.conf["bolddivine"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["bolddivine"] and "stop" or "start").. ' bolding Divines', 
    true)
    setUnderline(false)
    echo(", ")

    setUnderline(true)
    echoLink(svo.conf["underlinedivine"] and "undl" or "no undl", 
      'svo.config.set("underlinedivine", '..(svo.conf["underlinedivine"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["underlinedivine"] and "stop" or "start").. ' underlining Divines', 
    true)
    setUnderline(false)
    echo(", ")

    setUnderline(true)
    echoLink(svo.conf["italicizedivine"] and "ital" or "no ital", 
      'svo.config.set("italicizedivine", '..(svo.conf["italicizedivine"] and "false" or "true")..', true); ndb.showpolitics()', 
      'Click to '..(svo.conf["italicizedivine"] and "stop" or "start").. ' italicizing Divines', 
    true)
    setUnderline(false)

    echo(")")
    echo("\n")
  end

  local function showenemies()
    svo.echof("House, City and Order enemies:")

    for _, org in ipairs({"house", "city", "order"}) do
      setFgColor(unpack(svo.getDefaultColorNums))
      echo("  ")
      setUnderline(true)
      echoLink(svo.conf["highlight"..org] and "Highlighting" or "Not highlighting", 
        'svo.config.set("highlight'..org..'", '..(svo.conf["highlight"..org] and "false" or "true")..', true); ndb.showpolitics()', 
        'Click to '..(svo.conf["highlight"..org] and "stop" or "start").. ' highlighting names of your '..org..' enemies',
      true)
      setUnderline(false)

      if not svo.conf["highlight"..org] then
        echo(" names of your "..org.." enemies. ")
        echo((" "):rep(29-#org))
      else
        echo("     names of your "..org.. " enemies in ")
        setUnderline(true)
        setFgColor(unpack(color_table[svo.conf[org.."color"] or "a_darkwhite"]))
        echoLink(svo.conf[org.."color"] or "a_darkwhite", 
          "printCmdLine'vconfig "..org.."color '", 
          'Click to set the color of names on '..org..' enemies list', 
        true)
        setUnderline(false)
        setFgColor(unpack(svo.getDefaultColorNums))
        echo(", ")
        echo((" "):rep(25-#org-#(svo.conf[org.."color"] or "a_darkwhite")))
      end
      
      echo("(")

      setUnderline(true)
      echoLink(svo.conf["bold"..org] and "bold" or "no bld", 
        'svo.config.set("bold'..org..'", '..(svo.conf["bold"..org] and "false" or "true")..', true); ndb.showpolitics()', 
        'Click to '..(svo.conf["bold"..org] and "stop" or "start").. ' bolding names of your '..org..' enemies', 
      true)
      setUnderline(false)
      echo(", ")

      setUnderline(true)
      echoLink(svo.conf["underline"..org] and "undl" or "no undl", 
        'svo.config.set("underline'..org..'", '..(svo.conf["underline"..org] and "false" or "true")..', true); ndb.showpolitics()', 
        'Click to '..(svo.conf["underline"..org] and "stop" or "start").. ' underlining names of your '..org..' enemies', 
      true)
      setUnderline(false)
      echo(", ")

      setUnderline(true)
      echoLink(svo.conf["italicize"..org] and "ital" or "no ital", 
        'svo.config.set("italicize'..org..'", '..(svo.conf["italicize"..org] and "false" or "true")..', true); ndb.showpolitics()', 
        'Click to '..(svo.conf["italicize"..org] and "stop" or "start").. ' italicizing names of your '..org..' enemies', 
      true)
      setUnderline(false)

      echo(")")
      echo("\n")
    end
  end

  local function showordermembers()
    local r = db:fetch_sql(ndb.db.people, [[SELECT DISTINCT "order" FROM 'people';]])
    if not r then return end

    table.sort(r, function(a,b) return a.order < b.order end)

    local shownsomething
    svo.echof("Order members:")
    for i = 1, #r do
      if r[i].order ~= "" then
        shownsomething = true
        local order = r[i].order

        setFgColor(unpack(svo.getDefaultColorNums))
        echo("  ")
        setUnderline(true)
        echoLink(svo.conf["highlight"..order:lower()] and "Highlighting" or "Not highlighting", 
          'svo.config.set("highlight'..order:lower()..'", '..(svo.conf["highlight"..order:lower()] and "false" or "true")..', true); ndb.showpolitics()', 
          'Click to '..(svo.conf["highlight"..order:lower()] and "stop" or "start").. ' highlighting names of '..order:lower()..'\'s members',
        true)
        setUnderline(false)

        if not svo.conf["highlight"..order:lower()] then
          echo(" names of "..order.."'s Order members. ")
          echo((" "):rep(26-#order))
        else
          echo("     names of "..order.. "'s Order members in ")
          setUnderline(true)
          setFgColor(unpack(color_table[svo.conf[order:lower().."color"] or "a_darkwhite"]))
          echoLink(svo.conf[order:lower().."color"] or "a_darkwhite", 
            "printCmdLine'vconfig "..order:lower().."color '", 
            'Click to set the color of '..order:lower()..'\'s Order members', 
          true)
          setUnderline(false)
          setFgColor(unpack(svo.getDefaultColorNums))
          echo(", ")
          echo((" "):rep(22-#order-#(svo.conf[order:lower().."color"] or "a_darkwhite")))
        end
        
        echo("(")

        setUnderline(true)
        echoLink(svo.conf["bold"..order:lower()] and "bold" or "no bld", 
          'svo.config.set("bold'..order:lower()..'", '..(svo.conf["bold"..order:lower()] and "false" or "true")..', true); ndb.showpolitics()', 
          'Click to '..(svo.conf["bold"..order:lower()] and "stop" or "start").. ' bolding names '..order:lower()..'\'s Order members', 
        true)
        setUnderline(false)
        echo(", ")

        setUnderline(true)
        echoLink(svo.conf["underline"..order:lower()] and "undl" or "no undl", 
          'svo.config.set("underline'..order:lower()..'", '..(svo.conf["underline"..order:lower()] and "false" or "true")..', true); ndb.showpolitics()', 
          'Click to '..(svo.conf["underline"..order:lower()] and "stop" or "start").. ' underlining names '..order:lower()..'\'s Order members', 
        true)
        setUnderline(false)
        echo(", ")

        setUnderline(true)
        echoLink(svo.conf["italicize"..order:lower()] and "ital" or "no ital", 
          'svo.config.set("italicize'..order:lower()..'", '..(svo.conf["italicize"..order:lower()] and "false" or "true")..', true); ndb.showpolitics()', 
          'Click to '..(svo.conf["italicize"..order:lower()] and "stop" or "start").. ' italicizing names '..order:lower()..'\'s Order members',
        true)
        setUnderline(false)

        echo(")")
        echo("\n")
      end
    end

    if not shownsomething then
      setFgColor(unpack(svo.getDefaultColorNums))
      echo("  (no members of Orders are known)")
      resetFormat()
      echo("\n")
    end
  end

  -- watchfor > divine > city > order > house > citizens
  showwatchfor()
  echo("\n")
  showdivines()
  echo("\n")
  showenemies()
  echo("\n")
  showordermembers()
  echo("\n")
  showcities()

  if not noprompt then svo.showprompt() end
end