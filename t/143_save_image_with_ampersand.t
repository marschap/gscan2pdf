use warnings;
use strict;
use Test::More tests => 2;

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

my $path = 'sed & awk.png';

$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->save_image(
            path              => $path,
            list_of_pages     => [ $slist->{data}[0][2] ],
            finished_callback => sub { Gtk2->main_quit }
        );
    }
);
Gtk2->main;

ok( -f $path,     'file created' );
ok( -s $path > 0, 'file is not empty' );

#########################

unlink 'test.pnm', $path;
Gscan2pdf::Document->quit();
