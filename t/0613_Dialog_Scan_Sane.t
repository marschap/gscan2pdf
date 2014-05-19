use warnings;
use strict;
use Test::More tests => 3;
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

        $dialog->signal_connect(
            'changed-paper-formats' => sub {
                my ( $widget, $formats ) = @_;
                is_deeply( $dialog->{ignored_paper_formats},
                    ['large'], 'ignored paper formats' );
            }
        );
        $dialog->set(
            'paper-formats',
            {
                large => {
                    l => 0,
                    y => 3000,
                    x => 3000,
                    t => 0,
                },
                small => {
                    l => 0,
                    y => 30,
                    x => 30,
                    t => 0,
                }
            }
        );

        $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $widget, $paper ) = @_;
                is( $paper, 'small', 'do not change paper if it is too big' );
            }
        );

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $flag = TRUE;
                if ( $option eq 'br-y' ) {
                    $dialog->signal_handler_disconnect( $dialog->{signal} );
                    $loop->quit;
                }
            }
        );
        $dialog->set( 'paper', 'large' );
        $dialog->set( 'paper', 'small' );
        $loop->run unless ($flag);

        ######################################

        # So that it can be used in hash
        my $resolution = SANE_NAME_SCAN_RESOLUTION;

        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                Gtk2->main_quit;
                is( $option, $resolution,
                    'set other options after ignoring non-existant one' );
            }
        );
        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name('non-existant option'),
            'dummy' );

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
