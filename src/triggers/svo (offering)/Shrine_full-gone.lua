-- the queue can end in svo.corpse_stuff's disable function, or hold only that
local queue = svo.me.doqueue
local haveselfish = queue[#queue-1] == "vkeep selfishness on"
if type(queue[1]) == "string" and
   queue[1]:find("^offer") then
     svo.undoall()
    if haveselfish then
      svo.doadd("vkeep selfishness on")
    end
end
disableTrigger("Shrine full-gone")