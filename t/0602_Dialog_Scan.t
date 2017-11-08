use warnings;
use strict;
use Test::More tests => 20;
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
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->set(
    'paper-formats',
    {
        new => {
            l => 0,
            y => 10,
            x => 10,
            t => 0,
        }
    }
);

$dialog->set( 'num-pages', 2 );

my $profile_changes = 0;
my $signal;
$signal = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect($signal);

        my $options = $dialog->get('available-scan-options');

        # v1.3.7 had the bug that profiles were not being saved properly,
        # due to the profiles not being cloned in the set and get routines

        # need a new main loop to avoid nesting
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-x'), 10 );
        $loop->run unless ($flag);

        $loop   = Glib::MainLoop->new;
        $flag   = FALSE;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-y'), 10 );
        $loop->run unless ($flag);

        $dialog->save_current_profile('profile 1');
        is_deeply(
            $dialog->{profiles},
            {
                'profile 1' => {
                    data => {
                        backend => [
                            {
                                'tl-x' => '10'
                            },
                            {
                                'tl-y' => '10'
                            },
                        ]
                    }
                }
            },
            'applied 1st profile'
        );

        $loop   = Glib::MainLoop->new;
        $flag   = FALSE;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-x'), 20 );
        $loop->run unless ($flag);

        $loop   = Glib::MainLoop->new;
        $flag   = FALSE;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-y'), 20 );
        $loop->run unless ($flag);

        $dialog->save_current_profile('profile 2');
        is_deeply(
            $dialog->{profiles},
            {
                'profile 1' => {
                    data => {
                        backend => [
                            {
                                'tl-x' => '10'
                            },
                            {
                                'tl-y' => '10'
                            },
                        ]
                    }
                },
                'profile 2' => {
                    data => {
                        backend => [
                            {
                                'tl-x' => '20'
                            },
                            {
                                'tl-y' => '20'
                            },
                        ]
                    }
                },
            },
            'applied 2nd profile without affecting 1st'
        );

        $dialog->remove_profile('profile 1');
        is_deeply(
            $dialog->{profiles},
            {
                'profile 2' => {
                    data => {
                        backend => [
                            {
                                'tl-x' => '20'
                            },
                            {
                                'tl-y' => '20'
                            },
                        ]
                    }
                },
            },
            'remove_profile()'
        );

        is $options->by_name('source')->{val}, 'Flatbed',
          'source defaults to Flatbed';
        is $dialog->get('num-pages'), 1,
          'allow-batch-flatbed should force num-pages';
        is $dialog->{framen}->is_sensitive, FALSE, 'num-page gui ghosted';
        $dialog->set( 'num-pages', 2 );
        is $dialog->get('num-pages'), 1,
          'allow-batch-flatbed should force num-pages2';

        is $dialog->{checkx}->visible, FALSE,
          'flatbed, so hide checkbox for extended page numbering';
        is $dialog->{framex}->visible, FALSE,
          'flatbed, so hide frame for extended page numbering';
        is $dialog->{frames}->visible, FALSE,
          'flatbed, so hide frame for page side radio buttons';

        $dialog->set( 'allow-batch-flatbed', TRUE );
        $dialog->set( 'num-pages',           2 );
        $signal = $dialog->signal_connect(
            'changed-num-pages' => sub {
                $dialog->signal_handler_disconnect($signal);
                is $dialog->get('num-pages'), 1,
                  'allow-batch-flatbed should force num-pages3';
                is $dialog->{framen}->is_sensitive, FALSE,
                  'num-page gui ghosted2';
            }
        );
        $dialog->set( 'allow-batch-flatbed', FALSE );

        # need a new main loop to avoid nesting
        $loop = Glib::MainLoop->new;
        $flag = FALSE;
        is $dialog->get('adf-defaults-scan-all-pages'), 1,
          'default adf-defaults-scan-all-pages';
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                if ( $option eq 'source' ) {
                    $dialog->signal_handler_disconnect($signal);
                    is $dialog->get('num-pages'), 0,
                      'adf-defaults-scan-all-pages should force num-pages';
                    $flag = TRUE;
                    $loop->quit;
                }
            }
        );
        $dialog->set_option( $options->by_name('source'),
            'Automatic Document Feeder' );
        $loop->run unless ($flag);

        # need a new main loop to avoid nesting
        $loop   = Glib::MainLoop->new;
        $flag   = FALSE;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect($signal);
                $dialog->set( 'num-pages', 1 );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_option( $options->by_name('source'), 'Flatbed' );
        $loop->run unless ($flag);

        $dialog->set( 'adf-defaults-scan-all-pages', 0 );
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect($signal);
                is $dialog->get('num-pages'), 1,
                  'adf-defaults-scan-all-pages should force num-pages 2';

                is $dialog->{checkx}->visible, TRUE,
                  'simplex ADF, so hide checkbox for extended page numbering';
                is $dialog->{framex}->visible, TRUE,
                  'simplex ADF, so hide frame for extended page numbering';
                is $dialog->{frames}->visible, TRUE,
                  'simplex ADF, so hide frame for page side radio buttons';

                Gtk2->main_quit;
            }
        );
        $dialog->set_option( $options->by_name('source'),
            'Automatic Document Feeder' );
    }
);
$dialog->set( 'device', 'test' );
$dialog->scan_options;
Gtk2->main;

is( Gscan2pdf::Dialog::Scan::get_combobox_num_rows( $dialog->{combobp} ),
    3, 'available paper reapplied after setting/changing device' );
is( $dialog->{combobp}->get_active_text,
    'Manual', 'paper combobox has a value' );

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
