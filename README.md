# Svof
Svof is an AI system for Achaea, an online MUD. It has advanced and adaptable curing capabilities, defence raising, name highlighting, limbcounter tracking and other features. It is the free and open-source version of what used to be Svo.

# Downloading
Download `svof.mpackage` for free from the [latest release](https://github.com/svof/svof/releases/latest) :)

# Installing
Open `svof.mpackage` with Mudlet's Package Manager - that is the whole install. Svof used to ship as 24 modules that had to be added in the Module Manager and kept synced from an unzipped folder; it is one package now, and none of that is needed. If you are coming from a module install, Svof removes the old modules for you on first run and leaves your xml files on disk untouched.

Full instructions are [here](https://github.com/svof/svof/blob/in-client-svof/doc/index.rst#installing).

# Documentation
See [documentation](https://svof.github.io/svof/) on how to install, use, and take advantage of the powerful system in your scripts.

# Contributing
1. Read the [Developer Readme](https://github.com/svof/svof/blob/in-client-svof/Developer_readme.md) for an introduction and useful how-tos.
1. Create or login to your github account.
2. Create a fork of the [svof repository](https://github.com/svof/svof) (It's in the top right corner)
3. Switch to the in-client-svof branch, it's in the drop down menu below Commits.
4. Clone your fork.
5. Make your changes under `src/` - that is the source of truth. Each trigger, alias and script is its own `.lua` file, with its settings in the `.json` beside it.
6. Build the package with [muddler](https://github.com/demonnic/muddler) and install the resulting `build/svof.mpackage` to test it in Mudlet.
7. Commit the changed files.
8. Push the branch to your fork.
9. Open a pull request from it.
10. Add a title/description.
11. Check off "Create a new branch for this commit and start a pull request".
12. Name your branch.
13. Click propose changes.
14. Go through your changes, makes sure nothing is out of the ordinary. (Like it saying you changed the entire file)
15. Click compare across fork. Then switch the base repository to svof/svof - base: in-client-svof.
16. Click create pull request.
17. Wait for approval and it to be merged.
18. You've updated Svof, congratulations!

If you're looking for something to do, have a look at the existing [issues/features](https://github.com/svof/svof/issues) list, and have a [look at the wiki](https://github.com/svof/svof/wiki) on information about the project.

## License
Svof is licensed under [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/). Make sure you look at the license before using Svof source code!


# Authors
2011-2015, Vadim Peretokin.

2015+: you?
