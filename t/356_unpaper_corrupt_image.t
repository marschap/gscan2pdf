use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gscan2pdf::Unpaper;
    use Gtk2 -init;    # Could just call init separately
    use version;
}

SKIP: {
    skip 'unpaper not installed', 1
      unless ( system("which unpaper > /dev/null 2> /dev/null") == 0 );
    my $unpaper = Gscan2pdf::Unpaper->new;

    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($FATAL);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    my %paper_sizes = (
        A4 => {
            x => 210,
            y => 297,
            l => 0,
            t => 0,
        },
        'US Letter' => {
            x => 216,
            y => 279,
            l => 0,
            t => 0,
        },
        'US Legal' => {
            x => 216,
            y => 356,
            l => 0,
            t => 0,
        },
    );

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);
    $slist->set_paper_sizes( \%paper_sizes );

    # Create test image
    system(
'convert -size 2100x2970 +matte -depth 1 -border 2x2 -bordercolor black -pointsize 12 -density 300 label:"The quick brown fox" test.pnm'
    );

    $slist->import_files(
        paths             => ['test.pnm'],
        finished_callback => sub {

            # Now we've imported it,
            # remove the data to give a corrupt image
            system("echo '' > $slist->{data}[0][2]->{filename}");
            $slist->unpaper(
                page              => $slist->{data}[0][2],
                options           => $unpaper->get_cmdline,
                finished_callback => sub {
                    Gtk2->main_quit;
                },
                error_callback => sub {
                    pass('caught errors from unpaper');
                }
            );
        }
    );
    Gtk2->main;

    unlink 'test.pnm', <$dir/*>;
    rmdir $dir;
    Gscan2pdf::Document->quit();
}
