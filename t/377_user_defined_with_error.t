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

my %paper_sizes = (
    A4 => {
        x => 210,
        y => 297,
        l => 0,
        t => 0,
    },
    'US Letter' => {
        x => 216,
        y => 279,
        l => 0,
        t => 0,
    },
    'US Legal' => {
        x => 216,
        y => 356,
        l => 0,
        t => 0,
    },
);

# Create test image
my $filename = 'white.pnm';
system("convert -size 210x297 xc:white $filename");

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);
$slist->set_paper_sizes( \%paper_sizes );

$slist->get_file_info(
    path              => $filename,
    finished_callback => sub {
        my ($info) = @_;
        $slist->import_file(
            info              => $info,
            first             => 1,
            last              => 1,
            finished_callback => sub {

                # inject error before user_defined
                chmod 0500, $dir;    # no write access

                $slist->user_defined(
                    page           => $slist->{data}[0][2],
                    command        => 'convert %i -negate %o',
                    error_callback => sub {
                        ok( 1, 'caught error injected before user_defined' );
                        chmod 0700, $dir;    # allow write access

                        $slist->user_defined(
                            page            => $slist->{data}[0][2],
                            command         => 'convert %i -negate %o',
                            queued_callback => sub {

                                # inject error during user_defined
                                chmod 0500, $dir;    # no write access
                            },
                            error_callback => sub {
                                ok( 1,
'user_defined caught error injected in queue'
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

Gscan2pdf::Document->quit();
