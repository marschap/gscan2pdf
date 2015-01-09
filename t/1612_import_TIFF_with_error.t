use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 3;

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
system('convert rose: test.tif');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

# inject error before get_file_info
chmod 0500, $dir;    # no write access

$slist->get_file_info(
    path           => 'test.tif',
    error_callback => sub {
        ok( 1, 'get_file_info caught error injected before call' );
        chmod 0700, $dir;    # allow write access
        $slist->get_file_info(
            path              => 'test.tif',
            finished_callback => sub {
                my ($info) = @_;

                # inject error before import_file
                chmod 0500, $dir;    # no write access
                $slist->import_file(
                    info           => $info,
                    first          => 1,
                    last           => 1,
                    error_callback => sub {
                        ok( 1,
                            'import_file caught error injected before call' );
                        chmod 0700, $dir;    # allow write access
                        $slist->import_file(
                            info            => $info,
                            first           => 1,
                            last            => 1,
                            queued_callback => sub {

                                # inject error during import_file
                                chmod 0500, $dir;    # no write access
                            },
                            error_callback => sub {
                                ok( 1,
                                    'import_file caught error injected in queue'
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

unlink 'test.tif', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
