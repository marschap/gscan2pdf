use warnings;
use strict;
use Test::More tests => 8;
use Gtk2 -init;    # Could just call init separately

BEGIN {
    use_ok('Gscan2pdf::Document');
}

#########################

Glib::set_application_name('gscan2pdf');

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

#########################

unlink 'test.pnm', 'test.pdf';
Gscan2pdf::Document->quit();
