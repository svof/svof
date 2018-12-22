Svof People Tracker
======================
Just use any of the people-locating methods - sense, wholist, fly/view, alertness, trace - it'll plot people on your map.

You can disable it or easily change color of labels in it's **vconfig2** menu entry, along with the size of the labels.

The script works in tandem with the `Mudlet Mapper script <http://wiki.mudlet.org/w/IRE_mapping_script#Download>`_, and thus the latest version is required - or **12.5.10 at minimum**!

* if it's not possible to tell where exactly a person is, like when they're in a room with a non-unique name, then it'll put identifiers into all rooms that match and only put the list of people in the right-most room. This seems the best way to deal with this problem so far, but if you have better ideas let me know

Comprehensive guide to setting this up
----------------------------------------
1) **Get the map open** - press the Map button in Mudlet or *Toolbox → Show map* to spawn it. If you'd always like the map showing, `this script <http://wiki.mudlet.org/w/Mudlet_Mapper>`_ will help you do that. Don't worry if the map doens't track you / says invalid position or etc right now.

2) **Get the mapper script** - `go here <http://wiki.mudlet.org/w/IRE_mapping_script>`_ and install this script. If you already have it, remove it and install it - it is updated very often. After you install it, reconnect - that way it will know you're connected to Achaea, and not another game.

3) **Get the map** - after you reconnected, do *mconfig crowdmap on*. It will download a map if you don't have one. After it downloads, you should be able to walk around and it will visually track you on the map.

4) **Done** - steps 1-3 were really just a trick to get your map working. The peopletracker works automatically and without fuss, you're done. See below on useful aliases to know.

Aliases
^^^^^^^^
.. glossary::

  qwho
  	Scans the who list and plots people on the map wherever they are. Doesn't spam you with wholist and does it quietly.

  qwhom
    Scans the who list and shows you a nice menu of where everyone is - broken down by area and room. Plots people on the map as well - all qwho variants do.

  qwho <area>
    Scans the who list and shows you all people in that area only.

  qwhog
    Scans the wholist and shows you groups of 2+ people only.

  qwhow
    Scans the wholist and only shows you people that are on your watchfor list.

  vconfig watchfor <person>
    Adds or removes a person on the watchfor list - used in qwhow. You can script this as well - put the name down as a key in the ``svo.me.watchfor`` table. To remove a name, set it to nil (not false).

  vshow watchfor
    Lists the people on your watchfor list.

  vconfig labelsize <font size>
    Sets the size of the labels to use on the map. Default size is 10.

  ppin <area>
    Reports where all the people in the area are to the ccto output - default is party, and you can adjust it with vconfig ccto. Use one of the qwho aliases to refresh this information, or one of the locating abilities you have.

  ppwith <person>
    Reports all the companions of a person to the ccto output (see above). It also echoes it back to you, so you can see this in case you aren't in a party.

  ppof <city>
    Reports all citizens of a particular city that are online and are visible on qw (so ungemmed).

  gotop
    Walks over to where your target (as defined by the 'target' variable) was known to be last.

  gotop <person>
    Walks over to where the person was known to be last.

  gotop flag, gotop hill
    In a KoTH, walks over to the flag or the hill - use *es <arena>* to update where the location is.

  mstop
    stops walking from goto and gotop.

  alertness on
    Plots people adjacent to you and in your room as they move around.

  angel/demon presences
    Plots everybody in the area on the map!

  <class locating ability>
    Plots that invididual on the map as you locate them.

  farsee <person>
    If the person is in the same area as you, it'll plot them on the map.
