use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 5;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gscan2pdf::Document;

BEGIN {
    use Gtk2 -init;         # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.tif');
my $old = `identify -format '%m %G %g %z-bit %r' test.tif`;

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.tif'],
    finished_callback => sub {
        my $clipboard = $slist->copy_selection(TRUE);
        $slist->paste_selection( $clipboard, '0', 'after' )
          ;    # copy-paste page 1->2
        isnt(
            "$slist->{data}[0][2]{filename}",
            "$slist->{data}[1][2]{filename}",
            'different filename'
        );
        isnt( "$slist->{data}[0][2]{uuid}",
            "$slist->{data}[1][2]{uuid}", 'different uuid' );
        is( "$slist->{data}[1][0]", 2, 'new page is number 2' );
        my @rows = $slist->get_selected_indices;
        is_deeply( \@rows, [1], 'pasted page selected' );

        $clipboard = $slist->cut_selection;
        is( $#{$clipboard}, 0, 'cut 1 page to clipboard' );
        Gtk2->main_quit;
    }
);
Gtk2->main;

#########################

unlink 'test.tif', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
