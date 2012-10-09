# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use Gscan2pdf::Unpaper;
 use Gtk2 -init;    # Could just call init separately
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

SKIP: {
 skip 'unpaper not installed', 2
   unless ( system("which unpaper > /dev/null 2> /dev/null") == 0 );
 my $unpaper =
   Gscan2pdf::Unpaper->new( { 'output-pages' => 2, layout => 'double' } );

 use Log::Log4perl qw(:easy);
 Log::Log4perl->easy_init($WARN);
 our $logger = Log::Log4perl::get_logger;
 Gscan2pdf::Document->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -border 2x2 -bordercolor black -pointsize 12 -density 300 label:"The quick brown fox" 1.pnm'
 );
 system(
'convert +matte -depth 1 -border 2x2 -bordercolor black -pointsize 12 -density 300 label:"The slower lazy dog" 2.pnm'
 );
 system('convert -size 100x100 xc:black black.pnm');
 system('convert 1.pnm black.pnm 2.pnm +append test.pnm');

 my $slist = Gscan2pdf::Document->new;

 # dir for temporary files
 my $dir = File::Temp->newdir;
 mkdir($dir);
 $slist->set_dir($dir);

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
     my $pid    = $slist->unpaper(
      page               => $slist->{data}[0][2],
      options            => $unpaper->get_cmdline,
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

 unlink 'test.pnm', '1.pnm', '2.pnm', 'black.pnm', 'test.jpg';
 Gscan2pdf::Document->quit();
}
