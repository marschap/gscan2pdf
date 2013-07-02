use warnings;
use strict;
use Test::More tests => 13;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane 0.05;              # To get SANE_* enums

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
  title           => 'title',
  'transient-for' => $window,
  'logger'        => $logger
 ),
 'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::CLI' );

is( $dialog->get('hidden-scan-options'), undef, 'initial hidden-scan-options' );

my $signal;
$signal = $dialog->signal_connect(
 'changed-option-visibility' => sub {
  ok( 1, 'changed-option-visibility' );

  is_deeply( $dialog->get('hidden-scan-options'),
   ['mode'], 'updated hidden-scan-options' );
  $dialog->signal_handler_disconnect($signal);

  $dialog->set( 'hidden-scan-options', undef );
  is( $dialog->get('hidden-scan-options'), undef, 'reset hidden-scan-options' );
 }
);
$dialog->set( 'hidden-scan-options', ['mode'] );

$dialog->signal_connect(
 'changed-device-list' => sub {
  ok( 1, 'changed-device-list' );

  is_deeply(
   $dialog->get('device-list'),
   [ { 'name' => 'test', 'model' => 'test', 'label' => 'test' } ],
   'add model field if missing'
  );

  $signal = $dialog->signal_connect(
   'changed-device' => sub {
    my ( $widget, $name ) = @_;
    is( $name, 'test', 'changed-device' );
    $dialog->signal_handler_disconnect($signal);
   }
  );
  $dialog->set( 'device', 'test' );
 }
);
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );

$signal = $dialog->signal_connect(
 'reloaded-scan-options' => sub {
  ok( 1, 'reloaded-scan-options' );
  $dialog->signal_handler_disconnect($signal);

  my $options = $dialog->get('available-scan-options');
  my $option  = $options->by_name('mode');
  isnt( $option->{widget}, undef, 'mode widget exists' );

  $dialog->set( 'hidden-scan-options', ['Mode'] );
  is( $option->{widget}, undef, 'mode widget removed by title' );
  Gtk2->main_quit;
 }
);
Gtk2->main;

__END__
