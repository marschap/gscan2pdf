use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 6;

BEGIN {
 use Gscan2pdf::Document;
 use_ok('Gscan2pdf::Tesseract');
 use Gtk2 -init;       # Could just call init separately
}

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

SKIP: {
 skip 'Tesseract not installed', 5 unless Gscan2pdf::Tesseract->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -colorspace Gray -pointsize 12 -density 300 label:"The quick brown fox" test.tif'
 );

 my $slist = Gscan2pdf::Document->new;

 # dir for temporary files
 my $dir = File::Temp->newdir;
 $slist->set_dir($dir);

 $slist->get_file_info(
  path              => 'test.tif',
  finished_callback => sub {
   my ($info) = @_;
   $slist->import_file(
    info              => $info,
    first             => 1,
    last              => 1,
    finished_callback => sub {
     $slist->tesseract(
      page              => $slist->{data}[0][2],
      language          => 'eng',
      finished_callback => sub {
       like( $slist->{data}[0][2]{hocr}, qr/The/, 'Tesseract returned "The"' );
       like( $slist->{data}[0][2]{hocr},
        qr/quick/, 'Tesseract returned "quick"' );
       like( $slist->{data}[0][2]{hocr},
        qr/brown/, 'Tesseract returned "brown"' );
       like( $slist->{data}[0][2]{hocr}, qr/fox/, 'Tesseract returned "fox"' );
       is( dirname("$slist->{data}[0][2]{filename}"),
        "$dir", 'using session directory' );
       Gtk2->main_quit;
      }
     );
    }
   );
  }
 );
 Gtk2->main;

 unlink 'test.tif', <$dir/*>;
 rmdir $dir;
}

Gscan2pdf::Document->quit();
