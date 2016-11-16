use warnings;
use strict;
use Test::More tests => 2;
use Sane 0.05;              # To get SANE_* enums
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately

BEGIN {
    use Gscan2pdf::Dialog::Scan::CLI;
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger,
);

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        ######################################

        # Setting a profile means setting a series of options; setting the
        # first, waiting for it to finish, setting the second, and so on. If one
        # of the settings is already applied, and therefore does not fire a
        # signal, then there is a danger that the rest of the profile is not
        # set.

        $dialog->add_profile(
            'g51',
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [
                        {
                            'page-height' => '297'
                        },
                        {
                            'y' => '297'
                        },
                        {
                            'resolution' => '51'
                        },
                    ]
                }
            )
        );
        $dialog->add_profile(
            'c50',
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [
                        {
                            'page-height' => '297'
                        },
                        {
                            'y' => '297'
                        },
                        {
                            'resolution' => '50'
                        },
                    ]
                }
            )
        );

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{profile_signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{profile_signal} );
                my $optwidget    = $dialog->{option_widgets}{resolution};
                my $widget_value = $optwidget->get_value;
                is( $widget_value, 51, 'correctly updated widget' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', 'g51' );
        $loop->run unless ($flag);

        # need a new main loop because of the timeout
        $loop = Glib::MainLoop->new;
        $flag = FALSE;
        my $bry = SANE_NAME_SCAN_BR_Y;
        $dialog->{profile_signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{profile_signal} );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            {
                                $bry => '297'
                            },
                            {
                                'resolution' => '50'
                            },
                        ]
                    },
                    'fired signal and set profile'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', 'c50' );
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

#########################

__END__
