use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gscan2pdf::Tesseract;
    use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

SKIP: {
    skip 'Tesseract not installed', 2
      unless Gscan2pdf::Tesseract->setup($logger);

    # Create test image
    my $filename = 'test.png';
    system(
"convert +matte -depth 1 -colorspace Gray -pointsize 12 -density 300 label:'The quick brown fox' $filename"
    );

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->get_file_info(
        path              => $filename,
        finished_callback => sub {
            my ($info) = @_;
            $slist->import_file(
                info              => $info,
                first             => 1,
                last              => 1,
                finished_callback => sub {

                    # inject error before tesseract
                    chmod 0500, $dir;    # no write access

                    $slist->tesseract(
                        page           => $slist->{data}[0][2],
                        language       => 'eng',
                        error_callback => sub {
                            ok( 1, 'caught error injected before tesseract' );
                            chmod 0700, $dir;    # allow write access

                            $slist->tesseract(
                                page            => $slist->{data}[0][2],
                                language        => 'eng',
                                queued_callback => sub {

                                    # inject error during tesseract
                                    chmod 0500, $dir;    # no write access
                                },
                                error_callback => sub {
                                    ok( 1,
'tesseract caught error injected in queue'
                                    );
                                    chmod 0700, $dir;    # allow write access
                                    Gtk2->main_quit;
                                }
                            );

                        }
                    );
                }
            );
        }
    );
    Gtk2->main;

#########################

    unlink $filename, <$dir/*>;
    rmdir $dir;
}

Gscan2pdf::Document->quit();
