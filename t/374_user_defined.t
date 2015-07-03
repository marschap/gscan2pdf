use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 5;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
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
        is( int( abs( $slist->{data}[0][2]{resolution} - 25.4 ) ),
            0, 'Resolution of imported image' );
        $slist->user_defined(
            page              => $slist->{data}[0][2],
            command           => 'convert %i tmp.pgm;mv tmp.pgm %i',
            finished_callback => sub {
                is( int( abs( $slist->{data}[0][2]{resolution} - 25.4 ) ),
                    0, 'Resolution of converted image' );
                my ( $dir, $base, $suffix ) =
                  fileparse( "$slist->{data}[0][2]{filename}", qr/\.[^.]*/ );
                is( $dir,    "$dir", 'using session directory' );
                is( $suffix, ".pgm", 'still has an extension' );
                $slist->save_pdf(
                    path              => 'test.pdf',
                    list_of_pages     => [ $slist->{data}[0][2] ],
                    finished_callback => sub { Gtk2->main_quit }
                );
            }
        );
    }
);
Gtk2->main;

like( `pdfinfo test.pdf`, qr/A4/, 'PDF is A4' );

#########################

unlink 'white.pnm', 'test.pdf', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
