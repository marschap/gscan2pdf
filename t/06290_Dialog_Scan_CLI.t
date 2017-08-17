use warnings;
use strict;
use Test::More tests => 2;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums
use Sub::Override;          # Override Frontend::CLI to test functionality that
                            # we can't with the test backend

BEGIN {
    use Gscan2pdf::Dialog::Scan::CLI;
}

#########################

my $window = Gtk2::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

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
        'name'            => SANE_NAME_SCAN_TL_X,
        'constraint_type' => 1
    },
    {
        'cap'             => 5,
        'constraint_type' => 1,
        'name'            => SANE_NAME_SCAN_TL_Y,
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
        name         => SANE_NAME_SCAN_BR_X,
        title        => 'Bottom-right x',
        desc         => 'Bottom-right x position of scan area.',
        'val'        => '215.899993896484',
        'type'       => 2,
        'constraint' => {
            'max'   => '215.899993896484',
            'min'   => '0',
            'quant' => '0'
        },
        'cap'             => 5,
        'constraint_type' => 1
    },
    {
        'val'        => '296.925994873047',
        name         => SANE_NAME_SCAN_BR_Y,
        title        => 'Bottom-right y',
        desc         => 'Bottom-right y position of scan area.',
        'max_values' => 1,
        'unit'       => 3,
        'constraint' => {
            'min'   => '0',
            'quant' => '0',
            'max'   => '296.925994873047'
        },
        'type'            => 2,
        'cap'             => 5,
        'constraint_type' => 1,
    }
];

my $override = Sub::Override->new;
$override->replace(
    'Gscan2pdf::Frontend::CLI::find_scan_options' => sub {
        my ( $class, %options ) = @_;
        if ( defined $options{started_callback} ) {
            $options{started_callback}->();
        }
        if ( defined $options{options}{data}{backend} ) {
            my ( $key, $value ) = each %{ $options{options}{data}{backend}[0] };
            if ( $key eq 'source' and $value eq 'ADF' ) {
                for (qw(3 5)) {
                    $options->[$_]{constraint}{max} = 800;
                }
            }
        }
        if ( defined $options{finished_callback} ) {
            $options{finished_callback}
              ->( Gscan2pdf::Scanner::Options->new_from_data($options) );
        }
        return;
    }
);

Gscan2pdf::Frontend::CLI->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);
$dialog->set( 'reload-triggers', ['source'] );
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

my $signal = $dialog->signal_connect(
    'changed-device-list' => sub {

        my $signal;
        $signal = $dialog->signal_connect(
            'changed-device' => sub {
                my ( $widget, $name ) = @_;
                $dialog->signal_handler_disconnect($signal);
            }
        );
        $dialog->set( 'device', 'test' );
    }
);

# give gtk a chance to hit the main loop before starting
Glib::Idle->add( sub { $dialog->set( 'device-list', [ { 'name' => 'test' } ] ) }
);

Gtk2->main;

__END__
