use warnings;
use strict;
use Test::More tests => 3;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk3 -init;    # Could just call init separately
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
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->save_image(
            path          => 'test.jpg',
            list_of_pages => [ $slist->{data}[0][2] ],
            options       => {
                post_save_hook         => 'convert %i test2.png',
                post_save_hook_options => 'fg',
            },
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

like(
    `identify test.jpg`,
    qr/test.jpg JPEG 70x46 70x46\+0\+0 8-bit sRGB/,
    'valid JPG created'
);
like(
    `identify test2.png`,
    qr/test2\.png PNG 70x46 70x46\+0\+0 8-bit sRGB \d+K?B 0\.000u 0:00\.000\b/,
    'ran post-save hook'
);

#########################

unlink 'test.pnm', 'test.jpg';
Gscan2pdf::Document->quit();
