use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 1;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;       # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(
'convert +matte -depth 1 -colorspace Gray -type Bilevel -pointsize 12 -density 300 label:"The quick brown fox" test.pdf'
);
system(
'convert +matte -depth 1 -colorspace Gray -type Bilevel -pointsize 12 -density 300 label:"The quick brown fox" test.png'
);
my $old = `identify -format '%m %G %g %z-bit %r' test.png`;

my $slist = Gscan2pdf::Document->new;

$slist->get_file_info(
 path              => 'test.pdf',
 finished_callback => sub {
  my ($info) = @_;
  $slist->import_file(
   info              => $info,
   first             => 1,
   last              => 1,
   finished_callback => sub {
    is( `identify -format '%m %G %g %z-bit %r' $slist->{data}[0][2]{filename}`,
     $old, 'PDF imported correctly' );
    Gtk2->main_quit;
   }
  );
 }
);
Gtk2->main;

#########################

unlink 'test.pdf', 'test.png';
Gscan2pdf::Document->quit();
