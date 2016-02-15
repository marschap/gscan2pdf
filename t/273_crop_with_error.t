use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.gif');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.gif'],
    finished_callback => sub {

        # inject error before crop
        chmod 0500, $dir;    # no write access

        $slist->crop(
            page           => $slist->{data}[0][2],
            x              => 10,
            y              => 10,
            w              => 10,
            h              => 10,
            error_callback => sub {
                pass('caught error injected before crop');
                chmod 0700, $dir;    # allow write access

                $slist->crop(
                    page            => $slist->{data}[0][2],
                    x               => 10,
                    y               => 10,
                    w               => 10,
                    h               => 10,
                    queued_callback => sub {

                        # inject error during crop
                        chmod 0500, $dir;    # no write access
                    },
                    error_callback => sub {
                        pass('crop caught error injected in queue');
                        chmod 0700, $dir;    # allow write access
                        Gtk2->main_quit;
                    }
                );

            }
        );
    }
);
Gtk2->main;

#########################

unlink 'white.pnm', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
