# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 22;

BEGIN {
 use_ok('Gscan2pdf::Tesseract');
 use Encode;
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
our $logger = Log::Log4perl::get_logger;
my $prog_name = 'gscan2pdf';
use Locale::gettext 1.05;    # For translations
our $d = Locale::gettext->domain($prog_name);

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
Error opening data file /usr/share/tesseract-ocr/tessdata/.traineddata
Tesseract Open Source OCR Engine v3.01 with Leptonica
Image file  cannot be opened!
Error during processing.
EOS

( $tessdata, $version, $suffix ) =
  Gscan2pdf::Tesseract::parse_tessdata($output);
is( $tessdata, '/usr/share/tesseract-ocr/tessdata', 'v3.01 tessdata' );
is( $version,  3.01,                                'v3.01' );
is( $suffix,   '.traineddata',                      'v3.01 suffix' );

$output = <<'EOS';
Tesseract couldn't load any languages!
Tesseract Open Source OCR Engine v3.02 with Leptonica
Cannot open input file:
EOS

( $tessdata, $version, $suffix ) =
  Gscan2pdf::Tesseract::parse_tessdata($output);
is( $version,  3.02,                                'v3.02' );
is( $suffix,   '.traineddata',                      'v3.02 suffix' );

$output = <<'EOS';
N9tesseract8IndexMapE
Usage
TESSDATA_PREFIX
Warning:explicit path for executable will not be used for configs
/usr/share/tesseract-ocr/
Offset for type %d is %lld
EOS

is( Gscan2pdf::Tesseract::parse_strings(split /\n/, $output), '/usr/share/tesseract-ocr/tessdata', 'v3.02 tessdata' );

SKIP: {
 skip 'Tesseract not installed', 9 unless Gscan2pdf::Tesseract->setup;

 # Create test image
 system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.tif'
 );

 my $got = Gscan2pdf::Tesseract->hocr( 'test.tif', 'eng' );

 like( $got, qr/The/,   'Tesseract returned "The"' );
 like( $got, qr/quick/, 'Tesseract returned "quick"' );
 like( $got, qr/brown/, 'Tesseract returned "brown"' );
 like( $got, qr/fox/,   'Tesseract returned "fox"' );

 my $languages = Gscan2pdf::Tesseract->languages;
 skip 'German language pack for Tesseract not installed', 5
   unless ( defined $languages->{'deu'} );

 # Create test image
 system(
"convert +matte -depth 1 -pointsize 12 -density 300 label:'öÖäÄüÜß' test.tif"
 );

 $got = Gscan2pdf::Tesseract->hocr( 'test.tif', 'deu' );
 is( Encode::is_utf8( $got, 1 ), 1, "Tesseract returned UTF8" );
 for my $c (qw( ö ä ü ß )) {
  my $c2 = decode_utf8($c);
  like( $got, qr/$c2/, "Tesseract returned $c" );
 }

 unlink 'test.tif';
}

__END__
