use warnings;
use strict;
use Test::More tests => 49;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane 0.05;              # To get SANE_* enums

BEGIN {
    use_ok('Gscan2pdf::Dialog::Scan::Sane');
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Sane->setup($logger);

ok(
    my $dialog = Gscan2pdf::Dialog::Scan::Sane->new(
        title           => 'title',
        'transient-for' => $window,
        'logger'        => $logger
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::Sane' );

is( $dialog->get('device'),                '',       'device' );
is( $dialog->get('device-list'),           undef,    'device-list' );
is( $dialog->get('dir'),                   undef,    'dir' );
is( $dialog->get('num-pages'),             1,        'num-pages' );
is( $dialog->get('max-pages'),             0,        'max-pages' );
is( $dialog->get('page-number-start'),     1,        'page-number-start' );
is( $dialog->get('page-number-increment'), 1,        'page-number-increment' );
is( $dialog->get('side-to-scan'),          'facing', 'side-to-scan' );
is( $dialog->get('available-scan-options'), undef, 'available-scan-options' );

$dialog->{signal} = $dialog->signal_connect(
    'changed-num-pages' => sub {
        my ( $widget, $n, $signal ) = @_;
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        is( $n, 0, 'changed-num-pages' );
    }
);
$dialog->set( 'allow-batch-flatbed', TRUE );
$dialog->set( 'num-pages',           0 );

$dialog->{signal} = $dialog->signal_connect(
    'changed-page-number-start' => sub {
        my ( $widget, $n ) = @_;
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        is( $n, 2, 'changed-page-number-start' );
    }
);
$dialog->set( 'page-number-start', 2 );

$dialog->{signal} = $dialog->signal_connect(
    'changed-page-number-increment' => sub {
        my ( $widget, $n ) = @_;
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        is( $n, 2, 'changed-page-number-increment' );

        $dialog->{signal} = $dialog->signal_connect(
            'changed-side-to-scan' => sub {
                my ( $widget, $side ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $side, 'reverse', 'changed-side-to-scan' );
                is( $dialog->get('page-number-increment'),
                    -2, 'reverse side gives increment -2' );
            }
        );
        $dialog->set( 'side-to-scan', 'reverse' );

    }
);
$dialog->set( 'page-number-increment', 2 );

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );
        pass('reloaded-scan-options');

        # So that it can be used in hash
        my $resolution = SANE_NAME_SCAN_RESOLUTION;

        $dialog->{signal} = $dialog->signal_connect(
            'added-profile' => sub {
                my ( $widget, $name, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $name, 'my profile', 'added-profile signal emitted' );
                is_deeply(
                    $profile,
                    {
                        backend =>
                          [ { $resolution => 51 }, { mode => 'Color' } ]
                    },
                    'added-profile profile'
                );
            }
        );
        $dialog->add_profile(
            'my profile',
            {
                backend => [ { $resolution => 51 }, { mode => 'Color' } ]
            }
        );

        $dialog->{signal} = $dialog->signal_connect(
            'added-profile' => sub {
                my ( $widget, $name, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $name, 'my profile', 'replaced profile' );
                is_deeply(
                    $profile,
                    {
                        backend =>
                          [ { $resolution => 52 }, { mode => 'Color' } ]
                    },
                    'new added-profile profile'
                );
                is(
                    Gscan2pdf::Dialog::Scan::get_combobox_num_rows(
                        $dialog->{combobsp}
                    ),
                    1,
                    'replaced entry in combobox'
                );
            }
        );
        $dialog->add_profile(
            'my profile',
            {
                backend => [ { $resolution => 52 }, { mode => 'Color' } ]
            }
        );

        ######################################

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $profile, 'my profile', 'changed-profile' );
                is_deeply(
                    $dialog->get('current-scan-options'),
                    {
                        backend =>
                          [ { $resolution => 52 }, { mode => 'Color' } ],
                        'frontend' => { 'num_pages' => 0 }

                    },
                    'current-scan-options with profile'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', 'my profile' );
        $loop->run unless ($flag);

        ######################################

        $dialog->add_profile(
            'my profile2',
            {
                backend => [ { $resolution => 52 }, { mode => 'Color' } ]
            }
        );

        # need a new main loop because of the timeout
        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $profile, 'my profile2',
                    'set profile with identical options' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', 'my profile2' );
        $loop->run unless ($flag);

        ######################################

        # need a new main loop because of the timeout
        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $dialog->get('profile'),
                    undef, 'changing an option deselects the current profile' );
                is_deeply(
                    $dialog->get('current-scan-options'),
                    {
                        backend =>
                          [ { mode => 'Color' }, { $resolution => 51 } ],
                        'frontend' => { 'num_pages' => 0 }
                    },
                    'current-scan-options without profile'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name($resolution), 51 );
        $loop->run unless ($flag);
        my @geometry_widgets = keys %{ $options->{geometry} };
        cmp_ok(
            $#geometry_widgets == 3,
            '||',
            $#geometry_widgets == 5,
            'Only 4 or 6 options should be flagged as geometry'
        );

        ######################################

        # need a new main loop because of the timeout
        $loop = Glib::MainLoop->new;
        $flag = FALSE;

        # Reset profile for next test
        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $profile, 'my profile',
                    'reset profile back to my profile' );
                is_deeply(
                    $dialog->get('current-scan-options'),
                    {
                        backend =>
                          [ { $resolution => 52 }, { mode => 'Color' } ],
                        'frontend' => { 'num_pages' => 0 }
                    },
                    'current-scan-options after reset to profile my profile'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', 'my profile' );
        $loop->run unless ($flag);

        ######################################

        # need a new main loop because of the timeout
        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $profile, undef,
'changing an option fires the changed-profile signal if a profile is set'
                );
                is_deeply(
                    $dialog->get('current-scan-options'),
                    {
                        backend =>
                          [ { mode => 'Color' }, { $resolution => 51 } ],
                        'frontend' => { 'num_pages' => 0 }
                    },
                    'current-scan-options without profile (again)'
                );
                my $reloaded_options = $dialog->get('available-scan-options');
                is( $reloaded_options->by_name($resolution)->{val},
                    51, 'option value updated when reloaded' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name($resolution), 51 );
        $loop->run unless ($flag);

        ######################################

        $dialog->signal_connect(
            'removed-profile' => sub {
                my ( $widget, $profile ) = @_;
                is( $profile, 'my profile', 'removed-profile' );
            }
        );
        $dialog->remove_profile('my profile');

        ######################################

        $dialog->add_profile(
            'cli geometry',
            {
                backend => [
                    { l           => 1 },
                    { y           => 50 },
                    { x           => 50 },
                    { t           => 2 },
                    { $resolution => 50 }
                ]
            }
        );

        # need a new main loop because of the timeout
        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                my $options  = $dialog->get('available-scan-options');
                my $expected = {
                    backend    => [             { mode => 'Color' } ],
                    'frontend' => { 'num_pages' => 0 }
                };
                push @{ $expected->{backend} },
                  { scalar(SANE_NAME_PAGE_HEIGHT) => 52 }
                  if ( defined $options->by_name(SANE_NAME_PAGE_HEIGHT) );
                push @{ $expected->{backend} },
                  { scalar(SANE_NAME_PAGE_WIDTH) => 51 }
                  if ( defined $options->by_name(SANE_NAME_PAGE_WIDTH) );
                push @{ $expected->{backend} },
                  { scalar(SANE_NAME_SCAN_TL_X) => 1 },
                  { scalar(SANE_NAME_SCAN_BR_Y) => 52 },
                  { scalar(SANE_NAME_SCAN_BR_X) => 51 },
                  { scalar(SANE_NAME_SCAN_TL_Y) => 2 },
                  { $resolution                 => 50 };
                is_deeply( $dialog->get('current-scan-options'),
                    $expected, 'CLI geometry option names' );
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
                pass('changed-paper-formats');
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

        $loop = Glib::MainLoop->new;
        $flag = FALSE;
        $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $widget, $paper ) = @_;
                is( $paper, 'new2', 'changed-paper' );
                ok( not( $widget->{option_widgets}{'tl-x'}->visible ),
                    'geometry hidden' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        my $s_signal;
        $s_signal = $dialog->signal_connect(
            'started-process' => sub {
                $dialog->signal_handler_disconnect($s_signal);
                pass('started-process');
            }
        );
        my $c_signal;
        $c_signal = $dialog->signal_connect(
            'changed-progress' => sub {
                $dialog->signal_handler_disconnect($c_signal);
                pass('changed-progress');
            }
        );
        my $f_signal;
        $f_signal = $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                $dialog->signal_handler_disconnect($f_signal);
                is(
                    $process,
                    'set_option tl-x to 0',
                    'finished-process set_option'
                );
            }
        );
        $dialog->set( 'paper', 'new2' );
        $loop->run unless ($flag);

        my $n = 0;
        $dialog->signal_connect(
            'new-scan' => sub {
                my ( $widget, $status, $path ) = @_;
                ++$n;
            }
        );
        $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
                    is( $n, 1, 'new-scan emitted once' );

                    # changing device via the combobox
                    # should really change the device!
                    $dialog->{signal} = $dialog->signal_connect(
                        'changed-device' => sub {
                            my ( $widget, $name ) = @_;
                            $dialog->signal_handler_disconnect(
                                $dialog->{signal} );
                            is( $name, 'test:1',
                                'changed-device via combobox' );
                        }
                    );
                    $dialog->signal_connect(
                        'reloaded-scan-options' => sub {
                            my $e_signal;
                            $e_signal = $dialog->signal_connect(
                                'process-error' => sub {
                                    my ( $widget, $process, $message ) = @_;
                                    $dialog->signal_handler_disconnect(
                                        $e_signal);
                                    is( $process, 'open_device',
                                        'caught error opening device' );
                                    Gtk2->main_quit;
                                }
                            );

                            # setting an unknown device should throw an error
                            $dialog->set( 'device', 'error' );
                        }
                    );
                    $dialog->{combobd}->set_active(1);
                }
            }
        );
        $dialog->set( 'num-pages',         1 );
        $dialog->set( 'page-number-start', 1 );
        $dialog->set( 'side-to-scan',      'facing' );
        $dialog->scan;
    }
);
$dialog->{signal} = $dialog->signal_connect(
    'changed-device-list' => sub {
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        pass('changed-device-list');

        is_deeply(
            $dialog->get('device-list'),
            [
                {
                    'name'  => 'test:0',
                    'model' => 'test:0',
                    'label' => 'test:0'
                },
                {
                    'name'  => 'test:1',
                    'model' => 'test:1',
                    'label' => 'test:1'
                }
            ],
            'add model field if missing'
        );

        is(
            Gscan2pdf::Dialog::Scan::get_combobox_num_rows(
                $dialog->{combobd}
            ),
            3,
            'we still have the rescan item'
        );

        $dialog->{signal} = $dialog->signal_connect(
            'changed-device' => sub {
                my ( $widget, $name ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $name, 'test:0', 'changed-device' );
            }
        );
        $dialog->set( 'device', 'test:0' );
    }
);
$dialog->set( 'device-list',
    [ { 'name' => 'test:0' }, { 'name' => 'test:1' } ] );
Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;
__END__
