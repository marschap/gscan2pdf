use warnings;
use strict;
use Test::More tests => 3;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
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
    paths             => [ 'test.pnm', 'test.pnm' ],
    finished_callback => sub {
        $slist->save_pdf(
            path          => 'test.pdf',
            list_of_pages => [ $slist->{data}[0][2], $slist->{data}[1][2] ],
            options       => {
                ps                     => 'te st.ps',
                pstool                 => 'pdf2ps',
                post_save_hook         => 'cp %i test2.ps',
                post_save_hook_options => 'fg',
            },
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

like(
    `identify 'te st.ps'`,
    qr/te st.ps\[0\] PS \d+x\d+ \d+x\d+\+0\+0 16-bit sRGB .*B/,
    'valid postscript created (p1)'
);
like(
    `identify 'te st.ps'`,
    qr/te st.ps\[1\] PS \d+x\d+ \d+x\d+\+0\+0 16-bit sRGB .*B/,
    'valid postscript created (p2)'
);
like(
    `identify test2.ps`,
    qr/test2.ps\[0\] PS \d+x\d+ \d+x\d+\+0\+0 16-bit sRGB .*B/,
    'ran post-save hook'
);

#########################

unlink 'test.pnm', 'test2.ps', 'te st.ps';
Gscan2pdf::Document->quit();
