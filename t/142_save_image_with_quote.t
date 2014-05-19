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
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

mkdir "te'st";

$slist->get_file_info(
    path              => 'test.pnm',
    finished_callback => sub {
        my ($info) = @_;
        $slist->import_file(
            info              => $info,
            first             => 1,
            last              => 1,
            finished_callback => sub {
                $slist->save_image(
                    path              => "te'st/te'st.jpg",
                    list_of_pages     => [ $slist->{data}[0][2] ],
                    finished_callback => sub { Gtk2->main_quit }
                );
            }
        );
    }
);
Gtk2->main;

ok( -f "te\'st/te'st.jpg", 'file created' );

ok( -s "te\'st/te'st.jpg" > 0, 'file is not empty' );

#########################

unlink 'test.pnm', "te'st/te'st.jpg";
rmdir "te'st";
Gscan2pdf::Document->quit();
