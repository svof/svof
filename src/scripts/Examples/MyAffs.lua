-- made by Lynara

svo.stopWatches = svo.stopWatches or {}
function MyAffs(eventname, data)
   local default = svo.getDefaultColor()
   if eventname == "svo got aff" then
      svo.stopWatches[data] = svo.affl[data] and svo.affl[data].sw or 0
      svo.echof("Got aff: <0,210,0>%s <210,210,210>(<170,0,0>%s%s affs<210,210,210>)", data, table.size(svo.affl), default )
   else
      svo.echof([[Lost aff: <0,210,0>%s <210,210,210>(<0,210,0>%s%ssec<210,210,210>) (<170,0,0>%s%s left<210,210,210>)]],
 data, getStopWatchTime(svo.stopWatches[data]), default, table.size(svo.affl), default)
   end
end