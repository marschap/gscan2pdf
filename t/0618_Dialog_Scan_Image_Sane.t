use warnings;
use strict;
use Test::More tests => 1;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums

BEGIN {
    use Gscan2pdf::Dialog::Scan::Image_Sane;
}

#########################

my $window = Gtk2::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        $dialog->signal_connect(
            'changed-scan-option' => sub {
                $dialog->set( 'num-pages',             0 );
                $dialog->set( 'page-number-increment', 2 );
                $dialog->scan;
            }
        );

        # The test dialog conveniently gives us
        #    Source = Automatic Document Feeder,
        # which returns SANE_STATUS_NO_DOCS after the 10th scan.
        # Test that we catch this scanning reverse pages
        # this should also unblock num-page to allow-batch-flatbed
        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name('source'),
            'Automatic Document Feeder' );

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
                    $flag = TRUE;
                    $loop->quit;
                }
            }
        );
        $dialog->scan;
        $loop->run unless ($flag);

        $dialog->set( 'side-to-scan',      'reverse' );
        $dialog->set( 'page-number-start', 20 );
        $dialog->set( 'max-pages',         10 );
        $dialog->signal_connect(
            'process-error' => sub {
                my ( $widget, $msg ) = @_;
                fail 'Should not throw error';
                Gtk2->main_quit;
            }
        );
        $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
                    pass 'Finished scanning reverse pages';
                    Gtk2->main_quit;
                }
            }
        );
        $dialog->scan;
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

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
