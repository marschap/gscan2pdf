# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

SKIP: {
 skip 'gocr not installed', 1
   unless ( system("which gocr > /dev/null 2> /dev/null") == 0 );

 use Log::Log4perl qw(:easy);
 Log::Log4perl->easy_init($WARN);
 our $logger = Log::Log4perl::get_logger;
 Gscan2pdf::Document->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.pnm'
 );

 my $slist = Gscan2pdf::Document->new;
 $slist->get_file_info(
  'test.pnm',
  undef, undef, undef,
  sub {
   my ($info) = @_;
   $slist->import_file(
    $info, 1, 1, undef, undef, undef,
    sub {
     my $pid = $slist->gocr(
      $slist->{data}[0][2],
      undef, undef, undef, undef, undef, undef,
      sub {
       is( $slist->{data}[0][2]{hocr}, undef, 'no OCR output' );
       $slist->save_image( 'test.jpg', [ $slist->{data}[0][2] ],
        undef, undef, undef, sub { Gtk2->main_quit } );
      }
     );
     $slist->cancel($pid);
    }
   );
  }
 );
 Gtk2->main;

 is( system('identify test.jpg'),
  0, 'can create a valid JPG after cancelling previous process' );

 unlink 'test.pnm', 'test.jpg';
 Gscan2pdf::Document->quit();
}
