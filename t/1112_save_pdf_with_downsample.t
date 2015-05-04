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
system(
'convert +matte -depth 1 -colorspace Gray -pointsize 12 -density 300 label:"The quick brown fox" test.png'
);

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->get_file_info(
    path              => 'test.png',
    finished_callback => sub {
        my ($info) = @_;
        $slist->import_file(
            info              => $info,
            first             => 1,
            last              => 1,
            finished_callback => sub {
                $slist->save_pdf(
                    path              => 'test.pdf',
                    list_of_pages     => [ $slist->{data}[0][2] ],
                    finished_callback => sub {
                        $slist->save_pdf(
                            path          => 'test2.pdf',
                            list_of_pages => [ $slist->{data}[0][2] ],
                            options       => {
                                downsample       => 1,
                                'downsample dpi' => 150,
                            },
                            finished_callback => sub { Gtk2->main_quit }
                        );
                    }
                );
            }
        );
    }
);
Gtk2->main;

is( -s 'test.pdf' > -s 'test2.pdf', 1,
    'downsampled PDF smaller than original' );
system('pdfimages test2.pdf x');
like(
    `identify -format '%m %G %g %z-bit %r' x-000.pbm`,
    qr/PBM 22\dx2\d 22\dx2\d[+]0[+]0 1-bit DirectClass Gray/,
    'downsampled'
);

#########################

unlink 'test.png', 'test.pdf', 'test2.pdf', 'x-000.pbm';
Gscan2pdf::Document->quit();
