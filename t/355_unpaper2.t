use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 3;

BEGIN {
    use Gscan2pdf::Document;
    use Gscan2pdf::Unpaper;
    use Gtk2 -init;    # Could just call init separately
}

SKIP: {
    skip 'unpaper not installed', 2
      unless ( system("which unpaper > /dev/null 2> /dev/null") == 0 );
    Gscan2pdf::Translation::set_domain('gscan2pdf');
    my $unpaper =
      Gscan2pdf::Unpaper->new( { 'output-pages' => 2, layout => 'double' } );

    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($WARN);
    Gscan2pdf::Document->setup(Log::Log4perl::get_logger);

    # Create test image
    system(
'convert +matte -depth 1 -border 2x2 -bordercolor black -pointsize 12 -density 300 label:"The quick brown fox" 1.pnm'
    );
    system(
'convert +matte -depth 1 -border 2x2 -bordercolor black -pointsize 12 -density 300 label:"The slower lazy dog" 2.pnm'
    );
    system('convert -size 100x100 xc:black black.pnm');
    system('convert 1.pnm black.pnm 2.pnm +append test.pnm');

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths             => ['test.pnm'],
        finished_callback => sub {
            $slist->unpaper(
                page              => $slist->{data}[0][2],
                options           => { command => $unpaper->get_cmdline },
                finished_callback => sub {
                    is( system("identify $slist->{data}[0][2]{filename}"),
                        0, 'valid PNM created for LH' );
                    is( system("identify $slist->{data}[1][2]{filename}"),
                        0, 'valid PNM created for RH' );
                    is( dirname("$slist->{data}[0][2]{filename}"),
                        "$dir", 'using session directory' );

                    Gtk2->main_quit;
                }
            );
        }
    );
    Gtk2->main;

    unlink 'test.pnm', '1.pnm', '2.pnm', 'black.pnm', <$dir/*>;
    rmdir $dir;
    Gscan2pdf::Document->quit();
}
