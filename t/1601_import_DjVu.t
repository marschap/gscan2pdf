use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 4;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.jpg;c44 test.jpg test.djvu');
my $text = <<'EOS';
(page 0 0 2236 3185
  (column 157 3011 1725 3105
    (para 157 3014 1725 3101
      (line 157 3014 1725 3101
        (word 157 3030 241 3095 "28")
        (word 533 3033 645 3099 "LA")
        (word 695 3014 1188 3099 "MARQUISE")
        (word 1229 3034 1365 3098 "DE")
        (word 1409 3031 1725 3101 "GANGE")))))
EOS
open my $fh, '>', 'text.txt';
print {$fh} $text;
close $fh;
system("djvused 'test.djvu' -e 'select 1; set-txt text.txt' -s");

my $old = `identify -format '%m %G %g %z-bit %r' test.djvu`;

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my $expected =
qr{^<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf \d+(?:\.\d+)+' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' title='bbox 0 0 2236 3185'>
   <div class='ocr_carea' title='bbox 157 80 1725 174'>
    <p class='ocr_par' title='bbox 157 84 1725 171'>
     <span class='ocr_line' title='bbox 157 84 1725 171'>
      <span class='ocr_word' title='bbox 157 90 241 155'>28</span>
      <span class='ocr_word' title='bbox 533 86 645 152'>LA</span>
      <span class='ocr_word' title='bbox 695 86 1188 171'>MARQUISE</span>
      <span class='ocr_word' title='bbox 1229 87 1365 151'>DE</span>
      <span class='ocr_word' title='bbox 1409 84 1725 154'>GANGE</span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>$};

$slist->import_files(
    paths            => ['test.djvu'],
    started_callback => sub {
        my ( $n, $process_name, $jobs_completed, $jobs_total, $message,
            $progress )
          = @_;
        pass 'started callback';
    },
    finished_callback => sub {
        like(
`identify -format '%m %G %g %z-bit %r' $slist->{data}[0][2]{filename}`,
            qr/^TIFF/,
            'DjVu imported correctly'
        );
        is( dirname("$slist->{data}[0][2]{filename}"),
            "$dir", 'using session directory' );
        like( $slist->{data}[0][2]{hocr}, $expected, 'hocr layer' );
        Gtk2->main_quit;
    }
);
Gtk2->main;

#########################

unlink 'test.djvu', 'text.txt', 'test.jpg', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
