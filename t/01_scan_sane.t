# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;

BEGIN {
 use_ok('Gscan2pdf::Frontend::Sane');
 use Gtk2;
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
our $logger = Log::Log4perl::get_logger;
my $prog_name = 'gscan2pdf';
use Locale::gettext 1.05;    # For translations
our $d = Locale::gettext->domain($prog_name);
Gscan2pdf::Frontend::Sane->setup( $prog_name, $d, $logger );

SKIP: {
 if (
  eval {
   Gscan2pdf::Frontend::Sane->open_device(
    'test',
    sub { },
    sub { },
    sub {
     Gscan2pdf::Frontend::Sane->scan_pages(
      '.',
      'out%d.pnm',
      1, 1, 1,
      sub { },
      sub { },
      sub { },
      sub {
       is( -s 'out1.pnm', 30807, 'PNM created with expected size' );
       Gtk2->main_quit;
      }
     );
    }
   );
  }
   )
 {
  Gtk2->main;

#########################

  unlink 'out1.pnm';
 }
 else {
  skip 'SANE test backend not installed', 1;
 }
}

Gscan2pdf::Frontend::Sane->quit();
