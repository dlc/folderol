folderol - A planet-like aggregator
===================================

`folderol` aggregates RSS and Atom feeds, and generates one or more
output files as a side-effect. It is config driven, using a
dosini-style config file that is modeled after [Planet][]'s config
file, although simpler. Unlike planet, it stores parsed feeds and
entries in a [sqlite][] database for fast retrieval.

One of the reasons I started writing this is because the Planet
codebase is a confusing mess and the documentation is inconsistent
and, in many places, downright incorrect. (This also goes for the
[Venus][] variant of Planet, as well.)

Technologies
============

`folderol` is built using Perl and the [Template Toolkit][tt2],
because that's what I'm [most comfortable with][ttbook] and because,
comparitively, all other templating systems are silly hacks.

The following module are required to run `folderol`, all of which
should be available via common packaging systems (I've confirmed
they're available in `macports`, `yum`, `apt-get`, and `zypper`) and
of course from [CPAN](http://www.cpan.org/):

* [XML::Feed](http://search.cpan.org/dist/XML-Feed/)
* [Template](http://search.cpan.org/dist/Template/)
* [DBI](http://search.cpan.org/dist/DBI/)
* [DBD::SQLite](http://search.cpan.org/dist/DBD-SQLite/)

TODO
====

* Tests!
* Documentation
* Example templates. Bleah.
* Eventual CPAN release, possibly.

  [Planet]: http://planetplanet.org/
  [Venus]: http://www.intertwingly.net/code/venus/
  [sqlite]: http://sqlite.org/
  [tt2]: http://tt2.org/
  [ttbook]: http://shop.oreilly.com/product/9780596004767.do
