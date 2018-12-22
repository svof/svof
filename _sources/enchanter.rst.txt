Svof Enchanter
==============
The enchanter was written with whole orders in mind. It will Use the Medallion of Enchantment correctly, split creation batches accordingly and allows the start of whole orders in one command. The script also automatically detects the ids of the ouroboros. An example usage of the enchanter would be: ::

	-- lists all known enchantments
	enchant list

	-- shows the commodity cost of the order
	enchant cost 19 eye, scroll1234 waterwalking, 3 45123 magic, 10 star, 10 meteor

	-- does the full order
	enchant 19 eye, scroll1234 waterwalking, boots12341 waterwalking, 3 45123 magic, 10 star, 10 meteor

	-- repeats the same order
	reenchant	

Aliases
^^^^^^^
.. glossary::

  enchant <order>
    Does your **entire** order - separate different enchantments with a comma.

    For item creation (**including meteor**), simply put the number of items you want to create.

    For enchantments you can select an example for the items you want to enchant (specify it by id). If you choose to do so, you can specify, how many of that enchantment/item combination is made. Will then pick the items for you that have the same short description and are not worn. See the magic enchantment example above.

  enchant list
    Lists all known enchantments.

  enchant cost <order>
    Calculates the commodity cost of the order.

  enchant cancel
    Stops the current order after the currently running enchantment.

  enchant cancel force
    Immediately stops the current enchantment order

  reenchant
    Repeats the last order.

  vconfig enchantgetgold <command>
    Sets the command how to retrieve gold coins, if one is needed for the enchantment (action **flipcoin**). The command may contain '$' as command separator.

  vconfig enchantputgold <command>
    Sets the command how to put gold coins away, if one is needed for the enchantment (action **flipcoin**). The command contain '$' as command separator.

  vconfig haveenchantmentmedallion
    Toggles whether you have the Medallion of Enchantment or not.


API
^^^
.. glossary::

  svo.get_enchant_cost(what, howMany, exampleItem, costCollection)
    what - the name of the enchantment

    howMany - amount of created items of that type

    exampleItem - If this is the empty string (""), the howMany argument is ignored for enchantments. If it is something else, it calculates the cost of howMany enchantments. This value is ignored for created items and meteors.

    If costCollection is given and a table, the cost will also be added to that table. This is especially useful to collect total costs in a loop.

    Returns a key - value table with commodity as key and the needed amount as key.

    Example: ::

    	vlua svo.getEnchantCost("star", 10)
    	--returns
    	{
    	  goldbar = 20
    	  silverbar = 10
    	}
