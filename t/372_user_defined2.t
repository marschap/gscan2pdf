use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
Gscan2pdf::Document->setup(Log::Log4perl::get_logger);

# Create test image
system('convert xc:white white.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['white.pnm'],
    finished_callback => sub {
        $slist->user_defined(
            page              => $slist->{data}[0][2],
            command           => 'convert %i -negate %i',
            finished_callback => sub {
                $slist->analyse(
                    page              => $slist->{data}[0][2],
                    finished_callback => sub { Gtk2->main_quit }
                );
            }
        );
    }
);
Gtk2->main;

is( $slist->{data}[0][2]{mean}, 0, 'User-defined with %i' );

#########################

unlink 'white.pnm';
Gscan2pdf::Document->quit();
