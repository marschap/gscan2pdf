use warnings;
use strict;
use Test::More tests => 13;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately

BEGIN {
    use_ok('Gscan2pdf::Dialog::Scan::CLI');
}

#########################

my $window = Gtk2::Window->new;

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

ok(
    my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
        title                  => 'title',
        'transient-for'        => $window,
        'logger'               => $logger,
        'visible-scan-options' => { mode => 1 },
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::CLI' );

is_deeply(
    $dialog->get('visible-scan-options'),
    { mode => 1 },
    'initial visible-scan-options'
);

my $signal;
$signal = $dialog->signal_connect(
    'changed-option-visibility' => sub {
        pass('changed-option-visibility');

        is_deeply(
            $dialog->get('visible-scan-options'),
            { mode => 0 },
            'updated visible-scan-options'
        );
        $dialog->signal_handler_disconnect($signal);

        $dialog->set( 'visible-scan-options', { mode => 1 } );
        is_deeply(
            $dialog->get('visible-scan-options'),
            { mode => 1 },
            'reset visible-scan-options'
        );
    }
);
$dialog->set( 'visible-scan-options', { mode => 0 } );

$dialog->signal_connect(
    'changed-device-list' => sub {
        pass('changed-device-list');

        is_deeply(
            $dialog->get('device-list'),
            [ { 'name' => 'test', 'model' => 'test', 'label' => 'test' } ],
            'add model field if missing'
        );

        $signal = $dialog->signal_connect(
            'changed-device' => sub {
                my ( $widget, $name ) = @_;
                is( $name, 'test', 'changed-device' );
                $dialog->signal_handler_disconnect($signal);
            }
        );
        $dialog->set( 'device', 'test' );
    }
);
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );

$signal = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        pass('reloaded-scan-options');
        $dialog->signal_handler_disconnect($signal);

        is( $dialog->{option_widgets}{mode}->visible,
            TRUE, 'mode widget visible' );

        $dialog->set( 'visible-scan-options', { mode => 0 } );
        is( $dialog->{option_widgets}{mode}->visible,
            '', 'mode widget hidden by title' );
        Gtk2->main_quit;
    }
);
Gtk2->main;

__END__
