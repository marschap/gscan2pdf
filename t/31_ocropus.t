use warnings;
use strict;
use Test::More tests => 7;

BEGIN {
    use_ok('Gscan2pdf::Ocropus');
    use Gscan2pdf::Tesseract;
    use Encode;
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

SKIP: {
    skip 'Ocropus not installed', 6 unless Gscan2pdf::Ocropus->setup($logger);

    # Create test image
    system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.png'
    );

    my $got = Gscan2pdf::Ocropus->hocr( 'test.png', 'eng', $logger );
    like( $got, qr/The quick brown fox/, 'Ocropus returned sensible text' );

    skip 'Tesseract not installed', 5
      unless Gscan2pdf::Tesseract->setup($logger);
    my $languages = Gscan2pdf::Tesseract->languages;
    skip 'German language pack for Tesseract not installed', 5
      unless ( defined $languages->{'deu'} );

    # Create test image
    system(
"convert +matte -depth 1 -pointsize 12 -density 300 label:'öÖäÄüÜß' test.png"
    );

    $got = Gscan2pdf::Ocropus->hocr( 'test.png', 'deu', $logger );
    is( Encode::is_utf8( $got, 1 ), 1, "Ocropus returned UTF8" );
    for my $c (qw( ö ä ü ß )) {
        my $c2 = decode_utf8($c);
        like( $got, qr/$c2/, "Ocropus returned $c" );
    }

    unlink 'test.png';
}

done_testing();
