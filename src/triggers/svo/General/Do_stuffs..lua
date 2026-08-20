svo.watch = svo.watch or {}

if not svo.innews then
  for _, balance in pairs{"balance", "equilibrium"} do
    if svo["had_"..balance] and not svo.bals[balance] then
      raiseEvent("svo lost balance", balance)

      svo.watch["bal_"..balance] = svo.watch["bal_"..balance] or createStopWatch()
      startStopWatch(svo.watch["bal_"..balance])
    elseif not svo["had_"..balance] and svo.bals[balance] then
      raiseEvent("svo got balance", balance)

      if svo.watch["bal_"..balance] then
        local s = stopStopWatch(svo.watch["bal_"..balance])
        svo.stats["last"..balance] = s
        if svo.conf.showbaltimes then svo.echotime(s) end
      end
    end

    svo["had_"..balance] = nil
  end
end

svo.onprompt()