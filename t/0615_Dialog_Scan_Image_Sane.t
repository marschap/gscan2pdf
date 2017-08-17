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
Log::Log4perl->easy_init($ERROR);
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

        # There are some backends where the paper-width and -height options are
        # only valid when the ADF is active. Therefore, changing the paper size
        # when the flatbed is active tries to set these options, causing an
        # "invalid argument" error, which is normally not possible, as the
        # option is ghosted.
        # Test this by setting up a profile with "bool-soft-select-soft-detect"
        # and then a valid option. Check that:
        # a. no error message is produced
        # b. the rest of the profile is correctly applied
        # c. the appropriate signals are still emitted.

        $dialog->add_profile(
            'my profile',
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [
                        { 'bool-soft-select-soft-detect' => TRUE },
                        { mode                           => 'Color' }
                    ]
                }
            )
        );

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->signal_connect(
            'process-error' => sub { ok 0, 'Should not throw error' } );
        $dialog->{profile_signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{profile_signal} );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    { backend => [ { mode => 'Color' } ] },
                    'correctly set rest of profile'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', 'my profile' );
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

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
