local haveselfish = svo.me.doqueue[#svo.me.doqueue-1]:find("^vkeep selfishness on$")
if svo.me.doqueue[1] and
   svo.me.doqueue[1]:find("^offer") then 
     svo.undoall()
    if haveselfish then
      svo.doadd("vkeep selfishness on")
    end
end
disableTriger("Shrine full-gone")