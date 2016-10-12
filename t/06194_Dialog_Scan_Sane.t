use warnings;
use strict;
use Test::More tests => 2;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane 0.05;              # To get SANE_* enums
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
        'type'       => 2,
        'max_values' => 1,
        'desc' =>
'Bottom-right y position of scan area. You should use it in "User defined" mode only!',
        'index'           => 14,
        'constraint_type' => 1,
        'constraint'      => {
            'quant' => '0',
            'min'   => '0',
            'max'   => '355.599990844727'
        },
        'name'  => 'br-y',
        'val'   => '355.599990844727',
        'cap'   => 5,
        'unit'  => 3,
        'title' => 'br-y'
    },
    {
        'max_values' => 1,
        'type'       => 3,
        'desc'       => 'Scan mode',
        'index'      => 2,
        'name'       => 'mode',
        'constraint' =>
          [ 'Gray', 'Color', 'Black & White', 'Error Diffusion', 'ATEII' ],
        'constraint_type' => 3,
        'val'             => 'Gray',
        'cap'             => 5,
        'unit'            => 0,
        'title'           => 'Scan mode'
    },
    {
        'max_values' => 1,
        'type'       => 2,
        'index'      => 11,
        'desc' =>
'Top-left x position of scan area. You should use it in "User defined" mode only!',
        'val'             => '0',
        'constraint_type' => 1,
        'name'            => 'tl-x',
        'constraint'      => {
            'min'   => '0',
            'max'   => '216',
            'quant' => '0'
        },
        'title' => 'tl-x',
        'cap'   => 5,
        'unit'  => 3
    },
    {
        'val'             => 150,
        'name'            => 'resolution',
        'constraint'      => [ 150, 200, 300, 400, 600 ],
        'constraint_type' => 2,
        'title'           => 'Scan resolution',
        'cap'             => 5,
        'unit'            => 4,
        'type'            => 1,
        'max_values'      => 1,
        'desc'            => 'Scan resolution',
        'index'           => 3
    },
    {
        'desc' =>
'Top-left y position of scan area. You should use it in "User defined" mode only!',
        'index'           => 12,
        'type'            => 2,
        'max_values'      => 1,
        'title'           => 'tl-y',
        'cap'             => 5,
        'unit'            => 3,
        'val'             => '0',
        'constraint_type' => 1,
        'name'            => 'tl-y',
        'constraint'      => {
            'max'   => '355.599990844727',
            'min'   => '0',
            'quant' => '0'
        }
    },
    {
        'type'            => 3,
        'max_values'      => 1,
        'desc'            => 'scanmode,choose simplex or duplex scan',
        'index'           => 8,
        'val'             => 'Simplex',
        'constraint'      => [ 'Simplex', 'Duplex' ],
        'name'            => 'ScanMode',
        'constraint_type' => 3,
        'title'           => 'ScanMode',
        'cap'             => 5,
        'unit'            => 0
    },
    {
        'constraint' => {
            'min'   => '0',
            'max'   => '216',
            'quant' => '0'
        },
        'name'            => 'br-x',
        'constraint_type' => 1,
        'val'             => '216',
        'unit'            => 3,
        'cap'             => 5,
        'title'           => 'br-x',
        'type'            => 2,
        'max_values'      => 1,
        'desc' =>
'Bottom-right x position of scan area. You should use it in "User defined" mode only!',
        'index' => 13
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
        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                is $dialog->get('num-pages'), 1,
                  'num-pages reset to 1 because no source option';
                Gtk2->main_quit;
            }
        );
        my $options = $dialog->get('available-scan-options');
        $dialog->set( 'num-pages', 2 );
        $dialog->set_option( $options->by_name('ScanMode'), 'Duplex' );
    }
);
$dialog->get_devices;

Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;
__END__
