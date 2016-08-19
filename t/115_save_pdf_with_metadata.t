use warnings;
use strict;
use Encode qw(decode);
use Test::More tests => 3;

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
system('convert rose: test.pnm');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my $metadata = Gscan2pdf::Document::prepare_output_metadata(
    'PDF',
    {
        'document date' => decode( 'utf8', '2016-02-10' ),
        title           => 'metadata title',
    }
);
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

like( `pdfinfo test.pdf`, qr/metadata title/, 'metadata title in PDF' );
like(
    `pdfinfo test.pdf`,
    qr/Wed Feb 10 00:00:00 2016/,
    'metadata ModDate in PDF'
);

#########################

unlink 'test.pnm', 'test.pdf';
Gscan2pdf::Document->quit();
