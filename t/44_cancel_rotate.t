use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.jpg');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

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
     angle              => 90,
     page               => $slist->{data}[0][2],
     cancelled_callback => sub {
      is(
       -s 'test.jpg',
       -s "$slist->{data}[0][2]{filename}",
       'image not rotated'
      );
      $slist->save_image(
       path              => 'test2.jpg',
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

is( system('identify test2.jpg'),
 0, 'can create a valid JPG after cancelling previous process' );

#########################

unlink 'test.jpg', 'test2.jpg';
Gscan2pdf::Document->quit();
