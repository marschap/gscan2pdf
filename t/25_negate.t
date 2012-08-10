use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use_ok('Gscan2pdf::Document');
 use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
our $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert xc:white white.pnm');

my $slist = Gscan2pdf::Document->new;
$slist->get_file_info(
 path              => 'white.pnm',
 finished_callback => sub {
  my ($info) = @_;
  $slist->import_file(
   info              => $info,
   first             => 1,
   last              => 1,
   finished_callback => sub {
    $slist->negate(
     $slist->{data}[0][2],
     undef, undef, undef,
     sub {
      $slist->analyse(
       page              => $slist->{data}[0][2],
       finished_callback => sub { Gtk2->main_quit }
      );
     }
    );
   }
  );
 }
);
Gtk2->main;

is( $slist->{data}[0][2]{mean}, 0, 'Found dark page' );

#########################

unlink 'white.pnm';
Gscan2pdf::Document->quit();
