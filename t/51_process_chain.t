use warnings;
use strict;
use Test::More tests => 4;
use Gtk2 -init;    # Could just call init separately
use Gscan2pdf::Tesseract;
use Gscan2pdf::Document;
use Gscan2pdf::Unpaper;

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

Gscan2pdf::Translation::set_domain('gscan2pdf');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

SKIP: {
    skip 'Tesseract not installed', 4
      unless Gscan2pdf::Tesseract->setup($logger);
    skip 'unpaper not installed', 4
      unless ( system("which unpaper > /dev/null 2> /dev/null") == 0 );

    my $unpaper = Gscan2pdf::Unpaper->new;
    my $vbox    = Gtk2::VBox->new;
    $unpaper->add_options($vbox);

    # Create b&w test image
    system(
'convert +matte -depth 1 -colorspace Gray -pointsize 12 -density 300 label:"The quick brown fox" -rotate -90 test.pnm'
    );

    $slist->import_scan(
        filename          => 'test.pnm',
        page              => 1,
        rotate            => 90,
        unpaper           => $unpaper,
        ocr               => 1,
        resolution        => 300,
        delete            => 1,
        dir               => $dir,
        engine            => 'tesseract',
        language          => 'eng',
        finished_callback => sub {
            like( $slist->{data}[0][2]{hocr},
                qr/The/, 'Tesseract returned "The"' );
            like( $slist->{data}[0][2]{hocr},
                qr/quick/, 'Tesseract returned "quick"' );
            like( $slist->{data}[0][2]{hocr},
                qr/brown/, 'Tesseract returned "brown"' );
            like( $slist->{data}[0][2]{hocr},
                qr/f(o|0)x/, 'Tesseract returned "fox"' );
            Gtk2->main_quit;
        }
    );
    Gtk2->main;
}

#########################

unlink 'test.pnm';
Gscan2pdf::Document->quit();
