use warnings;
use strict;
use Test::More tests => 1;
use Gtk3 -init;    # Could just call init separately

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
system('convert magick:netscape test.pbm');
my $input = `identify test.pbm`;

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.pbm'],
    finished_callback => sub {
        $slist->save_pdf(
            path              => 'test.pdf',
            list_of_pages     => [ $slist->{data}[0][2] ],
            finished_callback => sub {
                system('pdfimages test.pdf x');
                like(
                    `identify x-000.p*m`,
                    qr/1-bit Bilevel Gray/,
                    'PDF with 1bpp created'
                );
                Gtk3->main_quit;
            }
        );
    }
);
Gtk3->main;

#########################

unlink 'test.pbm', 'test.pdf', <x-000.p*m>;
Gscan2pdf::Document->quit();
