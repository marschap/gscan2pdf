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
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;
$slist->get_file_info(
 path              => 'test.pnm',
 finished_callback => sub {
  my ($info) = @_;
  $slist->import_file(
   info              => $info,
   first             => 1,
   last              => 1,
   finished_callback => sub {
    my $md5sum = `md5sum $slist->{data}[0][2]{filename} | cut -c -32`;
    my $pid    = $slist->to_png(
     page               => $slist->{data}[0][2],
     cancelled_callback => sub {
      is(
       $md5sum,
       `md5sum $slist->{data}[0][2]{filename} | cut -c -32`,
       'image not modified'
      );
      $slist->save_image(
       path              => 'test.jpg',
       list_of_pages     => [ $slist->{data}[0][2] ],
       finished_callback => sub { Gtk2->main_quit }
      );
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

#########################

unlink 'test.pnm', 'test.jpg';
Gscan2pdf::Document->quit();
