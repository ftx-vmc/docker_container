#!/usr/bin/perl -w
use strict;

my $group_name = $ARGV[0];

open(GROUPS, '/etc/group');
my $gid = (split /:/, (grep /^$group_name:/, <GROUPS>)[0])[2];
close GROUPS;

print $gid, "\n";
exit;
