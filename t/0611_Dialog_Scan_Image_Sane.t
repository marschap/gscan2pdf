use warnings;
use strict;
use Test::More tests => 6;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums

BEGIN {
    use_ok('Gscan2pdf::Dialog::Scan::Image_Sane');
}

#########################

my $window = Gtk2::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Image_Sane->setup($logger);

ok(
    my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
        title           => 'title',
        'transient-for' => $window,
        'logger'        => $logger
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::Image_Sane' );

my $signal;
$signal = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect($signal);

        # So that it can be used in hash
        my $resolution = SANE_NAME_SCAN_RESOLUTION;

        $dialog->add_profile(
            'my profile',
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [ { $resolution => 52 } ]
                }
            )
        );

        my $loop;
        my $option_signal;
        $option_signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    { backend => [ { $resolution => 52 } ] },
                    'current-scan-options'
                );
                $dialog->signal_handler_disconnect($option_signal);
                $loop->quit;
            }
        );
        $signal = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect($signal);
                is( $profile, 'my profile', 'changed-profile' );
            }
        );

        # need a new main loop because of the timeout
        $loop = Glib::MainLoop->new;
        $dialog->set( 'profile', 'my profile' );
        $loop->run;

        $dialog->signal_connect(
            'reloaded-scan-options' => sub {
                is( $dialog->get('profile'),
                    undef, 'reloading scan options unsets profile' );
                Gtk2->main_quit;
            }
        );
        $dialog->scan_options('test');
    }
);
$dialog->set( 'device', 'test' );
$dialog->scan_options('test');
Gtk2->main;

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
