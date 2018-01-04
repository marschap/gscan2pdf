use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 4;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

Gscan2pdf::Document->setup(Log::Log4perl::get_logger);
my $slist = Gscan2pdf::Document->new;
my $dir   = File::Temp->newdir;
$slist->set_dir($dir);
$slist->open_session_file( info => 'test.gs2p' );

like(
    `file $slist->{data}[0][2]{filename}`,
    qr/PNG image data, 70 x 46, 8-bit\/color RGB, non-interlaced/,
    'PNG extracted with expected size'
);
is(
    $slist->{data}[0][2]{hocr},
    'The quick brown fox',
    'Basic OCR output extracted'
);

# Add another image to test behaviour with multiple saves
system('convert rose: test.pnm');

$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->save_session('test2.gs2p');
        Gtk3->main_quit;
    }
);
Gtk3->main;

is(
    `file test2.gs2p`,
    "test2.gs2p: gzip compressed data\n",
    'Session file created'
);
cmp_ok( -s 'test2.gs2p', '>', 0, 'Non-empty Session file created' );

#########################

Gscan2pdf::Document->quit;
unlink 'test.gs2p', 'test.pnm';
