use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 1;

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
system('convert xc:white white.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->get_file_info(
    path              => 'white.pnm',
    finished_callback => sub {
        my ($info) = @_;
        $slist->import_file(
            info              => $info,
            first             => 1,
            last              => 1,
            finished_callback => sub {

                # Now we've imported it,
                # remove the data to give a corrupt image
                system("echo '' > $slist->{data}[0][2]->{filename}");
                $slist->negate(
                    page              => $slist->{data}[0][2],
                    finished_callback => sub {
                        ok( 0, 'caught errors from negate' );
                        Gtk2->main_quit;
                    },
                    error_callback => sub {
                        ok( 1, 'caught errors from negate' );
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
