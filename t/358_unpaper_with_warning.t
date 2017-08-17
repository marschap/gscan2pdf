use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gscan2pdf::Unpaper;
    use Gtk2 -init;    # Could just call init separately
}

#########################

SKIP: {
    skip 'unpaper not installed', 1
      unless ( system("which unpaper > /dev/null 2> /dev/null") == 0 );
    Gscan2pdf::Translation::set_domain('gscan2pdf');
    my $unpaper =
      Gscan2pdf::Unpaper->new( { 'deskew-scan-direction' => 'bottom,top' } );

    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($FATAL);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    # Create test image
    my $filename = 'test.png';
    system(
'convert +matte -depth 1 -colorspace Gray -pointsize 12 -density 300 label:"The quick brown fox" -rotate 20 '
          . $filename );

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths             => [$filename],
        finished_callback => sub {
            $slist->unpaper(
                page           => $slist->{data}[0][2],
                options        => { command => $unpaper->get_cmdline },
                error_callback => sub {
                    my ($message) = @_;
                    unlike( $message, qr/Processing/,
                        'Removed processing line from warning message' );
                    Gtk2->main_quit;
                }
            );
        }
    );
    Gtk2->main;

#########################

    unlink $filename, <$dir/*>;
    rmdir $dir;
}

Gscan2pdf::Document->quit();
