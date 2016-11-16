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

        # v1.5.0 introduced the property allow-batch-flatbed, disabled by
        # default. However, this prevented num_pages from defaulting to all,
        # even with Source = Automatic Document Feeder in the default scan
        # options.

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        my $signal;
        $signal = $dialog->signal_connect(
            'changed-current-scan-options' => sub {
                $dialog->signal_handler_disconnect($signal);
                is $dialog->get('num-pages'), 0, 'num-pages';
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_current_scan_options(
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    'backend' =>
                      [ { 'source' => 'Automatic Document Feeder' } ],
                    'frontend' => { 'num_pages' => '0' }
                }
            )
        );
        $loop->run unless ($flag);
        Gtk2->main_quit;
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
