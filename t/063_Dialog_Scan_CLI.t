use warnings;
use strict;
use Test::More tests => 47;
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

  is_deeply(
   $dialog->get('device-list'),
   [ { 'name' => 'test', 'model' => 'test', 'label' => 'test' } ],
   'add model field if missing'
  );

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
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );

my $csignal;
$csignal = $dialog->signal_connect(
 'changed-num-pages' => sub {
  my ( $widget, $n, $signal ) = @_;
  is( $n, 0, 'changed-num-pages' );
  $dialog->signal_handler_disconnect($csignal);
 }
);
$dialog->set( 'num-pages', 0 );

$dialog->signal_connect(
 'changed-page-number-start' => sub {
  my ( $widget, $n ) = @_;
  is( $n, 2, 'changed-page-number-start' );
 }
);
$dialog->set( 'page-number-start', 2 );

$signal = $dialog->signal_connect(
 'changed-page-number-increment' => sub {
  my ( $widget, $n ) = @_;
  is( $n, 2, 'changed-page-number-increment' );
  $dialog->signal_handler_disconnect($signal);
 }
);
$dialog->set( 'page-number-increment', 2 );

$dialog->signal_connect(
 'changed-side-to-scan' => sub {
  my ( $widget, $side ) = @_;
  is( $side, 'reverse', 'changed-side-to-scan' );
  is( $dialog->get('page-number-increment'),
   -2, 'reverse side gives increment -2' );
 }
);
$dialog->set( 'side-to-scan', 'reverse' );

my $reloads = 0;
$dialog->signal_connect(
 'reloaded-scan-options' => sub {
  ++$reloads;
 }
);

$signal = $dialog->signal_connect(
 'reloaded-scan-options' => sub {
  is( $reloads, 1, 'reloaded-scan-options' );
  $dialog->signal_handler_disconnect($signal);

  # So that it can be used in hash
  my $resolution = SANE_NAME_SCAN_RESOLUTION;
  my $brx        = SANE_NAME_SCAN_BR_X;

  $signal = $dialog->signal_connect(
   'added-profile' => sub {
    my ( $widget, $name, $profile ) = @_;
    is( $name, 'my profile', 'added-profile name' );
    is_deeply(
     $profile,
     [ { $resolution => 52 }, { mode => 'Color' } ],
     'added-profile profile'
    );
    $dialog->signal_handler_disconnect($signal);
   }
  );
  $dialog->add_profile( 'my profile',
   [ { $resolution => 52 }, { mode => 'Color' } ] );

  ######################################

  $signal = $dialog->signal_connect(
   'added-profile' => sub {
    my ( $widget, $name, $profile ) = @_;
    is( $name, 'old profile', 'added-profile old name' );
    is_deeply(
     $profile,
     [ { mode => 'Gray' }, { $resolution => 51 } ],
     'added-profile profile as hash'
    );
    $dialog->signal_handler_disconnect($signal);
   }
  );
  $dialog->add_profile( 'old profile', { $resolution => 51, mode => 'Gray' } );

  ######################################

  $dialog->signal_connect(
   'removed-profile' => sub {
    my ( $widget, $profile ) = @_;
    is( $profile, 'old profile', 'removed-profile' );
   }
  );
  $dialog->remove_profile('old profile');

  ######################################

  # need a new main loop because of the timeout
  my $loop = Glib::MainLoop->new;
  my $flag = FALSE;
  $signal = $dialog->signal_connect(
   'changed-profile' => sub {
    my ( $widget, $profile ) = @_;
    is( $profile, 'my profile', 'changed-profile' );
    is_deeply(
     $dialog->get('current-scan-options'),
     [ { $resolution => 52 }, { mode => 'Color' } ],
     'current-scan-options with profile'
    );
    is( $reloads, 1, 'reloaded-scan-options not called' );
    $dialog->signal_handler_disconnect($signal);
    $flag = TRUE;
    $loop->quit;
   }
  );
  $dialog->set( 'profile', 'my profile' );
  $loop->run unless ($flag);

  ######################################

  $dialog->add_profile( 'my profile2',
   [ { $resolution => 52 }, { mode => 'Color' } ] );

  # need a new main loop because of the timeout
  $loop   = Glib::MainLoop->new;
  $flag   = FALSE;
  $signal = $dialog->signal_connect(
   'changed-profile' => sub {
    my ( $widget, $profile ) = @_;
    is( $profile, 'my profile2', 'set profile with identical options' );
    $dialog->signal_handler_disconnect($signal);
    $flag = TRUE;
    $loop->quit;
   }
  );
  $dialog->set( 'profile', 'my profile2' );
  $loop->run unless ($flag);

  ######################################

  # need a new main loop because of the timeout
  $loop   = Glib::MainLoop->new;
  $flag   = FALSE;
  $signal = $dialog->signal_connect(
   'changed-scan-option' => sub {
    my ( $widget, $option, $value ) = @_;
    is( $dialog->get('profile'),
     undef, 'changing an option deselects the current profile' );
    is_deeply(
     $dialog->get('current-scan-options'),
     [ { mode => 'Color' }, { $resolution => 51 } ],
     'current-scan-options without profile'
    );
    $dialog->signal_handler_disconnect($signal);
    $flag = TRUE;
    $loop->quit;
   }
  );
  my $options = $dialog->get('available-scan-options');
  $dialog->set_option( $options->by_name($resolution), 51 );
  $loop->run unless ($flag);

  ######################################

  # need a new main loop because of the timeout
  $loop = Glib::MainLoop->new;
  $flag = FALSE;

  # Reset profile for next test
  $signal = $dialog->signal_connect(
   'changed-profile' => sub {
    my ( $widget, $profile ) = @_;
    is( $profile, 'my profile', 'reset profile' );
    $dialog->signal_handler_disconnect($signal);
    $flag = TRUE;
    $loop->quit;
   }
  );
  $dialog->set( 'profile', 'my profile' );
  $loop->run unless ($flag);

  ######################################

  # need a new main loop because of the timeout
  $loop   = Glib::MainLoop->new;
  $flag   = FALSE;
  $signal = $dialog->signal_connect(
   'changed-profile' => sub {
    my ( $widget, $profile ) = @_;
    is( $profile, undef,
     'changing an option fires the changed-profile signal if a profile is set'
    );
    is_deeply(
     $dialog->get('current-scan-options'),
     [ { $resolution => 52 }, { mode => 'Gray' } ],
     'current-scan-options without profile (again)'
    );
    my $reloaded_options = $dialog->get('available-scan-options');
    is( $reloaded_options->by_name($resolution)->{val},
     52, 'option value updated when reloaded' );
    $dialog->signal_handler_disconnect($signal);
    $flag = TRUE;
    $loop->quit;
   }
  );
  $options = $dialog->get('available-scan-options');
  $dialog->set_option( $options->by_name('mode'), 'Gray' );
  $loop->run unless ($flag);

  ######################################

  $dialog->set( 'reload-triggers', qw(mode) );

  # need a new main loop because of the timeout
  $loop = Glib::MainLoop->new;
  $flag = FALSE;
  $dialog->signal_connect(
   'reloaded-scan-options' => sub {
    is_deeply(
     $dialog->get('current-scan-options'),
     [ { $resolution => 52 }, { mode => 'Color' } ],
     'setting a option with a reload trigger to a non-default value stays set'
    );
    $flag = TRUE;
    $loop->quit;
   }
  );
  $options = $dialog->get('available-scan-options');
  $dialog->set_option( $options->by_name('mode'), 'Color' );
  $loop->run unless ($flag);

  ######################################

  # need a new main loop because of the timeout
  $loop   = Glib::MainLoop->new;
  $flag   = FALSE;
  $signal = $dialog->signal_connect(
   'changed-scan-option' => sub {
    my ( $widget, $option, $value ) = @_;
    is_deeply(
     $dialog->get('current-scan-options'),
     [ { x => 11 } ],
     'map option names'
    );
    $dialog->signal_handler_disconnect($signal);
    $flag = TRUE;
    $loop->quit;
   }
  );
  $dialog->set( 'current-scan-options', [ { $brx => 11 } ] );
  $loop->run unless ($flag);

  ######################################

  $dialog->set(
   'paper-formats',
   {
    new => {
     l => 1,
     y => 50,
     x => 50,
     t => 2,
    }
   }
  );

  $dialog->add_profile( 'cli geometry',
   [ { 'Paper size' => 'new' }, { $resolution => 50 } ] );

  # need a new main loop because of the timeout
  $loop   = Glib::MainLoop->new;
  $flag   = FALSE;
  $signal = $dialog->signal_connect(
   'changed-profile' => sub {
    my ( $widget, $profile ) = @_;
    my $options = $dialog->get('available-scan-options');
    my $expected = [ { 'Paper size' => 'new' } ];
    push @$expected, { scalar(SANE_NAME_PAGE_HEIGHT) => 52 }
      if ( defined $options->by_name(SANE_NAME_PAGE_HEIGHT) );
    push @$expected, { scalar(SANE_NAME_PAGE_WIDTH) => 51 }
      if ( defined $options->by_name(SANE_NAME_PAGE_WIDTH) );
    push @$expected, { y => 50 }, { l => 1 }, { t => 2 }, { x => 50 },
      { $resolution => 50 };
    is_deeply( $dialog->get('current-scan-options'),
     $expected, 'CLI geometry option names' );
    $dialog->signal_handler_disconnect($signal);
    $flag = TRUE;
    $loop->quit;
   }
  );
  $dialog->set( 'profile', 'cli geometry' );
  $loop->run unless ($flag);

  ######################################

  $dialog->signal_connect(
   'changed-paper-formats' => sub {
    my ( $widget, $formats ) = @_;
    ok( 1, 'changed-paper-formats' );
   }
  );
  $dialog->set(
   'paper-formats',
   {
    new2 => {
     l => 0,
     y => 10,
     x => 10,
     t => 0,
    }
   }
  );

  $dialog->signal_connect(
   'changed-paper' => sub {
    my ( $widget, $paper ) = @_;
    is( $paper, 'new2', 'changed-paper' );

    my $options = $dialog->get('available-scan-options');
    my $expected = [ { 'Paper size' => 'new' }, { $resolution => 50 } ];
    push @$expected, { scalar(SANE_NAME_PAGE_HEIGHT) => 10 }
      if ( defined $options->by_name(SANE_NAME_PAGE_HEIGHT) );
    push @$expected, { scalar(SANE_NAME_PAGE_WIDTH) => 10 }
      if ( defined $options->by_name(SANE_NAME_PAGE_WIDTH) );
    push @$expected, { l => 0 }, { t => 0 }, { x => 10 }, { y => 10 };
    is_deeply( $dialog->get('current-scan-options'),
     $expected, 'CLI geometry option names after setting paper' );
   }
  );
  $dialog->set( 'paper', 'new2' );

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
    $flag = TRUE;
    Gtk2->main_quit;
   }
  );
  $dialog->set( 'num-pages',             1 );
  $dialog->set( 'page-number-increment', 1 );
  $dialog->set_option( $options->by_name('enable-test-options'), TRUE );
  $dialog->scan;
 }
);
Gtk2->main;

is( $reloads, 2, 'Final number of calls reloaded-scan-options' );
is( $dialog->get('available-scan-options')->by_name('mode')->{val},
 'Color', 'reloaded option still set to non-default value' );

__END__
