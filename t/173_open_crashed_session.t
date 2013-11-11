use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

Gscan2pdf::Document->setup(Log::Log4perl::get_logger);
my $slist = Gscan2pdf::Document->new;
$slist->open_session('tmp');

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

Gscan2pdf::Document->quit;
