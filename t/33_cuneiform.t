# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 6;

BEGIN {
 use_ok('Gscan2pdf::Cuneiform');
 use Encode;
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

SKIP: {
 skip 'Cuneiform not installed', 5 unless Gscan2pdf::Cuneiform->setup;

 use Log::Log4perl qw(:easy);
 Log::Log4perl->easy_init($DEBUG);
 our $logger = Log::Log4perl::get_logger;
 my $prog_name = 'gscan2pdf';
 use Locale::gettext 1.05;    # For translations
 our $d = Locale::gettext->domain($prog_name);

 # Create test image
 system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.bmp'
 );

 my $got = Gscan2pdf::Cuneiform->hocr( 'test.bmp', 'eng' );

 like( $got, qr/The quick brown fox/, 'Cuneiform returned sensible text' );

 # Create test image
 system(
"convert +matte -depth 1 -pointsize 12 -density 300 label:'öÖäÄüÜß' test.bmp"
 );

 my $got = Gscan2pdf::Cuneiform->hocr( 'test.bmp', 'ger' );
 is( Encode::is_utf8( $got, 1 ), 1, "Cuneiform returned UTF8" );
 for my $c (qw( ö ä ü )) {
  my $c2 = decode_utf8($c);
  like( $got, qr/$c2/, "Cuneiform returned $c" );
 }

 unlink 'test.bmp';
}
