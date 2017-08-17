use warnings;
use strict;
use Test::More tests => 9;
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
                    'changed-options-cache' => sub {
                        $dialog->signal_handler_disconnect($signal);
                        is_deeply(
                            $dialog->get('current-scan-options')->get_data,
                            { backend => [ { mode => 'Color' } ] },
                            'cached Color'
                        );

                        $signal2 = $dialog->signal_connect(
                            'fetched-options-cache' => sub {
                                my ( $widget, $device, $cache_key ) = @_;
                                $dialog->signal_handler_disconnect($signal2);
                                pass('fetched-options-cache');
                            }
                        );
                        $signal = $dialog->signal_connect(
                            'reloaded-scan-options' => sub {
                                $dialog->signal_handler_disconnect($signal);
                                is_deeply(
                                    $dialog->get('current-scan-options')
                                      ->get_data,
                                    { backend => [ { mode => 'Gray' } ] },
                                    'retrieved Gray from cache'
                                );

                                $signal = $dialog->signal_connect(
                                    'reloaded-scan-options' => sub {
                                        $dialog->signal_handler_disconnect(
                                            $signal);
                                        is_deeply(
                                            $dialog->get(
                                                'current-scan-options')
                                              ->get_data,
                                            {
                                                backend =>
                                                  [ { mode => 'Color' } ]
                                            },
                                            'retrieved Color from cache'
                                        );

                                        $signal = $dialog->signal_connect(
                                            'reloaded-scan-options' => sub {
                                                $dialog
                                                  ->signal_handler_disconnect(
                                                    $signal);
                                                is_deeply(
                                                    $dialog->get(
                                                        'current-scan-options')
                                                      ->get_data,
                                                    {
                                                        backend => [
                                                            { mode => 'Gray' }
                                                        ]
                                                    },
'retrieved Gray from cache #2'
                                                );
                                                Gtk2->main_quit;
                                            }
                                        );
                                        $dialog->set_option(
                                            $dialog->get(
                                                'available-scan-options')
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
                            $dialog->get('available-scan-options')
                              ->by_name('mode'),
                            'Gray'
                        );

                    }
                );
                $dialog->set_option(
                    $dialog->get('available-scan-options')->by_name('mode'),
                    'Color' );
            }
        );
    }
);
$dialog->set( 'device-list', [ { 'name' => 'test' } ] );
$dialog->set( 'device', 'test' );

Gtk2->main;

#########################

__END__
