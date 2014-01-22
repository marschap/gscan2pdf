use warnings;
use strict;
use Test::More tests => 3;
use File::Path qw(remove_tree);

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

Gscan2pdf::Document->setup(Log::Log4perl::get_logger);
my $slist = Gscan2pdf::Document->new;
my $dir = File::Spec->catfile( File::Spec->tmpdir, 'gscan2pdf-tmp' );
$slist->set_dir($dir);
$slist->open_session($dir);

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

$slist = Gscan2pdf::Document->new;
unlink File::Spec->catfile( $dir, 'session' );
$slist->set_dir($dir);
$slist->open_session( undef, undef,
 sub { pass('trapped missing session file') } );

#########################

Gscan2pdf::Document->quit;
remove_tree($dir);
