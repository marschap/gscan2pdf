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

# Create test image
system('convert rose: test.jpg;c44 test.jpg test.djvu');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths           => ['test.djvu'],
    queued_callback => sub {

        # inject error during import_file
        chmod 0500, $dir;    # no write access
    },
    error_callback => sub {
        pass('import_file caught error injected in queue');
        chmod 0700, $dir;    # allow write access
        Gtk3->main_quit;
    }
);
Gtk3->main;

#########################

unlink 'test.djvu', 'test.jpg', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
