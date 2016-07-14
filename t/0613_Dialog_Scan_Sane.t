use warnings;
use strict;
use Test::More tests => 1;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane 0.05;              # To get SANE_* enums

BEGIN {
    use Gscan2pdf::Dialog::Scan::Sane;
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        ######################################

        # So that it can be used in hash
        my $resolution = SANE_NAME_SCAN_RESOLUTION;

        $dialog->{signal} = $dialog->signal_connect(
            'changed-current-scan-options' => sub {
                my ( $widget, $option_array ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                Gtk2->main_quit;
                is_deeply(
                    $option_array,
                    { backend => [ { $resolution => 51 }, ] },
                    'emitted changed-current-scan-options'
                );
            }
        );
        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name($resolution), 51 );
    }
);
$dialog->{signal} = $dialog->signal_connect(
    'changed-device-list' => sub {
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        $dialog->set( 'device', 'test:0' );
    }
);
$dialog->set( 'device-list',
    [ { 'name' => 'test:0' }, { 'name' => 'test:1' } ] );
Gtk2->main;

Gscan2pdf::Frontend::Sane->quit;
__END__
