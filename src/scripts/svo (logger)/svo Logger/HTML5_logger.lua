html5log = html5log or {}

function html5log.recordcurrentline()
  local line_num, cur_line = getLineNumber(), getCurrentLine()

  local output, tc = {}, 1
  local index = 0
  local r,g,b = 0,0,0
  local br,bg,bb = 0,0,0
  local cbr,cbg,cbb --last bg colors
  local cr,cg,cb -- last colors
  local tc = 1 -- table count

  while index < #cur_line do
    index = index + 1

    if moveCursor("main", index, line_num) and selectString(cur_line:sub(index), 1) then
      r,g,b = getFgColor()
      br,bg,bb = getBgColor()
      if cr ~= r or cg ~= g or cb ~= b or cbr ~= br or cbg ~= bg or cbb ~= bb then
        cr,cg,cb = r,g,b
        cbr,cbg,cbb = br,bg,bb
        if tc == 1 then
          output[tc] = string.format("<span style=\'color: rgb(%d,%d,%d);background: rgb(%d,%d,%d);'>%s", r,g,b,br,bg,bb, cur_line:sub(index, index))
        else
          output[tc] = string.format("</span><span style=\'color: rgb(%d,%d,%d);background: rgb(%d,%d,%d);'>%s", r,g,b,br,bg,bb, cur_line:sub(index, index))
        end
        tc = tc +1
      else
        output[tc] = cur_line:sub(index, index)
        tc = tc +1
      end
      cur_line:sub(index, index)
    end
  end
  output[#output+1] = "</span>"

  return table.concat(output)
end

function html5log_stoplogging()
  disableTrigger("Capture each line")
  disableTrigger("Record on the prompt")

  html5log.current_data[#html5log.current_data+1] = [[</div>
</body>
</html>]]


  local logfile = getMudletHomeDir().."/svolog.html"
  local file_output = io.open(logfile, "w")


  local conversions = {
    ["¦"] = "&brvbar;",
    ["×"] = "&times;",
    ["«"] = "&#171;",
    ["»"] = "&raquo;"
  }


  local s = table.concat(html5log.current_data)

  for from, to in pairs(conversions) do
    s = string.gsub(s, from, to)
  end

  file_output:write(s)
  file_output:close()

  -- this can use quite a bit of memory on a large buffer, so free it up right away
  collectgarbage("collect")
  local location = [[file:///]]..logfile:gsub([[\]], "/")
  cecho("\n<cyan>Log recording finished, opening <cyan>"..location..".")
  openUrl(location)

  html5log.current_data = nil
  html5log.inbetween = nil
  if html5log.trig then killTrigger(html5log.trig) end
  html5log.trig = nil

  html5log.label:hide()
  collectgarbage("collect")
end

function html5log.showlabel()
  if html5log.label then
    html5log.label:show()
  else

    html5log.label = Geyser.Label:new({
      name="html5log.label",
      x=-110, y=-60,
      width=50, height=30,
    })

    html5log.label:setStyleSheet[[
      color: #333;
      border: 2px solid #555;
      border-radius: 11px;
      padding: 5px;
      background: qradialgradient(cx: 0.3, cy: -0.4,
      fx: 0.3, fy: -0.4,
      radius: 1.35, stop: 0 #fff, stop: 1 #888);
      min-width: 80px;
  ]]

    html5log.label:echo"<center>Stop logging</center>"
    html5log.label:setClickCallback("html5log_stoplogging")
  end
end

function html5log.recordline()
  html5log.inbetween[#html5log.inbetween+1] = html5log.recordcurrentline()

  if isPrompt() then
    for i = 1, #html5log.inbetween do
      html5log.current_data[#html5log.current_data+1] = string.format([[<div id="%d" class="log tnc_default"><p>%s</p></div>]], getStopWatchTime(html5log.recording_stopwatch)*1000, string.gsub(html5log.inbetween[i], '\n', '<br/>'))
    end

    html5log.inbetween = {}
  end
end