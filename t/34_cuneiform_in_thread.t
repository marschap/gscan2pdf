# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use_ok('Gscan2pdf::Cuneiform');
 use Gtk2 -init;    # Could just call init separately
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

SKIP: {
 skip 'Cuneiform not installed', 1 unless Gscan2pdf::Cuneiform->setup;

 use Log::Log4perl qw(:easy);
 Log::Log4perl->easy_init($WARN);
 our $logger = Log::Log4perl::get_logger;
 Gscan2pdf::Document->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.bmp'
 );

 my $slist = Gscan2pdf::Document->new;
 $slist->get_file_info(
  'test.bmp',
  undef, undef, undef,
  sub {
   my ($info) = @_;
   $slist->import_file(
    $info, 1, 1, undef, undef, undef,
    sub {
     $slist->cuneiform(
      $slist->{data}[0][2],
      'eng', undef, undef, undef,
      sub {
       like(
        $slist->{data}[0][2]{hocr},
        qr/The quick brown fox/,
        'Cuneiform returned sensible text'
       );
       Gtk2->main_quit;
      }
     );
    }
   );
  }
 );
 Gtk2->main;

 unlink 'test.bmp';
 Gscan2pdf::Document->quit();
}
