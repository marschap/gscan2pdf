use warnings;
use strict;
use Test::More tests => 18;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane 0.05;              # To get SANE_* enums

BEGIN {
 use_ok('Gscan2pdf::Scanner::Dialog');
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

#Log::Log4perl->easy_init($DEBUG);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Sane->setup($logger);

ok(
 my $dialog = Gscan2pdf::Scanner::Dialog->new(
  title           => 'title',
  'transient-for' => $window,
  'logger'        => $logger
 ),
 'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Scanner::Dialog' );

is( $dialog->get('device'),                '',    'device' );
is( $dialog->get('device-list'),           undef, 'device-list' );
is( $dialog->get('dir'),                   undef, 'dir' );
is( $dialog->get('num-pages'),             1,     'num-pages' );
is( $dialog->get('page-number-start'),     1,     'page-number-start' );
is( $dialog->get('page-number-increment'), 1,     'page-number-increment' );
is( $dialog->get('scan-options'),          undef, 'scan-options' );

$dialog->signal_connect(
 'changed-device' => sub {
  my ( $widget, $name ) = @_;
  is( $name, 'test', 'changed-device' );
 }
);
$dialog->set( 'device', 'test' );

my $signal = $dialog->signal_connect(
 'changed-device-list' => sub {
  ok( 1, 'changed-device-list' );
 }
);
$dialog->set( 'device-list', [ { label => 'test' } ] );

$dialog->signal_connect(
 'changed-num-pages' => sub {
  my ( $widget, $n, $signal ) = @_;
  is( $n, 0, 'changed-num-pages' );
  $dialog->signal_handler_disconnect($signal);
 },
 $signal
);
$dialog->set( 'num-pages', 0 );

$dialog->signal_connect(
 'changed-page-number-start' => sub {
  my ( $widget, $n ) = @_;
  is( $n, 2, 'changed-page-number-start' );
 }
);
$dialog->set( 'page-number-start', 2 );

$dialog->signal_connect(
 'changed-page-number-increment' => sub {
  my ( $widget, $n ) = @_;
  is( $n, 2, 'changed-page-number-increment' );
 }
);
$dialog->set( 'page-number-increment', 2 );

$dialog->signal_connect(
 'changed-scan-option' => sub {
  my ( $widget, $option, $value ) = @_;
  is( $option, SANE_NAME_SCAN_RESOLUTION, 'changed-scan-option name' );
  is( $value, 51, 'changed-scan-option value' );
 }
);
my $options = $dialog->get('scan-options');
$dialog->set_option( $options->by_name(SANE_NAME_SCAN_RESOLUTION), 51 );

$dialog->signal_connect(
 'changed-profile' => sub {
  my ( $widget, $profile ) = @_;
  is( $profile, 'my profile', 'changed-profile' );
 }
);
$dialog->add_profile( 'my profile', [ { SANE_NAME_SCAN_RESOLUTION => 52 } ] );
$dialog->set( 'profile', 'my profile' );

$dialog->signal_connect(
 'reloaded-scan-options' => sub {
  ok( 1, 'reloaded-scan-options' );
 }
);
$dialog->set( 'scan-options', Gscan2pdf::Scanner::Options->new );

$dialog = Gscan2pdf::Scanner::Dialog->new(
 title           => 'title',
 'transient-for' => $window
);
$dialog->signal_connect(
 'new-scan' => sub {
  my ( $widget, $n ) = @_;
  is( $n, 1, 'new_scan' );
  Gtk2->main_quit;
 }
);
Glib::Idle->add( sub { $dialog->scan; } );
Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;
__END__
