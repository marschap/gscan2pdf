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
system('convert rose: test.pnm; c44 test.pnm te\ st.djvu');

my $slist = Gscan2pdf::Document->new;
$slist->import_files(
    paths             => ['te st.djvu'],
    finished_callback => sub {
        is( $#{ $slist->{data} }, 0, 'Imported correctly DjVu with spaces' );
        Gtk2->main_quit;
    }
);
Gtk2->main;

#########################

unlink 'test.pnm', 'te st.djvu';
Gscan2pdf::Document->quit();
