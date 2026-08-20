svo.loader.mindnet = function()
  -- adds the vconfig mindnet option with the following code:

  svo.config.setoption("mindnet", {
    type = "boolean",
    onenabled = function() svo.echof("<0,250,0>Will%s announce mindnet to cc.", svo.getDefaultColor()) end,
    ondisabled = function() svo.echof("<250,0,0>Won't%s announce mindnet to cc.", svo.getDefaultColor()) end,
    vconfig2string = true,
    onshow = function (defaultcolour)
      fg("gold")
      echoLink("mr:", "", "svo Mindnet Report", true)

    if svo.conf.mindnet then
      fg("a_cyan") echoLink(" Announcing ", 'svo.config.set("mindnet", "off", true)', "Click to disable mindnet announces", true) fg(defaultcolour)
      echo("mindet to cc")
    else
      fg("a_cyan") echoLink(" Not announcing ", 'svo.config.set("mindnet", "on", true)', "Click to enable mindnet announces", true) fg(defaultcolour)
      echo("mindnet")
    end
    echo(".\n")
    end
  })
end