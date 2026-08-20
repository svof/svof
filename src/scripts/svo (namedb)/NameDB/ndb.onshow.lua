function ndb.onshow()
    local c = table.size(svo.me.highlightignore)

    svo.echofn("# of people on the highlightignore: %d ", c)

    setFgColor(unpack(svo.getDefaultColorNums))
    setUnderline(true)
    echoLink("(view)", 'echo"\\n" expandAlias"vshow highlightignore"', 'Click here open the highlightignore list menu', true)
    echo"\n"
end