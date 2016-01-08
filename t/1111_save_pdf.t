use warnings;
use strict;
use Test::More tests => 4;
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
    paths             => ['test.pnm'],
    finished_callback => sub {
        is( $slist->scans_saved, '', 'pages not tagged as saved' );
        $slist->save_pdf(
            path              => 'test.pdf',
            list_of_pages     => [ $slist->{data}[0][2] ],
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
