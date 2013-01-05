This is BliStr 0.1, a system for automated development of new E prover
strategies.

INSTALL: in this directory, run

 ./setupdirs.sh installdir

Then go to installdir/bin, set the $grootdir variable in BliStr.pl to
installdir, possibly modify the parameters above $grootdir, and run
Blistr.pl. When BliStr finishes, the new strategies are in
installdir/prots.

PREREQUISITES:

The binary "eprover1.6tst2" (E 1.6 will do) needs to be in path and
executable. GNU Parallel (http://www.gnu.org/software/parallel/) needs
to be in path and executable. If not, modify the EvalStrat function. A
12-core machine is assumed for the global high-limit evaluations,
again see EvalStrat.

CONTACT: Josef Urban (firstname dot lastname at gmail dot com)
