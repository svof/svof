svo.me = svo.me or {}
svo.me.time = svo.me.time or {
  h = 0, m = 0,
  tictimer = false,
  min2s = 2.5
}

function svo.sync_time(hour)
  svo.me.time.h, svo.me.time.m = hour, 0
  if svo.me.time.tictimer then killTimer(svo.me.time.tictimer) end

  svo.me.time.tictimer = tempTimer(svo.me.time.min2s - getNetworkLatency(), svo.tic_time)
end

function svo.tic_time()
  svo.me.time.m = svo.me.time.m + 1
  if svo.me.time.m >= 60 then
    svo.me.time.h = svo.me.time.h + 1
    if svo.me.time.h >= 24 then svo.me.time.h = 0 end

    svo.me.time.m = 0
  end

  svo.echof("It is now %.0d:%1d", svo.me.time.h, svo.me.time.m)
  svo.me.time.tictimer = tempTimer(svo.me.time.min2s, svo.tic_time)
end