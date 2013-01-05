#!/usr/bin/perl

use strict;

# --definitional-cnf=24 --tstp-in --oriented-simul-paramod --forward-context-sr --destructive-er-aggressive --destructive-er --prefer-initial-clauses -winvfreqrank -c1 -Ginvfreq -F1 --delete-bad-limit=150000000 -WSelectMaxLComplexAvoidPosPred -H'(4*ConjectureRelativeSymbolWeight(SimulateSOS,0.5, 100, 100, 100, 100, 1.5, 1.5, 1),3*ConjectureRelativeSymbolWeight(PreferNonGoals,0.5, 100, 100, 100, 100, 1.5, 1.5, 1),1*Clauseweight(PreferProcessed,1,1,1),1*FIFOWeight(PreferProcessed))' -s --print-statistics --print-pid --resources-info --memory-limit=192


my %heurs =
(
'crswcp' => 'ConjectureRelativeSymbolWeight(ConstPrio,0.1, 100, 100, 100, 100, 1.5, 1.5, 1.5)',
'crswsos' => 'ConjectureRelativeSymbolWeight(SimulateSOS,0.5, 100, 100, 100, 100, 1.5, 1.5, 1)',
'crswng' => 'ConjectureRelativeSymbolWeight(PreferNonGoals,0.5, 100, 100, 100, 100, 1.5, 1.5, 1)',
'cswcp' => 'ConjectureSymbolWeight(ConstPrio,10,10,5,5,5,1.5,1.5,1.5)',
'rwsos' => 'Refinedweight(SimulateSOS,1,1,2,1.5,2)',
'cwbcd' => 'Clauseweight(ByCreationDate,2,1,0.8)',
'rwng' => 'Refinedweight(PreferNonGoals,1,1,2,1.5,1.5)',
'cwproc' => 'Clauseweight(PreferProcessed,1,1,1)',
'cwcp' => 'Clauseweight(ConstPrio,3,1,1)',
'rwpgg' => 'Refinedweight(PreferGroundGoals,2,1,2,1.0,1)',
'fwcp' => 'FIFOWeight(ConstPrio)',
'fwproc' => 'FIFOWeight(PreferProcessed)'
);


# ILS params to E params
my %other =
(
 'prord' => '-G',
 'tord' => '-t',
 'sel' => '-W',
 'splaggr' => '--split-aggressive',
 'srd' => '--split-reuse-defs',
 'simparamod' => '--simul-paramod',
 'splcl' => '--split-clauses=',
 'forwardcntxtsr' => '--forward-context-sr'
);

# This is just a Perl version of the Ruby code in e_wrapper1.rb .
# translate a line of ILS params into E strategy
# the line is a space separated list of params - value pairs lik
# zz-my22simple:
# crswcp 8 crswng 6 crswsos 0 cswcp 0 cwbcd 1 cwcp 12 cwproc 0 forwardcntxtsr 0 fwcp 1 fwproc 2 prord invfreq rwng 0 rwpgg 10 rwsos 1 sel SelectComplexG simparamod normal splaggr 0 splcl 7 srd 1 tord Auto
#
# which is
# my22simple:
# eprover1.6tst2 -s -R --memory-limit=Auto --print-statistics --definitional-cnf=24 --tstp-format --split-clauses=7 --simul-paramod --forward-context-sr --destructive-er-aggressive --destructive-er --prefer-initial-clauses -tAuto -winvfreqrank -c1 -Ginvfreq -F1 --delete-bad-limit=150000000 -WSelectComplexG -H'(1*FIFOWeight(ConstPrio),6*ConjectureRelativeSymbolWeight(PreferNonGoals,0.5, 100, 100, 100, 100, 1.5, 1.5, 1),8*ConjectureRelativeSymbolWeight(ConstPrio,0.1, 100, 100, 100, 100, 1.5, 1.5, 1.5),2*FIFOWeight(PreferProcessed),1*Refinedweight(SimulateSOS,1,1,2,1.5,2))' --cpu-limit=3 /local/data/mptp/ec/paramils2.3.5-source/example_data/e1/MZT538+1.p
sub ILS2E
{
    my ($strILS) = @_;

    my @lILS = split(/ +/, $strILS);

    my $i=0;
    my @prmsILS = ();
    my @valsILS = ();

    while ($i < $#lILS)
    {
	push(@prmsILS, $lILS[$i]);
	push(@valsILS, $lILS[$i+1]);
	$i = $i+2;
    }

    my @heurparms = ();
    my @otherparms = ();
    my $strE = '';

    foreach my $i (0 .. $#prmsILS)
    {
	my $p = $prmsILS[$i];
	my $v = $valsILS[$i];

	if(exists $heurs{$p})
	{
	  unless($v eq '0')
	  {
	    my $res = $v . '*' . $heurs{$p};
	    push(@heurparms, $res);
	  }
	}
	elsif(exists $other{$p})
	{

	  my $ep0 = $other{$p};

	  if($p =~ m/^(splaggr|srd|forwardcntxtsr)$/)
	  {
	    push(@otherparms, $ep0) unless($v eq '0');
	  }
	  elsif($p =~ m/^splcl$/)
	  {
	    push(@otherparms, $ep0 . $v) unless($v eq '0');
	  }
	  elsif($p =~ m/^(tord|sel)$/)
	  {
	    push(@otherparms, $ep0 . $v);
	  }
	  elsif($p =~ m/^simparamod$/)
	  {
	    if($v eq 'oriented')
	    {
	      push(@otherparms, "--oriented-simul-paramod");
	    }
	    elsif(!($v eq 'none'))
	    {
	      push(@otherparms, $ep0);
	    }
	  }
	  elsif($p =~ m/^prord$/)
	  {
	    if($v eq 'invfreq')
	    {
	      push(@otherparms, "-winvfreqrank -c1 -Ginvfreq");
	    }
	    else
	    {
	      push(@otherparms, $ep0 . $v);
	    }
	  }
	}
	else { die "unknown param: $p:$_" }
      }

    my $heurstr = " -H'(" . join(",", @heurparms) . ")' ";
    my $otherstr = join(' ', @otherparms);

    my $params1 = ' --definitional-cnf=24 --destructive-er-aggressive --destructive-er --prefer-initial-clauses -F1 --delete-bad-limit=150000000 ' . $otherstr . $heurstr;

    return $params1;
#{splaggr_s} #{splcl_s} #{srd_s} #{simparamod_s} #{forwardcntxtsr_s}  -t#{tord} #{prord}  -W#{sel} -H'(" + heur + ")' --cpu-limit=#{cutoff_time} #{infilename}"

}

while(<>)
{
    chomp;
    print ILS2E($_);
}
