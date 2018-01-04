use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
    use PDF::API2;
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(
'convert +matte -depth 1 -colorspace Gray -pointsize 12 -units PixelsPerInch -density 300 label:"The quick brown fox" -border 20x10 test.png'
);
my $info = `identify test.png`;
my ( $width, $height );
if ( $info =~ /(\d+)+x(\d+)/ ) { ( $width, $height ) = ( $1, $2 ) }

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my $hocr = <<EOS;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>
</title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='tesseract 3.03' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word'/>
</head>
<body>
  <div class='ocr_page' id='page_1' title='image "test.png"; bbox 0 0 452 57; ppageno 0'>
   <div class='ocr_carea' id='block_1_1' title="bbox 1 9 449 55">
    <p class='ocr_par' dir='ltr' id='par_1_1' title="bbox 1 9 449 55">
     <span class='ocr_line' id='line_1_1' title="bbox 1 9 449 55; baseline 0 -10"><span class='ocrx_word' id='word_1_1' title='bbox 1 9 85 45; x_wconf 90' lang='eng' dir='ltr'>The</span> <span class='ocrx_word' id='word_1_2' title='bbox 103 9 217 55; x_wconf 89' lang='eng' dir='ltr'>quick</span> <span class='ocrx_word' id='word_1_3' title='bbox 235 9 365 45; x_wconf 94' lang='eng' dir='ltr'>brown</span> <span class='ocrx_word' id='word_1_4' title='bbox 383 9 449 45; x_wconf 94' lang='eng' dir='ltr'>fox</span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS

$slist->import_files(
    paths             => ['test.png'],
    finished_callback => sub {
        $slist->{data}[0][2]{hocr} = $hocr;
        $slist->save_pdf(
            path              => 'test.pdf',
            list_of_pages     => [ $slist->{data}[0][2] ],
            finished_callback => sub {
                $slist->import_files(
                    paths             => ['test.pdf'],
                    finished_callback => sub {

                        # Because we cannot reproduce the exact typeface used
                        # in the original, we cannot expect to be able to
                        # round-trip the text layer. Here, at least we can check
                        # that we have scaled the page size correctly.
                        like(
                            $slist->{data}[1][2]{hocr},
                            qr/bbox\s0\s0\s$width\s$height/xsm,
                            'import text layer'
                        );
                        Gtk3->main_quit;
                    }
                );
            }
        );
    }
);
Gtk3->main;

like(
    `pdftotext test.pdf -`,
    qr/The\s*quick\s*brown\s*fox/,
    'PDF with expected text'
);

#########################

unlink 'test.png', 'test.pdf';
Gscan2pdf::Document->quit();
