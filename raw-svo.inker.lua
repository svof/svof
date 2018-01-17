-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo.ti_version = "1.1"

local limb_order = {'head', 'torso', "right arm", "left arm", "right leg", "left leg", 'back'}
local tattoos = {
  ox = {
    {
      1,
      'goldink',
    },
    {
      1,
      'redink',
    },
    {
      1,
      'yellowink',
    },
    {
      1,
      'blueink',
    }
  },
  cloak = {
    {
      3,
      'blueink',
    }
  },
  firefly = {
    {
      1,
      'yellowink',
    }
  },
  bell = {
    {
      3,
      'blueink',
    },
    {
      2,
      'redink',
    }
  },
  moss = {
    {
      1,
      'blueink',
    },
    {
      1,
      'redink',
    },
    {
      1,
      'yellowink',
    }
  },
  prism = {
    {
      1,
      'blueink',
    },
    {
      1,
      'greenink',
    },
    {
      1,
      'purpleink',
    },
    {
      1,
      'redink',
    },
    {
      1,
      'yellowink',
    }
  },
  mindseye = {
    {
      2,
      'blueink',
    },
    {
      1,
      'greenink',
    }
  },
  brazier = {
    {
      2,
      'redink',
    },
    {
      2,
      'yellowink',
    }
  },
  feather = {
    {
      2,
      'blueink',
    },
    {
      1,
      'redink',
    }
  },
  moon = {
    {
      1,
      'blueink',
    },
    {
      1,
      'redink',
    },
    {
      1,
      'yellowink',
    }
  },
  starburst = {
    {
      1,
      'blueink',
    },
    {
      1,
      'goldink',
    },
    {
      1,
      'greenink',
    },
    {
      1,
      'purpleink',
    },
    {
      1,
      'redink',
    },
    {
      1,
      'yellowink',
    }
  },
  chameleon = {
    {
      1,
      'goldink',
    },
    {
      1,
      'purpleink',
    },
    {
      1,
      'yellowink',
    }
  },
  crystal = {
    {
      1,
      'greenink',
    },
    {
      1,
      'purpleink',
    },
    {
      1,
      'yellowink',
    }
  },
  megalith = {
    {
      2,
      'goldink',
    }
  },
  tree = {
    {
      5,
      'greenink',
    }
  },
  hourglass = {
    {
      1,
      'blueink',
    },
    {
      2,
      'yellowink',
    }
  },
  hammer = {
    {
      1,
      'purpleink',
    },
    {
      2,
      'redink',
    }
  },
  tentacle = {
    {
      2,
      'greenink',
    },
    {
      1,
      'purpleink',
    }
  },
  web = {
    {
      1,
      'greenink',
    },
    {
      1,
      'yellowink',
    }
  },
  boar = {
    {
      1,
      'purpleink',
    },
    {
      2,
      'redink',
    }
  },
  shield = {
    {
      1,
      'greenink',
    },
    {
      2,
      'redink',
    }
  }
}

svo.ti_inking = false

-- if ends with 'on person', then it's on a person!
function svo.ti_ink(order)
  local anotherperson = order:match(" on (%w+)$")
  if anotherperson then order = order:sub(1, #order-#anotherperson-4) end
  local tattoosorder = string.split(order, ",")
  for i = 1, #tattoosorder do tattoosorder[i] = string.trim(tattoosorder[i]) end

  svo.ti_inking = {on = anotherperson or 'me', tattoos = tattoosorder, ink_counter = 1, tattoo_counter = 1}
  svo.echof("Going to ink %s on %s.", svo.concatand(svo.ti_inking.tattoos), svo.ti_inking.on)
  svo.showprompt() echo"\n"
  svo.app('on')

  svo.ti_inknext()
end

local function doneinking()
    local touchables = {'moss', 'moon', 'boar', 'megalith', 'ox'}
    local needtotouch = {}
    for i = 1, svo.ti_inking.tattoo_counter do
      if table.contains(touchables, svo.ti_inking.tattoos[i]) then needtotouch[#needtotouch+1] = svo.ti_inking.tattoos[i] end
    end
    if #needtotouch > 0 then
      if svo.ti_inking.on ~= 'me' then
        if svo.conf.telltouch then send(string.format("say to %s you should now touch your %s tattoo%s", svo.ti_inking.on, svo.concatand(needtotouch), (#needtotouch == 1 and "" or 's'))) end
      end
    end

    svo.ti_inking = nil
    echo("\n")
    svo.app('off')
    svo.echof("Finished inking all tattoos.")
end

function svo.ti_cantink(limb)
  if not svo.ti_inking then return end
  if limb == limb_order[#limb_order] then
    echo("\n")
    svo.echof("No more inking spots on %s :|", (svo.ti_inking.on == 'me' and 'you' or svo.ti_inking.on))
    svo.showprompt()
    doneinking()
  else
    svo.ti_inking.ink_counter = svo.ti_inking.ink_counter + 1
    svo.ti_inknext()
  end
end

function svo.ti_finishedinking()
  if not svo.ti_inking then return end

  if table.contains({'moss', 'moon', 'boar', 'megalith', 'ox'}, svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter]) then
    send("touch "..svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter])
  end

  svo.ti_inking.tattoo_counter = svo.ti_inking.tattoo_counter + 1

  if not svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter] then
    doneinking()
  else
    svo.ti_inking.ink_counter = 1
    echo("\n")
    svo.echof("Inking the next tattoo...")
    svo.ti_inknext()
  end
end

function svo.ti_inknext()
  if svo.ti_inking.ink_counter == 1 and not tattoos[svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter]] then
    svo.echof("Don't know the inks necessary for a %s tattoo.", svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter])
    svo.showprompt()
  elseif svo.ti_inking.ink_counter == 1 then
    for _, t in pairs(tattoos[svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter]]) do
      svo.sendc(string.format("outr %d %s", t[1], t[2]), false)
    end
  end

  svo.sendc(string.format("ink %s on %s of %s", svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter], limb_order[svo.ti_inking.ink_counter], svo.ti_inking.on))
end

function svo.ti_interrupted()
  if not svo.ti_inking then return end

  svo.ti_inking.ink_counter = 1
  if svo.ti_inking.on == 'me' then
    echo"\n" svo.echof("Be still! Going to ink again in a few...")
  else
    send(string.format("say to %s be still!", svo.ti_inking.on))
  end
  tempTimer(2, function() svo.ti_inknext() end)
end

function svo.ti_noinks()
  echo("\n") svo.echof("Lacking inks for the %s tattoo...", svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter])
  if not svo.ti_inking.tattoos[svo.ti_inking.tattoo_counter + 1] then
    doneinking()
  else
    svo.ti_inking.tattoo_counter = svo.ti_inking.tattoo_counter + 1
    svo.ti_inknext()
  end
end

svo.config.setoption('telltouch',
{
  type = 'boolean',
  vconfig2string = true,
  onshow = function (defaultcolour)
    fg('gold')
    echoLink("ti:", "", "svo Tattoo Inker", true)
    -- <Tell/Don't tell> people to touch inked tattoos
    if svo.conf.telltouch then
      fg('a_cyan') echoLink(" Will tell", "svo.config.set('telltouch', false, true)", "Click to stop telling people to touch their newly-inked tattoos", true)
    else
      fg('a_cyan') echoLink(" Won't tell", "svo.config.set('telltouch', true, true)", "Click to start telling people to touch their newly-inked tattoos", true)
    end
    fg(defaultcolour) echo(" people to touch inked tattoos")
    echo(".\n")
  end,
  onenabled = function ()
    svo.echof("<0,250,0>Will%s tell people to touch tattoos they need to after inking.", svo.getDefaultColor())
  end,
  ondisabled = function () svo.echof("<250,0,0>Won't%s tell people to touch tattoos they need to after inking.", svo.getDefaultColor()) end
})

svo.echof("Loaded svo Tattoo Inker, version %s.", tostring(svo.ti_version))
