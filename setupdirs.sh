#!/bin/bash
# run as ./setupdirs.sh /home/mptp/big/blistr2 
if [ -z "$1" ]; then echo "install dir required"; exit 1; fi
distrdir=`pwd`
mkdir $1; mkdir $1/bin
tar xzf trainingproblems.tar.gz -C$1
tar xzf initialresults.tar.gz  -C$1
cp -a BliStr.pl $1/bin/BliStr.pl 
cp -a prmils/params2str.pl $1/bin/params2str.pl
cd $1 
mv  trainingproblems allprobs
mv initialresults initprots
mkdir strats; mkdir prots
wget http://www.cs.ubc.ca/labs/beta/Projects/ParamILS/paramils2.3.5-source.zip
unzip paramils2.3.5-source.zip
ln -s paramils2.3.5-source paramils
cd paramils2.3.5-source
mkdir example_e1
cp -a $distrdir/prmils/e-params.txt example_e1/
cp -a $distrdir/prmils/e_wrapper1.rb example_e1/
tar xzf $distrdir/trainingproblems.tar.gz -Cexample_data
mv example_data/trainingproblems example_data/e1





