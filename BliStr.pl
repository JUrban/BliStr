#!/usr/bin/perl -w

=head1 NAME

BliStr.pl (Grow new strategies for E prover by running ParamILS (local search) on suitable problem sets)

=head1 SYNOPSIS

# modify $grootdir and the params above it
# install by running the setupdir.sh script
# if starting with different strategies, describe them in %ginitstrnames
# then:

time ./BliStr.pl 

=head1 DESCRIPTION

BliStr is a system that automatically develops strategies for E prover
on a large set of problems. The main idea is to interleave (i)
iterated low-timelimit local search for new strategies on small sets
of similar easy problems with (ii) higher-timelimit evaluation of the
new strategies on all problems. The accummulated results of the global
higher-timelimit runs are used to evolve the definition of ``easy
similar'' sets of problems, and to control the selection of the next
strategy to be improved.

=head1 COPYRIGHT

Copyright (C) 2012-2013 Josef Urban (firstname dot lastname at gmail dot com)

=head1 LICENCE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut


use strict;
use File::Copy qw(copy);
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);

my $gtraintime = 1; # time for training runs of E in seconds
my $gtunertimeout = 400; # timeout for one PrmILS run
my $gtesttime  = 10; # time for testing runs in seconds
my $gmaxiter   = 100; # max number of the main loop iterations

# the root dir for operations
my $grootdir = '/home/mptp/big/blistr2';

# the diredtory with all problems and generated protokoll solutions 
my $gallprobs = "$grootdir/allprobs"; 

# the directory with initial (non-generated) protokoll solutions
# the protokolls will be copied to $gallprobs using the generated names
# their strategy descriptions have to exist in %ginitstrnames
my $ginitprots = "$grootdir/initprots"; 


# install with rootdir as $1 :
# mkdir $1; cd $1
# mkdir allprobs; mkdir strats; mkdir prots
# wget http://www.cs.ubc.ca/labs/beta/Projects/ParamILS/paramils2.3.5-source.zip
# unzip paramils2.3.5-source.zip
# cd paramils2.3.5-source
# mkdir example_data/e1
my $gPIdir = "$grootdir/paramils"; # /home/mptp/big/ec/paramils2.3.5-source';

# directory with the e1 subdirectory containing problems
# and .txt and tst files with problems selection
my $gPIexmpldir = $gPIdir . "/example_data";

# here are scenario files like 
# example_e1/scenario-protokoll_my17simple.10.txt
my $gPIscendir = $gPIdir . "/example_e1";

# the place to put finished strategies in
my $gstratsdir = "$grootdir/strats";

# the place to put E protokoll defs in
my $gprotsdir = "$grootdir/prots";

# the place with binaries
my $gbindir = "$grootdir/bin";

# directory to add to problem names
my $gprobprefix = 'example_data/e1'; # ecnf1

# problem name suffix
my $gprobsuffix = '.p'; # .p.leancop.cnf

# The number of top strategies we grow (N)
my $gmaxstrnr = 20; # shift;

# Minimal number of problems where the strategy should be best (versatility)
my $gminstrprobs = 8; # shift;

$gmaxstrnr = 20 unless(defined($gmaxstrnr));
$gminstrprobs = 8 unless(defined($gminstrprobs));

# prefix for strategy def files (in the paramils language)
my $gstrdefname = 'atpstr_my_';

# prefix for E protokoll def files (in E language)
my $gprotname = 'protokoll_' . $gstrdefname;

# this was a misunderstaning: numRun is just for bookkeeping
my $gN = 1; # the N parameter for paramils

# the initial set of strategies (now from E1.6pre's auto mode before CASC tuning)
# this sets covers 597 problems of  the MZT 1000
my %ginitstrnames =
    (
     'protokoll_G-E--_008_B31_F1_PI_AE_S4_CS_SP_S2S' => 'splaggr 1 splcl 4 simparamod normal forwardcntxtsr 1 tord LPO4 prord invfreqconstmin sel SelectNewComplexAHP crswcp 10 fwcp 1 rwsos 0 rwng 0 cwproc 0 fwproc 0',
     'protokoll_G-E--_008_K18_F1_PI_AE_CS_SP_S0Y' => 'splaggr 0 simparamod normal forwardcntxtsr 1 prord invfreq sel SelectMaxLComplexAvoidPosPred crswcp 10 fwcp 1 rwsos 0 rwng 0 cwproc 0 fwproc 0',
     'protokoll_G-E--_010_B02_F1_PI_AE_S4_CS_SP_S0Y' => 'splaggr 1 splcl 4 simparamod normal forwardcntxtsr 1 tord LPO4 prord arity sel SelectMaxLComplexAvoidPosPred crswsos 4 crswng 3 cwproc 1 fwproc 1 rwsos 0 rwng 0',
     'protokoll_G-E--_024_B07_F1_PI_AE_Q4_CS_SP_S0Y' => 'splaggr 0 srd 1 splcl 4 simparamod normal forwardcntxtsr 1 tord LPO4 prord invfreq sel SelectMaxLComplexAvoidPosPred crswsos 4 crswng 3 cwproc 1 fwproc 1 rwsos 0 rwng 0',
     'protokoll_G-E--_045_B31_F1_PI_AE_S4_CS_SP_S0Y' => 'splaggr 1 splcl 4 simparamod normal forwardcntxtsr 1 tord LPO4 prord invfreqconstmin sel SelectMaxLComplexAvoidPosPred rwsos 4 rwng 3 cwproc 1 fwproc 1',
     'protokoll_G-E--_045_K18_F1_PI_AE_CS_OS_S0S' => 'splaggr 0 simparamod oriented forwardcntxtsr 1 prord invfreq sel SelectComplexG rwsos 4 rwng 3 cwproc 1 fwproc 1'
    );


# initialize with the covering strategies
my %gstrnames = %ginitstrnames;

# old manually grown strategies - use for comparison
my %gstrnames_old = 
    (
     'protokoll_my22simple' => 'zz-my22simple',
     'protokoll_my21simple' => 'zz-my21simple',
     'protokoll_my20simple' => 'zz-my20simple',
     'protokoll_my19simple' => 'zz-my19simple',
     'protokoll_my17simple' => 'zz36',
     'protokoll_my18simple' => 'zz-my18simple',
     'protokoll_my18simple_KBO' => 'zz-my18simple_KBO',
     'protokoll_my9simple' => 'zz23',
     'protokoll_my5simple' => 'zz13',

     'protokoll_cnf_my22simple' => 'zz-my22simple',
     'protokoll_cnf_my21simple' => 'zz-my21simple',
     'protokoll_cnf_my20simple' => 'zz-my20simple',
     'protokoll_cnf_my19simple' => 'zz-my19simple',
     'protokoll_cnf_my17simple' => 'zz36',
     'protokoll_cnf_my18simple' => 'zz-my18simple',
     'protokoll_cnf_my18simple_KBO' => 'zz-my18simple_KBO',
     'protokoll_cnf_my9simple' => 'zz23',
     'protokoll_cnf_my5simple' => 'zz13'
    );

# record the previous attempts
my %gtested = ();

# for each problem count of prmils runs weighted by the number of problems in each run
my %gprobruncnt = ();

# prefer diversity (explore & exploit)
my $gdiverse = 1;

sub LOG {print @_;}



# For each protokoll in $%v, print its hash of best-solved problems
# with their performance. Only do this for the problems withe
# performance between min and max.
sub PrintProbStr
{
    my ($v,$min,$max) = @_;
    foreach my $p (sort keys %$v) {
	print "\n$p:\n";
	foreach my $k (sort keys %{$v->{$p}}) {
	    print "$k:$v->{$p}{$k}\n" if(($v->{$p}{$k}>=$min) && ($v->{$p}{$k}<=$max));
	}
    }
}



# Print the scenario and training and testing files for all protokolls in %v.
sub PrintAllProbStrFiles
{
    my ($v,$iter,$min,$max) = @_;
    foreach my $p (sort keys %$v)
    {
	PrintProbStrFiles($v,$p,$iter,$min,$max);
    }
}

# Print the scenario and training and testing files for one protokoll.
# TODO: because we print here only min/max-limited problems, we could consider any solutions in TopStratProbs
sub PrintProbStrFiles
{
    my ($v,$p,$iter,$min,$max) = @_;
    PrintScenario($p,$iter);
    open(F,">$gPIexmpldir/$p.iter$iter.txt");
    open(F1,">$gPIexmpldir/$p.iter$iter.tst");
    foreach my $k (sort keys %{$v->{$p}})
    {
	if(($v->{$p}{$k}>=$min) && ($v->{$p}{$k}<=$max))
	{
	    print F ("$gprobprefix/", "$k", $gprobsuffix, "\n");
	    print F1 ("$gprobprefix/", "$k", $gprobsuffix, "\n");
	}
    }
    close(F); close (F1);
}

# the info about proiblems, protokolls, and perfomance in lines of form:
# MZT001+1.p.protokoll_my17simple:# Processed clauses                    : 51
#
# Returns the hash of the best strategies and the counts hash
sub TopStratProbs
{
    my ($maxstr,$minstrprobs,$min,$max) = @_;

    my %g = (); #  the best strategy name for a problem
    my %h = ();	#  best (lowest) score so far for each problem
    my %i = (); #  the second lowest score for each poblem
    my %j = (); #  the second best strategy name for a problem
    my %v = (); #  for each strategy keeps the names of best problems and their scores
    my %c = (); #  for each strategy the (adjusted) count of best solutions

    chdir $gallprobs;
    open(RESULTS,"ls | grep protokoll_ | xargs grep -l Theorem | xargs grep Processed|") or die;
    while (<RESULTS>)
    {
	m/^([^.]*)\..*protokoll_([^:]*).*: *(\d+)/ or die;
	if ((! exists($h{$1})) || ($h{$1} > $3))
	{
	    $i{$1}=$h{$1};
	    $j{$1}=$g{$1};
	    $h{$1} = $3;
	    $g{$1} = $2;
	}
    }
    close(RESULTS);

    my $allsolved = scalar(keys %h);
    LOG "TOTALSOLVED: $allsolved\n";

    # zero the $gprobruncnt of newly solved problems
    foreach my $pr (keys %h) { $gprobruncnt{$pr}=0 unless exists($gprobruncnt{$pr}); }

    # count the eligible best problems for each strategy
    # TODO: this means that we disregard the info about easy and very hard problems - could be problematic at some point

    foreach my $k (keys %g) { $c{$g{$k}}++ if( ($h{$k} >= $min) &&  ($h{$k}<=$max)); }

    #print %c,"\n";

    
    # if the eligible count is low, set it to 0 (will boost versatile strats)
    # TODO: after deleting, we could consider again the problems on which the deleted strategies were best

    foreach my $s (keys %c) { $c{$s}=0 if( $c{$s} < $minstrprobs ); }

    #print %c,"\n";

    # also take only best $maxstr strategies, set rest to 0

    my $cnt = 0;
    my @bestorder0 = sort {$c{$b} <=> $c{$a}} keys %c;
    my $bestpr = $bestorder0[0];
    my @bestorder = ();
    foreach my $s (@bestorder0) 
    { 
	$cnt++; 
	$c{$s}=0 if($cnt > $maxstr); 
	push(@bestorder,$s) unless($c{$s}==0);
    }
    
    #print %c,"\n";

    foreach my $k (sort keys %h)
    {
	$v{$g{$k}}{$k}=$h{$k} if(exists($c{$g{$k}}) && ($c{$g{$k}} > 0));
    }

    return (\@bestorder, \%v, \%h );
}


# Print the scenario file for an old strategy $str to be improved in iteration $iter
# $str is the content-based name
sub PrintScenario
{
    my ($str,$iter,$cT,$tT) = @_;

#	print "time ./param_ils_2_3_run.rb -numRun 0 -scenariofile $gPIscendir/scenario-$str.$iter.txt -N 10000 -validN 30 -init $gstratsdir/$str >$str.iter$iter.mylog & \n";

	open(F,">$gPIscendir/scenario-$str.iter$iter.txt");


	print F <<SCEN;
algo = ruby e_wrapper1.rb
execdir = example_e1
deterministic = 1
run_obj = runlength
overall_obj = mean
cutoff_time = $cT
cutoff_length = max
tunerTimeout = $tT
paramfile = example_e1/e-params.txt
outdir = example_e1/paramils-out
instance_file = example_data/$str.iter$iter.txt
test_instance_file = example_data/$str.iter$iter.tst
SCEN

	close(F);

}

# select suitable training problems
sub StrTrainProbs
{
    my ($str,$v,$h,$min,$max) = @_;
    my %res = ();
    foreach my $k (sort keys %{$v->{$str}})
    {
	if(($v->{$str}{$k}>=$min) && ($v->{$str}{$k}<=$max))
	{
	    $res{$k} = ();
	}
    }
    return \%res;
}

# return 1 if a strategy was already grown with a hash of problems
sub AlreadyTested
{
    my ($str,$probs) = @_;

    return 0 unless exists $gtested{$str};

    my $probsstr = join(',', sort keys %{$probs});

    return 0 unless exists $gtested{$str}{$probsstr};

    return 1;
}

# print scenario, train and test file for strategy $str in iteration $iter
# a strategy may be attempted in multiple iterations but we should make sure that
# it is with different test files
# this is a TODO
#
# Returns the number of problems used for running prmils
sub PrepareStrategy
{

    my ($str,$v,$h,$iter,$trainprobs) = @_;
    PrintScenario($str,$iter,$gtraintime,$gtunertimeout);
    open(F,">$gPIexmpldir/$str.iter$iter.txt");
    open(F1,">$gPIexmpldir/$str.iter$iter.tst");
    my $i = 0;
    foreach my $k (sort keys %{$trainprobs})
    {
	    print F ("$gprobprefix/", "$k", $gprobsuffix, "\n");
	    print F1 ("$gprobprefix/", "$k", $gprobsuffix, "\n");
	    $i++;
    }
    close(F); close (F1);
    return $i;
}


# RULES:
# 1. strategy is a string of prmils keys/values, it lives in a content-named file
# 2. protokoll is a corresponding string of E options, it inherits name from its strategy
# 3. new strategies are generated in prmils runs (iterations) from old ones
# 4. one prmils run is described by train files and a strategy
# 5. the prmils scenario and log are in scenario-e$iter.txt and $str.iter$iter.mylog

# grow (the current best) strategy on selected training problems by paramils
# Input: strategy, $iter, nr of test runs, $N
# Return: a strategy content name or 'notnew' or 'error'
# Side effects: creates the new strategy def in $gstratsdir/$gstrdefname$strsha1
#               and the new protokoll in $gprotsdir/$gprotname$strsha1
sub GrowStratILS
{

    my ($str,$iter,$testnr,$N) = @_;
    my $iter1 = $iter+1;
 # j=376; for i in `seq 1 12`; do cd prmils$i; ./param_ils_2_3_run.rb -numRun 0 -scenariofile example_e1/scenario-e-full$j.txt -N 20000 -validN $j > mylog$i 2>&1 & cd ..; done

# ./param_ils_2_3_run.rb -numRun 0 -scenariofile example_e1/scenario-$prot.$iter.txt -N 10000 -validN 30 -init $gstrnames{$prot} >$prot.$iter.mylog 
# ./param_ils_2_3_run.rb -numRun 0 -scenariofile example_e1/scenario-protokoll_my17simple.10.txt -N 10000 -validN 30 -init zz36 >protokoll_my17simple.10.mylog &
# ../scripts/param_ils_2_3_run.rb -numRun 0 -scenariofile example_e1/scenario-e8.txt -N 1000 -validN 6 -init zz29

    chdir $gPIdir;

    my $newstrparams = `$gPIdir/param_ils_2_3_run.rb -numRun $gN -scenariofile $gPIscendir/scenario-$str.iter$iter.txt  -validN $testnr -init $gstratsdir/$str | tee $str.iter$iter.mylog |  grep 'Active parameters:' | tail -n1`;

    if($newstrparams =~ m/.*Active parameters: */)
    {
	$newstrparams =~ s/.*Active parameters: *//;
	$newstrparams =~ s/,//g;
	$newstrparams =~ s/=/ /g;
	my $strsha1 = sha1_hex($newstrparams);
	my $newstr = $gstrdefname . $strsha1;
	my$strfnm = "$gstratsdir/$newstr";
	if(-e $strfnm)
	{
	    LOG "NEWSTR: not new: $strfnm\n";
	    return 'notnew';
	}
	else
	{
	    #Combined result: 188467.875
	    my $combres = `tac $str.iter$iter.mylog | grep -m1 'Combined result'`;

	    open(F,">$strfnm");
	    print F $newstrparams;
	    close(F);
	    `$gbindir/params2str.pl $strfnm > $gprotsdir/$gprotname$strsha1`;
	    print "NEWSTR: $newstr : $strfnm\n";
	    return $newstr;
	}
    }
    else
    {
	LOG "NEWSTR: error\n";
	return 'error';
    }
}

# evaluate on all .p problems a strategy $str with gtesttime 
# $ iter is unused now
sub EvalStrat
{
    my ($str,$iter) = @_;
    my $protnm = 'protokoll_' . $str;
    my $prot = `cat $gprotsdir/$protnm`;

    `cd $gallprobs; ls *.p | time parallel -j12 "eprover1.6tst2 -s -R --memory-limit=Auto --print-statistics --tstp-format $prot --cpu-limit=$gtesttime {} > {}.$protnm"`;

}

# Initialize the naming of existing strategies and protokolls
# Die if an protokoll is unknown
sub InitStratsProts
{
    chdir $ginitprots;
    my @all = glob("*.protokoll_*");
    my %prot2file = ();

    foreach my $_ (@all)
    {
	m/^(.*)\.(protokoll_.*)/ or die;
	my ($name,$prot) = ($1,$2);
	$prot2file{$prot}{$name}= ();
    }

    my $iter = 0;
    foreach my $prot (sort keys %prot2file)
    {
	exists $ginitstrnames{$prot} or die "Initial protokoll description needed: $prot";
	$iter++;

	my $strparams = $ginitstrnames{$prot};
	my $strsha1 = sha1_hex($strparams);
	my $newstr = $gstrdefname . $strsha1;
	my $strfnm = "$gstratsdir/$newstr";
	my $protnm = $gprotname . $strsha1;
	open(F,">$strfnm");
	print F $strparams;
	close(F);
	`$gbindir/params2str.pl $strfnm > $gprotsdir/$protnm`;
	LOG "INITSTR: $strparams : $strfnm\n";
	LOG "$prot ==> $protnm\n";
	foreach my $f (keys %{$prot2file{$prot}})
	{
	    copy("$f.$prot", "$gallprobs/$f.$protnm");
	}
    }
    return $iter;
}

# the main clistr loop
# starts from $i = # initial protocolls
sub Iterate
{
    my ($i)=@_;
    while($i < $gmaxiter)
    {
	$i++;
	LOG "ITER: $i\n";
	# in the current directory, find the best covering set
	my ($beststrs,$v,$h) = TopStratProbs($gmaxstrnr,$gminstrprobs,500,30000);

	# if diversity prefered, sort the strats by lowest avrg previous run nr 
	if($gdiverse == 1)
	{	    
	    my %tmp = ();
	    my %s = ();
	    foreach my $str (@$beststrs)
	    {
		my $trainprobs = StrTrainProbs($str,$v,$h,500,30000);
		$s{$str} = scalar(keys %{$trainprobs});
		$tmp{$str} = 0;
		foreach my $pr (keys %{$trainprobs})
		{
		    $tmp{$str} += $gprobruncnt{$pr};
		}
		if($tmp{$str} > 0)
		{		    
		    $tmp{$str} = $tmp{$str}/$s{$str};
		}
	    }

	    # prefer less-run and bigger size of training set
	    my @beststrs1 = sort { $tmp{$a} <=> $tmp{$b} || $s{$b} <=> $s{$a}} keys %tmp;
	    $beststrs = \@beststrs1;
	}

	LOG "TOPSTRATS:\n";
	PrintProbStr($v,500,30000);

#	PrintProbStrFiles($v,10,500,30000);

	# try to improve each of the top strategies until a new strategy is found
	my $j = 0;
      STR:
	while($j < $#{$beststrs})
	{
	    LOG "SUBITER $j\n";
	    my $trainprobs = StrTrainProbs($beststrs->[$j],$v,$h,500,30000);
	    if(AlreadyTested($beststrs->[$j],$trainprobs) == 1)
	    {
		$j++;
		next STR; 
	    }
	    my $testnr = PrepareStrategy($beststrs->[$j],$v,$h,$i,$trainprobs);
	    my $probsstr = join(',', sort keys %{$trainprobs});
	    LOG "Improving $beststrs->[$j] with $testnr problems: $probsstr\n";
	    my $improved = GrowStratILS($beststrs->[$j],$i,$testnr,$gN);
	   
	    # update the run stats
	    $gtested{$beststrs->[$j]}{$probsstr} = ();	    
	    foreach my $pr (keys %{$trainprobs})
	    {
		$gprobruncnt{$pr} += 1/$testnr;
	    }

	    if($improved eq 'error')
	    {
		die;
	    }
	    elsif($improved eq 'notnew') 
	    {
		# produced an old strat, prepare the next best
		$j++; $i++;
	    }
	    else
	    {
		# produced a new strat, evaluate and exit this inner loop
		EvalStrat($improved,$i+1);
		$j = 1+$#{$beststrs};
	    }
	}
    }
}

sub BliStr1
{
    my $i = InitStratsProts();
    Iterate($i);
}

my $i = InitStratsProts();

    Iterate(2);

# my ($beststrs,$v,$h) = TopStratProbs($gmaxstrnr,$gminstrprobs,500,30000);

# PrintProbStr($v,500,30000);

# PrintProbStrFiles($v,$beststrs->[0],10,500,30000);
