use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 3;

BEGIN {
    use Gscan2pdf::Document;
    use_ok('Gscan2pdf::Cuneiform');
    use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
my $logger = Log::Log4perl::get_logger;

SKIP: {
    skip 'Cuneiform not installed', 2
      unless Gscan2pdf::Cuneiform->setup($logger);

    Gscan2pdf::Document->setup($logger);

    # Create test image
    system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.png'
    );

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->get_file_info(
        path              => 'test.png',
        finished_callback => sub {
            my ($info) = @_;
            $slist->import_file(
                info              => $info,
                first             => 1,
                last              => 1,
                finished_callback => sub {
                    $slist->cuneiform(
                        page              => $slist->{data}[0][2],
                        language          => 'eng',
                        finished_callback => sub {
                            like(
                                $slist->{data}[0][2]{hocr},
                                qr/The quick brown fox/,
                                'Cuneiform returned sensible text'
                            );
                            is( dirname("$slist->{data}[0][2]{filename}"),
                                "$dir", 'using session directory' );
                            Gtk2->main_quit;
                        }
                    );
                }
            );
        }
    );
    Gtk2->main;

    unlink 'test.png', <$dir/*>;
    rmdir $dir;
    Gscan2pdf::Document->quit();
}
