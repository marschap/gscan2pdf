# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Gscan2pdf.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Test::More tests => 1;

BEGIN {
 use Gscan2pdf::Document;
 use Gscan2pdf::Unpaper;
 use Gtk2 -init;    # Could just call init separately
 use version;
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

SKIP: {
 skip 'unpaper not installed', 1
   unless ( system("which unpaper > /dev/null 2> /dev/null") == 0 );
 my $unpaper = Gscan2pdf::Unpaper->new;

 use Log::Log4perl qw(:easy);
 Log::Log4perl->easy_init($WARN);
 our $logger = Log::Log4perl::get_logger;
 Gscan2pdf::Document->setup($logger);

 # Create test image
 system(
'convert +matte -depth 1 -border 2x2 -bordercolor black -pointsize 12 -density 300 label:"The quick brown fox" test.pnm'
 );

 my $slist = Gscan2pdf::Document->new;
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
       $slist->save_image(
        path              => 'test.png',
        list_of_pages     => [ $slist->{data}[0][2] ],
        finished_callback => sub { Gtk2->main_quit }
       );
      }
     );
    }
   );
  }
 );
 Gtk2->main;

 is( system('identify test.png'), 0, 'valid PNG created' );

 unlink 'test.pnm', 'test.png';
 Gscan2pdf::Document->quit();
}
