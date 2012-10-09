use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
 use PDF::API2;
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
our $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.pnm');

my %options;
$options{font} = `fc-list : file | grep times.ttf`;
chomp $options{font};
$options{font} =~ s/: $//;

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
    use utf8;
    $slist->{data}[0][2]{hocr} =
      'пени способствовала сохранению';
    $slist->save_pdf(
     path              => 'test.pdf',
     list_of_pages     => [ $slist->{data}[0][2] ],
     options           => \%options,
     finished_callback => sub { Gtk2->main_quit }
    );
   }
  );
 }
);
Gtk2->main;

like(
 `pdftotext test.pdf -`,
 qr/пени способствовала сохранению/,
 'PDF with expected text'
);

#########################

unlink 'test.pnm', 'test.pdf';
Gscan2pdf::Document->quit();
