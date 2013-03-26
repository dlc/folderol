folderol - A planet-like aggregator
===================================

`folderol` aggregates RSS and Atom feeds, and generates one or more
output files as a side-effect. It is config driven, using a
dosini-style config file that is modeled after [Planet][]'s config
file, although simpler. Unlike planet, it stores parsed feeds and
entries in a [sqlite][] database for fast retrieval.

One of the reasons I started writing this is because the Planet
codebase is a confusing mess and the documentation is atrocious,
inconsisnt, and downright incorrect, in many places. (This also goes
for the [Venus][] variant of Planet, as well.)

TODO
====

* Tests!
* Documentation
* Output, via the [Template Toolkit][tt]
* Example templates. Bleah.
* Eventual CPAN release, possibly.

  [Planet]: http://planetplanet.org/
  [Venus]: http://www.intertwingly.net/code/venus/
  [sqlite]: http://sqlite.org/
  [tt]: http://tt2.org/
