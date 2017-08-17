use warnings;
use strict;
use Test::More tests => 9;
use Gtk2 -init;    # Could just call init separately

BEGIN {
    use_ok('Gscan2pdf::Document');
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
    paths            => ['test.pnm'],
    started_callback => sub {
        my ( $thread, $process, $completed, $total ) = @_;
        is( $completed, 0, 'completed counter starts at 0' );
        is( $total,     2, 'total counter starts at 2' );
    },
    finished_callback => sub {
        is( $slist->scans_saved, '', 'pages not tagged as saved' );
        $slist->save_pdf(
            path             => 'test.pdf',
            list_of_pages    => [ $slist->{data}[0][2] ],
            started_callback => sub {
                my ( $thread, $process, $completed, $total ) = @_;
                is( $completed, 0, 'completed counter re-initialised' );
                is( $total,     0, 'total counter re-initialised' );
            },
            options => {
                post_save_hook         => 'convert %i test2.png',
                post_save_hook_options => 'fg',
            },
            finished_callback => sub {
                is(
                    `pdfinfo test.pdf | grep 'Page size:'`,
                    "Page size:      70 x 46 pts\n",
                    'valid PDF created'
                );
                is( $slist->scans_saved, 1, 'pages tagged as saved' );
                Gtk2->main_quit;
            }
        );
    }
);
Gtk2->main;

like(
    `identify test2.png`,
    qr/test2.png PNG 70x46 70x46\+0\+0 8-bit sRGB/,
    'ran post-save hook on pdf'
);

#########################

unlink 'test.png', 'test.pdf', 'test2.png';
Gscan2pdf::Document->quit();
