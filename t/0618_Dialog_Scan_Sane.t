use warnings;
use strict;
use Test::More tests => 2;
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

        # The test dialog conveniently gives us
        #    Source = Automatic Document Feeder,
        # which returns SANE_STATUS_NO_DOCS after the 10th scan.
        # Test that we catch this.

        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name('source'),
            'Automatic Document Feeder' );
        $dialog->set( 'num-pages', 0 );

        my $n = 0;
        $dialog->signal_connect(
            'new-scan' => sub {
                my ( $widget, $path, $num ) = @_;
                ++$n;
                if ( $num == 10 ) { ok 1, 'new-scan emitted with n=10' }
                if ( $n > 10 ) {
                    ok 0, 'new-scan emitted 10 times';
                    Gtk2->main_quit;
                }
            }
        );
        $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
                    is( $n, 10, 'new-scan emitted 10 times' );
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

Gscan2pdf::Frontend::Sane->quit;
__END__
