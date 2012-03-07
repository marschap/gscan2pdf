# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf;
 use Gscan2pdf::Document;
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# Thumbnail dimensions
our $widtht  = 100;
our $heightt = 100;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
our $logger = Log::Log4perl::get_logger;
my $prog_name = 'gscan2pdf';
use Locale::gettext 1.05;    # For translations
our $d = Locale::gettext->domain($prog_name);

my $slist = Gscan2pdf::Document->new;
$slist->open_session('tmp');

is( -s $slist->{data}[0][2]{filename},
 6936, 'PNG extracted with expected size' );
is(
 $slist->{data}[0][2]{hocr},
 'The quick brown fox',
 'Basic OCR output extracted'
);

#########################

unlink <tmp/*>;
rmdir 'tmp';
