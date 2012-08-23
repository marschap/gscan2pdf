use warnings;
use strict;
use Test::More tests => 6;

BEGIN {
 use_ok('Gscan2pdf::Cuneiform');
 use Encode;
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

SKIP: {
 skip 'Cuneiform not installed', 5 unless Gscan2pdf::Cuneiform->setup($logger);

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

 $got = Gscan2pdf::Cuneiform->hocr( 'test.bmp', 'ger' );
 is( Encode::is_utf8( $got, 1 ), 1, "Cuneiform returned UTF8" );
 for my $c (qw( ö ä ü )) {
  my $c2 = decode_utf8($c);
  like( $got, qr/$c2/, "Cuneiform returned $c" );
 }

 unlink 'test.bmp';
}
