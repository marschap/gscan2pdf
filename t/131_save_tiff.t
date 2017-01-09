use warnings;
use strict;
use Test::More tests => 3;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk2 -init;    # Could just call init separately
}

#########################

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
        $slist->save_tiff(
            path          => 'test.tif',
            list_of_pages => [ $slist->{data}[0][2] ],
            options       => {
                post_save_hook         => 'convert %i test2.png',
                post_save_hook_options => 'fg',
            },
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

like(
    `identify test.tif`,
    qr/test.tif TIFF 70x46 70x46\+0\+0 8-bit sRGB 7.74KB/,
    'valid TIFF created'
);
is(
    `identify test2.png`,
    "test2.png PNG 70x46 70x46+0+0 8-bit sRGB 7.12KB 0.000u 0:00.000\n",
    'ran post-save hook'
);

#########################

unlink 'test.pnm', 'test.tif', 'test2.png';
Gscan2pdf::Document->quit();
