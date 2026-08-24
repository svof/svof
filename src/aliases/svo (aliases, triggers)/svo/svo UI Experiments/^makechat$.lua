svo = svo or {}
svo.ui = svo.ui or {}

if svo.ui.initialized then return end

if not Vyzor then
  svo.echof("You need to have Vyzor installed for this to show up - get it from http://forums.mudlet.org/viewtopic.php?f=6&t=2647")
  return
end

svo.ui.map = Vyzor.Map( 0, .5, 1, .5 )

local chat_back = Vyzor.Frame( "chat_background", 0, 0, 1, .5 )
chat_back:Add( Vyzor.Border( 5, Vyzor.BorderStyle.Groove,
		Vyzor.Brush( Vyzor.Color( Vyzor.ColorMode.RGB, 0, 255, 0 ) ),
		5
	)
)

local tab_border = Vyzor.Border( 2, Vyzor.BorderStyle.DotDotDash,
	Vyzor.Brush( Vyzor.Color( Vyzor.ColorMode.RGB, 0, 0, 255 ) ),
	1
)

svo.ui.chat = svo.ui.chat or Vyzor.Chat( "test_chat", chat_back, {"All", "Party"}, Vyzor.TabLocation.Bottom,
	0.05, nil, nil, {Vyzor.Color( Vyzor.ColorMode.Name, "white" ), tab_border}
)

xpcall(function()
Vyzor.Left:Add( Vyzor.Background( Vyzor.Brush( Vyzor.Color( Vyzor.ColorMode.Name, "grey" ) ) ) )
Vyzor.HUD.Frames["VyzorRight"]:Add( svo.ui.chat )
Vyzor.HUD.Frames["VyzorRight"]:Add( svo.ui.map )

Vyzor.HUD.Draw()
end, function(e) display(e) display(debug.traceback()) end)
svo.ui.initialized = true

svo_enableCommChannel()

svo.echof("BIG GIANT NOTE: This is not the final thing! The final might or might not be completely different.")