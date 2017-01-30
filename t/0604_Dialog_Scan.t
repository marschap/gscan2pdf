use warnings;
use strict;
use Test::More tests => 1;
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

# A Canon Lide 220 was producing scanimage output without a val for source,
# producing the error: Use of uninitialized value in pattern match (m//)
# when loading the options. Override enough to test for this.
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
        'name'            => 'source',
        'title'           => 'Source',
        'unit'            => 0,
        'type'            => 3,
        'max_values'      => 1,
        'cap'             => 37,
        'desc'       => 'Selects the scan source (such as a document-feeder).',
        'index'      => 3,
        'constraint' => [ 'Flatbed', 'Transparency Adapter' ]
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
        $options->[$index]{val} = $value;
        Gscan2pdf::Frontend::Sane::_thread_get_options( $self, $uuid );
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
        $dialog->set_option( $options->by_name('source'), 'Flatbed' );
    }
);
$dialog->get_devices;

Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;
__END__
