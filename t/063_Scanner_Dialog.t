use warnings;
use strict;
use Test::More tests => 1;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane 0.05;              # To get SANE_* enums
use Gscan2pdf::Dialog::Scan::Sane;

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Sane->new(
 title           => 'title',
 'transient-for' => $window,
 'logger'        => $logger
);
$dialog->set( 'device', 'test' );
$dialog->scan_options('test');

my $signal;
$signal = $dialog->signal_connect(
 'reloaded-scan-options' => sub {
  $dialog->signal_handler_disconnect($signal);

  # The ADF in the test backend returns out of documents after 10 scans
  my $options = $dialog->get('available-scan-options');
  $dialog->set_option( $options->by_name('source'),
   'Automatic Document Feeder' );
  $dialog->set( 'num-pages', 0 );

  # Check we actually get 10 scans
  my ( $n_signal, $n );
  $n_signal = $dialog->signal_connect(
   'new-scan' => sub {
    ( my $widget, $n ) = @_;
   }
  );

  $dialog->signal_connect(
   'finished-process' => sub {
    my ( $widget, $process ) = @_;
    if ( $process eq 'scan_pages' ) {
     is( $n, 10, 'new-scan emitted 10 times' );
     Gtk2->main_quit;
    }
   }
  );
  $dialog->scan;
 }
);
Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;

unlink <out*.pnm>
__END__
