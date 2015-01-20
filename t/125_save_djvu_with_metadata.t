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

my $metadata = { Title => 'metadata title' };
$slist->get_file_info(
    path              => 'test.pnm',
    finished_callback => sub {
        my ($info) = @_;
        $slist->import_file(
            info              => $info,
            first             => 1,
            last              => 1,
            finished_callback => sub {
                $slist->save_djvu(
                    path              => 'test.djvu',
                    list_of_pages     => [ $slist->{data}[0][2] ],
                    metadata          => $metadata,
                    finished_callback => sub { Gtk2->main_quit }
                );
            }
        );
    }
);
Gtk2->main;

like(
    `djvused test.djvu -e 'print-meta'`,
    qr/metadata title/,
    'metadata in DjVu'
);

#########################

unlink 'test.pnm', 'test.djvu';
Gscan2pdf::Document->quit();