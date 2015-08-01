use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 4;

BEGIN {
    use_ok('Gscan2pdf::Document');
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

$slist->import_files(
    paths             => ['test.jpg'],
    finished_callback => sub {
        $slist->rotate(
            angle             => 90,
            page              => $slist->{data}[0][2],
            display_callback  => sub { ok 1, 'Triggered display callback' },
            finished_callback => sub {
                is( system("identify $slist->{data}[0][2]{filename}"),
                    0, 'valid JPG created' );
                is( dirname("$slist->{data}[0][2]{filename}"),
                    "$dir", 'using session directory' );
                Gtk2->main_quit;
            }
        );
    }
);
Gtk2->main;

#########################

unlink 'test.jpg', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
