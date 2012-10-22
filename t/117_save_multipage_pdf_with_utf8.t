use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
 use PDF::API2;
 use File::Copy;
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: 1.pnm');

# number of pages
my $n = 3;
my @pages;

my %options;
$options{font} = `fc-list : file | grep times.ttf | head -n 1`;
chomp $options{font};
$options{font} =~ s/: $//;

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

for my $i ( 1 .. $n ) {
 copy( '1.pnm', "$i.pnm" ) if ( $i > 1 );
 $slist->get_file_info(
  path              => "$i.pnm",
  finished_callback => sub {
   my ($info) = @_;
   $slist->import_file(
    info              => $info,
    first             => 1,
    last              => 1,
    finished_callback => sub {
     use utf8;
     $slist->{data}[ $i - 1 ][2]{hocr} =
       'пени способствовала сохранению';
     push @pages, $slist->{data}[ $i - 1 ][2];
     $slist->save_pdf(
      path              => 'test.pdf',
      list_of_pages     => \@pages,
      options           => \%options,
      finished_callback => sub { Gtk2->main_quit }
     ) if ( $i == $n );
    }
   );
  }
 );
}
Gtk2->main;

is( `pdffonts test.pdf | grep -c TrueType` + 0,
 1, 'font embedded once in multipage PDF' );

#########################

for my $i ( 1 .. $n ) {
 unlink "$i.pnm";
}
unlink 'test.pdf';
Gscan2pdf::Document->quit();
