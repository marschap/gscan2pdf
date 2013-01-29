use warnings;
use strict;
use Test::More tests => 9;

BEGIN {
 use_ok('Gscan2pdf::Page');
 use Encode;
}

#########################

Glib::set_application_name('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

# Create test image
system('convert rose: test.pnm');

Gscan2pdf::Page->set_logger(Log::Log4perl::get_logger);
my $page = Gscan2pdf::Page->new(
 filename   => 'test.pnm',
 format     => 'Portable anymap',
 resolution => 72,
 dir        => File::Temp->newdir,
);

$page->{hocr} = <<'EOS';
                  '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title></title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
<meta name='ocr-system' content='tesseract'>
</head>
<body>
<div class='ocr_page' id='page_1' title='image "test.tif"; bbox 0 0 422 61'>
<div class='ocr_carea' id='block_1_1' title="bbox 1 14 420 59">
<p class='ocr_par'>
<span class='ocr_line' id='line_1_1' title="bbox 1 14 420 59"><span class='ocr_word' id='word_1_1' title="bbox 1 14 77 48"><span class='xocr_word' id='xword_1_1' title="x_wconf -3">The</span></span> <span class='ocr_word' id='word_1_2' title="bbox 92 14 202 59"><span class='xocr_word' id='xword_1_2' title="x_wconf -3">quick</span></span> <span class='ocr_word' id='word_1_3' title="bbox 214 14 341 48"><span class='xocr_word' id='xword_1_3' title="x_wconf -3">brown</span></span> <span class='ocr_word' id='word_1_4' title="bbox 355 14 420 48"><span class='xocr_word' id='xword_1_4' title="x_wconf -4">fox</span></span></span>
</p>
</div>
</div>
</body>
</html>
EOS

my @boxes = (
 [ 1,   14, 77,  48, 'The' ],
 [ 92,  14, 202, 59, 'quick' ],
 [ 214, 14, 341, 48, 'brown' ],
 [ 355, 14, 420, 48, 'fox' ]
);
is_deeply( [ $page->boxes ], \@boxes, 'Boxes from tesseract 3.00' );

#########################

$page->{hocr} = <<'EOS';
<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN
    http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><meta content="ocr_line ocr_page" name="ocr-capabilities"/><meta content="en" name="ocr-langs"/><meta content="Latn" name="ocr-scripts"/><meta content="" name="ocr-microformats"/><title>OCR Output</title></head>
<body><div class="ocr_page" title="bbox 0 0 274 58; image test.png"><span class="ocr_line" title="bbox 3 1 271 47">&#246;&#246;&#228;ii&#252;&#252;&#223; &#8364;
</span></div></body></html>
EOS

@boxes = ( [ 3, 1, 271, 47, decode_utf8('ööäiiüüß €') ] );
is_deeply( [ $page->boxes ], \@boxes, 'Boxes from ocropus 0.3 with UTF8' );

#########################

$page->{hocr} = <<'EOS';
<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN
    http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><meta content="ocr_line ocr_page" name="ocr-capabilities"/><meta content="en" name="ocr-langs"/><meta content="Latn" name="ocr-scripts"/><meta content="" name="ocr-microformats"/><title>OCR Output</title></head>
<body><div class="ocr_page" title="bbox 0 0 202 114; image /tmp/GgRiywY66V/qg_kooDQKE.pnm"><span class="ocr_line" title="bbox 22 26 107 39">&#164;&#246;A&#228;U&#252;&#223;'
</span><span class="ocr_line" title="bbox 21 74 155 87">Test Test Test E
</span></div></body></html>
EOS

@boxes = (
 [ 22, 26, 107, 39, "\x{a4}\x{f6}A\x{e4}U\x{fc}\x{df}'" ],
 [ 21, 74, 155, 87, 'Test Test Test E' ]
);
is_deeply( [ $page->boxes ], \@boxes, 'More boxes from ocropus 0.3 with UTF8' );

#########################

$page->{hocr} = <<'EOS';
<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN
    http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><meta content="ocr_line ocr_page" name="ocr-capabilities"/><meta content="en" name="ocr-langs"/><meta content="Latn" name="ocr-scripts"/><meta content="" name="ocr-microformats"/><title>OCR Output</title></head>
<body><div class="ocr_page" title="bbox 0 0 422 61; image test.png"><span class="ocr_line" title="bbox 1 14 420 59">The quick brown fox
</span></div></body></html>
EOS

@boxes = ( [ 1, 14, 420, 59, 'The quick brown fox' ] );
is_deeply( [ $page->boxes ], \@boxes, 'Boxes from ocropus 0.4' );

#########################

$page->{hocr} = <<'EOS';
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html><head><title></title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
<meta name='ocr-system' content='openocr'>
</head>
<body><div class='ocr_page' id='page_1' title='image "test.bmp"; bbox 0 0 422 61'>
<p><span class='ocr_line' id='line_1' title="bbox 1 15 420 60">The quick brown fox<span class='ocr_cinfo' title="x_bboxes 1 15 30 49 31 15 55 49 57 27 77 49 -1 -1 -1 -1 92 27 114 60 116 27 139 49 141 15 153 49 155 27 175 49 176 15 202 49 -1 -1 -1 -1 214 15 237 49 239 27 256 49 257 27 279 49 282 27 315 49 317 27 341 49 -1 -1 -1 -1 355 15 373 49 372 27 394 49 397 27 420 49 "></span></span>
</p>
<p><span class='ocr_line' id='line_2' title="bbox 0 0 0 0"></span>
</p>
</div></body></html>
EOS

@boxes = ( [ 1, 15, 420, 60, 'The quick brown fox' ] );
is_deeply( [ $page->boxes ], \@boxes, 'Boxes from cuneiform 1.0.0' );

#########################

my %paper_sizes = (
 A4 => {
  x => 210,
  y => 297,
  l => 0,
  t => 0,
 },
 'US Letter' => {
  x => 216,
  y => 279,
  l => 0,
  t => 0,
 },
 'US Legal' => {
  x => 216,
  y => 356,
  l => 0,
  t => 0,
 },
);

system('convert -size 210x297 xc:white test.pnm');
$page = Gscan2pdf::Page->new(
 filename => 'test.pnm',
 format   => 'Portable anymap',
 dir      => File::Temp->newdir,
);
is_deeply(
 $page->matching_paper_sizes( \%paper_sizes ),
 { A4 => 25 },
 'basic portrait'
);
system('convert -size 297x210 xc:white test.pnm');
$page = Gscan2pdf::Page->new(
 filename => 'test.pnm',
 format   => 'Portable anymap',
 dir      => File::Temp->newdir,
);
is_deeply(
 $page->matching_paper_sizes( \%paper_sizes ),
 { A4 => 25 },
 'basic landscape'
);

#########################

is( $page->resolution( \%paper_sizes ), 25, 'resolution' );

#########################

unlink 'test.pnm';

__END__
