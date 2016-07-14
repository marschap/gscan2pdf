use warnings;
use strict;
use Test::More tests => 7;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Sane 0.05;              # To get SANE_* enums

BEGIN {
    use Gscan2pdf::Dialog::Scan::CLI;
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

my $profile_changes = 0;
$dialog->{signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{signal} );

        # v1.3.8 had the bug that having applied geometry settings via a paper
        # size, if a profile was set that changed the geometry, the paper size
        # was not unset.
        $dialog->set(
            'paper-formats',
            {
                '10x10' => {
                    l => 0,
                    y => 10,
                    x => 10,
                    t => 0,
                }
            }
        );

        # loop to prevent us going on until setting applied.
        # alternatively, we could have had a lot of nexting.
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $widget, $paper ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'paper', '10x10' );
        $loop->run unless ($flag);

        $dialog->add_profile(
            '20x20',
            {
                backend => [
                    {
                        'tl-y' => '20'
                    },
                ]
            }
        );

        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $paper ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $dialog->get('paper'),
                    undef, 'paper undefined after changing geometry' );
                is( $dialog->{combobp}->get_active_text,
                    'Manual', 'paper undefined means manual geometry' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', '20x20' );
        $loop->run unless ($flag);

        # If a profile is set, and setting a paper changes the geometry,
        # the profile should be unset.
        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $widget, $paper ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $dialog->get('profile'),
                    undef, 'profile undefined after changing geometry' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'paper', '10x10' );
        $loop->run unless ($flag);

        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $widget, $paper ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $dialog->get('paper'),
                    undef, 'manual geometry means undefined paper' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        Gscan2pdf::Dialog::Scan::set_combobox_by_text( $dialog->{combobp},
            'Manual' );
        $loop->run unless ($flag);

        $dialog->add_profile(
            '10x10',
            {
                backend => [
                    {
                        'tl-y' => '0'
                    },
                    {
                        'tl-x' => '0'
                    },
                    {
                        'br-y' => '10'
                    },
                    {
                        'br-x' => '10'
                    },
                ],
                frontend => { paper => '10x10' }
            }
        );

        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $paper ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $dialog->get_paper_by_geometry,
                    '10x10', 'get_paper_by_geometry()' );
                is( $dialog->get('paper'),
                    '10x10', 'paper size updated after changing profile' );
                is( $dialog->{combobp}->get_active_text,
                    '10x10', 'paper undefined means manual geometry' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', '10x10' );
        $loop->run unless ($flag);

        Gtk2->main_quit;
    }
);
$dialog->set( 'device', 'test' );
$dialog->scan_options;
Gtk2->main;

__END__
