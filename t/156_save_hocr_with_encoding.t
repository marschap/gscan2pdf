use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my $hocr = <<'EOS';
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
  <div class='ocr_page' id='page_1' title='image "incas1_modif.jpg"; bbox 0 0 2452 3484; ppageno 0'>
   <div class='ocr_carea' id='block_1_9' title="bbox 1249 2403 2165 3246">
    <p class='ocr_par' dir='ltr' id='par_1_12' title="bbox 1250 2403 2165 3245">
     <span class='ocr_line' id='line_1_70' title="bbox 1251 3205 2162 3245; baseline 0.001 -9"><span class='ocrx_word' id='word_1_518' title='bbox 1251 3205 1344 3236; x_wconf 92' lang='fra' dir='ltr'>donc</span> <span class='ocrx_word' id='word_1_519' title='bbox 1359 3213 1401 3237; x_wconf 91' lang='fra' dir='ltr'>un</span> <span class='ocrx_word' id='word_1_520' title='bbox 1416 3206 1532 3245; x_wconf 86' lang='fra' dir='ltr'>village</span> <span class='ocrx_word' id='word_1_521' title='bbox 1546 3205 1567 3236; x_wconf 88' lang='fra' dir='ltr'>à</span> <span class='ocrx_word' id='word_1_522' title='bbox 1581 3205 1700 3237; x_wconf 93' lang='fra' dir='ltr'>Cuzco</span> <span class='ocrx_word' id='word_1_523' title='bbox 1714 3205 1740 3245; x_wconf 83' lang='fra'>(&lt;&lt;</span> <span class='ocrx_word' id='word_1_524' title='bbox 1756 3208 1871 3237; x_wconf 92' lang='fra' dir='ltr'>centre</span> <span class='ocrx_word' id='word_1_525' title='bbox 1885 3207 1930 3237; x_wconf 93' lang='fra' dir='ltr'>du</span> <span class='ocrx_word' id='word_1_526' title='bbox 1946 3207 2075 3237; x_wconf 91' lang='fra' dir='ltr'>monde</span> <span class='ocrx_word' id='word_1_527' title='bbox 2090 3219 2105 3232; x_wconf 88' lang='fra'><strong><em>&gt;&gt;</em></strong></span> <span class='ocrx_word' id='word_1_528' title='bbox 2120 3215 2162 3237; x_wconf 93' lang='fra' dir='ltr'>en</span> 
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS

$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->{data}[0][2]{hocr} = $hocr;

        # The line below was altering the xml, so we need it in the test
        my @boxes = $slist->{data}[0][2]->boxes;

        $slist->save_hocr(
            path              => 'test.txt',
            list_of_pages     => [ $slist->{data}[0][2] ],
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

is( `cat test.txt`, $hocr, 'saved hocr with encoded xml characters' );

#########################

unlink 'test.pnm', 'test.txt';
Gscan2pdf::Document->quit();
