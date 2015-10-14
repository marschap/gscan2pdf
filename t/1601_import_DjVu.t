use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 3;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.jpg;c44 test.jpg test.djvu');
my $old = `identify -format '%m %G %g %z-bit %r' test.djvu`;

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths            => ['test.djvu'],
    started_callback => sub {
        my ( $n, $process_name, $jobs_completed, $jobs_total, $message,
            $progress )
          = @_;
        ok(
            ( defined $message and $message ne '' ),
            'started callback has message'
        );
    },
    finished_callback => sub {
        like(
`identify -format '%m %G %g %z-bit %r' $slist->{data}[0][2]{filename}`,
            qr/^TIFF/,
            'DjVu imported correctly'
        );
        is( dirname("$slist->{data}[0][2]{filename}"),
            "$dir", 'using session directory' );
        Gtk2->main_quit;
    }
);
Gtk2->main;

#########################

unlink 'test.djvu', 'test.jpg', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
