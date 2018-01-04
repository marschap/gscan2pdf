use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 2;

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

# use fixed name in temporary directory to be able to pick it up as a crashed
# session in the next test
$slist->set_dir( File::Spec->catfile( File::Spec->tmpdir, 'gscan2pdf-tmp' ) );
$slist->open_session_file( info => 'test2.gs2p' );

# allow up to pick it up as a crashed session in next test
$slist->save_session;

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

#########################

unlink 'test2.gs2p';
Gscan2pdf::Document->quit;
