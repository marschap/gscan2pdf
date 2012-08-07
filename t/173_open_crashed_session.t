# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use Gtk2 -init;    # Could just call init separately
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

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

unlink <tmp/*>;
rmdir 'tmp';
Gscan2pdf::Document->quit;
