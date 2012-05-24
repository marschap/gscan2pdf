use warnings;
use strict;
use Test::More tests => 34;
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

is( $dialog->get('device'),                '',       'device' );
is( $dialog->get('device-list'),           undef,    'device-list' );
is( $dialog->get('dir'),                   undef,    'dir' );
is( $dialog->get('num-pages'),             1,        'num-pages' );
is( $dialog->get('max-pages'),             0,        'max-pages' );
is( $dialog->get('page-number-start'),     1,        'page-number-start' );
is( $dialog->get('page-number-increment'), 1,        'page-number-increment' );
is( $dialog->get('side-to-scan'),          'facing', 'side-to-scan' );
is( $dialog->get('available-scan-options'), undef, 'available-scan-options' );

my $signal = $dialog->signal_connect(
 'changed-device-list' => sub {
  ok( 1, 'changed-device-list' );

  my $signal;
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
$dialog->set( 'device-list',
 [ { 'name' => 'test:0', 'model' => 'frontend-tester', 'vendor' => 'Noname' } ]
);

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
 'changed-side-to-scan' => sub {
  my ( $widget, $side ) = @_;
  is( $side, 'reverse', 'changed-side-to-scan' );
 }
);
$dialog->set( 'side-to-scan', 'reverse' );

$signal = $dialog->signal_connect(
 'reloaded-scan-options' => sub {
  ok( 1, 'reloaded-scan-options' );
  $dialog->signal_handler_disconnect($signal);

  # So that it can be used in hash
  my $resolution = SANE_NAME_SCAN_RESOLUTION;

  $dialog->signal_connect(
   'added-profile' => sub {
    my ( $widget, $name, $profile ) = @_;
    is( $name, 'my profile', 'added-profile name' );
    is_deeply( $profile, [ { $resolution => 52 } ], 'added-profile profile' );
   }
  );
  $dialog->add_profile( 'my profile', [ { $resolution => 52 } ] );

  # need a new main loop because of the timeout
  my $loop;
  my $profile_signal = $dialog->signal_connect(
   'changed-profile' => sub {
    my ( $widget, $profile ) = @_;
    is( $profile, 'my profile', 'changed-profile' );
    is_deeply(
     $dialog->get('current-scan-options'),
     [ { $resolution => 52 } ],
     'current-scan-options with profile'
    );
    $loop->quit;
   }
  );
  $loop = Glib::MainLoop->new;
  $dialog->set( 'profile', 'my profile' );
  $loop->run;

  my $option_signal;
  $option_signal = $dialog->signal_connect(
   'changed-scan-option' => sub {
    my ( $widget, $option, $value ) = @_;
    is( $option, SANE_NAME_SCAN_RESOLUTION, 'changed-scan-option name' );
    is( $value, 51, 'changed-scan-option value' );
    is( $dialog->get('profile'),
     undef, 'changing an option deselects the current profile' );
    is_deeply(
     $dialog->get('current-scan-options'),
     [ { $resolution => 51 } ],
     'current-scan-options without profile'
    );
    $dialog->signal_handler_disconnect($option_signal);
   }
  );
  my $options = $dialog->get('available-scan-options');
  $dialog->set_option( $options->by_name(SANE_NAME_SCAN_RESOLUTION), 51 );

  $dialog->signal_connect(
   'removed-profile' => sub {
    my ( $widget, $profile ) = @_;
    is( $profile, 'my profile', 'removed-profile' );
   }
  );
  $dialog->remove_profile('my profile');

  $dialog->signal_connect(
   'changed-paper-formats' => sub {
    my ( $widget, $formats ) = @_;
    ok( 1, 'changed-paper-formats' );
   }
  );
  $dialog->set(
   'paper-formats',
   {
    A4 => {
     l => 0,
     y => 297,
     x => 210,
     t => 0,
    }
   }
  );

  $dialog->signal_connect(
   'changed-paper' => sub {
    my ( $widget, $paper ) = @_;
    is( $paper, 'A4', 'changed-paper' );
   }
  );
  $dialog->set( 'paper', 'A4' );

  my $s_signal;
  $s_signal = $dialog->signal_connect(
   'started-process' => sub {
    ok( 1, 'started-process' );
    $dialog->signal_handler_disconnect($s_signal);
   }
  );
  my $c_signal;
  $c_signal = $dialog->signal_connect(
   'changed-progress' => sub {
    ok( 1, 'changed-progress' );
    $dialog->signal_handler_disconnect($c_signal);
   }
  );
  my $f_signal;
  $f_signal = $dialog->signal_connect(
   'finished-process' => sub {
    my ( $widget, $process ) = @_;
    is( $process, 'set_option', 'finished-process set_option' );
    $dialog->signal_handler_disconnect($f_signal);
   }
  );

  # FIXME: figure out how to emit this
  #     my $e_signal;
  #     $e_signal = $dialog->signal_connect(
  #      'process-error' => sub {
  #       ok( 1, 'process-error' );
  #       $dialog->signal_handler_disconnect($e_signal);
  #      }
  #     );
  $dialog->signal_connect(
   'new-scan' => sub {
    my ( $widget, $n ) = @_;
    is( $n, 2, 'new_scan' );
    Gtk2->main_quit;
   }
  );
  $dialog->scan;

 }
);
Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;
__END__
