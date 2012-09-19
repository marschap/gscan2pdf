use warnings;
use strict;
use Test::More tests => 16;
use Glib 1.210 qw(TRUE FALSE);
use Gtk2 -init;    # Could just call init separately

BEGIN {
 use_ok('Gscan2pdf::Document');
}

#########################

Glib::set_application_name('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
our $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

my $slist = Gscan2pdf::Document->new;
is( $slist->pages_possible( 1, 1 ),
 -1, 'pages_possible infinite forwards in empty document' );
is( $slist->pages_possible( 2, -1 ),
 2, 'pages_possible finite backwards in empty document' );

$slist->{data}[0][0] = 2;
is( $slist->pages_possible( 2, 1 ), 0,
 'pages_possible 0 due to existing page' );
is( $slist->pages_possible( 1, 1 ),
 1, 'pages_possible finite forwards in non-empty document' );
is( $slist->pages_possible( 1, -1 ),
 1, 'pages_possible finite backwards in non-empty document' );

$slist->{data}[0][0] = 1;
is( $slist->pages_possible( 2, 1 ),
 -1, 'pages_possible infinite forwards in non-empty document' );

$slist->{data}[0][0] = 1;
$slist->{data}[1][0] = 3;
$slist->{data}[2][0] = 5;
is( $slist->pages_possible( 2, 1 ),
 1, 'pages_possible finite forwards starting in middle of range' );
is( $slist->pages_possible( 2, -1 ),
 1, 'pages_possible finite backwards starting in middle of range' );
is( $slist->pages_possible( 6, -2 ),
 3, 'pages_possible finite backwards starting at end of range' );

#########################

is( $slist->valid_renumber( 1, 1, 'all' ), TRUE, 'valid_renumber all step 1' );
is( $slist->valid_renumber( 3, -1, 'all' ),
 TRUE, 'valid_renumber all start 3 step -1' );
is( $slist->valid_renumber( 2, -1, 'all' ),
 FALSE, 'valid_renumber all start 2 step -1' );

$slist->select(0);
is( $slist->valid_renumber( 1, 1, 'selected' ),
 TRUE, 'valid_renumber selected ok' );
is( $slist->valid_renumber( 3, 1, 'selected' ),
 FALSE, 'valid_renumber selected nok' );

#########################

$slist->renumber( 1, 1, 'all' );
is_deeply(
 $slist->{data},
 [ [ 1, undef, undef ], [ 2, undef, undef ], [ 3, undef, undef ] ],
 'renumber start 1 step 1'
);

#########################

Gscan2pdf::Document->quit();
