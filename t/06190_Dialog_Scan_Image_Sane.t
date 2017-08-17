use warnings;
use strict;
use Test::More tests => 2;
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

        ######################################

        # Cancel the scan immediately after starting it and test that:
        # a. the new-scan signal is not emitted.
        # b. we can successfully scan afterwards

        $dialog->set( 'num-pages', 2 );

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        my $n    = 0;
        $dialog->{start_signal} = $dialog->signal_connect(
            'started-process' => sub {
                my ( $widget, $process ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{start_signal} );
                $dialog->cancel_scan;
            }
        );
        $dialog->{new_signal} = $dialog->signal_connect(
            'new-scan' => sub {
                ++$n;
            }
        );
        $dialog->{finished_signal} = $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
                    $dialog->signal_handler_disconnect( $dialog->{new_signal} );
                    $dialog->signal_handler_disconnect(
                        $dialog->{finished_signal} );
                    $flag = TRUE;
                    ok( ( $n < 2 ), 'Did not throw new-scan signal twice' );
                    $loop->quit;
                }
            }
        );
        $dialog->scan;
        $loop->run unless ($flag);

        $dialog->{new_signal} = $dialog->signal_connect(
            'new-scan' => sub {
                $dialog->signal_handler_disconnect( $dialog->{new_signal} );
                ok 1, 'Successfully scanned after cancel';
            }
        );
        $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
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
