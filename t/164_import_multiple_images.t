use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
 use File::Copy;
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: 1.tif');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

for my $i ( 1 .. 10 ) {
 copy( '1.tif', "$i.tif" ) if ( $i > 1 );
 $slist->get_file_info(
  path              => "$i.tif",
  finished_callback => sub {
   my ($info) = @_;
   $slist->import_file(
    info              => $info,
    first             => 1,
    last              => 1,
    finished_callback => sub {
     Gtk2->main_quit if ( $i == 10 );
    }
   );
  }
 );
}
Gtk2->main;

is( $#{ $slist->{data} }, 9, 'Imported 10 images' );

#########################

for my $i ( 1 .. 10 ) {
 unlink "$i.tif";
}
Gscan2pdf::Document->quit();
