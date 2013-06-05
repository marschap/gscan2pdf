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

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->get_file_info(
 path              => 'test2.tif',
 finished_callback => sub {
  my ($info) = @_;
  is( $info->{pages}, 2, 'found 2 pages' );
  Gtk2->main_quit;
 }
);
Gtk2->main;

#########################

unlink 'test.tif', 'test2.tif', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
