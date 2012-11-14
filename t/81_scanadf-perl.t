use warnings;
use strict;
use Test::More tests => 1;

#########################

SKIP: {
 skip 'scanadf v1.0.14 not installed', 1
   unless ( `scanadf --version` eq "scanadf (sane-frontends) 1.0.14\n" );

 my $output = `perl bin/scanadf-perl --device=test --help`;
 $output =~ s/scanadf-perl/scanadf/g;

 my $example = `scanadf --device=test --help`;

 my @output  = split( "\n", $output );
 my @example = split( "\n", $example );
 is_deeply( \@output, \@example, "basic help functionality" );
}
