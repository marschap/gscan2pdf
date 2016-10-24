use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 2;
use Carp;
use Sub::Override;     # Override Page to test functionality that
                       # we can't otherwise reproduce

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
my $logger = Log::Log4perl::get_logger;

# The overrides must occur before the thread is spawned in setup.
my $override = Sub::Override->new;
$override->replace(
    'Gscan2pdf::Page::import_djvutext' => sub {
        my ( $self, $text ) = @_;
        croak 'Error parsing djvu text';
        return;
    }
);

Gscan2pdf::Document->setup($logger);

# Create test image
system('convert rose: test.jpg;c44 test.jpg test.djvu');

my $old = `identify -format '%m %G %g %z-bit %r' test.djvu`;

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my $expected = <<'EOS';
EOS

$slist->import_files(
    paths          => ['test.djvu'],
    error_callback => sub {
        my ($message) = @_;
        ok( ( defined $message and $message ne '' ),
            'error callback has message' );
    },
    finished_callback => sub {
        like(
`identify -format '%m %G %g %z-bit %r' $slist->{data}[0][2]{filename}`,
            qr/^TIFF/,
            'DjVu otherwise imported correctly'
        );
        Gtk2->main_quit;
    }
);
Gtk2->main;

#########################

unlink 'test.djvu', 'text.txt', 'test.jpg', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
