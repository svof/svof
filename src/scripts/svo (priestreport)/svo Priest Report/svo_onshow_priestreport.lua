function svo_onshow_priestreport()
  if not svo.loader.priestreporter then return end
    local c = table.size(svo.me.locatelist)

    svo.echofn("# of people on the locatelist: %d ", c)

    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true)
    echoLink("(view)", 'echo"\\n" expandAlias"vshow locatelist"', 'Click here open the locatelist list menu', true)
    echo"\n"
end