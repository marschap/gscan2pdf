use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
Gscan2pdf::Document->setup(Log::Log4perl::get_logger);

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
system('convert -size 210x297 xc:white white.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);
$slist->set_paper_sizes( \%paper_sizes );

$slist->import_files(
    paths             => ['white.pnm'],
    finished_callback => sub {

        # Now we've imported it,
        # remove the data to give a corrupt image
        system("echo '' > $slist->{data}[0][2]->{filename}");
        $slist->user_defined(
            page              => $slist->{data}[0][2],
            command           => 'convert %i -negate %o',
            finished_callback => sub {
                Gtk2->main_quit;
            },
            error_callback => sub {
                pass('caught errors from user-defined');
            }
        );
    }
);
Gtk2->main;

#########################

unlink 'white.pnm', 'test.pdf', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
