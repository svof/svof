Svof Priest Healer
======================
This addon allows Priests to cure other people and enemies. Svof already comes with Healing use for yourself (and several nice modes of integrating Healing into your normal curing while at it), this enables you to cure others.

The script does rely on some features of the Svof Priest system, so it is necessary to have. It also takes available open channels into account and won't try to cure afflictions that you can't due to channels not being opened.

The script *does* take into account which channels do you have open that you can heal with - so make sure you have all channels open if you'd like to be able to cure most afflictions!

Aliases
^^^^^^^^
.. glossary::

  cre <ally>
  	Diagnoses and cures one affliction off a person. If you'd like to cure them again, use ``cre`` again. It will use your aeon/retardation priorities to prioritize which affliction to cure first.

  cre <list of allies>
    Diagnoses and cures a whole lot of people at once (ie cre person1 person1 person3 ...). Make sure you use the full names - anti-illusion is in place to prevent you from getting tricked into healing someone else. You can spam this (as long as you have mana!) to cure allies with whatever you can - one affliction at a time from the whole group.

    Don't use this on yourself, use dv instead.

  crc <enemy or list of enemies>
  	Heals an enemies of deaf, blindness and insomnia.

  crc
  	Heals whoever is targetted by the 'target' variable.
