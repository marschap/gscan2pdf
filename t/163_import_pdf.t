use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use_ok('Gscan2pdf::Document');
 use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
our $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.pdf');
system('convert rose: test.png');

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
    system("cp $slist->{data}[0][2]{filename} test2.png");
    Gtk2->main_quit;
   }
  );
 }
);
Gtk2->main;

is( -s 'test.png', -s 'test2.png', 'PDF imported correctly' );

#########################

unlink 'test.pdf', 'test.png', 'test2.png';
Gscan2pdf::Document->quit();
