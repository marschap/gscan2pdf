use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 4;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.jpg');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.jpg'],
    finished_callback => sub {
        $slist->threshold(
            threshold         => 80,
            page              => $slist->{data}[0][2],
            finished_callback => sub {
                is( system("identify $slist->{data}[0][2]{filename}"),
                    0, 'created valid file' );
                is( dirname("$slist->{data}[0][2]{filename}"),
                    "$dir", 'using session directory' );
                $slist->save_pdf(
                    path          => 'test.pdf',
                    list_of_pages => [ $slist->{data}[0][2] ],
                    options       => {
                        compression => 'none',
                    },
                    finished_callback => sub { Gtk3->main_quit }
                );
            }
        );
    }
);
Gtk3->main;

is(
    `pdfinfo test.pdf | grep 'Page size:'`,
    "Page size:      70 x 46 pts\n",
    'created valid PDF'
);

#########################

unlink 'test.jpg', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
