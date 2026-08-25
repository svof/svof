-- sample custom echo! Feel free to change the 'demo' name, so you can do 'vconfig echotype <name>'.

-- to edit this, mode this script outside of Svo - doesn't matter if it's before or after Svo scripts
-- then do 'vshow colors' to select your new colour scheme

-- this does take #'s for colours, not words - http://colorschemedesigner.com might help you in
-- selecting the hex colour code and then use http://www.yellowpipe.com/yis/tools/hex-to-rgb/color-converter.php
-- to convert it to the 3 RGB colours
function Customize_systems_echos()
if not (svo and svo.echos) then return end

-- this does the (svo): blah-style echoes
function svo.echos.demo(newline, what)
  decho("<80,66,80>(<107,79,125>svo<80,66,80>)<87,85,89>: <159,128,180>" .. what)
  if newline then echo"\n" end
end

-- this is the default color of the text in (svo): <this colour here>, so keep it consistent
-- with the last colour used above
function svo.echosd.demo()
  return "<159,128,180>"
end

end

-- this is so editing the scheme after loading works
Customize_systems_echos()