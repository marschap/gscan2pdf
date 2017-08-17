use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.tif');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

# inject error before import_files
chmod 0500, $dir;    # no write access

$slist->import_files(
    paths          => ['test.tif'],
    error_callback => sub {
        pass('import_files caught error injected before call');
        chmod 0700, $dir;    # allow write access
        $slist->import_files(
            paths           => ['test.tif'],
            queued_callback => sub {

                # inject error during import_file
                chmod 0500, $dir;    # no write access
            },
            error_callback => sub {
                pass('import_files caught error injected in queue');
                chmod 0700, $dir;    # allow write access
                Gtk2->main_quit;
            }
        );
    }
);
Gtk2->main;

#########################

unlink 'test.tif', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
