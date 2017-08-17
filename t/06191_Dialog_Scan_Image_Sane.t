use warnings;
use strict;
use Test::More tests => 3;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums
use Sub::Override;    # Override Frontend::Image_Sane to test functionality that
                      # we can't with the test backend
use Storable qw(freeze);    # For cloning the options cache

BEGIN {
    use Gscan2pdf::Dialog::Scan::Image_Sane;
}

#########################

my $window = Gtk2::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

# The overrides must occur before the thread is spawned in setup.
my $override = Sub::Override->new;
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_get_devices' => sub {
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
    'Gscan2pdf::Frontend::Image_Sane::_thread_open_device' => sub {
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
        'val'        => 'Flatbed',
        'title'      => 'Scan source',
        'unit'       => 0,
        'max_values' => 1,
        'constraint' => [ 'Flatbed', 'ADF', 'Duplex' ],
        'desc'       => 'Selects the scan source (such as a document-feeder).',
        'type'       => 3,
        'cap'        => 5,
        'constraint_type' => 3,
        'name'            => 'source'
    },
    {
        'unit'       => 3,
        'max_values' => 1,
        'title'      => 'Top-left x',
        'val'        => '0',
        'type'       => 2,
        'desc'       => 'Top-left x position of scan area.',
        'constraint' => {
            'max'   => '215.899993896484',
            'min'   => '0',
            'quant' => '0'
        },
        'cap'             => 5,
        'name'            => 'tl-x',
        'constraint_type' => 1
    },
    {
        'cap'             => 5,
        'constraint_type' => 1,
        'name'            => 'tl-y',
        'val'             => '0',
        'title'           => 'Top-left y',
        'unit'            => 3,
        'max_values'      => 1,
        'desc'            => 'Top-left y position of scan area.',
        'constraint'      => {
            'quant' => '0',
            'min'   => '0',
            'max'   => '296.925994873047'
        },
        'type' => 2
    },
    {
        'unit'       => 3,
        'max_values' => 1,
        'title'      => 'Bottom-right x',
        'val'        => '215.899993896484',
        'type'       => 2,
        'constraint' => {
            'max'   => '215.899993896484',
            'min'   => '0',
            'quant' => '0'
        },
        'desc'            => 'Bottom-right x position of scan area.',
        'cap'             => 5,
        'name'            => 'br-x',
        'constraint_type' => 1
    },
    {
        'val'        => '296.925994873047',
        'title'      => 'Bottom-right y',
        'max_values' => 1,
        'unit'       => 3,
        'desc'       => 'Bottom-right y position of scan area.',
        'constraint' => {
            'min'   => '0',
            'quant' => '0',
            'max'   => '296.925994873047'
        },
        'type'            => 2,
        'cap'             => 5,
        'constraint_type' => 1,
        'name'            => 'br-y'
    }
];
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_get_options' => sub {
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
    'Gscan2pdf::Frontend::Image_Sane::_thread_set_option' => sub {
        my ( $self, $uuid, $index, $value ) = @_;
        my $info = 0;
        if ( $index == 1 and $value = 'ADF' ) {
            for (qw(3 5)) {
                $options->[$_]{constraint}{max} = 800;
            }
            $info = SANE_INFO_RELOAD_OPTIONS;
        }
        $options->[$index]{val} = $value;
        if ( $info & SANE_INFO_RELOAD_OPTIONS ) {
            Gscan2pdf::Frontend::Image_Sane::_thread_get_options( $self,
                $uuid );
        }
        else {
            $self->{return}->enqueue(
                {
                    type    => 'finished',
                    process => 'set-option',
                    uuid    => $uuid,
                    status  => SANE_STATUS_GOOD,
                }
            );
        }
        return;
    }
);

Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
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
        $dialog->set(
            'paper-formats',
            {
                'US Letter' => {
                    'y' => 279,
                    'l' => 0,
                    't' => 0,
                    'x' => 216
                },
                'US Legal' => {
                    't' => 0,
                    'l' => 0,
                    'y' => 356,
                    'x' => 216
                }
            }
        );
        is_deeply( $dialog->{ignored_paper_formats},
            ['US Legal'], 'flatbed paper' );

        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                is_deeply( $dialog->{ignored_paper_formats},
                    undef, 'ADF paper' );
                Gtk2->main_quit;
            }
        );
        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name('source'), 'ADF' );
    }
);
$dialog->get_devices;

Gtk2->main;

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
