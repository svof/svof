# Svof
Svof is an AI system for Achaea, an online MUD. It has advanced and adaptable curing capabilities, defence raising, name highlighting, limbcounter tracking and other features. It is the free and open-source version of what used to be Svo.

# Downloading
To download the system for use, [see here](https://github.com/svof/svof/releases).

# Contributing
To code in the system itself, follow instructions below on how to set it up. See also the [developer readme](Developer readme.md) for more useful information.

If you're looking for something to do, have a look at the existing [issues/features](https://github.com/svof/svof/issues) list, and have a [look at the wiki](https://github.com/svof/svof/wiki) on information about the project.

## License
Svof is licensed under [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/). You must read the license before using Svof source code.

## Setup

1. Obtain Svof source code. Either clone using Git (which will allow you to easily update the Svof code and contribute back) or a [zip snapshot](https://github.com/svof/svof/archive/master.zip) (which doesn't require knowledge of Git).
1. Uninstall Svof/Svof you currently have installed. This is necessary to run the developer version of the system.
1. Install Lua, LuaFileSystem, LuaRocks, Penlight, and 7zip.
    1. Windows: download and install latest [LuaForWindows](https://github.com/rjpcomputing/luaforwindows/releases), which all the Lua components indluded. Install 7zip [from here](http://www.7-zip.org/download.html).
    1. Ubuntu: install [Lua](https://apps.ubuntu.com/cat/applications/lua5.1/), [LuaFileSystem](https://apps.ubuntu.com/cat/applications/lua-filesystem/), [LuaRocks](https://apps.ubuntu.com/cat/applications/luarocks/), [Penlight](https://apps.ubuntu.com/cat/applications/lua-penlight/), and [7zip](https://apps.ubuntu.com/cat/applications/p7zip-full/).
    1. OSX: install [Homebrew](http://brew.sh).
        1. Using Brew from your Terminal: `brew install lua` and `brew install p7zip`.
            1. Afterwards, make sure to `brew install lua5.1`.
        1. Using LuaRocks from your Terminal: `luarocks install luafilesystem` and `luarocks install penlight`
1. Open the command-line and navigate to the Svof folder, and run:

       On Ubuntu:
       ./generate.lua -o &lt;your class&gt;

       In Windows:
       generate.lua -o &lt;your class&gt;
       
       On OSX:
       lua5.1 generate.lua -o &lt;your class&gt;


1. Replace &lt;Svof Git location&gt; with the path to the XML files, and then run this command in Mudlet.

        lua installModule([[<Svof Git location>/svo (burncounter).xml]]) installModule([[<Svof Git location>/svo (dragonlimbcounter).xml]]) installModule([[<Svof Git location>/svo (elistsorter).xml]]) installModule([[<Svof Git location>/svo (enchanter).xml]]) installModule([[<Svof Git location>/svo (fishdist).xml]]) installModule([[<Svof Git location>/svo (inker).xml]]) installModule([[<Svof Git location>/svo (install the zip, not me).xml]]) installModule([[<Svof Git location>/svo (knightlimbcounter).xml]]) installModule([[<Svof Git location>/svo (logger).xml]]) installModule([[<Svof Git location>/svo (magilimbcounter).xml]]) installModule([[<Svof Git location>/svo (metalimbcounter).xml]]) installModule([[<Svof Git location>/svo (mindnet).xml]]) installModule([[<Svof Git location>/svo (monklimbcounter).xml]]) installModule([[<Svof Git location>/svo (namedb).xml]]) installModule([[<Svof Git location>/svo (offering).xml]]) installModule([[<Svof Git location>/svo (peopletracker).xml]]) installModule([[<Svof Git location>/svo (priesthealing).xml]]) installModule([[<Svof Git location>/svo (priestlimbcounter).xml]]) installModule([[<Svof Git location>/svo (priestreport).xml]]) installModule([[<Svof Git location>/svo (reboundingsileristracker).xml]]) installModule([[<Svof Git location>/svo (refiller).xml]]) installModule([[<Svof Git location>/svo (runeidentifier).xml]]) installModule([[<Svof Git location>/svo (simple mindnet).xml]]) installModule([[<Svof Git location>/svo (sparkstracker).xml]]) installModule([[<Svof Git location>/svo (stormhammertarget).xml]])
1. When prompted to find the Svof folder location, select the &lt;Svof Git location&gt;/own svo folder
1. Go to Toolbox > Module Manager and tick all 'don't sync' boxes, so they become 'sync', for all Svof XML files.

All set!

## Editing

Code in Svof comes from two places - Mudlet and the Lua files. In order to make a change in Mudlet (alias/trigger/script), edit in Mudlet directly, then hit Save Profile. Since you've installed the xml files as modules with the sync option, changes will be written back to the XML file automatically, and you'll see your Git client instantly show what you've changed. In order to make a change in the Lua files, edit the raw-* files directly (not the ones in the bin/ folder), save, rebuild Svof (using *generate.lua -o \<your class>* above) and reload it (by restarting your profile or Mudlet).


# Authors
2011-2015, Vadim Peretokin.
