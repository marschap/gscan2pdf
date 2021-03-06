use warnings;
use strict;
use Test::More tests => 2;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums

BEGIN {
    use Gscan2pdf::Dialog::Scan::Image_Sane;
}

#########################

my $window = Gtk3::Window->new;

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

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    { backend => [ { 'enable-test-options' => 1 } ] },
                    'enabled test options'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name('enable-test-options'), TRUE );
        $loop->run unless ($flag);

        # have to use changed-scan-option callback because profile now undef
        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            { 'enable-test-options' => 1 },
                            { 'button'              => undef }
                        ]
                    },
                    'button'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_option( $options->by_name('button') );
        $loop->run unless ($flag);

        Gtk3->main_quit;
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
Gtk3->main;

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
