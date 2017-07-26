use warnings;
use strict;
use Test::More tests => 3;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums
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
        'name'  => 'source',
        'val'   => 'Flatbed',
        'unit'  => 0,
        'cap'   => 5,
        'index' => 1,
        'desc'  => 'Selects the scan source (such as a document-feeder).',
        'title' => 'Scan source',
        'constraint_type' => 3,
        'type'            => 3,
        'constraint'      => [ 'Flatbed', 'ADF', 'Duplex' ],
        'max_values'      => 1
    },
    {
        'type'            => 1,
        'constraint_type' => 2,
        'constraint'      => [ 75, 100, 200, 300 ],
        'max_values'      => 1,
        'name'            => 'resolution',
        'cap'             => 5,
        'unit'            => 4,
        'val'             => 75,
        'index'           => 2,
        'desc'            => 'Sets the resolution of the scanned image.',
        'title'           => 'Scan resolution'
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
        my $info = 0;
        if ( $index == 1 and $value = 'Flatbed' ) {
            $options->[2]{constraint} = [ 75, 100, 200, 300, 600, 1200 ];
            $info = SANE_INFO_RELOAD_OPTIONS;
        }
        $options->[$index]{val} = $value;
        if ( $info & SANE_INFO_RELOAD_OPTIONS ) {
            Gscan2pdf::Frontend::Sane::_thread_get_options( $self, $uuid );
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

        # loop to prevent us going on until setting applied.
        # alternatively, we could have had a lot of nesting.
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;

                $dialog->signal_handler_disconnect( $dialog->{signal} );

                my $res_widget = $widget->{option_widgets}{resolution};
                my $model      = $res_widget->get_model;
                my $iter       = $model->get_iter_first;
                my @list;
                while ($iter) {
                    my $info = $model->get($iter);
                    push @list, $info;
                    $iter = $model->iter_next($iter);
                }
                is_deeply(
                    \@list,
                    [ 75, 100, 200, 300, 600, 1200 ],
                    'resolution widget updated'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name('source'), 'Flatbed' );
        $loop->run unless ($flag);

       # Up to v1.8.3 had the bug that if the options in a combobox changed, the
       # values set by them were not updated
        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $value, 600, 'got 600' );
                Gtk2->main_quit;
            }
        );
        my $res_widget = $dialog->{option_widgets}{resolution};
        $res_widget->set_active(4);
    }
);
$dialog->get_devices;

Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;
__END__
