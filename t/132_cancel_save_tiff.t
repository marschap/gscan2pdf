use warnings;
use strict;
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
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        my $pid = $slist->save_tiff(
            path               => 'test.tif',
            list_of_pages      => [ $slist->{data}[0][2] ],
            cancelled_callback => sub {
                $slist->save_image(
                    path              => 'test.jpg',
                    list_of_pages     => [ $slist->{data}[0][2] ],
                    finished_callback => sub { Gtk2->main_quit }
                );
            }
        );
        $slist->cancel($pid);
    }
);
Gtk2->main;

is( system('identify test.jpg'),
    0, 'can create a valid JPG after cancelling save TIFF process' );

#########################

unlink 'test.pnm', 'test.tif', 'test.jpg';
Gscan2pdf::Document->quit();
