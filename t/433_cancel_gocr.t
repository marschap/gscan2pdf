use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

SKIP: {
    skip 'gocr not installed', 1
      unless ( system("which gocr > /dev/null 2> /dev/null") == 0 );

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
            my $pid = $slist->gocr(
                page               => $slist->{data}[0][2],
                cancelled_callback => sub {
                    is( $slist->{data}[0][2]{hocr}, undef, 'no OCR output' );
                    $slist->save_image(
                        path              => 'test.jpg',
                        list_of_pages     => [ $slist->{data}[0][2] ],
                        finished_callback => sub { Gtk2->main_quit }
                    );
                }
            );
            $slist->cancel($pid);
        }
    );
    Gtk2->main;

    is( system('identify test.jpg'),
        0, 'can create a valid JPG after cancelling previous process' );

    unlink 'test.pnm', 'test.jpg';
    Gscan2pdf::Document->quit();
}
