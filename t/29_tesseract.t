use warnings;
use strict;
use Test::More tests => 22;

BEGIN {
 use_ok('Gscan2pdf::Tesseract');
 use Encode;
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

my $output = <<EOS;
Unable to load unicharset file /usr/share/tesseract-ocr/tessdata/.unicharset
EOS

my ( $tessdata, $version, $suffix ) =
  Gscan2pdf::Tesseract::parse_tessdata($output);
is( $tessdata, '/usr/share/tesseract-ocr/tessdata', 'v2 tessdata' );
is( $version,  2,                                   'v2' );
is( $suffix,   '.unicharset',                       'v2 suffix' );

$output = <<EOS;
Error openning data file /usr/share/tesseract-ocr/tessdata/.traineddata

EOS

( $tessdata, $version, $suffix ) =
  Gscan2pdf::Tesseract::parse_tessdata($output);
is( $tessdata, '/usr/share/tesseract-ocr/tessdata', 'v3 tessdata' );
is( $version,  3,                                   'v3' );
is( $suffix,   '.traineddata',                      'v3 suffix' );

$output = <<EOS;
Tesseract Open Source OCR Engine v3.01 with Leptonica
Cannot open input file:
Error opening data file /usr/share/tesseract-ocr/tessdata/.traineddata

EOS

( $tessdata, $version, $suffix ) =
  Gscan2pdf::Tesseract::parse_tessdata($output);
is( $tessdata, '/usr/share/tesseract-ocr/tessdata', 'v3.01 tessdata' );
is( $version,  3.01,                                'v3.01' );
is( $suffix,   '.traineddata',                      'v3.01 suffix' );

$output = <<'EOS';
Tesseract Open Source OCR Engine v3.02 with Leptonica
Cannot open input file:
Tesseract couldn't load any languages!


EOS

( $tessdata, $version, $suffix ) =
  Gscan2pdf::Tesseract::parse_tessdata($output);
is( $version, 3.02,           'v3.02' );
is( $suffix,  '.traineddata', 'v3.02 suffix' );

$output = <<'EOS';
N9tesseract8IndexMapE
Usage
TESSDATA_PREFIX
Warning:explicit path for executable will not be used for configs
/usr/share/tesseract-ocr/
Offset for type %d is %lld
EOS

is(
 Gscan2pdf::Tesseract::parse_strings($output),
 '/usr/share/tesseract-ocr/tessdata',
 'v3.02 tessdata'
);

SKIP: {
 skip 'Tesseract not installed', 9 unless Gscan2pdf::Tesseract->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -colorspace Gray -pointsize 12 -density 300 label:"The quick brown fox" test.png'
 );

 my ( $got, $messages ) =
   Gscan2pdf::Tesseract->hocr( 'test.png', 'eng', $logger );

 like( $got, qr/The/,     'Tesseract returned "The"' );
 like( $got, qr/quick/,   'Tesseract returned "quick"' );
 like( $got, qr/brown/,   'Tesseract returned "brown"' );
 like( $got, qr/f(o|0)x/, 'Tesseract returned "fox"' );

 my $languages = Gscan2pdf::Tesseract->languages;
 skip 'German language pack for Tesseract not installed', 5
   unless ( defined $languages->{'deu'} );

 # Create test image
 system(
"convert +matte -depth 1 -colorspace Gray -pointsize 12 -density 300 label:'öÖäÄüÜß' test.png"
 );

 ( $got, $messages ) = Gscan2pdf::Tesseract->hocr( 'test.png', 'deu', $logger );
 is( Encode::is_utf8( $got, 1 ), 1, "Tesseract returned UTF8" );
 for my $c (qw( ö ä ü ß )) {
  my $c2 = decode_utf8($c);
  like( $got, qr/$c2/, "Tesseract returned $c" );
 }

 unlink 'test.png';
}

__END__
