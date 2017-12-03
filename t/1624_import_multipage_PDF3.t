use warnings;
use strict;
use File::Temp;
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk2 -init;    # Could just call init separately
}

#########################

TODO: {
    todo_skip 'pdfunite (poppler utils) not installed', 1 unless `which pdfunite`;
    todo_skip '2000 page pdf import cannot succeede with current architecture',
      1
      if 1;

    Gscan2pdf::Translation::set_domain('gscan2pdf');
    use Log::Log4perl qw(:easy);

    Log::Log4perl->easy_init($WARN);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    # Create test image
    system('convert rose: page1.pdf');
    system(
'pdfunite page1.pdf page1.pdf page1.pdf page1.pdf page1.pdf page1.pdf page1.pdf page1.pdf page1.pdf page1.pdf 10.pdf'
    );
    system(
'pdfunite 10.pdf 10.pdf 10.pdf 10.pdf 10.pdf 10.pdf 10.pdf 10.pdf 10.pdf 10.pdf 100.pdf'
    );
    system(
'pdfunite 100.pdf 100.pdf 100.pdf 100.pdf 100.pdf 100.pdf 100.pdf 100.pdf 100.pdf 100.pdf 1000.pdf'
    );
    system('pdfunite 1000.pdf 1000.pdf 2000.pdf');

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths             => ['2000.pdf'],
        finished_callback => sub {
            is( $#{ $slist->{data} }, 1999, 'imported 2000 images' );
            Gtk2->main_quit;
        }
    );
    Gtk2->main;

#########################

    unlink 'page1.pdf', '10.pdf', '100.pdf', '1000.pdf', '2000.pdf', <$dir/*>;
    rmdir $dir;

    Gscan2pdf::Document->quit();
}
