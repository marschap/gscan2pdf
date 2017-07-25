use warnings;
use strict;
use Test::More tests => 5;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane;                   # To get SANE_* enums
use Sub::Override;          # Override Frontend::Sane to test functionality that
                            # we can't with the test backend
use Storable qw(freeze);    # For cloning the options cache

BEGIN {
    use Gscan2pdf::Dialog::Scan::Sane;
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

# The overrides must occur before the thread is spawned in setup.
my $override = Sub::Override->new;
$override->replace(
    'Gscan2pdf::Frontend::Sane::_thread_get_devices' => sub {
        my ( $self, $uuid ) = @_;
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'get-devices',
                uuid    => $uuid,
                info    => freeze(
                    [
                        {
                            'name'  => 'mock_device',
                            'label' => 'mock_device'
                        }
                    ]
                ),
                status => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);
$override->replace(
    'Gscan2pdf::Frontend::Sane::_thread_open_device' => sub {
        my ( $self, $uuid, $device_name ) = @_;
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'open-device',
                uuid    => $uuid,
                info    => freeze( \$device_name ),
                status  => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);

my $options = [
    undef,
    {
        'val'        => '299.212005615234',
        'constraint' => {
            'max'   => '299.212005615234',
            'min'   => 0,
            'quant' => 0
        },
        'unit'            => 3,
        'title'           => 'Bottom-right y',
        'name'            => 'br-y',
        'constraint_type' => 1,
        'desc'            => 'Bottom-right y position of scan area.',
        'type'            => 2,
        'cap'             => 5,
        'max_values'      => 1,
        'index'           => 1
    },
    {
        'max_values' => 1,
        'index'      => 2,
        'type'       => 2,
        'desc'       => 'Top-left x position of scan area.',
        'cap'        => 5,
        'unit'       => 3,
        'title'      => 'Top-left x',
        'name'       => 'tl-x',
        'val'        => 0,
        'constraint' => {
            'quant' => 0,
            'min'   => 0,
            'max'   => '215.900009155273'
        },
        'constraint_type' => 1
    },
    {
        'title'      => 'Top-left y',
        'name'       => 'tl-y',
        'unit'       => 3,
        'constraint' => {
            'quant' => 0,
            'min'   => 0,
            'max'   => '299.212005615234'
        },
        'val'             => 0,
        'constraint_type' => 1,
        'max_values'      => 1,
        'index'           => 3,
        'cap'             => 5,
        'type'            => 2,
        'desc'            => 'Top-left y position of scan area.'
    },
    {
        'cap'             => 5,
        'type'            => 2,
        'desc'            => 'Bottom-right x position of scan area.',
        'max_values'      => 1,
        'index'           => 4,
        'constraint_type' => 1,
        'constraint'      => {
            'quant' => 0,
            'min'   => 0,
            'max'   => '215.900009155273'
        },
        'val'   => '215.900009155273',
        'title' => 'Bottom-right x',
        'name'  => 'br-x',
        'unit'  => 3
    },
];
$override->replace(
    'Gscan2pdf::Frontend::Sane::_thread_get_options' => sub {
        my ( $self, $uuid ) = @_;
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'get-options',
                uuid    => $uuid,
                info    => freeze($options),
                status  => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);
$override->replace(
    'Gscan2pdf::Frontend::Sane::_thread_set_option' => sub {
        my ( $self, $uuid, $index, $value ) = @_;
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'set-option',
                uuid    => $uuid,
                status  => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);

Gscan2pdf::Frontend::Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->{signal} = $dialog->signal_connect(
    'changed-device-list' => sub {
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        is_deeply(
            $dialog->get('device-list'),
            [
                {
                    'name'  => 'mock_device',
                    'model' => 'mock_device',
                    'label' => 'mock_device'
                }
            ],
            'successfully mocked getting device list'
        );
        $dialog->set( 'device', 'mock_device' );
    }
);

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        $dialog->signal_connect(
            'changed-paper-formats' => sub {
                my ( $widget, $formats ) = @_;
                pass('changed-paper-formats');
            }
        );
        $dialog->set(
            'paper-formats',
            {
                'US Letter' => {
                    'x' => '216',
                    'l' => '0',
                    'y' => '279',
                    't' => '0'
                }
            }
        );

        $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $widget, $paper ) = @_;
                is( $paper, 'US Letter', 'changed-paper' );
                ok( not( $widget->{option_widgets}{'tl-x'}->visible ),
                    'geometry hidden' );

                my $reloaded_options = $dialog->get('available-scan-options');
                is( $reloaded_options->by_name(SANE_NAME_SCAN_BR_X)->{val},
                    215.900009155273, 'option value rounded down to max' );

                Gtk2->main_quit;
            }
        );
        $dialog->set( 'paper', 'US Letter' );
    }
);
$dialog->get_devices;

Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;
__END__
