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
Log::Log4perl->easy_init($WARN);
Gscan2pdf::Document->setup(Log::Log4perl::get_logger);

# Create test image
system('convert -size 210x297 xc:white white.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['white.pnm'],
    finished_callback => sub {
        $slist->{data}[0][2]{resolution} = 10;
        $slist->user_defined(
            page              => $slist->{data}[0][2],
            command           => 'convert %i tmp.ppm;mv tmp.ppm %i',
            finished_callback => sub {
                is( $slist->{data}[0][2]{resolution},
                    10, 'Resolution of converted image taken from input' );
                Gtk2->main_quit;
            }
        );
    }
);
Gtk2->main;

#########################

unlink 'white.pnm', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
