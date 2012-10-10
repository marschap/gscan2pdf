use warnings;
use strict;
use Test::More tests => 1;
use Gtk2 -init;    # Could just call init separately
use POSIX qw(locale_h);

BEGIN {
 use Gscan2pdf::Document;
 use PDF::API2;
}

#########################

setlocale( LC_NUMERIC, "de_DE" );
Glib::set_application_name('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
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
    $slist->save_pdf(
     path              => 'test.pdf',
     list_of_pages     => [ $slist->{data}[0][2] ],
     finished_callback => sub { Gtk2->main_quit }
    );
   }
  );
 }
);
Gtk2->main;

is( system('identify test.pdf'), 0, 'valid PDF created' );

#########################

unlink 'test.pnm', 'test.pdf';
Gscan2pdf::Document->quit();
