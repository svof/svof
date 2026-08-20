-- after editing this, do vshow herbstat to make it appear. To adjust the font size used, use vconfig herbstatsize #

-- if you'd like your changes to stay between Svo updates, move this script out of Svo's folder,
-- and make sure it is *after* Svo's folder after an update


svo.riftlabel = Geyser.Label:new({  name = "svo.riftlabel",
                               x = -360, y = -166,
                               width = 355, height = 166})

if not svo or not svo.conf or not svo.conf.riftlabel then svo.riftlabel:hide() end