use warnings;
use strict;
use Test::More tests => 10;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2 -init;             # Could just call init separately

BEGIN {
    use_ok('Gscan2pdf::Dialog::Scan::CLI');
}

#########################

my $window = Gtk2::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::CLI->setup($logger);

ok(
    my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
        title             => 'title',
        'transient-for'   => $window,
        'logger'          => $logger,
        'reload-triggers' => qw(mode),
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan::CLI' );

$dialog->set( 'cache-options', TRUE );

$dialog->signal_connect(
    'process-error' => sub {
        my ( $widget, $process, $msg ) = @_;
        Gtk2->main_quit;
    }
);

my ( $signal, $signal2 );
$signal = $dialog->signal_connect(
    'changed-options-cache' => sub {
        $dialog->signal_handler_disconnect($signal);
        is_deeply(
            $dialog->get('current-scan-options')->get_data,
            { backend => [] },
            'cached default Gray - no scan option set'
        );

        $signal = $dialog->signal_connect(
            'reloaded-scan-options' => sub {
                $dialog->signal_handler_disconnect($signal);

                $signal = $dialog->signal_connect(
                    'changed-scan-option' => sub {
                        my ( $widget, $option, $value ) = @_;
                        $dialog->signal_handler_disconnect($signal);
                        is( $option, 'source', 'setting source' );
                        is(
                            $value,
                            'Automatic Document Feeder',
                            'setting source to Automatic Document Feeder'
                        );

                        $signal = $dialog->signal_connect(
                            'reloaded-scan-options' => sub {
                                $dialog->signal_handler_disconnect($signal);
                                my $options =
                                  $dialog->get('available-scan-options');
                                is( $options->by_name('mode')->{val},
                                    'Color', 'set mode to Color' );
                                is(
                                    $options->by_name('source')->{val},
                                    'Automatic Document Feeder',
                                    'source still Automatic Document Feeder'
                                );
                                $signal = $dialog->signal_connect(
                                    'reloaded-scan-options' => sub {
                                        $dialog->signal_handler_disconnect(
                                            $signal);
                                        my $options = $dialog->get(
                                            'available-scan-options');
                                        is( $options->by_name('mode')->{val},
                                            'Gray', 'set mode to Gray' );
                                        is(
                                            $options->by_name('source')->{val},
                                            'Automatic Document Feeder',
'source still Automatic Document Feeder'
                                        );
                                        Gtk2->main_quit;
                                    }
                                );
                                $dialog->set_option(
                                    $dialog->get('available-scan-options')
                                      ->by_name('mode'),
                                    'Gray'
                                );
                            }
                        );
                        $dialog->set_option(
                            $dialog->get('available-scan-options')
                              ->by_name('mode'),
                            'Color'
                        );
                    }
                );
                $dialog->set_option(
                    $dialog->get('available-scan-options')->by_name('source'),
                    'Automatic Document Feeder' );
            }
        );
    }
);
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );
$dialog->set( 'device', 'test' );

Gtk2->main;

#########################

__END__
