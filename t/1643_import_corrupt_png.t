use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create corrupt image
system('echo "" > test.png');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.png'],
    finished_callback => sub {
        fail('caught errors importing file');
        Gtk3->main_quit;
    },
    error_callback => sub {
        pass('caught errors importing file');
        Gtk3->main_quit;
    }
);
Gtk3->main;

#########################

unlink 'test.png', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
