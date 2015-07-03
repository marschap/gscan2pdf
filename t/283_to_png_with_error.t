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
my $filename = 'test.pnm';
system("convert rose: $filename");

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => [$filename],
    finished_callback => sub {

        # inject error before to_png
        chmod 0500, $dir;    # no write access

        $slist->to_png(
            page           => $slist->{data}[0][2],
            error_callback => sub {
                ok( 1, 'caught error injected before to_png' );
                chmod 0700, $dir;    # allow write access

                $slist->to_png(
                    page            => $slist->{data}[0][2],
                    queued_callback => sub {

                        # inject error during to_png
                        chmod 0500, $dir;    # no write access
                    },
                    error_callback => sub {
                        ok( 1, 'to_png caught error injected in queue' );
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

unlink $filename, <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
