use warnings;
use strict;
use Test::More tests => 9;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately

BEGIN {
 use_ok('Gscan2pdf::Dialog::Scan::CLI');
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

ok(
 my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
  title             => 'title',
  'transient-for'   => $window,
  'logger'          => $logger,
  'reload-triggers' => qw(mode),
 ),
 'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::CLI' );

is( $dialog->get('cache-options'), 0, 'default cache-options' );

my $signal;
$signal = $dialog->signal_connect(
 'changed-cache-options' => sub {
  my ( $widget, $cache_options ) = @_;
  $dialog->signal_handler_disconnect($signal);
  is( $cache_options, TRUE, 'changed cache-options' );
 }
);
$dialog->set( 'cache-options', TRUE );

$signal = $dialog->signal_connect(
 'changed-options-cache' => sub {
  my ( $widget, $cache ) = @_;
  $dialog->signal_handler_disconnect($signal);
  ok( 1, 'changed options-cache' );

  my $options = $dialog->get('available-scan-options');
  $dialog->set_option( $options->by_name('mode'), 'Color' );

  $signal = $dialog->signal_connect(
   'changed-options-cache' => sub {
    my ( $widget, $cache ) = @_;
    $dialog->signal_handler_disconnect($signal);
    ok( 1, 'changed options-cache after set mode' );

    $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
     title             => 'title',
     'transient-for'   => $window,
     'logger'          => $logger,
     'reload-triggers' => qw(mode),
     'cache-options'   => TRUE,
     'options-cache'   => $cache,
    );
    $signal = $dialog->signal_connect(
     'fetched-options-cache' => sub {
      my ( $widget, $device, $cache_key ) = @_;
      $dialog->signal_handler_disconnect($signal);
      ok( 1, 'fetched-options-cache' );

      $signal = $dialog->signal_connect(
       'fetched-options-cache' => sub {
        my ( $widget, $device, $cache_key ) = @_;
        $dialog->signal_handler_disconnect($signal);
        ok( 1, 'fetched-options-cache for set mode' );
        Gtk2->main_quit;
       }
      );

      my $signal2;
      $signal2 = $dialog->signal_connect(
       'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect($signal2);
        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name('mode'), 'Color' );
       }
      );

     }
    );
    $dialog->set( 'device-list', [ { 'name' => 'test' } ] );
    $dialog->set( 'device', 'test' );
   }
  );
 }
);
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );
$dialog->set( 'device', 'test' );

Gtk2->main;

__END__
