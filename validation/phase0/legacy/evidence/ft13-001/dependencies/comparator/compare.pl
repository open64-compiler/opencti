#!/usr/bin/perl
use strict;
my ($test,$actual,$master)=@ARGV;
open(my $a,'<',$actual) or die "actual unavailable";
open(my $m,'<',$master) or die "master unavailable";
local $/;
my $left=<$a>;my $right=<$m>;
print "DiffPgmOut\n" if $left ne $right;
exit 0;
