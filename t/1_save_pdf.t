# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 3;
BEGIN {
  use_ok('Gscan2pdf');
  use_ok('Gscan2pdf::Document');
  use PDF::API2;
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
Gscan2pdf->setup($d, $logger, \%SETTING);

# Create test image
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;
$slist->get_file_info( sub { $slist->import_file( 1, 1, sub {
  $slist->save_pdf('test.pdf', [ $slist->{data}[0][2] ], undef, sub {Gtk2->main_quit}, sub {}, sub {});
}, sub {}, sub {} ) }, sub {}, sub{}, 'test.pnm' );
Gtk2->main;

is( -s 'test.pdf', 3152, 'PDF created with expected size' );

#########################

unlink 'test.pnm', 'test.pdf';
Gscan2pdf->kill();
