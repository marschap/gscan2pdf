use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 3;

BEGIN {
    use Gscan2pdf::Document;
    use_ok('Gscan2pdf::Ocropus');
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

SKIP: {
    skip 'Ocropus not installed', 2 unless Gscan2pdf::Ocropus->setup($logger);

    # Create test image
    system(
'convert +matte -depth 1 -pointsize 12 -density 300 label:"The quick brown fox" test.png'
    );

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths             => ['test.png'],
        finished_callback => sub {
            $slist->ocropus(
                page              => $slist->{data}[0][2],
                language          => 'eng',
                finished_callback => sub {
                    like(
                        $slist->{data}[0][2]{hocr},
                        qr/The quick brown fox/,
                        'Ocropus returned sensible text'
                    );
                    is( dirname("$slist->{data}[0][2]{filename}"),
                        "$dir", 'using session directory' );
                    Gtk3->main_quit;
                }
            );
        }
    );
    Gtk3->main;

    unlink 'test.png', <$dir/*>;
    rmdir $dir;
}

Gscan2pdf::Document->quit();
