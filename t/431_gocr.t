use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

SKIP: {
    skip 'gocr not installed', 1
      unless ( system("which gocr > /dev/null 2> /dev/null") == 0 );

    Gscan2pdf::Translation::set_domain('gscan2pdf');
    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($WARN);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    # Create test image
    system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.pnm'
    );

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths             => ['test.pnm'],
        finished_callback => sub {
            $slist->gocr(
                page              => $slist->{data}[0][2],
                finished_callback => sub {
                    like(
                        $slist->{data}[0][2]{hocr},
                        qr/The quick brown fox/,
                        'gocr returned sensible text'
                    );
                    Gtk3->main_quit;
                }
            );
        }
    );
    Gtk3->main;

    unlink 'test.pnm';
    Gscan2pdf::Document->quit();
}
