Svof Enchanter
==============
The enchanter was written with whole orders in mind. It will Use the Medaillon of Enchantment correctly, split creation batches accordingly and allows the start of whole orders in one command. The script also automatically detects the ids of the ouroboros. An example usage of the enchanter would be: ::

	-- lists all known enchantments
	enchant list

	-- shows the commodity cost of the order
	enchant cost 19 eye, scroll1234 waterwalking, ring45123 magic, 10 star, 10 meteor

	-- does the full order
	enchant 19 eye, scroll1234 waterwalking, boots12341 waterwalking, ring45123 magic, 10 star, 10 meteor

	-- repeats the same order
	reenchant	

Aliases
^^^^^^^
.. glossary::

  enchant <order>
    Does your **entire** order - separate different enchantments with a comma.

    For item creation (**including meteor**), simply put the number of items you want to create.

    For enchantments you will need to put every item you want to enchant as an extra enchantment (see the waterwaling part of example above)

  enchant list
    Lists all known enchantments.

  enchant cost <order>
    Calculates the commodity cost of the order.

  reenchant
    Repeats the last order.

  vconfig enchantGetGold <command>
    Sets the command how to retrieve gold coins, if one is needed for the enchantment (action **flipcoin**). The command may contain '$' as command separator.

  vconfig enchantPutGold <command>
    Sets the command how to put gold coins away, if one is needed for the enchantment (action **flipcoin**). The command contain '$' as command separator.

  vconfig haveEnchantmentMedaillon
    Toggles whether you have the Medaillon of Enchantment or not.


API
^^^
.. glossary::

  svo.getEnchantCost(what, howMany, costCollection)
    what - the name of the enchantment

    howMany - amount of created items of that type (only needed for created items including meteor)

    If costCollection is given and a table, the cost will also be added to that table. This is especially useful to collect total costs in a loop.

    Returns a key - value table with commodity as key and the needed amount as key.

    Example: ::

    	vlua svo.getEnchantCost("star", 10)
    	--returns
    	{
    	  goldbar = 20
    	  silverbar = 10
    	}
