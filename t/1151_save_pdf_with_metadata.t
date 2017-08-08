use warnings;
use strict;
use Date::Calc qw(Date_to_Time);
use File::stat;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Test::More tests => 4;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk2 -init;         # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
my $pnm = 'test.pnm';
my $pdf = 'test.pdf';
system("convert rose: $pnm");

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my %metadata = ( date => [ 2016, 2, 10 ], title => 'metadata title' );
$slist->import_files(
    paths             => [$pnm],
    finished_callback => sub {
        $slist->save_pdf(
            path              => $pdf,
            list_of_pages     => [ $slist->{data}[0][2] ],
            metadata          => \%metadata,
            options           => { set_timestamp => TRUE },
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

my $info = `pdfinfo $pdf`;
like( $info, qr/metadata title/,            'metadata title in PDF' );
like( $info, qr/Wed Feb 10 0\d:00:00 2016/, 'metadata ModDate in PDF' );
my $sb = stat($pdf);
is( $sb->mtime, Date_to_Time( 2016, 2, 10, 0, 0, 0 ), 'timestamp' );

#########################

unlink $pnm, $pdf;
Gscan2pdf::Document->quit();
