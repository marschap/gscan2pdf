package Gscan2pdf::Translation;

use strict;
use warnings;
use Locale::gettext 1.05;    # For translations

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '2.1.0';

    use base qw(Exporter);
    %EXPORT_TAGS = ();       # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw( __ );
}

my $d;

sub set_domain {
    my ( $prog_name, $locale ) = @_;
    $d = Locale::gettext->domain($prog_name);
    if ( defined $locale ) { $d->dir($locale) }
    return;
}

# makes it easier to extract strings with xgettext, as using Locale::gettext's
# 'get' as a keyword picks up various false positives, whilst '__' is unique,
# and closer to C's semi-standard '_'.
sub __ {    ## no critic (ProhibitUnusedPrivateSubroutines)
    my ($string) = @_;
    return $d->get($string);
}

1;

__END__
