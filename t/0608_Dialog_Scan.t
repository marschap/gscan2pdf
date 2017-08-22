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
Log::Log4perl->easy_init($FATAL);
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

my $raw_options = [
    undef,
    {
        'unit'            => 4,
        'constraint_type' => 2,
        'cap'             => 5,
        'index'           => 1,
        'desc'            => 'Sets the resolution of the scanned image.',
        'title'           => 'Scan resolution',
        'type'            => 1,
        'val'             => 75,
        'name'            => 'resolution',
        'max_values'      => 1,
        'constraint'      => [ 100, 200, 300, 600 ]
    },
    {
        'type'       => 3,
        'val'        => 'ADF',
        'max_values' => 1,
        'name'       => 'source',
        'constraint' => [ 'Flatbed', 'ADF' ],
        'title'      => 'Scan source',
        'desc'       => 'Selects the scan source (such as a document-feeder).',
        'index'      => 2,
        'cap'        => 5,
        'constraint_type' => 3,
        'unit'            => 0
    },
    {
        'type'       => 2,
        'val'        => 0,
        'name'       => 'tl-x',
        'max_values' => 1,
        'constraint' => {
            'min'   => 0,
            'max'   => '215.900009155273',
            'quant' => 0
        },
        'title'           => 'Top-left x',
        'desc'            => 'Top-left x position of scan area.',
        'index'           => 3,
        'cap'             => 5,
        'constraint_type' => 1,
        'unit'            => 3
    },
    {
        'desc'       => 'Top-left y position of scan area.',
        'title'      => 'Top-left y',
        'cap'        => 5,
        'index'      => 4,
        'name'       => 'tl-y',
        'max_values' => 1,
        'constraint' => {
            'min'   => 0,
            'quant' => 0,
            'max'   => '297.010681152344'
        },
        'val'             => 0,
        'type'            => 2,
        'constraint_type' => 1,
        'unit'            => 3
    },
    {
        'constraint_type' => 1,
        'unit'            => 3,
        'max_values'      => 1,
        'name'            => 'br-x',
        'constraint'      => {
            'min'   => 0,
            'max'   => '215.900009155273',
            'quant' => 0
        },
        'type'  => 2,
        'val'   => '215.900009155273',
        'desc'  => 'Bottom-right x position of scan area.',
        'title' => 'Bottom-right x',
        'cap'   => 5,
        'index' => 5
    },
    {
        'val'        => '297.010681152344',
        'type'       => 2,
        'name'       => 'br-y',
        'max_values' => 1,
        'constraint' => {
            'quant' => 0,
            'max'   => '297.010681152344',
            'min'   => 0
        },
        'index'           => 6,
        'cap'             => 5,
        'desc'            => 'Bottom-right y position of scan area.',
        'title'           => 'Bottom-right y',
        'unit'            => 3,
        'constraint_type' => 1
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
                info    => freeze($raw_options),
                status  => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);

# Force a reload for every option to trigger an infinite reload loop and test
# that the reload-recursion-limit is respected.
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_set_option' => sub {
        my ( $self, $uuid, $index, $value ) = @_;
        $raw_options->[$index]{val} = $value;

        # Reload
        Gscan2pdf::Frontend::Image_Sane::_thread_get_options( $self, $uuid );
        return;
    }
);

Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->set(
    'paper-formats',
    {
        'A4' => {
            'x' => 210,
            'y' => 297,
            't' => 0,
            'l' => 0
        },
    }
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

        my $signal;
        $signal = $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $dialog, $paper ) = @_;
                $dialog->signal_handler_disconnect($signal);
                Gtk2->main_quit;
            }
        );
        $dialog->set_current_scan_options(
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend =>
                      [ { 'resolution' => '100' }, { 'source' => 'Flatbed' } ],
                    frontend => { paper => 'A4' }
                }
            )
        );
    }
);
$dialog->get_devices;

Gtk2->main;
ok $dialog->get('num-reloads') < 6,
  'finished reload loops without recursion limit';

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
