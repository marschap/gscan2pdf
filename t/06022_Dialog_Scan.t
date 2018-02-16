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

# An Acer flatbed scanner using a snapscan backend had no default for the source
# option, and as it only had one possibility, which was never set, the source
# option never had a value. The numer of pages frame was therefore not ghosted
# in v1.8.11 and before.
my $raw_options = [
    undef,
    {
        'max_values' => 1,
        'title'      => 'Scan source',
        'desc'       => 'Selects the scan source (such as a document-feeder).',
        'name'       => 'source',
        'constraint_type' => 3,
        'index'           => 1,
        'constraint'      => ['Flatbed'],
        'unit'            => 0,
        'cap'             => 53,
        'type'            => 3
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

        ######################################

        my $options = $dialog->get('available-scan-options');
        ok $dialog->_flatbed_selected($options),
          '_flatbed_selected() without value';

        is $dialog->{framen}->is_sensitive, FALSE, 'num-page gui ghosted';
        $dialog->set( 'num-pages', 2 );
        is $dialog->get('num-pages'), 1,
          'allow-batch-flatbed should force num-pages';

        $dialog->set( 'allow-batch-flatbed', TRUE );
        $dialog->set( 'num-pages',           2 );
        is $dialog->get('num-pages'), 2, 'num-pages';
        ok $dialog->{framen}->is_sensitive, 'num-page gui not ghosted';

        Gtk3->main_quit;
    }
);
$dialog->get_devices;

Gtk3->main;

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
