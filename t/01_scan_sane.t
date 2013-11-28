use warnings;
use strict;
use Test::More tests => 2;

BEGIN {
 use_ok('Gscan2pdf::Frontend::Sane');
 use Gtk2;
}

#########################

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Sane->setup($logger);

Gscan2pdf::Frontend::Sane->open_device(
 device_name       => 'test',
 finished_callback => sub {
  Gscan2pdf::Frontend::Sane->scan_pages(
   dir               => '.',
   format            => 'out%d.pnm',
   start             => 1,
   step              => 1,
   npages            => 1,
   finished_callback => sub {
    is( -s 'out1.pnm', 30807, 'PNM created with expected size' );
    Gtk2->main_quit;
   }
  );
 }
);
Gtk2->main;

#########################

unlink 'out1.pnm';

Gscan2pdf::Frontend::Sane->quit();
