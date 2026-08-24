function ndb.showhonorswindow(text)
  ndb.autochecklabel = ndb.autochecklabel or Geyser.Label:new({
    name = "ndb.autochecklabel",
    x = "-370px", y = "-35px",
    width = "350px", height = "25px",
  })

  ndb.autochecklabel:setStyleSheet([[
    margin: 0px;
    padding: 2px;

    background: rgba(0, 0, 51, 75%);
    border: none;
    border-radius: 4px;

    qproperty-alignment: 'AlignLeft | AlignVCenter';
    qproperty-wordWrap: true;
    font-family: 'Ubuntu','Calibri',serif;
  ]])

  ndb.autochecklabel:show()
  ndb.autochecklabel:echo([[<p style="color: grey; font-size: 15px;">]]..text..[[</p>]])
end

function ndb.hidehonorswindow()
  if ndb.autochecklabel then ndb.autochecklabel:hide() end
end