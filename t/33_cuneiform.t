# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN {
  use_ok('Gscan2pdf::Cuneiform');
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

SKIP: {
 skip 'Cuneiform not installed', 1 unless Gscan2pdf::Cuneiform->setup;

 use Log::Log4perl qw(:easy);
 Log::Log4perl->easy_init($DEBUG);
 our $logger = Log::Log4perl::get_logger;
 my $prog_name = 'gscan2pdf';
 use Locale::gettext 1.05;    # For translations
 our $d = Locale::gettext->domain($prog_name);

 # Create test image
 system('convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.bmp');

 my $got = Gscan2pdf::Cuneiform->hocr('test.bmp', 'eng');

 like( $got, qr/The quick brown fox/, 'Cuneiform returned sensible text' );

 unlink 'test.bmp';
}
