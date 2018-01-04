use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
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

$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->{data}[0][2]{hocr} = <<EOS;
<!DOCTYPE html
 PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN
 http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
 <head>
  <meta content="ocr_line ocr_page" name="ocr-capabilities"/>
  <meta content="en" name="ocr-langs"/>
  <meta content="Latn" name="ocr-scripts"/>
  <meta content="" name="ocr-microformats"/>
  <title>OCR Output</title>
 </head>
 <body>
  <div class="ocr_page" title="bbox 0 0 70 46>
   <p class="ocr_par">
    <span class=\"ocr_line\" title=\"bbox 10 10 60 11\">The quick brown fox</span>
   </p>
  </div>
 </body>
</html>
EOS
        $slist->save_djvu(
            path              => 'test.djvu',
            list_of_pages     => [ $slist->{data}[0][2] ],
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

like( `djvutxt test.djvu`, qr/The quick brown fox/, 'DjVu with expected text' );

#########################

unlink 'test.pnm', 'test.djvu';
Gscan2pdf::Document->quit();
