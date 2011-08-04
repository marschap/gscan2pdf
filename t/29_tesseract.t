# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 5;
BEGIN {
  use_ok('Gscan2pdf::Tesseract');
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
our $logger = Log::Log4perl::get_logger;
my $prog_name = 'gscan2pdf';
use Locale::gettext 1.05;    # For translations
our $d = Locale::gettext->domain($prog_name);

SKIP: {
 skip 'Tesseract not installed', 1 unless Gscan2pdf::Tesseract->setup;

 # Create test image
 system('convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.tif');

 my $got = Gscan2pdf::Tesseract->hocr('test.tif', 'eng');

 like( $got, qr/The/,   'Tesseract returned "The"' );
 like( $got, qr/quick/, 'Tesseract returned "quick"' );
 like( $got, qr/brown/, 'Tesseract returned "brown"' );
 like( $got, qr/fox/,   'Tesseract returned "fox"' );

 unlink 'test.tif';
}
