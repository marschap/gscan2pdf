use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

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

$slist->get_file_info(
    path              => 'test.jpg',
    finished_callback => sub {
        my ($info) = @_;
        $slist->import_file(
            info              => $info,
            first             => 1,
            last              => 1,
            finished_callback => sub {

                # inject error before threshold
                chmod 0500, $dir;    # no write access

                $slist->threshold(
                    threshold      => 80,
                    page           => $slist->{data}[0][2],
                    error_callback => sub {
                        ok( 1, 'caught error injected before threshold' );
                        chmod 0700, $dir;    # allow write access

                        $slist->threshold(
                            threshold       => 80,
                            page            => $slist->{data}[0][2],
                            queued_callback => sub {

                                # inject error during threshold
                                chmod 0500, $dir;    # no write access
                            },
                            error_callback => sub {
                                ok( 1,
                                    'threshold caught error injected in queue'
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

unlink 'test.jpg', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
