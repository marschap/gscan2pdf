use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Test::More tests => 2;

BEGIN {
 use Gscan2pdf::Document;
 use Gscan2pdf::Unpaper;
 use Gtk2 -init;       # Could just call init separately
 use version;
}

SKIP: {
 skip 'unpaper not installed', 2
   unless ( system("which unpaper > /dev/null 2> /dev/null") == 0 );
 my $unpaper = Gscan2pdf::Unpaper->new;

 use Log::Log4perl qw(:easy);
 Log::Log4perl->easy_init($WARN);
 my $logger = Log::Log4perl::get_logger;
 Gscan2pdf::Document->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -border 2x2 -bordercolor black -pointsize 12 -density 300 label:"The quick brown fox" test.pnm'
 );

 my $slist = Gscan2pdf::Document->new;

 # dir for temporary files
 my $dir = File::Temp->newdir;
 $slist->set_dir($dir);

 $slist->get_file_info(
  path              => 'test.pnm',
  finished_callback => sub {
   my ($info) = @_;
   $slist->import_file(
    info              => $info,
    first             => 1,
    last              => 1,
    finished_callback => sub {
     $slist->unpaper(
      page              => $slist->{data}[0][2],
      options           => $unpaper->get_cmdline,
      finished_callback => sub {
       is( system("identify $slist->{data}[0][2]{filename}"),
        0, 'valid image created' );
       is( dirname("$slist->{data}[0][2]{filename}"),
        "$dir", 'using session directory' );
       Gtk2->main_quit;
      }
     );
    }
   );
  }
 );
 Gtk2->main;

 unlink 'test.pnm', <$dir/*>;
 rmdir $dir;
 Gscan2pdf::Document->quit();
}
