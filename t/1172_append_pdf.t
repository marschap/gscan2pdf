use warnings;
use strict;
use Test::More tests => 2;
use Gtk2 -init;    # Could just call init separately

BEGIN {
    use Gscan2pdf::Document;
}

#########################

Glib::set_application_name('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.pnm');
system('convert rose: test.pdf');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->save_pdf(
            path          => 'test.pdf',
            list_of_pages => [ $slist->{data}[0][2] ],
            options       => {
                append => 'test.pdf',
            },
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

is( `pdfinfo test.pdf | grep 'Pages:'`, "Pages:          2\n", 'PDF appended' );
is( -f 'test.pdf.bak', 1, 'Backed up original' );

#########################

unlink 'test.pnm', 'test.pdf', 'test.pdf.bak';
Gscan2pdf::Document->quit();
