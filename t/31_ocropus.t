# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
BEGIN {
  use_ok('Gscan2pdf::Ocropus');
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
 skip 'Ocropus not installed', 1 unless Gscan2pdf::Ocropus->setup;

 # Create test image
 system('convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.png');

 my $got = Gscan2pdf::Ocropus->hocr('test.png', 'eng');
 like( $got, qr/The quick brown fox/, 'Ocropus returned sensible text' );

 unlink 'test.png';
}

done_testing();
