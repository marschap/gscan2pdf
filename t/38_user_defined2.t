# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN {
  use Gscan2pdf;
  use Gscan2pdf::Document;
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# Thumbnail dimensions
our $widtht  = 100;
our $heightt = 100;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
our $logger = Log::Log4perl::get_logger;
my $prog_name = 'gscan2pdf';
use Locale::gettext 1.05;    # For translations
our $d = Locale::gettext->domain($prog_name);
Gscan2pdf->setup($d, $logger);

# Create test image
system('convert xc:white white.pnm');

my $slist = Gscan2pdf::Document->new;
$slist->get_file_info( 'white.pnm', sub {}, sub {}, sub {
 $slist->import_file( $Gscan2pdf::_self->{data_queue}->dequeue, 1, 1, sub {}, sub {}, sub {
  $slist->user_defined( $slist->{data}[0][2], 'convert %i -negate %i', sub {}, sub {}, sub {
   $slist->analyse( $slist->{data}[0][2], sub {}, sub {}, sub { Gtk2->main_quit });
  });
 })
});
Gtk2->main;

is( $slist->{data}[0][2]{mean}, 0, 'User-defined with %i' );

#########################

unlink 'white.pnm';
Gscan2pdf->quit();
