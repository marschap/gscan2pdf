# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
 use PDF::API2;
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

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
    $slist->save_pdf( 'test.pdf', [ $slist->{data}[0][2] ],
     undef, \%options, undef, undef, undef, sub { Gtk2->main_quit } );
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
