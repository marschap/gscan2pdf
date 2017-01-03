use warnings;
use strict;
use Test::More tests => 1;

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
system(
'convert -fill lightblue -pointsize 12 -density 300 label:"The quick brown fox" test.png'
);

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.png'],
    finished_callback => sub {
        $slist->save_tiff(
            path          => 'test.tif',
            list_of_pages => [ $slist->{data}[0][2] ],
            options       => {
                compression => 'lzw',
            },
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

is(
    `identify test.tif`,
    "test.tif TIFF 452x57 452x57+0+0 16-bit sRGB 23KB 0.000u 0:00.000\n",
    'valid TIFF created'
);

#########################

unlink 'test.tif', 'test.png';
Gscan2pdf::Document->quit();
