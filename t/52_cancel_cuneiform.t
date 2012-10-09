use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use Gscan2pdf::Cuneiform;
 use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

SKIP: {
 skip 'Cuneiform not installed', 2 unless Gscan2pdf::Cuneiform->setup($logger);

 Gscan2pdf::Document->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.png'
 );

 my $slist = Gscan2pdf::Document->new;

 # dir for temporary files
 my $dir = File::Temp->newdir;
 mkdir($dir);
 $slist->set_dir($dir);

 $slist->get_file_info(
  path              => 'test.png',
  finished_callback => sub {
   my ($info) = @_;
   $slist->import_file(
    info              => $info,
    first             => 1,
    last              => 1,
    finished_callback => sub {
     my $pid = $slist->cuneiform(
      page               => $slist->{data}[0][2],
      language           => 'eng',
      cancelled_callback => sub {
       is( $slist->{data}[0][2]{hocr}, undef, 'no OCR output' );
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

 unlink 'test.png', 'test.jpg';
 Gscan2pdf::Document->quit();
}
