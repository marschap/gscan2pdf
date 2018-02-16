use warnings;
use strict;
use Test::More tests => 5;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums
use Sub::Override;    # Override Frontend::Image_Sane to test functionality that
                      # we can't with the test backend
use Storable qw(freeze);    # For cloning the options cache

BEGIN {
    use Gscan2pdf::Dialog::Scan::Image_Sane;
}

#########################

my $window = Gtk3::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger();

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
        'title'      => 'Brightness',
        'desc'       => 'Controls the brightness of the acquired image.',
        'unit'       => 0,
        'cap'        => 13,
        'index'      => 1,
        'name'       => 'brightness',
        'constraint' => {
            'min'   => -100,
            'max'   => 100,
            'quant' => 1
        },
        'type'            => 1,
        'val'             => 0,
        'max_values'      => 1,
        'constraint_type' => 1
    },
    {
        'index'      => 2,
        'name'       => 'contrast',
        'constraint' => {
            'quant' => 1,
            'max'   => 100,
            'min'   => -100
        },
        'max_values'      => 1,
        'val'             => 0,
        'type'            => 1,
        'constraint_type' => 1,
        'title'           => 'Contrast',
        'desc'            => 'Controls the contrast of the acquired image.',
        'cap'             => 13,
        'unit'            => 0
    },
    {
        'name'            => 'resolution',
        'index'           => 3,
        'constraint'      => [600],
        'constraint_type' => 2,
        'max_values'      => 1,
        'val'             => 600,
        'type'            => 1,
        'desc'            => 'Sets the resolution of the scanned image.',
        'title'           => 'Scan resolution',
        'cap'             => 5,
        'unit'            => 4
    },
    {
        'max_values'      => 1,
        'type'            => 1,
        'val'             => 300,
        'constraint_type' => 2,
        'index'           => 4,
        'name'            => 'x-resolution',
        'constraint'      => [ 150, 225, 300, 600, 900, 1200 ],
        'cap'             => 69,
        'unit'            => 4,
        'title'           => 'X-resolution',
        'desc' => 'Sets the horizontal resolution of the scanned image.'
    },
    {
        'index'           => 5,
        'name'            => 'y-resolution',
        'constraint'      => [ 150, 225, 300, 600, 900, 1200, 1800, 2400 ],
        'val'             => 300,
        'type'            => 1,
        'max_values'      => 1,
        'constraint_type' => 2,
        'desc'  => 'Sets the vertical resolution of the scanned image.',
        'title' => 'Y-resolution',
        'unit'  => 4,
        'cap'   => 69
    },
    {
        'desc'            => '',
        'title'           => 'Geometry',
        'cap'             => 64,
        'unit'            => 0,
        'index'           => 6,
        'max_values'      => 1,
        'type'            => 5,
        'constraint_type' => 0
    },
    {
        'title' => 'Scan area',
        'desc'  => 'Select an area to scan based on well-known media sizes.',
        'unit'  => 0,
        'cap'   => 5,
        'index' => 7,
        'constraint' => [
            'Maximum', 'A4',     'A5 Landscape', 'A5 Portrait',
            'B5',      'Letter', 'Executive',    'CD'
        ],
        'name'            => 'scan-area',
        'val'             => 'Maximum',
        'type'            => 3,
        'max_values'      => 1,
        'constraint_type' => 3
    },
    {
        'unit'            => 3,
        'cap'             => 5,
        'title'           => 'Top-left x',
        'desc'            => 'Top-left x position of scan area.',
        'val'             => 0,
        'type'            => 2,
        'max_values'      => 1,
        'constraint_type' => 1,
        'name'            => 'tl-x',
        'index'           => 8,
        'constraint'      => {
            'min'   => 0,
            'max'   => '215.899993896484',
            'quant' => 0
        }
    },
    {
        'desc'       => 'Top-left y position of scan area.',
        'title'      => 'Top-left y',
        'cap'        => 5,
        'unit'       => 3,
        'constraint' => {
            'quant' => 0,
            'min'   => 0,
            'max'   => '297.179992675781'
        },
        'index'           => 9,
        'name'            => 'tl-y',
        'constraint_type' => 1,
        'max_values'      => 1,
        'type'            => 2,
        'val'             => 0
    },
    {
        'constraint_type' => 1,
        'max_values'      => 1,
        'type'            => 2,
        'val'             => '215.899993896484',
        'index'           => 10,
        'constraint'      => {
            'min'   => 0,
            'max'   => '215.899993896484',
            'quant' => 0
        },
        'name'  => 'br-x',
        'cap'   => 5,
        'unit'  => 3,
        'desc'  => 'Bottom-right x position of scan area.',
        'title' => 'Bottom-right x'
    },
    {
        'cap'             => 5,
        'unit'            => 3,
        'desc'            => 'Bottom-right y position of scan area.',
        'title'           => 'Bottom-right y',
        'max_values'      => 1,
        'type'            => 2,
        'val'             => '297.179992675781',
        'constraint_type' => 1,
        'index'           => 11,
        'constraint'      => {
            'min'   => 0,
            'max'   => '297.179992675781',
            'quant' => 0
        },
        'name' => 'br-y'
    },
    {
        'cap'   => 5,
        'unit'  => 0,
        'title' => 'Scan source',
        'desc'  => 'Selects the scan source (such as a document-feeder).',
        'constraint_type' => 3,
        'max_values'      => 1,
        'type'            => 3,
        'val'             => 'Flatbed',
        'index'           => 12,
        'constraint'      => [ 'Flatbed', 'Automatic Document Feeder' ],
        'name'            => 'source'
    },
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
        if ( $index == 12 and $value = 'Automatic Document Feeder' ) {  # source
            $options->[10]{constraint}{max} = '215.899993896484';
            $options->[11]{constraint}{max} = '355.599990844727';
            $options->[10]{val}             = '215.899993896484';
            $options->[11]{val}             = '355.599990844727';
            $info                           = SANE_INFO_RELOAD_OPTIONS;
        }

        # x-resolution, y-resolution, scan-area
        elsif ( $index == 4 or $index == 5 or $index == 7 ) {
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

my $num_calls = 0;
$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        # loop to prevent us going on until setting applied.
        # alternatively, we could have had a lot of nesting.
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'added-profile' => sub {
                my ( $widget, $name, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $name, 'my profile', 'added-profile signal emitted' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->add_profile(
            'my profile',
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [
                        {
                            'br-x' => '210'
                        },
                        {
                            'br-y' => '297'
                        },
                        {
                            'source' => 'Automatic Document Feeder'
                        },
                        {
                            'scan-area' => 'A4'
                        },
                        {
                            'y-resolution' => '150'
                        },
                        {
                            'x-resolution' => '150'
                        },
                        {
                            'brightness' => 10
                        },
                        {
                            'contrast' => 10
                        }
                    ]
                }
            )
        );

        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                ++$num_calls;
                is( $profile, 'my profile', 'changed-profile' );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            {
                                'source' => 'Automatic Document Feeder'
                            },
                            {
                                'br-x' => 210
                            },
                            {
                                'scan-area' => 'A4'
                            },
                            {
                                'br-y' => 297
                            },
                            {
                                'y-resolution' => '150'
                            },
                            {
                                'x-resolution' => '150'
                            },
                            {
                                'brightness' => 10
                            },
                            {
                                'contrast' => 10
                            }
                        ],

                        'frontend' => {
                            'num_pages' => 0
                        }
                    },
                    'profile with multiple reloads'
                );
                Glib::Idle->add( sub { Gtk3->main_quit } );
            }
        );
        $dialog->set( 'profile', 'my profile' );
    }
);
$dialog->get_devices;

Gtk3->main;
is( $num_calls, 1, 'changed-profile only called once' );

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
