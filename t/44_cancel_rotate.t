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
   info              => $info,
   first             => 1,
   last              => 1,
   finished_callback => sub {
    my $pid = $slist->rotate(
     90,
     $slist->{data}[0][2],
     undef, undef, undef, undef, undef, undef,
     sub {
      is(
       -s 'test.jpg',
       -s "$slist->{data}[0][2]{filename}",
       'image not rotated'
      );
      $slist->save_image( 'test2.jpg', [ $slist->{data}[0][2] ],
       undef, undef, undef, sub { Gtk2->main_quit } );
     }
    );
    $slist->cancel($pid);
   }
  );
 }
);
Gtk2->main;

is( system('identify test2.jpg'),
 0, 'can create a valid JPG after cancelling previous process' );

#########################

unlink 'test.jpg', 'test2.jpg';
Gscan2pdf::Document->quit();
