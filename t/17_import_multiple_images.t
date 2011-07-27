# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN {
  use Gscan2pdf;
  use Gscan2pdf::Document;
  use File::Copy;
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# Thumbnail dimensions
our $widtht  = 100;
our $heightt = 100;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
our $logger = Log::Log4perl::get_logger;
my $prog_name = 'gscan2pdf';
use Locale::gettext 1.05;    # For translations
our $d = Locale::gettext->domain($prog_name);
Gscan2pdf->setup($d, $logger);

# Create test image
system('convert rose: 1.tif');

my $slist = Gscan2pdf::Document->new;
for my $i (1 .. 10) {
 copy('1.tif', "$i.tif") if ($i > 1);
 $slist->get_file_info( "$i.tif", undef, undef, undef, sub {
  my ($info) = @_;
  $slist->import_file( $info, 1, 1, undef, undef, undef, sub {
   Gtk2->main_quit if ($i == 10);
  })
 });
}
Gtk2->main;

is( $#{$slist->{data}}, 9, 'Imported 10 images' );

#########################

for my $i (1 .. 10) {
 unlink "$i.tif";
}
Gscan2pdf->quit();
