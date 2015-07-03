use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk2 -init;    # Could just call init separately
    use PDF::API2;
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
$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->save_pdf(
            path              => 'test.pdf',
            list_of_pages     => [ $slist->{data}[0][2] ],
            metadata          => $metadata,
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

like( `pdfinfo test.pdf`, qr/metadata title/, 'metadata in PDF' );

#########################

unlink 'test.pnm', 'test.pdf';
Gscan2pdf::Document->quit();
