use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 4;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk2 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger         = Log::Log4perl::get_logger;
my $tess_installed = Gscan2pdf::Tesseract->setup($logger);

Gscan2pdf::Document->setup($logger);

# Create b&w test image
system(
'convert +matte -depth 1 -colorspace Gray -pointsize 12 -units PixelsPerInch -density 300 label:"The quick brown fox" test.png'
);

# Add text layer with tesseract
if ($tess_installed) {
    system('tesseract -l eng test.png test pdf');
}
else {
    system(
'convert +matte -depth 1 -colorspace Gray -pointsize 12 -density 300 label:"The quick brown fox" test.pdf'
    );
}

my $old = `identify -format '%m %G %g %z-bit %r' test.png`;

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.pdf'],
    finished_callback => sub {
        is(
`identify -format '%m %G %g %z-bit %r' $slist->{data}[0][2]{filename}`,
            $old,
            'PDF imported correctly'
        );
      SKIP: {
            skip 'Tesseract not installed', 1 unless $tess_installed;
            like( $slist->{data}[0][2]{hocr},
                qr/quick/xsm, 'import text layer' );
        }
        is( dirname("$slist->{data}[0][2]{filename}"),
            "$dir", 'using session directory' );
        Gtk2->main_quit;
    }
);
Gtk2->main;

#########################

unlink 'test.pdf', 'test.png', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
