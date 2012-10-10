use warnings;
use strict;
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

# Create empty test image
system('touch test.ppm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->get_file_info(
 path           => 'test.ppm',
 error_callback => sub {
  my ($text) = @_;
  is(
   $text,
   'test.ppm is not a recognised image type',
   'message opening empty image'
  );
  Gtk2->main_quit;
 },
 finished_callback => sub {
  Gtk2->main_quit;
 }
);
Gtk2->main;

#########################

unlink 'test.ppm', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
