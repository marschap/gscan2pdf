use warnings;
use strict;
use Test::More tests => 11;
use Gscan2pdf::Page;

BEGIN {
    use_ok('Gscan2pdf::Canvas');
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
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
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
     <span class='ocr_line' id='line_1_1' title="bbox 1 14 420 59">
      <span class='ocr_word' id='word_1_1' title="bbox 1 14 77 48">
       <span class='xocr_word' id='xword_1_1' title="x_wconf -3">The</span>
      </span>
      <span class='ocr_word' id='word_1_2' title="bbox 92 14 202 59">
       <span class='xocr_word' id='xword_1_2' title="x_wconf -3">quick</span>
      </span>
      <span class='ocr_word' id='word_1_3' title="bbox 214 14 341 48">
       <span class='xocr_word' id='xword_1_3' title="x_wconf -3">brown</span>
      </span>
      <span class='ocr_word' id='word_1_4' title="bbox 355 14 420 48">
       <span class='xocr_word' id='xword_1_4' title="x_wconf -4">fox</span>
      </span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS

my $canvas = Gscan2pdf::Canvas->new($page);
my $group  = $canvas->get_root_item;
$group = $group->get_child(0);
$group = $group->get_child(1);
$group = $group->get_child(1);
$group = $group->get_child(1);
my $text = $group->get_child(1);

$canvas->set_box_text( $text, 'No' );

my $expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 422 61'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 14 420 59'>
    <span class='ocr_line' id='line_1_1' title='bbox 1 14 420 59'>
     <span class='ocr_word' id='word_1_1' title='bbox 1 14 77 48; x_wconf 100'>No</span>
     <span class='ocr_word' id='word_1_2' title='bbox 92 14 202 59; x_wconf -3'>quick</span>
     <span class='ocr_word' id='word_1_3' title='bbox 214 14 341 48; x_wconf -3'>brown</span>
     <span class='ocr_word' id='word_1_4' title='bbox 355 14 420 48; x_wconf -4'>fox</span>
    </span>
   </div>
  </div>
 </body>
</html>
EOS

is( $page->{hocr}, $expected, 'updated hocr' );

#########################

$canvas->set_box_text( $text, '<em>No</em>' );

$expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 422 61'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 14 420 59'>
    <span class='ocr_line' id='line_1_1' title='bbox 1 14 420 59'>
     <span class='ocr_word' id='word_1_1' title='bbox 1 14 77 48; x_wconf 100'>&lt;em&gt;No&lt;/em&gt;</span>
     <span class='ocr_word' id='word_1_2' title='bbox 92 14 202 59; x_wconf -3'>quick</span>
     <span class='ocr_word' id='word_1_3' title='bbox 214 14 341 48; x_wconf -3'>brown</span>
     <span class='ocr_word' id='word_1_4' title='bbox 355 14 420 48; x_wconf -4'>fox</span>
    </span>
   </div>
  </div>
 </body>
</html>
EOS

is( $page->{hocr}, $expected, 'updated hocr with HTML-escape characters' );

#########################

$page = Gscan2pdf::Page->new(
    filename   => 'test.pnm',
    format     => 'Portable anymap',
    resolution => 72,
    dir        => File::Temp->newdir,
);

$page->{hocr} = <<'EOS';
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title></title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
<meta name='ocr-system' content='tesseract'>
</head>
 <body>
  <div class='ocr_page' id='page_1' title='image "test.tif"; bbox 0 0 204 288'>
   <div class='ocr_carea' id='block_1_1' title="bbox 1 14 202 286">
    <p class='ocr_par'>
     <span class='ocr_line' id='line_1_1' title="bbox 1 14 202 59; baseline 0.008 -9 ">
      <span class='ocr_word' id='word_1_1' title="bbox 1 14 77 48">
       <span class='xocr_word' id='xword_1_1' title="x_wconf -3">The</span>
      </span>
      <span class='ocr_word' id='word_1_2' title="bbox 92 14 202 59">
       <span class='xocr_word' id='xword_1_2' title="x_wconf -3">quick</span>
      </span>
     </span>
    </p>
    <p class='ocr_par'>
     <span class='ocr_line' id='line_1_2' title="bbox 1 80 35 286; textangle 90">
      <span class='ocr_word' id='word_1_4' title="bbox 1 80 35 195">
       <span class='xocr_word' id='xword_1_4' title="x_wconf -4">fox</span>
      </span>
      <span class='ocr_word' id='word_1_3' title="bbox 1 159 35 286">
       <span class='xocr_word' id='xword_1_3' title="x_wconf -3">brown</span>
      </span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS

$canvas = Gscan2pdf::Canvas->new($page);
$group  = $canvas->get_root_item;
$group  = $group->get_child(0);
$group  = $group->get_child(1);
$group  = $group->get_child(1);
$group  = $group->get_child(2);
$text   = $group->get_child(1);

SKIP: {
    if ( $Goo::Canvas::VERSION < 0.07 ) {
        skip 'Goo::Canvas::get_transform() segfaults', 6;
    }
    my $matrix = $text->get_transform;

    is( $matrix->x0, -103.251044000815, 'rotated text x0' );
    is( $matrix->y0, -42.1731768180892, 'rotated text y0' );
    is( $matrix->xx, 2.86820126298635,  'rotated text xx' );
    is( $matrix->xy, 0,                 'rotated text xy' );
    is( $matrix->yx, 0,                 'rotated text yx' );
    is( $matrix->yy, 2.86820126298635,  'rotated text yy' );
}

$expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 204 288'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 14 202 286'>
    <span class='ocr_line' id='line_1_1' title='bbox 1 14 202 59; baseline 0.008 -9'>
     <span class='ocr_word' id='word_1_1' title='bbox 1 14 77 48; x_wconf -3'>The</span>
     <span class='ocr_word' id='word_1_2' title='bbox 92 14 202 59; x_wconf -3'>quick</span>
    </span>
    <span class='ocr_line' id='line_1_2' title='bbox 1 80 35 286; textangle 90'>
     <span class='ocr_word' id='word_1_4' title='bbox 1 80 35 195; x_wconf -4'>fox</span>
     <span class='ocr_word' id='word_1_3' title='bbox 1 159 35 286; x_wconf -3'>brown</span>
    </span>
   </div>
  </div>
 </body>
</html>
EOS

$canvas->canvas2hocr;
is( $page->{hocr}, $expected, 'updated hocr with extended hOCR properties' );

#########################

$page = Gscan2pdf::Page->new(
    filename   => 'test.pnm',
    format     => 'Portable anymap',
    resolution => 72,
    dir        => File::Temp->newdir,
);

$page->{hocr} = 'The quick brown fox';

$canvas   = Gscan2pdf::Canvas->new($page);
$expected = <<"EOS";
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page'  title='bbox 0 0 70 46'>The quick brown fox</div>
 </body>
</html>
EOS

$canvas->canvas2hocr;
is( $canvas->{page}{hocr}, $expected, 'canvas2hocr from simple text' );

#########################

unlink 'test.pnm';

__END__
