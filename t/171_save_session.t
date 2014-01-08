use warnings;
use strict;
use Test::More tests => 2;
use File::Basename;    # Split filename into dir, file, ext

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
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;
$slist->set_dir( File::Temp->newdir );
$slist->get_file_info(
 path              => 'test.pnm',
 finished_callback => sub {
  my ($info) = @_;
  $slist->import_file(
   info              => $info,
   first             => 1,
   last              => 1,
   finished_callback => sub {
    $slist->{data}[0][2]{hocr} = 'The quick brown fox';
    $slist->save_session('test.gs2p');
    Gtk2->main_quit;
   }
  );
 }
);
Gtk2->main;

is(
 `file test.gs2p`,
 "test.gs2p: gzip compressed data\n",
 'Session file created'
);
cmp_ok( -s 'test.gs2p', '>', 0, 'Non-empty Session file created' );

#########################

Gscan2pdf::Document->quit();
unlink 'test.pnm';
