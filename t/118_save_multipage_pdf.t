# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
 use Gscan2pdf;
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
 use PDF::API2;
 use File::Copy;
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
our $logger = Log::Log4perl::get_logger;
Gscan2pdf->setup($logger);

# Create test image
system('convert rose: 1.pnm');

# number of pages
my $n = 3;
my @pages;

my $slist = Gscan2pdf::Document->new;
for my $i ( 1 .. $n ) {
 copy( '1.pnm', "$i.pnm" ) if ( $i > 1 );
 $slist->get_file_info(
  "$i.pnm", undef, undef, undef,
  sub {
   my ($info) = @_;
   $slist->import_file(
    $info, 1, 1, undef, undef, undef,
    sub {
     use utf8;
     $slist->{data}[ $i - 1 ][2]{hocr} = 'hello world';
     push @pages, $slist->{data}[ $i - 1 ][2];
     $slist->save_pdf( 'test.pdf', \@pages, undef, undef, undef, undef, undef,
      sub { Gtk2->main_quit } )
       if ( $i == $n );
    }
   );
  }
 );
}
Gtk2->main;

is( `pdffonts test.pdf | grep -c Times-Roman` + 0,
 1, 'font embedded once in multipage PDF' );

#########################

for my $i ( 1 .. $n ) {
 unlink "$i.pnm";
}
unlink 'test.pdf';
Gscan2pdf->quit();
