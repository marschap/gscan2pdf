use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;       # Could just call init separately
}

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
Gscan2pdf::Document->setup(Log::Log4perl::get_logger);

# Create test image
system('convert xc:white white.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
mkdir($dir);
$slist->set_dir($dir);

$slist->get_file_info(
 path              => 'white.pnm',
 finished_callback => sub {
  my ($info) = @_;
  $slist->import_file(
   info              => $info,
   first             => 1,
   last              => 1,
   finished_callback => sub {
    $slist->user_defined(
     page              => $slist->{data}[0][2],
     command           => 'convert %i -negate %o',
     finished_callback => sub {
      $slist->analyse(
       page              => $slist->{data}[0][2],
       finished_callback => sub {
        is( $slist->{data}[0][2]{mean}, 0, 'User-defined with %i and %o' );
        is( dirname("$slist->{data}[0][2]{filename}"),
         "$dir", 'using session directory' );
        Gtk2->main_quit;
       }
      );
     }
    );
   }
  );
 }
);
Gtk2->main;

#########################

unlink 'white.pnm', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
