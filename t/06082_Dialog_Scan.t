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
        'type'            => 2,
        'name'            => 'tl-x',
        'unit'            => 3,
        'val'             => 0,
        'max_values'      => 1,
        'desc'            => 'Top-left x position of scan area.',
        'cap'             => 5,
        'constraint_type' => 1,
        'title'           => 'Top-left x',
        'index'           => 3,
        'constraint'      => {
            'max'   => '215.872192382812',
            'quant' => '0.0211639404296875',
            'min'   => 0
        }
    },
    {
        'cap'             => 5,
        'constraint_type' => 1,
        'title'           => 'Top-left y',
        'index'           => 4,
        'constraint'      => {
            'min'   => 0,
            'max'   => '279.364013671875',
            'quant' => '0.0211639404296875'
        },
        'type'       => 2,
        'name'       => 'tl-y',
        'unit'       => 3,
        'val'        => 0,
        'max_values' => 1,
        'desc'       => 'Top-left y position of scan area.'
    },
    {
        'constraint' => {
            'min'   => 0,
            'max'   => '279.364013671875',
            'quant' => '0.0211639404296875'
        },
        'constraint_type' => 1,
        'title'           => 'Bottom-right y',
        'cap'             => 5,
        'index'           => 5,
        'max_values'      => 1,
        'desc'            => 'Bottom-right y position of scan area.',
        'name'            => 'br-y',
        'type'            => 2,
        'val'             => '279.364013671875',
        'unit'            => 3
    },
    {
        'unit'            => 3,
        'val'             => '215.872192382812',
        'name'            => 'br-x',
        'type'            => 2,
        'desc'            => 'Bottom-right x position of scan area.',
        'max_values'      => 1,
        'index'           => 6,
        'cap'             => 5,
        'constraint_type' => 1,
        'title'           => 'Bottom-right x',
        'constraint'      => {
            'max'   => '215.872192382812',
            'quant' => '0.0211639404296875',
            'min'   => 0
        }
    },
    {
        'unit'            => 0,
        'name'            => 'swcrop',
        'constraint_type' => 0,
        'type'            => 0,
        'index'           => 7,
        'cap'             => 69,
        'val'             => 0,
        'max_values'      => 1,
        'desc'  => 'Request driver to remove border from pages digitally.',
        'title' => 'Software crop'
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

# Reload if inexact due to quant > 0 to test that this doesn't trigger an
# infinite reload loop
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_set_option' => sub {
        my ( $self, $uuid, $index, $value ) = @_;
        if (    defined $raw_options->[$index]{constraint}
            and ref( $raw_options->[$index]{constraint} ) eq 'HASH'
            and defined $raw_options->[$index]{constraint}{quant} )
        {
            $raw_options->[$index]{val} =
              int( $value / $raw_options->[$index]{constraint}{quant} + .5 ) *
              $raw_options->[$index]{constraint}{quant};

            # Reload
            if ( $value != $raw_options->[$index]{val} ) {
                Gscan2pdf::Frontend::Image_Sane::_thread_get_options( $self,
                    $uuid );
            }
        }
        else {
            $raw_options->[$index]{val} = $value;
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

$dialog->set(
    'paper-formats',
    {
        'A4' => {
            'x' => 210,
            'y' => 279,
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
                    backend => [
                        { 'resolution' => '100' },
                        { 'source'     => 'Flatbed' },
                        { 'swcrop'     => '' }
                    ],
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
