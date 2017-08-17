use warnings;
use strict;
use Gtk2 -init;
use Test::More tests => 7;

BEGIN {
    use_ok('Gscan2pdf::PageRange');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
ok( my $range = Gscan2pdf::PageRange->new, 'Created PageRange widget' );
isa_ok( $range, 'Gscan2pdf::PageRange' );

is( $range->get('active'), 'selected', 'selected' );

my $range2 = Gscan2pdf::PageRange->new;
is( $range2->get_active, 'selected', 'selected2' );
$range2->set_active('all');
is( $range2->get_active, 'all', 'all' );
is( $range->get_active,  'all', 'all2' );

#########################

__END__
