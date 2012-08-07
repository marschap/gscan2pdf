# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 4;

BEGIN {
 use_ok('Gscan2pdf');
 use_ok('Gscan2pdf::Document');
 use Gtk2 -init;    # Could just call init separately
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
our $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.jpg');

my $slist = Gscan2pdf::Document->new;
$slist->get_file_info(
 path              => 'test.jpg',
 finished_callback => sub {
  my ($info) = @_;
  $slist->import_file(
   $info, 1, 1, undef, undef, undef,
   sub {
    $slist->crop(
     $slist->{data}[0][2],
     10, 10, 10, 10, undef, undef, undef,
     sub {
      $slist->save_image( 'test2.jpg', [ $slist->{data}[0][2] ],
       undef, undef, undef, sub { Gtk2->main_quit } );
     }
    );
   }
  );
 }
);
Gtk2->main;

is( system('identify test2.jpg'), 0, 'valid JPG created' );
cmp_ok(
 -s 'test2.jpg',
 '<',
 -s 'test.jpg',
 'cropped JPG smaller than original'
);

#########################

unlink 'test.jpg', 'test2.jpg';
Gscan2pdf::Document->quit();
