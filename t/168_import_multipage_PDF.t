use warnings;
use strict;
use File::Temp;
use Test::More tests => 1;

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
system('convert rose: test.tif');
system('tiffcp test.tif test.tif test2.tif');
system('tiff2pdf -o test2.pdf test2.tif');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->get_file_info(
 path              => 'test2.pdf',
 finished_callback => sub {
  my ($info) = @_;
  $slist->import_file(
   info              => $info,
   first             => 1,
   last              => 2,
   finished_callback => sub {
    is( $#{ $slist->{data} }, 1, 'imported 2 images' );
    Gtk2->main_quit;
   }
  );
 }
);
Gtk2->main;

#########################

unlink 'test.tif', 'test2.tif', 'test2.pdf', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
