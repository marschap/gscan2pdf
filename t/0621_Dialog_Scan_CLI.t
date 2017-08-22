use warnings;
use strict;
use Test::More tests => 46;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums

BEGIN {
    use_ok('Gscan2pdf::Dialog::Scan::CLI');
}

#########################

my $window = Gtk2::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
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
        pass('changed-device-list');

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
$dialog->set( 'allow-batch-flatbed', TRUE );
$dialog->set( 'num-pages',           0 );

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
        my $bry        = SANE_NAME_SCAN_BR_Y;
        my $tlx        = SANE_NAME_SCAN_TL_X;
        my $tly        = SANE_NAME_SCAN_TL_Y;

        $signal = $dialog->signal_connect(
            'added-profile' => sub {
                my ( $widget, $name, $profile ) = @_;
                is( $name, 'my profile', 'added-profile name' );
                is_deeply(
                    $profile->get_data,
                    {
                        backend =>
                          [ { $resolution => 52 }, { mode => 'Color' } ]
                    },
                    'added-profile profile'
                );
                $dialog->signal_handler_disconnect($signal);
            }
        );
        $dialog->add_profile(
            'my profile',
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [ { $resolution => 52 }, { mode => 'Color' } ]
                }
            )
        );

        ######################################

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $signal = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                is( $profile, 'my profile', 'changed-profile' );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend =>
                          [ { $resolution => 52 }, { mode => 'Color' } ],
                        'frontend' => { 'num_pages' => 0 }
                    },
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

        $dialog->add_profile(
            'my profile2',
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [ { $resolution => 52 }, { mode => 'Color' } ]
                }
            )
        );

        # need a new main loop because of the timeout
        $loop   = Glib::MainLoop->new;
        $flag   = FALSE;
        $signal = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                is( $profile, 'my profile2',
                    'set profile with identical options' );
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
            'changed-profile' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect($signal);
                is( $dialog->get('profile'),
                    undef, 'changing an option deselects the current profile' );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
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
        my @geometry_widgets = keys %{ $dialog->{geometry_boxes} };
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
        $signal = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                is( $profile, 'my profile', 'reset profile name' );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend =>
                          [ { $resolution => 52 }, { mode => 'Color' } ],
                        'frontend' => { 'num_pages' => 0 }
                    },
                    'reset profile options'
                );
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
                $dialog->signal_handler_disconnect($signal);
                is( $profile, undef,
'changing an option fires the changed-profile signal if a profile is set'
                );
            }
        );
        my $signal2;
        $signal2 = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $name, $value ) = @_;
                $dialog->signal_handler_disconnect($signal2);
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend =>
                          [ { $resolution => 52 }, { mode => 'Gray' } ],
                        'frontend' => { 'num_pages' => 0 }
                    },
                    'current-scan-options without profile (again)'
                );
                my $reloaded_options = $dialog->get('available-scan-options');
                is( $reloaded_options->by_name($resolution)->{val},
                    52, 'option value updated when reloaded' );
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
        $loop   = Glib::MainLoop->new;
        $flag   = FALSE;
        $signal = $dialog->signal_connect(
            'reloaded-scan-options' => sub {
                $dialog->signal_handler_disconnect($signal);
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend =>
                          [ { $resolution => 52 }, { mode => 'Color' } ],
                        'frontend' => { 'num_pages' => 0 }
                    },
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
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            { $resolution => 52 },
                            { mode        => 'Color' },
                            { $brx        => 11 },
                        ],
                        'frontend' => { 'num_pages' => 0 }
                    },
                    'map option names'
                );
                $dialog->signal_handler_disconnect($signal);
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_current_scan_options(
            Gscan2pdf::Scanner::Profile->new_from_data(
                { backend => [ { x => 11 } ] }
            )
        );
        $loop->run unless ($flag);

        ######################################

        $dialog->add_profile(
            'cli geometry',
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [
                        { l           => 1 },
                        { y           => 50 },
                        { x           => 50 },
                        { t           => 2 },
                        { $resolution => 50 }
                    ]
                }
            )
        );

        # need a new main loop because of the timeout
        $loop   = Glib::MainLoop->new;
        $flag   = FALSE;
        $signal = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                my $options = $dialog->get('available-scan-options');
                my $expected = [ { mode => 'Color' } ];
                push @$expected, { scalar(SANE_NAME_PAGE_HEIGHT) => 52 }
                  if ( defined $options->by_name(SANE_NAME_PAGE_HEIGHT) );
                push @$expected, { scalar(SANE_NAME_PAGE_WIDTH) => 51 }
                  if ( defined $options->by_name(SANE_NAME_PAGE_WIDTH) );
                push @$expected, { $tlx => 1 },
                  { $bry => 52 }, { $brx        => 51 },
                  { $tly => 2 },  { $resolution => 50 };
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend    => $expected,
                        'frontend' => { 'num_pages' => 0 }
                    },
                    'CLI geometry option names'
                );
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

        $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $widget, $paper ) = @_;
                is( $paper, 'new2', 'changed-paper' );

                my $options = $dialog->get('available-scan-options');
                my $expected = [ { mode => 'Color' }, { $resolution => 50 } ];
                push @$expected, { scalar(SANE_NAME_PAGE_HEIGHT) => 10 }
                  if ( defined $options->by_name(SANE_NAME_PAGE_HEIGHT) );
                push @$expected, { scalar(SANE_NAME_PAGE_WIDTH) => 10 }
                  if ( defined $options->by_name(SANE_NAME_PAGE_WIDTH) );
                push @$expected, { $tlx => 0 }, { $tly => 0 }, { $brx => 10 },
                  { $bry => 10 };
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend    => $expected,
                        'frontend' => { 'num_pages' => 0 }
                    },
                    'CLI geometry option names after setting paper'
                );
            }
        );
        $dialog->set( 'paper', 'new2' );

        my $s_signal;
        $s_signal = $dialog->signal_connect(
            'started-process' => sub {
                pass('started-process');
                $dialog->signal_handler_disconnect($s_signal);
            }
        );
        my $c_signal;
        $c_signal = $dialog->signal_connect(
            'changed-progress' => sub {
                pass('changed-progress');
                $dialog->signal_handler_disconnect($c_signal);
            }
        );

        # FIXME: figure out how to emit this
        #     my $e_signal;
        #     $e_signal = $dialog->signal_connect(
        #      'process-error' => sub {
        #       pass( 'process-error' );
        #       $dialog->signal_handler_disconnect($e_signal);
        #      }
        #     );
        $dialog->signal_connect(
            'new-scan' => sub {
                my ( $widget, $path, $n ) = @_;
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

is( $reloads, 3, 'Final number of calls reloaded-scan-options' );
is( $dialog->get('available-scan-options')->by_name('mode')->{val},
    'Color', 'reloaded option still set to non-default value' );
unlink 'out2.pnm';

__END__
