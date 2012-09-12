# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 7;

BEGIN {
 use_ok('Gscan2pdf::Ocropus');
 use Gscan2pdf::Tesseract;
 use Encode;
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

SKIP: {
 skip 'Ocropus not installed', 6 unless Gscan2pdf::Ocropus->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.png'
 );

 my $got = Gscan2pdf::Ocropus->hocr( 'test.png', 'eng' );
 like( $got, qr/The quick brown fox/, 'Ocropus returned sensible text' );

 skip 'Tesseract not installed', 5 unless Gscan2pdf::Tesseract->setup($logger);
 my $languages = Gscan2pdf::Tesseract->languages;
 skip 'German language pack for Tesseract not installed', 5
   unless ( defined $languages->{'deu'} );

 # Create test image
 system(
"convert +matte -depth 1 -pointsize 12 -density 300 label:'öÖäÄüÜß' test.png"
 );

 $got = Gscan2pdf::Ocropus->hocr( 'test.png', 'deu' );
 is( Encode::is_utf8( $got, 1 ), 1, "Ocropus returned UTF8" );
 for my $c (qw( ö ä ü ß )) {
  my $c2 = decode_utf8($c);
  like( $got, qr/$c2/, "Ocropus returned $c" );
 }

 unlink 'test.png';
}

done_testing();
