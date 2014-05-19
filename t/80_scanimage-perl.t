use warnings;
use strict;
use Test::More tests => 3;

#########################

ok( !system('perl bin/scanimage-perl --device=test --test > /dev/null 2>&1'),
    'test' );

#########################

SKIP: {
    skip 'scanimage v1.0.23 not installed', 2
      unless ( `scanimage --version` eq
        "scanimage (sane-backends) 1.0.23; backend version 1.0.23\n" );

    my $output = `perl bin/scanimage-perl --device=test --help`;
    $output =~ s/scanimage-perl/scanimage/g;

    my $example = `scanimage --device=test --help`;

    my @output  = split( "\n", $output );
    my @example = split( "\n", $example );
    is_deeply( \@output, \@example, "basic help functionality" );

#########################

    $output = `perl bin/scanimage-perl --device=test --all`;
    $output =~ s/scanimage-perl/scanimage/g;

    $example = `scanimage --device=test --all`;

    @output  = split( "\n", $output );
    @example = split( "\n", $example );
    is_deeply( \@output, \@example, "all options" );
}
