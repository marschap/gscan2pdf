use warnings;
use strict;
use Test::More tests => 1;
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

# $opt->{type} == SANE_TYPE_GROUP don't necessarily then have
# $opt->{name} defined, which was triggering the error:
# Use of uninitialized value in hash element
# when reloading the options. Override enough to test for this.
my $options = [
    undef,
    {
        'index'           => 1,
        'unit'            => 0,
        'cap'             => 0,
        'type'            => 5,
        'max_values'      => 0,
        'title'           => 'Scan mode',
        'constraint_type' => 0
    },
    {
        'constraint_type' => 3,
        'desc'       => 'Selects the scan source (such as a document-feeder).',
        'title'      => 'Scan source',
        'unit'       => 0,
        'index'      => 10,
        'constraint' => [ 'Auto', 'Flatbed', 'ADF' ],
        'val'        => 'Auto',
        'max_values' => 1,
        'name'       => 'source',
        'type'       => 3,
        'cap'        => 69
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
        $options->[$index]{val} = $value;
        Gscan2pdf::Frontend::Image_Sane::_thread_get_options( $self, $uuid );
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

Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->{signal} = $dialog->signal_connect(
    'changed-device-list' => sub {
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        $dialog->set( 'device', 'mock_device' );
    }
);

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );
        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                pass 'exiting via changed-scan callback';
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
