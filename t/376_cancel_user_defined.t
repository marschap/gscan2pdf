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

# Create test image
system('convert xc:white white.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['white.pnm'],
    finished_callback => sub {
        my $md5sum = `md5sum $slist->{data}[0][2]{filename} | cut -c -32`;
        $slist->user_defined(
            page              => $slist->{data}[0][2],
            command           => 'convert %i -negate %o',
            finished_callback => sub { ok 0, 'Finished callback' }
        );
        $slist->cancel(
            sub {
                is(
                    $md5sum,
                    `md5sum $slist->{data}[0][2]{filename} | cut -c -32`,
                    'image not modified'
                );
                $slist->save_image(
                    path              => 'test.jpg',
                    list_of_pages     => [ $slist->{data}[0][2] ],
                    finished_callback => sub { Gtk2->main_quit }
                );
            }
        );
    }
);
Gtk2->main;

is( system('identify test.jpg'),
    0, 'can create a valid JPG after cancelling previous process' );

#########################

unlink 'white.pnm', 'test.jpg';
Gscan2pdf::Document->quit();
