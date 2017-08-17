use warnings;
use strict;
use Test::More tests => 2;
use Gtk2 -init;    # Could just call init separately

BEGIN {
    use Gscan2pdf::Document;
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.pnm');
system("convert rose: 'te st.pdf'");

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->save_pdf(
            path          => 'te st.pdf',
            list_of_pages => [ $slist->{data}[0][2] ],
            options       => {
                prepend => 'te st.pdf',
            },
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

is(
    `pdfinfo 'te st.pdf' | grep 'Pages:'`,
    "Pages:          2\n",
    'PDF prepended'
);
is( -f 'te st.pdf.bak', 1, 'Backed up original' );

#########################

unlink 'test.pnm', 'te st.pdf', 'te st.pdf.bak';
Gscan2pdf::Document->quit();
